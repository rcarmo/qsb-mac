//
//  GoogleDocsSource.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Vermilion/Vermilion.h>
#import <GData/GData.h>
#import <QSBPluginUI/QSBPluginUI.h>

#import "HGSKeychainItem.h"
#import "GoogleDocsConstants.h"
#import <GTM/GTMNSEnumerator+Filter.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMTypeCasting.h>

#define kHGSTypeGoogleDoc HGS_SUBTYPE(kHGSTypeWebpage, @"googledoc")

@interface GoogleDocsSource : HGSGDataServiceSource {
 @private
  NSDictionary *docIcons_;
}

// Retrieve the authors information for a list of people associated
// with a document.
- (NSArray*)authorArrayForGDataPeople:(NSArray*)people;

// Main indexing function for each document associated with the account.
- (void)indexDoc:(GDataEntryBase *)doc
         context:(HGSGDataServiceIndexContext *)context;
- (void)docFeedTicket:(GDataServiceTicket *)ticket
     finishedWithFeed:(GDataFeedBase *)docFeed
                error:(NSError *)error;
@end

@implementation GoogleDocsSource

GTM_METHOD_CHECK(NSEnumerator,
                 gtm_enumeratorByMakingEachObjectPerformSelector:withObject:);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    // Cache the Google Docs icons
    NSImage *docImage = [self imageNamed:@"gdocdocument"];
    NSImage *presImage = [self imageNamed:@"gdocpresentation"];
    NSImage *pdfImage = [self imageNamed:@"gdocpdfdocument"];
    NSImage *spreadSheetImage = [self imageNamed:@"gdocspreadsheet"];
    docIcons_ = [[NSDictionary alloc] initWithObjectsAndKeys:
                 docImage, kDocCategoryDocument,
                 presImage, kDocCategoryPresentation,
                 pdfImage, kDocCategoryPDFDocument,
                 spreadSheetImage, kDocCategorySpreadsheet,
                 nil];
  }
  return self;
}

- (void)dealloc {
  [docIcons_ release];
  [super dealloc];
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  // If we're pivoting on docs.google.com then we can provide
  // a list of all of our docs.
  if (!isValid) {
    HGSResult *pivotObject = [query pivotObject];
    if ([pivotObject conformsToType:kHGSTypeWebApplication]) {
      NSURL *url = [pivotObject url];
      NSString *host = [url host];
      NSComparisonResult compareResult
        = [host compare:@"docs.google.com" options:NSCaseInsensitiveSearch];
      isValid = compareResult == NSOrderedSame;
    }
  }
  return isValid;
}

- (NSArray *)archiveKeys {
  NSArray *archiveKeys = [NSArray arrayWithObjects:
                          kGoogleDocsDocCategoryKey,
                          kGoogleDocsDocSaveAsIDKey,
                          kGoogleDocsWorksheetNamesKey,
                          nil];
  return archiveKeys;
}

- (NSArray*)authorArrayForGDataPeople:(NSArray*)people {
  NSMutableArray *peopleTerms
  = [NSMutableArray arrayWithCapacity:(2 * [people count])];
  NSCharacterSet *wsSet = [NSCharacterSet whitespaceCharacterSet];
  NSEnumerator *enumerator = [people objectEnumerator];
  GDataPerson *person;
  while ((person = [enumerator nextObject])) {

    NSString *authorName = [[person name] stringByTrimmingCharactersInSet:wsSet];
    if ([authorName length] > 0) {
      [peopleTerms addObject:authorName];
    }
    // Grab the author's email username as well
    NSString *authorEmail = [person email];
    NSUInteger atSignLocation = [authorEmail rangeOfString:@"@"].location;
    if (atSignLocation != NSNotFound) {
      authorEmail = [authorEmail substringToIndex:atSignLocation];
    }
    if (authorEmail && ![peopleTerms containsObject:authorEmail]) {
      [peopleTerms addObject:authorEmail];
    }
  }
  return peopleTerms;
}

#pragma mark -
#pragma mark Docs Fetching

- (GDataServiceTicket *)fetchTicketForService:(GDataServiceGoogle *)service {
  NSURL *docURL = [GDataServiceGoogleDocs docsFeedURL];
  return [service fetchFeedWithURL:docURL
                          delegate:self
                 didFinishSelector:@selector(docFeedTicket:
                                             finishedWithFeed:
                                             error:)];
}

- (Class)serviceClass {
  return [GDataServiceGoogleDocs class];
}

- (void)docFeedTicket:(GDataServiceTicket *)ticket
     finishedWithFeed:(GDataFeedBase *)docFeed
                error:(NSError *)error {
  HGSGDataServiceIndexContext *context
    = GTM_STATIC_CAST(HGSGDataServiceIndexContext, [ticket userData]);
  HGSAssert(context, nil);

  if (!error) {
    NSArray *docs = [docFeed entries];
    for (GDataEntryBase *doc in docs) {
      if ([context isCancelled]) break;
      [self indexDoc:doc context:context];
    }
  } else {
    NSString *fetchType = HGSLocalizedString(@"doc",
                                             @"A label denoting a GoogleDoc");
    [self handleErrorForFetchType:fetchType error:error];
  }
  [self ticketHandled:ticket forContext:context];
}

- (void)indexDoc:(GDataEntryBase *)doc
         context:(HGSGDataServiceIndexContext *)context {
  NSString *docTitle = [[doc title] stringValue];
  NSURL *docURL = [[doc HTMLLink] URL];
  if (!docURL) {
    return;
  }

  NSArray *categories = [doc categories];
  BOOL isSpreadsheet = [doc isKindOfClass:[GDataEntrySpreadsheet class]];
  BOOL isStarred = [GDataCategory categories:categories
                    containsCategoryWithLabel:kGDataCategoryLabelStarred];
  NSImage *icon = nil;
  NSString *categoryLabel = nil;

  if (isSpreadsheet) {
    categoryLabel = kDocCategorySpreadsheet;
  } else {
    // This doesn't work for spreadsheets because they have a different scheme.
    NSArray *kindArray = [GDataCategory categoriesWithScheme:kGDataCategoryScheme
                                              fromCategories:categories];
    if ([kindArray count]) {
      GDataCategory *category = [kindArray objectAtIndex:0];
      categoryLabel = [category label];
    }
  }

  if (categoryLabel) {
    icon = [docIcons_ objectForKey:categoryLabel];
  } else {
    categoryLabel = HGSLocalizedString(@"Unknown Google Docs Category",
                                       @"Text explaining that the category of "
                                       @"the could not be determined.");
  }
  if (!icon) {
    icon = [docIcons_ objectForKey:kDocCategoryDocument];
  }

  // Compose the contents of the path control.  First cell will be 'Google Docs',
  // followed by the account name in the second cell, with the last cell being
  // the document name.  A middle cell may be added if there is a folder, but
  // note that only the immediately containing folder will be shown even if
  // there are higher-level containing folders.
  NSURL *baseURL = [[[NSURL alloc] initWithScheme:[docURL scheme]
                                             host:[docURL host]
                                             path:@"/"]
                    autorelease];
  NSMutableArray *cellArray = [NSMutableArray array];
  NSString *docsString = HGSLocalizedString(@"Google Docs",
                                            @"A label denoting a Google Docs "
                                            @"result");
  NSDictionary *googleDocsCell
    = [NSDictionary dictionaryWithObjectsAndKeys:
       docsString, kQSBPathCellDisplayTitleKey,
       baseURL, kQSBPathCellURLKey,
       nil];
  [cellArray addObject:googleDocsCell];

  NSString *userName = [[self service] username];
  NSDictionary *userCell = [NSDictionary dictionaryWithObjectsAndKeys:
                            userName, kQSBPathCellDisplayTitleKey,
                            nil];
  [cellArray addObject:userCell];

  // See if there's an intervening folder.
  NSString *folderScheme = [kGDataNamespaceDocuments
                            stringByAppendingFormat:@"/folders/%@",
                            userName];
  NSArray *folders = [GDataCategory categoriesWithScheme:folderScheme
                                          fromCategories:categories];
  if (folders && [folders count]) {
    NSString *label = [[folders objectAtIndex:0] label];
    NSDictionary *folderCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                label, kQSBPathCellDisplayTitleKey,
                                nil];
    [cellArray addObject:folderCell];
  }

  NSDictionary *resultDocCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                 docTitle, kQSBPathCellDisplayTitleKey,
                                 docURL, kQSBPathCellURLKey,
                                 nil];
  [cellArray addObject:resultDocCell];

  // Let's consider Docs to be an extension of home.
  // TODO(stuartmorgan): maybe this should be true only for docs where the
  // user is an author (or, if we can get it from GData, "owned by me")?
  // Consider "starred" to be equivalent to things like the Dock.
  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag
                         | eHGSUserPersistentPathRankFlag];

  // We can't get last-used, so just use last-modified.
  NSDate *date = [[doc updatedDate] date];
  if (!date) {
    date = [NSDate distantPast];
  }

  NSString *flagName = isStarred ? @"star-flag" : nil;
  NSString *docID = [doc identifier];
  docID = [docID lastPathComponent];
  HGSAssert(rankFlags && cellArray && date && icon && categoryLabel && docID,
            @"Something essential is missing.");
  NSMutableDictionary *attributes
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       rankFlags, kHGSObjectAttributeRankFlagsKey,
       cellArray, kQSBObjectAttributePathCellsKey,
       date, kHGSObjectAttributeLastUsedDateKey,
       icon, kHGSObjectAttributeIconKey,
       categoryLabel, kGoogleDocsDocCategoryKey,
       docID, kGoogleDocsDocSaveAsIDKey,
       nil];
  if (flagName) {
    [attributes setObject:flagName forKey:kHGSObjectAttributeFlagIconNameKey];
  }
  HGSUnscoredResult *result = [HGSUnscoredResult resultWithURL:docURL
                                                          name:docTitle
                                                          type:kHGSTypeGoogleDoc
                                                        source:self
                                                    attributes:attributes];


  // Add other search term helpers such as the type of the document,
  // the authors, and if the document was starred.
  NSString *localizedCategory = nil;
  if ([categoryLabel isEqualToString:kDocCategoryPresentation]) {
    localizedCategory
      = HGSLocalizedString(@"presentation",
                           @"A search term indicating that this document "
                           @"is a presentation.");
  } else if ([categoryLabel isEqualToString:kDocCategoryPDFDocument]) {
    localizedCategory
      = HGSLocalizedString(@"pdf",
                           @"A search term indicating that this document "
                           @"is a PDF document.");
  } else if ([categoryLabel isEqualToString:kDocCategorySpreadsheet]) {
    localizedCategory
      = HGSLocalizedString(@"spreadsheet",
                           @"A search term indicating that this document "
                           @"is a spreadsheet.");
  } else {
    localizedCategory
      = HGSLocalizedString(@"document",
                           @"A search term indicating that this document "
                           @"is a word processing document.");
  }
  NSMutableArray *otherTerms
    = [NSMutableArray arrayWithObject:localizedCategory];
  [otherTerms addObjectsFromArray:[self authorArrayForGDataPeople:
                                   [doc authors]]];
  if (isStarred) {
    NSString *starredTerm
      = HGSLocalizedString(@"starred",
                           @"A keyword used when searching to detect items "
                           @"which have been starred by the user in "
                           @"Google Docs.");
    [otherTerms addObject:starredTerm];
  }

  [[context database] indexResult:result
                             name:docTitle
                       otherTerms:otherTerms];
}

@end

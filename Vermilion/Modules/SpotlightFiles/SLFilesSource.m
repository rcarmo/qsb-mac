//
//  SLFilesSource.m
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

#import "SLFilesSource.h"
#import <QSBPluginUI/QSBPluginUI.h>

#import "GTMMethodCheck.h"
#import "GTMGarbageCollection.h"
#import "NSNotificationCenter+MainThread.h"
#import "GTMTypeCasting.h"
#import "MDItemPrivate.h"
#import "MDQueryPrivate.h"

@interface SLFilesSource ()
@property (readonly, nonatomic) NSString *utiFilter;
@property (readonly, nonatomic) NSArray *valueListAttributes;
@property (readonly, nonatomic) NSDictionary *filterToCategoryIndexMap;
@property (readonly, nonatomic) NSArray *categories;

- (NSString*)typeFromGroup:(MDItemPrivateGroup)group;
- (NSUInteger *)groupToCategoryIndexMap;
@end

@implementation SLFilesOperation

- (id)initWithQuery:(HGSQuery*)query source:(HGSSearchSource *)source {
  if ((self = [super initWithQuery:query source:source])) {
    hgsResults_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  if (mdTopQuery_) {
    CFRelease(mdTopQuery_);
  }
  if (mdCategoryQuery_) {
    CFRelease(mdCategoryQuery_);
  }
  [hgsResults_ release];
  [resultCountByFilter_ release];
  [super dealloc];
}

CFIndex SLFilesCategoryIndexForItem(const CFTypeRef attrs[], void *context) {
  NSInteger idx = 0;
  BOOL isGood = CFNumberGetValue(attrs[0], kCFNumberNSIntegerType, &idx);
  HGSAssert(isGood, nil);
  HGSAssert(context, nil);
  HGSAssert(idx < MDItemPrivateGroupLast && idx >= MDItemPrivateGroupFirst, nil);
  NSUInteger *groupToCategoryIndexMap = (NSUInteger *)context;
  NSUInteger categoryIndex = groupToCategoryIndexMap[idx];
  return categoryIndex;
}

- (void)main {
  NSMutableArray *predicateSegments = [NSMutableArray array];

  HGSQuery* query = [self query];
  HGSResult *pivotObject = [query pivotObject];
  SLFilesSource *slSource = (SLFilesSource *)[self source];
  if (pivotObject) {
    HGSAssert([pivotObject conformsToType:kHGSTypeContact],
              @"Bad pivotObject: %@", pivotObject);

    NSString *emailAddress = [pivotObject valueForKey:kHGSObjectAttributeContactEmailKey];
    NSString *name = [pivotObject valueForKey:kHGSObjectAttributeNameKey];
    HGSAssert(name,
              @"How did we get a pivotObject without a name? %@",
              pivotObject);
    NSString *predString = nil;
    if (emailAddress) {
      predString
        = [NSString stringWithFormat:@"(* = \"%@\"cdw || * = \"%@\"cdw)",
           name, emailAddress];
    } else {
      predString = [NSString stringWithFormat:@"(* = \"%@\"cdw)", name];
    }
    [predicateSegments addObject:predString];
  }
  NSString *rawQueryString = [[query tokenizedQueryString] originalString];
  NSString *spotlightString
    = GTMCFAutorelease(_MDQueryCreateQueryString(NULL,
                                                 (CFStringRef)rawQueryString));
  [predicateSegments addObject:spotlightString];

  // if we have a uti filter, add it
  NSString *utiFilter = [slSource utiFilter];
  if (utiFilter) {
    [predicateSegments addObject:utiFilter];
  }

  // Make the final predicate string
  NSString *predicateString
    = [predicateSegments componentsJoinedByString:@" && "];

  // Build the query
  NSArray *valueListAttrs = [slSource valueListAttributes];
  @synchronized(self) {
    // Synchronize here so that if cancel is called on another thread, we don't
    // try and cancel half-created queries.
    mdTopQuery_ = MDQueryCreate(kCFAllocatorDefault,
                                (CFStringRef)predicateString,
                                (CFArrayRef)valueListAttrs,
                                (CFArrayRef)[NSArray arrayWithObject:(id)kMDItemLastUsedDate]);
    if (!mdTopQuery_) return;
    mdCategoryQuery_ = MDQueryCreate(kCFAllocatorDefault,
                                     (CFStringRef)predicateString,
                                     (CFArrayRef)valueListAttrs,
                                     (CFArrayRef)[NSArray arrayWithObject:(id)kMDItemLastUsedDate]);
    if (!mdCategoryQuery_) return;
    MDQuerySetMatchesSupportFiles(mdTopQuery_, NO);
    MDQuerySetMatchesSupportFiles(mdCategoryQuery_, NO);
    _MDQuerySetGroupComparator(mdCategoryQuery_,
                               SLFilesCategoryIndexForItem,
                               [slSource groupToCategoryIndexMap]);
  }
  BOOL goodQuery = NO;
  if (![self isCancelled]) {
    goodQuery = MDQueryExecute(mdTopQuery_, kMDQuerySynchronous);
  }
  if (goodQuery && ![self isCancelled]) {
    goodQuery = MDQueryExecute(mdCategoryQuery_, kMDQuerySynchronous);
  }

  if (!goodQuery && ![self isCancelled]) {
    // COV_NF_START
    CFStringRef queryString = MDQueryCopyQueryString(mdTopQuery_);
    // If something goes wrong, let the handler think we just completed with
    // no results so that we get cleaned up correctly.
    HGSLog(@"Failed to start mdquery: %@", queryString);
    CFRelease(queryString);
    // COV_NF_END
  } else {
    CFIndex groupCount = _MDQueryGetGroupCount(mdCategoryQuery_);
    NSMutableDictionary *resultCountByFilter = [NSMutableDictionary dictionary];
    NSArray *categories = [slSource categories];
    for (CFIndex i = 0; i < groupCount; ++i) {
      CFIndex count = _MDQueryGetResultCountForGroup(mdCategoryQuery_, i);
      if (count) {
        QSBCategory *category = [categories objectAtIndex:i];
        HGSTypeFilter *filter = [category typeFilter];
        [resultCountByFilter setObject:[NSNumber numberWithUnsignedInteger:count]
                                forKey:filter];
      }
    }
    NSUInteger count = MDQueryGetResultCount(mdTopQuery_);
    NSNumber *nsCount = [NSNumber numberWithUnsignedInteger:count];

    // Two common sets we get asked for is the complete set and the set
    // without suggestions. We will return the same value for both.
    NSSet *suggestSet = [NSSet setWithObject:kHGSTypeSuggest];
    HGSTypeFilter *filter
      = [HGSTypeFilter filterWithDoesNotConformTypes:suggestSet];
    [resultCountByFilter setObject:nsCount
                            forKey:filter];
    filter = [HGSTypeFilter filterAllowingAllTypes];
    [resultCountByFilter setObject:nsCount
                            forKey:filter];
    resultCountByFilter_ = [resultCountByFilter retain];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc hgs_postOnMainThreadNotificationName:kHGSSearchOperationDidUpdateResultsNotification
                                      object:self
                                    userInfo:nil];
  }
}

- (void)cancel {
  [super cancel];
  @synchronized(self) {
    if (mdTopQuery_) {
      MDQueryDisableUpdates(mdTopQuery_);
      MDQueryStop(mdTopQuery_);
    }
    if (mdCategoryQuery_) {
      MDQueryDisableUpdates(mdCategoryQuery_);
      MDQueryStop(mdCategoryQuery_);
    }
  }
}

- (id)getAttribute:(CFStringRef)attribute
             query:(MDQueryRef)query
              item:(MDItemRef)item
             index:(NSUInteger)idx
             group:(NSUInteger)group {
  id value = nil;
  if (query) {
    if (group == MDItemPrivateGroupLast) {
      value = MDQueryGetAttributeValueOfResultAtIndex(query, attribute, idx);
    } else {
      value = _MDQueryGetAttributeValueOfResultAtIndexForGroup(query, attribute, idx, group);
    }
  } else {
    value = GTMCFAutorelease(MDItemCopyAttribute(item, attribute));
  }
#if DEBUG
  // Some objects don't have dates and display names.
  if (attribute != kMDItemLastUsedDate && attribute != kMDItemDisplayName) {
    HGSAssert(value, @"Query: %@ item: %@ idx: %d group %d attr: %@",
              query, item, idx, group, attribute);
  }
#endif // DEBUG
  return value;
}

- (HGSScoredResult *)resultFromQuery:(MDQueryRef)query
                                item:(MDItemRef)mdItem
                               group:(NSUInteger)group
                               index:(NSUInteger)idx {
  NSValue *key = [NSValue valueWithPointer:mdItem];
  HGSScoredResult *scoredResult = [hgsResults_ objectForKey:key];
  if (!scoredResult) {
    HGSAssert(mdItem, @"Query: %@ idx: %d group %d", query, idx, group);
    NSString *path = nil;
    NSString *name = [self getAttribute:kMDItemDisplayName
                                  query:query
                                   item:mdItem
                                  index:idx
                                  group:group];
    if (!name) {
      // COV_NF_START
      // This can happen in cases where there isn't a lot of spotlight
      // information like a read only disk image that doesn't have a spotlight
      // database on it.
      name = GTMCFAutorelease(MDItemCopyAttribute(mdItem, kMDItemFSName));
      if (!name) {
        path = GTMCFAutorelease(MDItemCopyAttribute(mdItem, kMDItemPath));
        if (!path) {
          return nil;
        } else {
          name = [[path lastPathComponent] stringByDeletingPathExtension];
        }
      }
      // COV_NF_END
    }
    BOOL isURL = NO;
    NSString *contentType = [self getAttribute:kMDItemContentType
                                         query:query
                                          item:mdItem
                                         index:idx
                                         group:group];
    NSString *resultType = nil;
    if (contentType) {
      NSNumber *typeGroupNumber = [self getAttribute:kMDItemPrivateAttributeGroupId
                                               query:query
                                                item:mdItem
                                               index:idx
                                               group:group];
      if (typeGroupNumber) {
        int typeGroup = [typeGroupNumber intValue];

        // TODO: further subdivide the result types.
        switch (typeGroup) {
          case MDItemPrivateGroupApplication:
          case MDItemPrivateGroupSystemPref:
            // TODO: do we want a different type for prefpanes?
            resultType = kHGSTypeFileApplication;
            break;
          case MDItemPrivateGroupMessage:
            resultType = kHGSTypeEmail;
            break;
          case MDItemPrivateGroupContact:
            resultType = kHGSTypeContact;
            break;
          case MDItemPrivateGroupWeb:
            resultType = kHGSTypeWebHistory;
            isURL = YES;
            break;
          case MDItemPrivateGroupImage:
            resultType = kHGSTypeFileImage;
            break;
          case MDItemPrivateGroupMovie:
            resultType = kHGSTypeFileMovie;
            break;
          case MDItemPrivateGroupMusic:
            resultType = kHGSTypeFileMusic;
            break;
          case MDItemPrivateGroupDirectory:
            resultType = kHGSTypeDirectory;
            break;
          case MDItemPrivateGroupPDF:
            resultType = kHGSTypeFilePDF;
            break;
          case MDItemPrivateGroupPresentation:
            resultType = kHGSTypeFilePresentation;
            break;
          case MDItemPrivateGroupFont:
            resultType = kHGSTypeFileFont;
            break;
          case MDItemPrivateGroupCalendar:
            resultType = kHGSTypeFileCalendar;
            break;
          case MDItemPrivateGroupDocument:
          default:
          {
            if ([[name pathExtension] caseInsensitiveCompare:@"webloc"]
                == NSOrderedSame) {
              resultType = kHGSTypeWebBookmark;
            } else if (UTTypeConformsTo((CFStringRef)contentType,
                                        kUTTypePlainText)) {
              resultType = kHGSTypeTextFile;
            } else {
              resultType = kHGSTypeFile;
            }
          }
            break;
        }
      }
    }

    NSString *uri = nil;
    // We want to avoid getting the path if at all possible,
    // and we only really need the path if it isn't a URL.
    if (isURL) {
      NSString *uriPath = GTMCFAutorelease(MDItemCopyAttribute(mdItem,
                                                               kMDItemURL));
      if (uriPath) {
        uri = uriPath;
      }
    }
    if (!uri) {
      if (!path) {
        path = GTMCFAutorelease(MDItemCopyAttribute(mdItem, kMDItemPath));
      }
      if (!path) {
        return nil;
      }
      NSString *escaped
        = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      uri = [@"file://localhost" stringByAppendingString:escaped];
    }

    if (!resultType && path) {
      resultType = HGSTypeForPath(path);
      if ([resultType isEqual:kHGSTypeWebHistory]) {
        isURL = YES;
        NSString *uriPath = GTMCFAutorelease(MDItemCopyAttribute(mdItem,
                                                                 kMDItemURL));
        if (uriPath) {
          uri = uriPath;
        }
      }
    }

    NSString *iconFlagName = nil;
    if ([resultType isEqual:kHGSTypeWebHistory]) {
      // TODO(alcor): are there any items that are not history
      iconFlagName = @"history-flag";
    }

    HGSAssert(resultType != 0, nil);

    // Cache values the query has already copied
    NSDate *lastUsedDate = [self getAttribute:kMDItemLastUsedDate
                                        query:query
                                         item:mdItem
                                        index:idx
                                        group:group];
    if (!lastUsedDate) {
      lastUsedDate = [NSDate distantPast];  // COV_NF_LINE
    }
    const NSTimeInterval kSLOneMonth = 60 * 60 * 24 * 31;
    CGFloat insignificantScore
      = HGSCalibratedScore(kHGSCalibratedInsignificantScore);
    NSDate *nowDate = [NSDate date];
    NSTimeInterval timeSinceLastUsed
      = [nowDate timeIntervalSinceDate:lastUsedDate];
    CGFloat score = insignificantScore;
    if (timeSinceLastUsed < kSLOneMonth) {
      CGFloat highScore = HGSCalibratedScore(kHGSCalibratedModerateScore);
      CGFloat addOn = highScore - insignificantScore;
      addOn *= 1 - (timeSinceLastUsed / kSLOneMonth);
      score += addOn;
    }
    NSMutableDictionary *hgsAttributes
      = [NSMutableDictionary dictionaryWithObjectsAndKeys:
         lastUsedDate, kHGSObjectAttributeLastUsedDateKey,
         contentType, kHGSObjectAttributeUTTypeKey, nil];
    if (iconFlagName) {
      [hgsAttributes setObject:iconFlagName
                        forKey:kHGSObjectAttributeFlagIconNameKey];
    }
    if (isURL) {
      [hgsAttributes setObject:uri forKey:kHGSObjectAttributeSourceURLKey];
    }
    HGSTokenizedString *matchedTerm = [[self query] tokenizedQueryString];
    NSRange matchRange = NSMakeRange(0, [matchedTerm originalLength]);
    NSIndexSet *matchedIndexes
      = [NSIndexSet indexSetWithIndexesInRange:matchRange];
    scoredResult = [HGSScoredResult resultWithURI:uri
                                             name:name
                                             type:resultType
                                           source:[self source]
                                       attributes:hgsAttributes
                                            score:score
                                            flags:0
                                      matchedTerm:matchedTerm
                                   matchedIndexes:matchedIndexes];
    [hgsResults_ setObject:scoredResult forKey:key];
  }
  return scoredResult;
}

- (HGSScoredResult *)resultFromGroup:(NSUInteger)group
                               index:(NSUInteger)idx {
  MDItemRef mdItem = NULL;
  MDQueryRef query = NULL;
  if (group == MDItemPrivateGroupLast) {
    query = mdTopQuery_;
    mdItem = (MDItemRef)MDQueryGetResultAtIndex(query, idx);
  } else {
    query = mdCategoryQuery_;
    mdItem = (MDItemRef)_MDQueryGetResultAtIndexForGroup(query, idx, group);
  }
  return [self resultFromQuery:query item:mdItem group:group index:idx];
}

- (HGSScoredResult *)sortedRankedResultAtIndex:(NSUInteger)idx
                                    typeFilter:(HGSTypeFilter *)typeFilter {
  SLFilesSource *slSource = (SLFilesSource *)[self source];
  NSDictionary *filterToCategoryIndexMap = [slSource filterToCategoryIndexMap];
  NSNumber *nsCategoryIndex = [filterToCategoryIndexMap objectForKey:typeFilter];
  HGSAssert(nsCategoryIndex, @"Unknown category for filter: %@", typeFilter);
  NSUInteger categoryIndex = [nsCategoryIndex unsignedIntegerValue];
  HGSScoredResult *result = [self resultFromGroup:categoryIndex index:idx];
  return result;
}

- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)filter {
  NSNumber *value = [resultCountByFilter_ objectForKey:filter];
  return [value unsignedIntegerValue];
}

@end

@implementation SLFilesSource
@synthesize utiFilter = utiFilter_;
@synthesize valueListAttributes = valueListAttributes_;
@synthesize filterToCategoryIndexMap = filterToCategoryIndexMap_;
@synthesize categories = categories_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    // we need to build the filter
    rebuildUTIFilter_ = YES;

    NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
    HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
    [dc addObserver:self
           selector:@selector(extensionPointSourcesChanged:)
               name:kHGSExtensionPointDidAddExtensionNotification
             object:sourcesPoint];
    [dc addObserver:self
           selector:@selector(extensionPointSourcesChanged:)
               name:kHGSExtensionPointDidRemoveExtensionNotification
             object:sourcesPoint];
    valueListAttributes_
      = [[NSArray alloc] initWithObjects:(id)kMDItemPrivateAttributeGroupId,
         kMDItemLastUsedDate, kMDItemDisplayName, kMDItemContentType, nil];
    QSBCategoryManager *mgr = [QSBCategoryManager sharedManager];
    categories_ = [[mgr categories] copy];
    NSMutableDictionary *filterToCategoryIndexMap
      = [NSMutableDictionary dictionary];
    for (CFIndex i = 1; i <  MDItemPrivateGroupLast; ++i) {
      NSString *type = [self typeFromGroup:i];
      HGSAssert(type, nil);
      QSBCategory *category = [mgr categoryForType:type];
      NSUInteger categoryIndex
        = [categories_ indexOfObjectIdenticalTo:category];
      groupToCategoryIndexMap_[i] = categoryIndex;
      HGSTypeFilter *typeFilter = [category typeFilter];
      NSNumber *nsCategoryIndex
        = [NSNumber numberWithUnsignedInteger:categoryIndex];
      [filterToCategoryIndexMap setObject:nsCategoryIndex
                                   forKey:typeFilter];
    }
    NSSet *suggestSet = [NSSet setWithObject:kHGSTypeSuggest];
    HGSTypeFilter *filter
      = [HGSTypeFilter filterWithDoesNotConformTypes:suggestSet];
    NSNumber *last = [NSNumber numberWithUnsignedInt:MDItemPrivateGroupLast];
    [filterToCategoryIndexMap setObject:last forKey:filter];
    filter = [HGSTypeFilter filterAllowingAllTypes];
    [filterToCategoryIndexMap setObject:last forKey:filter];
    filterToCategoryIndexMap_ = [filterToCategoryIndexMap retain];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [utiFilter_ release];
  [categories_ release];
  [valueListAttributes_ release];
  [super dealloc];
}

- (NSString*)typeFromGroup:(MDItemPrivateGroup)group {
  struct {
    MDItemPrivateGroup group;
    NSString *type;
  } groupToTypeMap[] = {
    { MDItemPrivateGroupApplication, kHGSTypeFileApplication },
    { MDItemPrivateGroupSystemPref, kHGSTypeFileApplication },
    { MDItemPrivateGroupMessage, kHGSTypeEmail },
    { MDItemPrivateGroupContact, kHGSTypeContact },
    { MDItemPrivateGroupWeb, kHGSTypeWebpage },
    { MDItemPrivateGroupImage, kHGSTypeFileImage },
    { MDItemPrivateGroupMovie, kHGSTypeFileMovie },
    { MDItemPrivateGroupMusic, kHGSTypeFileMusic },
    { MDItemPrivateGroupDirectory, kHGSTypeDirectory },
    { MDItemPrivateGroupPDF, kHGSTypeFilePDF },
    { MDItemPrivateGroupPresentation, kHGSTypeFilePresentation },
    { MDItemPrivateGroupFont, kHGSTypeFileFont },
    { MDItemPrivateGroupCalendar, kHGSTypeFileCalendar },
    { MDItemPrivateGroupDocument, kHGSTypeFile }
  };
  NSString *type = nil;
  for (size_t i = 0;
       i < sizeof(groupToTypeMap) / sizeof(groupToTypeMap[0]);
       ++i) {
    if (group == groupToTypeMap[i].group) {
      type = groupToTypeMap[i].type;
      break;
    }
  }
  return type;
}

- (NSUInteger *)groupToCategoryIndexMap {
  return groupToCategoryIndexMap_;
}

// returns an operation to search this source for |query| and posts notifs
// to |observer|.
- (HGSSearchOperation *)searchOperationForQuery:(HGSQuery *)query {
  SLFilesOperation *searchOp
    = [[[SLFilesOperation alloc] initWithQuery:query source:self] autorelease];
  return searchOp;
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = NO;
  HGSResult *pivotObject = [query pivotObject];
  if (pivotObject) {
    isValid = [pivotObject conformsToType:kHGSTypeContact];
  } else {
    // Since Spotlight can return a lot of stuff, we only run the query if
    // it is at least 3 characters long.
    isValid = [[query tokenizedQueryString] originalLength] >= 3;
    if (isValid) {
      if (MDQueryPrivateIsSpotlightIndexing()) {
        HGSLog(@"Unable to use spotlight because it is indexing.");
        isValid = NO;
      }
    }
  }
  return isValid;
}

- (void)extensionPointSourcesChanged:(NSNotification*)notification {
  // since the notifications can come in batches as we load things (and if/when
  // we support enable/disable they too could come in batches), we just set a
  // flag to rebuild the string next time it's needed.
  rebuildUTIFilter_ = YES;
}

- (NSString *)utiFilter {
  // do we need to rebuild it?
  if (rebuildUTIFilter_) {
    // reset the flag first to avoid threading races w/o needing an @sync
    rebuildUTIFilter_ = NO;

    // collect the utis
    NSMutableSet *utiSet = [NSMutableSet set];
    NSArray *extensions = [[HGSExtensionPoint sourcesPoint] extensions];
    for (HGSSearchSource *searchSource in extensions) {
      NSSet *utis = [searchSource utisToExcludeFromDiskSources];
      if (utis) {
        [utiSet unionSet:utis];
      }
    }
    // make the filter string
    NSMutableArray *utiFilterArray
      = [NSMutableArray arrayWithCapacity:[utiSet count]];
    for (NSString *uti in utiSet) {
      NSString *utiFilterStr
        = [NSString stringWithFormat:@"( kMDItemContentTypeTree != '%@' )", uti];
      [utiFilterArray addObject:utiFilterStr];
    }
    NSString *utiFilter = [utiFilterArray componentsJoinedByString:@" && "];
    if ([utiFilter length] == 0) {
      // if there is no filter, we use nil to gate adding it when we run queries
      utiFilter = nil;
    }
    // save it off
    @synchronized(self) {
      [utiFilter_ release];
      utiFilter_ = [utiFilter retain];
    }
  }

  NSString *result;
  @synchronized(self) {
    // We retain/autorelease to tie the lifetime of the current value to the
    // current thread's autorelease pool.  This way if the string gets updated
    // after we have returned it, the object won't disappear on the caller.
    result = [[utiFilter_ retain] autorelease];
  }
  return result;
}

- (MDItemRef)mdItemRefForResult:(HGSResult*)result {
  MDItemRef mdItem = nil;
  NSURL *url = [result url];
  if ([url isFileURL]) {
    mdItem = MDItemCreate(kCFAllocatorDefault, (CFStringRef)[url path]);
    GTMCFAutorelease(mdItem);
  }
  return mdItem;
}

- (id)provideValueForKey:(NSString*)key result:(HGSResult *)result {
  MDItemRef mdItemRef = nil;
  id value = nil;

  if ([key isEqualToString:kHGSObjectAttributeIconKey]) {
    NSURL *url = [result url];
    if (![url isFileURL]) {
      value = [NSImage imageNamed:@"blue-nav"];
    }
  }
  if ([key isEqualToString:kHGSObjectAttributeEmailAddressesKey] &&
      (mdItemRef = [self mdItemRefForResult:result])) {
    NSMutableArray *allEmails = nil;
    NSArray *emails
      = GTMCFAutorelease(MDItemCopyAttribute(mdItemRef,
                                             kMDItemAuthorEmailAddresses));
    if (emails) {
      allEmails = [NSMutableArray arrayWithArray:emails];
    }
    emails = GTMCFAutorelease(MDItemCopyAttribute(mdItemRef,
                                                  kMDItemRecipientEmailAddresses));

    if (emails) {
      if (allEmails) {
        [allEmails addObjectsFromArray:emails];
      } else {
        allEmails = [NSMutableArray arrayWithArray:emails];
      }
    }
    if (allEmails) {
      value = allEmails;
    }
  } else if ([key isEqualToString:kHGSObjectAttributeContactsKey] &&
             (mdItemRef = [self mdItemRefForResult:result])) {
    NSMutableArray *allPeople = nil;
    NSArray *people = GTMCFAutorelease(MDItemCopyAttribute(mdItemRef,
                                                           kMDItemAuthors));
    if (people) {
      allPeople = [NSMutableArray arrayWithArray:people];
    }
    people = GTMCFAutorelease(MDItemCopyAttribute(mdItemRef, kMDItemRecipients));
    if (people) {
      if (allPeople) {
        [allPeople addObjectsFromArray:people];
      } else {
        allPeople = [NSMutableArray arrayWithArray:people];
      }
    }
    if (allPeople) {
      value = allPeople;
    }
  }
  if (!value) {
    value = [super provideValueForKey:key result:result];
  }
  return value;
}

@end



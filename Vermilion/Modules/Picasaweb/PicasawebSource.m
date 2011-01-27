//
//  PicasawebSource.m
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
#import <QSBPluginUI/QSBPluginUI.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <GTM/GTMTypeCasting.h>
#import <GData/GData.h>

#import "HGSKeychainItem.h"

static NSString *const kPhotosAlbumKey = @"kPhotosAlbumKey";

@interface PicasawebSource : HGSGDataServiceSource {
 @private
  NSImage *placeholderIcon_;
}

- (void)indexAlbum:(GDataEntryPhotoAlbum *)album
           context:(HGSGDataServiceIndexContext *)context;
- (void)indexPhoto:(GDataEntryPhoto *)photo
         withAlbum:(GDataEntryPhotoAlbum *)album
           context:(HGSGDataServiceIndexContext *)context;

// Utility function to fetch an encoded string containing just the user
// name without the trailing "@gmail.com".
- (NSString *)encodedUserNameFromName:(NSString *)username;

+ (void)setBestFitThumbnailFromMediaGroup:(GDataMediaGroup *)mediaGroup
                             inAttributes:(NSMutableDictionary *)attributes;

- (void)albumInfoFetcher:(GDataServiceTicket *)ticket
       finishedWithAlbum:(GDataFeedPhotoUser *)albumFeed
                   error:(NSError *)error;
- (void)photoInfoFetcher:(GDataServiceTicket *)ticket
       finishedWithPhoto:(GDataFeedPhotoAlbum *)photoFeed
                   error:(NSError *)error;
@end

@interface GDataMediaGroup (VermillionAdditions)

// Choose the best fitting thumbnail for this media item for the given
// |bestSize|.
- (GDataMediaThumbnail *)getBestFitThumbnailForSize:(CGSize)bestSize;

@end


@implementation PicasawebSource

GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    placeholderIcon_ = [[self imageNamed:@"PicasaPlaceholder.icns"] retain];
  }
  return self;
}

- (void)dealloc {
  [placeholderIcon_ release];
   [super dealloc];
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeIconKey]) {
    value = placeholderIcon_;
  }
  if (!value) {
    value = [super provideValueForKey:key result:result];
  }
  return value;
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  // If we're pivoting on an album then we can provide
  // a list of all of that albums images as results.
  if (!isValid) {
    HGSResult *pivotObject = [query pivotObject];
    isValid = ([pivotObject conformsToType:kHGSTypeWebPhotoAlbum]);
  }
  return isValid;
}

- (HGSResult *)preFilterResult:(HGSResult *)result
               matchesForQuery:(HGSQuery*)query
                  pivotObjects:(HGSResultArray *)pivotObjects {
  // Remove things that aren't from this album.
  // if we had a pivot object, we filter the results w/ the pivot info
  HGSAssert([pivotObjects count] <= 1, @"%@", pivotObjects);
  HGSResult *pivotObject = [pivotObjects objectAtIndex:0];
  if ([pivotObject conformsToType:kHGSTypeWebPhotoAlbum]) {
    NSURL *albumURL = [pivotObject url];
    NSString *albumURLString = [albumURL absoluteString];
    NSURL *photoURL = [result url];
    NSString *photoURLString = [photoURL absoluteString];
    if (![photoURLString hasPrefix:albumURLString]) {
      result = nil;
    }
  }
  return result;
}

- (NSString *)encodedUserNameFromName:(NSString *)username {
  // Strip off the domain from the user name.
  NSString *userNameEncoded = username;
  NSRange atRange = [userNameEncoded rangeOfString:@"@"];
  if (atRange.location != NSNotFound) {
    userNameEncoded = [userNameEncoded substringToIndex:atRange.location];
  }
  userNameEncoded = [userNameEncoded gtm_stringByEscapingForURLArgument];
  userNameEncoded = [@"/" stringByAppendingString:userNameEncoded];
  return userNameEncoded;
}

#pragma mark -
#pragma mark HGSGDataServiceSource Overrides

- (GDataServiceTicket *)fetchTicketForService:(GDataServiceGoogle *)service {
  NSString *userName = [service username];
  NSURL* albumFeedURL
    = [GDataServiceGooglePhotos photoFeedURLForUserID:userName
                                              albumID:nil
                                            albumName:nil
                                              photoID:nil
                                                 kind:nil
                                               access:nil];
  GDataServiceTicket *albumFetchTicket
    = [service fetchFeedWithURL:albumFeedURL
                       delegate:self
              didFinishSelector:@selector(albumInfoFetcher:
                                          finishedWithAlbum:
                                          error:)];
  return albumFetchTicket;
}

- (Class)serviceClass {
  return [GDataServiceGooglePhotos class];
}


#pragma mark -
#pragma mark Album information Extraction

- (void)indexAlbum:(GDataEntryPhotoAlbum *)album
           context:(HGSGDataServiceIndexContext *)context {
  HGSAssert(context, nil);
  NSString* albumTitle = [[album title] stringValue];
  NSURL* albumURL = [[album HTMLLink] URL];
  if (albumURL) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    // We can't get last-used, so just use last-modified.
    [attributes setObject:[[album updatedDate] date]
                   forKey:kHGSObjectAttributeLastUsedDateKey];

    // Compose the contents of the path control:
    // 'Picasaweb'/username/album name.
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/",
                                           [albumURL scheme],
                                           [albumURL host]]];
    NSString *picasaWeb = HGSLocalizedString(@"Picasaweb",
                                             @"A label denoting the picasaweb "
                                             @"service.");
    NSString *username = [[context service] username];
    NSString *userNameEncoded = [self encodedUserNameFromName:username];
    NSURL *userURL = [[[NSURL alloc] initWithScheme:[albumURL scheme]
                                               host:[albumURL host]
                                               path:userNameEncoded]
                      autorelease];
    NSArray *pathCellElements
      = [NSArray arrayWithObjects:
         [HGSPathCellElement elementWithTitle:picasaWeb url:baseURL],
         [HGSPathCellElement elementWithTitle:username
                                          url:userURL],
         [HGSPathCellElement elementWithTitle:albumTitle url:albumURL],
         nil];
    NSArray *cellArray
      = [HGSPathCellElement pathCellArrayWithElements:pathCellElements];
    if (cellArray) {
      [attributes setObject:cellArray forKey:kQSBObjectAttributePathCellsKey];
    }

    // Remember the first photo's URL to ease on-demand fetching later.
    [PicasawebSource setBestFitThumbnailFromMediaGroup:[album mediaGroup]
                                          inAttributes:attributes];

    // Add album description and tags to enhance searching.
    NSString* albumDescription = [[album photoDescription] stringValue];


    // Set up the snippet and detail.
    [attributes setObject:albumDescription
                   forKey:kHGSObjectAttributeSnippetKey];
    NSString *albumDetail = HGSLocalizedString(@"%u photos",
                                               @"A label denoting %u number of "
                                               @"online photos");
    NSUInteger photoCount = [[album photosUsed] unsignedIntValue];
    albumDetail = [NSString stringWithFormat:albumDetail, photoCount],
    [attributes setObject:albumDetail forKey:kHGSObjectAttributeSnippetKey];

    HGSUnscoredResult* result = [HGSUnscoredResult resultWithURL:albumURL
                                                            name:albumTitle
                                                            type:kHGSTypeWebPhotoAlbum
                                                          source:self
                                                      attributes:attributes];
    [[context database] indexResult:result
                               name:albumTitle
                          otherTerm:albumDescription];

    // Now index the photos in the album.
    NSURL *photoInfoFeedURL = [[album feedLink] URL];
    if (photoInfoFeedURL) {
      GDataServiceGoogle *service = [context service];
      GDataServiceTicket *photoInfoTicket
        = [service fetchFeedWithURL:photoInfoFeedURL
                           delegate:self
                  didFinishSelector:@selector(photoInfoFetcher:
                                              finishedWithPhoto:
                                              error:)];
      [photoInfoTicket setProperty:album forKey:kPhotosAlbumKey];
      [photoInfoTicket setUserData:context];
      [context addTicket:photoInfoTicket];
    }
  }
}

- (void)albumInfoFetcher:(GDataServiceTicket *)ticket
       finishedWithAlbum:(GDataFeedPhotoUser *)albumFeed
                   error:(NSError *)error {
  HGSGDataServiceIndexContext *context
    = GTM_STATIC_CAST(HGSGDataServiceIndexContext, [ticket userData]);
  HGSAssert(context, nil);
  if (!error) {
    for (GDataEntryPhotoAlbum* album in [albumFeed entries]) {
      if ([context isCancelled]) break;
      [self indexAlbum:album context:context];
    }
  } else {
    NSString *fetchType = HGSLocalizedString(@"album",
                                             @"A label denoting a Picasaweb "
                                             @"Photo Album");
    [self handleErrorForFetchType:fetchType error:error];
  }
  [self ticketHandled:ticket forContext:context];
}

#pragma mark -
#pragma mark Photo information Extraction

- (void)indexPhoto:(GDataEntryPhoto *)photo
         withAlbum:(GDataEntryPhotoAlbum *)album
           context:(HGSGDataServiceIndexContext *)context {
  NSURL* photoURL = [[photo HTMLLink] URL];
  if (photoURL) {
    NSString* photoDescription = [[photo photoDescription] stringValue];
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    // We can't get last-used, so just use last-modified.
    [attributes setObject:[[photo updatedDate] date]
                   forKey:kHGSObjectAttributeLastUsedDateKey];

    // Compose the contents of the path control:
    // 'Picasaweb'/username/album name/photo title.
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/",
                                           [photoURL scheme],
                                           [photoURL host]]];
    NSString *picasaWeb = HGSLocalizedString(@"Picasaweb",
                                             @"A label denoting the picasaweb "
                                             @"service.");
    NSString *username = [[context service] username];
    NSString *userNameEncoded = [self encodedUserNameFromName:username];
    NSURL *userURL = [[[NSURL alloc] initWithScheme:[photoURL scheme]
                                               host:[photoURL host]
                                               path:userNameEncoded]
                      autorelease];
    NSString* albumTitle = [[album title] stringValue];
    NSURL* albumURL = [[album HTMLLink] URL];
    NSString* photoTitle = [[photo title] stringValue];
    NSArray *pathCellElements
      = [NSArray arrayWithObjects:
         [HGSPathCellElement elementWithTitle:picasaWeb url:baseURL],
         [HGSPathCellElement elementWithTitle:username url:userURL],
         [HGSPathCellElement elementWithTitle:albumTitle url:albumURL],
         [HGSPathCellElement elementWithTitle:photoTitle url:photoURL],
         nil];
    NSArray *cellArray
      = [HGSPathCellElement pathCellArrayWithElements:pathCellElements];
    if (cellArray) {
      [attributes setObject:cellArray forKey:kQSBObjectAttributePathCellsKey];
    }
    if ([photoDescription length] == 0) {
      photoDescription = photoTitle;
    }

    // Remember the photo's first image URL.
    [PicasawebSource setBestFitThumbnailFromMediaGroup:[photo mediaGroup]
                                          inAttributes:attributes];

    // Add photo description and tags to enhance searching.
    NSMutableArray *otherStrings
      = [NSMutableArray arrayWithObjects:photoDescription,
                                         albumTitle,
                                         nil];

    // Add tags (aka 'keywords').
    NSArray *keywords = [[[photo mediaGroup] mediaKeywords] keywords];
    [otherStrings addObjectsFromArray:keywords];

    // TODO(mrossetti): Add name tags when available via the PWA API.

    // Set up the snippet and detail.
    NSString *photoSnippet = albumTitle;
    GDataPhotoTimestamp *photoTimestamp = [photo timestamp];
    if (photoTimestamp) {
      NSDate *timestamp = [photoTimestamp dateValue];
      NSDateFormatter *dateFormatter
        = [[[NSDateFormatter alloc] init]  autorelease];
      [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
      [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
      NSString *timestampString = [dateFormatter stringFromDate:timestamp];
      photoSnippet
        = [timestampString stringByAppendingFormat:@" (%@)", photoSnippet];
    }


    photoSnippet = [photoSnippet stringByAppendingFormat:@"\r%@", photoTitle];
    [attributes setObject:photoSnippet forKey:kHGSObjectAttributeSnippetKey];
    HGSUnscoredResult* result = [HGSUnscoredResult resultWithURL:photoURL
                                                            name:photoDescription
                                                            type:kHGSTypeWebImage
                                                          source:self
                                                      attributes:attributes];
    [[context database] indexResult:result
                               name:photoTitle
                         otherTerms:otherStrings];
  }
}

- (void)photoInfoFetcher:(GDataServiceTicket *)ticket
       finishedWithPhoto:(GDataFeedPhotoAlbum *)photoFeed
                   error:(NSError *)error {
  HGSGDataServiceIndexContext *context
    = GTM_STATIC_CAST(HGSGDataServiceIndexContext, [ticket userData]);
  HGSAssert(context, nil);
  if (!error) {
    NSArray *photoList = [photoFeed entries];
    for (GDataEntryPhoto *photo in photoList) {
      if ([context isCancelled]) break;
      GDataEntryPhotoAlbum *album = [ticket propertyForKey:kPhotosAlbumKey];
      [self indexPhoto:photo withAlbum:album context:context];
    }
  } else {
    NSString *fetchType = HGSLocalizedString(@"photo",
                                             @"A label denoting a Picasaweb "
                                             @"photo");
    [self handleErrorForFetchType:fetchType error:error];
  }
  [self ticketHandled:ticket forContext:context];
}

#pragma mark -
#pragma mark Thumbnails

+ (void)setBestFitThumbnailFromMediaGroup:(GDataMediaGroup *)mediaGroup
                             inAttributes:(NSMutableDictionary *)attributes {
  // Since a source doesn't really know about the particular UI to which it
  // is providing the thumbnail we will hardcode a desired size, which
  // just happens to be the size of the preview image in the Quicksearch
  // Bar.
  const CGSize bestSize = { 96.0, 128.0 };
  GDataMediaThumbnail *bestThumbnail
    = [mediaGroup getBestFitThumbnailForSize:bestSize];

  if (bestThumbnail) {
    NSString *photoURLString = [bestThumbnail URLString];
    if (photoURLString) {
      [attributes setObject:photoURLString
                     forKey:kHGSObjectAttributeIconPreviewFileKey];
    }
  }
}

@end

#pragma mark -

@implementation GDataMediaGroup (VermillionAdditions)

- (GDataMediaThumbnail *)getBestFitThumbnailForSize:(CGSize)bestSize {
  // This approach works best when choosing an image that will be scaled.  A
  // different approach will be required if the image is going to be cropped.
  GDataMediaThumbnail *bestThumbnail = nil;
  NSArray *thumbnails = [self mediaThumbnails];
  CGFloat bestDelta = 0.0;

  for (GDataMediaThumbnail *thumbnail in thumbnails) {
    CGFloat trialWidth = [[thumbnail width] floatValue];
    CGFloat trialHeight = [[thumbnail height] floatValue];
    CGFloat trialDelta = fabs(bestSize.width - trialWidth)
                         + fabs(bestSize.height - trialHeight);
    if (!bestThumbnail || trialDelta < bestDelta) {
      bestDelta = trialDelta;
      bestThumbnail = thumbnail;
    }
  }
  return bestThumbnail;
}

@end

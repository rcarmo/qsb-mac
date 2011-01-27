//
//  PicasaWebUploadImageAction.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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
#import "HGSKeychainItem.h"

// An action that will upload one or more images and/or videoa
// to a Picasa account.
//
@interface PicasaWebUploadImageAction : HGSGDataUploadAction 

// Bottleneck function to upload a single image.
- (void)uploadImage:(HGSResult *)image
               item:(NSUInteger)item
                 of:(NSUInteger)count;

@end


@implementation PicasaWebUploadImageAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL success = NO;
  GDataServiceGoogle *uploadService = [self uploadService];
  if (uploadService) {
    [self setUserWasNoticed:NO];
    HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
    NSUInteger directObjectsCount = [directObjects count];
    NSUInteger item = 0;
    for (HGSResult *directObject in directObjects) {
      [self uploadImage:directObject item:item of:directObjectsCount];
      ++item;
    }
    success = YES;
  }
  return success;
}

- (void)uploadImage:(HGSResult *)imageResult
               item:(NSUInteger)item
                 of:(NSUInteger)count {
  NSString *resultPath = [imageResult filePath];
  NSString *resultTitle = [imageResult displayName];
  NSString *mimeType = [HGSGDataUploadAction mimeTypeForResult:imageResult];
  if (mimeType) {
    GDataEntryPhoto *entry = [GDataEntryPhoto photoEntry];
    [entry setTitleWithString:resultTitle];
    // TODO(mrossetti): Perhaps set this from metainfo in the image file
    // or to the file's creation date.
    [entry setTimestamp:[GDataPhotoTimestamp timestampWithDate:[NSDate date]]];
    NSData *imageData = [NSData dataWithContentsOfFile:resultPath];
    if (imageData) {
      [entry setPhotoData:imageData];
      [entry setPhotoMIMEType:mimeType];
      [self uploadGDataEntry:entry
                  entryTitle:resultTitle
                        item:item
                          of:count];
    } else {
      HGSLogDebug(@"Failed to load imageData for '%@'.", resultPath);
    }
  } else {
    NSString *errorString
      = HGSLocalizedString(@"Could not upload '%@' because the MIME type of "
                           @"the file could not be determined.", 
                           @"A message explaining that the file given by %@ "
                           @"could not be uploaded because the type of the "
                           @"file could not be determined.");
    errorString = [NSString stringWithFormat:errorString, resultTitle];
    [self informUserWithDescription:errorString
                               type:kHGSUserMessageErrorType];
    HGSLogDebug(@"Could not determine MIME type for file '%@'.", resultPath);
  }
}

#pragma mark Utility Methods

- (NSURL *)uploadURL {
  NSURL *uploadURL = [GDataServiceGooglePhotos
                      photoFeedURLForUserID:kGDataServiceDefaultUser
                                    albumID:kGDataGooglePhotosDropBoxAlbumID
                                  albumName:nil
                                    photoID:nil
                                       kind:nil
                                     access:nil];
  return uploadURL;
}

- (Class)serviceClass {
  return [GDataServiceGooglePhotos class];
}

- (NSString *)serviceName {
  NSString *name
    = HGSLocalizedString(@"PicasaWeb", 
                         @"The title of a service provided by Google.");
  return name;
}

- (NSImage *)serviceIcon {
  return [self imageNamed:@"PicasaWeb.icns"];
}

@end

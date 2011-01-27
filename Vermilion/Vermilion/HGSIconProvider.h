//
//  HGSIconProvider.h
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

#import <Cocoa/Cocoa.h>

/*!
 @header
 @discussion HGSIconProvider
 */

@class HGSLRUCache;
@class HGSResult;

@interface HGSIconProvider : NSObject {
 @private
  NSOperation *basicOperation_;
  NSOperation *advancedOperation_;
  NSImage *icon_;
  HGSResult *result_;
}

@property (readonly, retain) NSImage *icon;

- (void)invalidate;
@end

/*!
 A icon caching/retrieval system that will get icons lazily for HGSResults.
*/
@interface HGSIconCache : NSObject {
 @private
  NSOperationQueue *iconOperationQueue_;
  HGSLRUCache *advancedCache_;
  HGSLRUCache *basicCache_;
  NSImage *placeHolderIcon_;
  NSImage *compoundPlaceHolderIcon_;
}

/*!
  Returns the singleton instance of HGSIconProvider
*/
+ (HGSIconCache *)sharedIconCache;

/*!
  Returns our default placeHolderIcon. Do not change this icon. Make a copy and
  change it.
*/
- (NSImage *)placeHolderIcon;

/*!
  Returns our default compound placeHolderIcon. Do not change this icon.  Make
  a copy and change it.
*/
- (NSImage *)compoundPlaceHolderIcon;

/*!
  Returns an HGSIconProvider value for a HGSResult.
  Checks our cache to see if we have an icon, otherwise goes through a
  "waterfall" model to get icons.
  By default the first image returned is a placeholder image.
  We will then start up an operation to return a default filesystem image.
  Finally we will then start up an operation to return a high quality image if
  one is available.
  If skipPlaceholder is YES then we will immediately go for the default
  filesystem image. Note that this can be slow, so should not be used unless
  we really want a "medium" quality icon immediately.

  The icon retreived by this method will be cached.
*/
- (HGSIconProvider *)iconProviderForResult:(HGSResult *)result
                           skipPlaceholder:(BOOL)skip;

/*!
  Anyone can request that an icon be cached and then retrieve it later.
*/
- (NSImage *)cachedIconForKey:(NSString *)key;
- (void)cacheIcon:(NSImage *)icon forKey:(NSString *)key;

/*!
  Updates the icon for a given result and caches the image for the future.
  This can be called from any thread. The actual setting happens on the main
  thread.
*/
- (void)setIcon:(NSImage *)icon forResult:(HGSResult *)result;

/*!
 Returns an NSImage * for a result if we have one cached, otherwise
 returns nil.
*/
- (NSImage *)cachedIconForResult:(HGSResult *)result;

- (NSImage *)imageWithRoundRectAndDropShadow:(NSImage *)image;

/*!
  Size of the largest icon used in the UI
*/
- (NSSize)preferredIconSize;

@end

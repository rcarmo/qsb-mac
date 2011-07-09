//
//  HGSIconProvider.m
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

#import <QuickLook/QuickLook.h>
#import "HGSIconProvider.h"
#import "HGSLRUCache.h"
#import "HGSResult.h"
#import "HGSSearchSource.h"
#import "HGSOperation.h"
#import "GTMObjectSingleton.h"
#import "GTMGeometryUtils.h"
#import "GTMNSImage+Scaling.h"
#import "GTMNSBezierPath+CGPath.h"
#import <GData/GDataHTTPFetcher.h>
#import "HGSLog.h"
#import "GTMDebugThreadValidation.h"
#import "GTMGarbageCollection.h"
#import "GTMSystemVersion.h"

static const void *LRURetain(CFAllocatorRef allocator, const void *value);
static void LRURelease(CFAllocatorRef allocator, const void *value);
static Boolean LRUEqual(const void *value1, const void *value2);
static CFHashCode LRUHash(const void *value);

const size_t kIconCacheSize = 5 * 1024 * 1024; // bytes
static HGSLRUCacheCallBacks kLRUCacheCallbacks = {
  0,           // version
  LRURetain,   // keyRetain
  LRURelease,  // keyRelease
  LRUEqual,    // keyEqual
  LRUHash,     // keyHash
  LRURetain,   // valueRetain
  LRURelease,  // valueRelease
  nil          // evict
};

static NSString *const kHGSIconProviderResultKey = @"HGSIconProviderResultKey";
static NSString *const kHGSIconProviderValueKey = @"HGSIconProviderValueKey";
static NSString *const kHGSIconProviderAttrKey = @"HGSIconProviderAttrKey";
static NSString *const kHGSIconProviderURIKey = @"HGSIconProviderURIKey";
static NSString *const kHGSIconProviderThumbnailURLFormat
  = @"HGSIconProviderThumbnailURLFormat";

// Give us an URL for the icon for a result. First we check to see if the
// result has a kHGSObjectAttributeIconPreviewFileKey, if not we use the
// results uri to get the icon. We create the file URLs by hand to avoid the
// disk hits required by [NSURL fileURLWithPath].
static NSString* IconURLStringForResult(HGSResult *result) {
  NSString *urlPath = [result valueForKey:kHGSObjectAttributeIconPreviewFileKey];
  if (!urlPath) {
    urlPath = [result uri];
  }
  if ([urlPath hasPrefix:@"http:"]) {
    // For urls, we can specify a thumbnail provider for web sites.
    // HTTPS sites are usually locked down, so ignore it for those
    NSString *thumbnailURL = [[NSUserDefaults standardUserDefaults]
                              stringForKey:kHGSIconProviderThumbnailURLFormat];
    if (thumbnailURL) {
      urlPath
        = [NSString stringWithFormat:thumbnailURL, urlPath];
    } else {
      NSArray *fileTypes = [NSImage imageFileTypes];
      NSString *extension = [urlPath pathExtension];
      if (![fileTypes containsObject:extension]) {
        urlPath = [urlPath stringByAppendingPathComponent:@"favicon.ico"];
      }
    }
  } else if ([urlPath hasPrefix:@"/"]) {
    urlPath
      = [urlPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    urlPath = [@"file://localhost/" stringByAppendingString:urlPath];
  }
  return urlPath;
}

// The URI is the key that we will store a result in the advancedCache_ under.
static NSString* IconAdvancedURIStringForResult(HGSResult *result) {
  NSString *urlString = IconURLStringForResult(result);
  if ([urlString hasPrefix:@"file://"] &&
      ![urlString hasPrefix:@"file:///"] ) {
    // We have a relative path. We prepend the source name on here to
    // uniquefy relative paths per source.
    NSString *sourceName = [[result source] displayName];
    urlString = [NSString stringWithFormat:@"%@-%@", sourceName, urlString];
  }
  return urlString;
}

// The URI is the key that we will store a result in the basicCache_ under.
// If a result does not return a basic URI we will not cache anything for it.
static NSString *IconBasicURIStringForResult(HGSResult *result) {
  NSString *uttypeURI = nil;
  // If we have a preview file key, we can't cache a basic icon.
  NSString *urlPath = [result valueForKey:kHGSObjectAttributeIconPreviewFileKey];
  if (!urlPath) {
    NSString *uttype = [result valueForKey:kHGSObjectAttributeUTTypeKey];
    if (uttype) {
      uttypeURI = [NSString stringWithFormat:@"uttype:%@", uttype];
    }
  }
  return uttypeURI;
}

static NSImage *FileSystemImageForURL(NSURL *url) {
  NSImage *icon;
  NSString *scheme = [url scheme];
  typedef struct {
    NSString *scheme;
    OSType icon;
  } SchemeMap;
  SchemeMap map[] = {
    { @"http", 'tSts' },
    { @"https", 'tSts' },
    { @"ftp", kInternetLocationFTPIcon },
    { @"sftp", kInternetLocationFTPIcon },
    { @"afp", kInternetLocationAppleShareIcon },
    { @"mailto", kInternetLocationMailIcon },
    { @"news", kInternetLocationNewsIcon }
  };
  OSType iconType = kInternetLocationGenericIcon;
  for (size_t i = 0; i < sizeof(map) / sizeof(SchemeMap); ++i) {
    if ([scheme caseInsensitiveCompare:map[i].scheme] == NSOrderedSame) {
      iconType = map[i].icon;
      break;
    }
  }
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  icon = [ws iconForFileType:NSFileTypeForHFSTypeCode(iconType)];
  return icon;
}

@class HGSIconOperation;

// Right now we cache up to two different icons per result. A basic version for
// results that give us a UTType, and the "custom" advanced version.
// Since the spotlight source gives us the majority of results, and it supplies
// us with a  UTType, the basic cache cuts down the number of icon operations we
// perform by almost 50%.
@interface HGSIconCache ()
// Remove an operation from our list of pending icon fetch operations.
- (void)setValueOnMainThread:(NSDictionary *)args;
- (NSImage *)cachedIconForKey:(NSString *)key fromCache:(HGSLRUCache *)cache;
- (void)cacheIcon:(NSImage *)icon
           forKey:(NSString *)key
            cache:(HGSLRUCache *)cache;
- (void)cacheBasicIcon:(NSImage *)icon forResult:(HGSResult *)result;
- (NSOperationQueue *)iconOperationQueue;
@end

@interface HGSIconProvider ()
- (id)initWithResult:(HGSResult *)result skipPlaceholder:(BOOL)skipPlaceholder;
- (void)basicDiskLoad:(id)ignored operation:(NSOperation *)op;
- (void)advancedDiskLoad:(id)ignored operation:(NSOperation *)op;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData
          operation:(NSOperation *)operation;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error
          operation:(NSOperation *)operation;

// All of these are intentionally atomic
@property (readwrite, retain) NSImage *icon;
@property (readwrite, assign) HGSResult *result;

@end

@implementation HGSIconCache

GTMOBJECT_SINGLETON_BOILERPLATE(HGSIconCache, sharedIconCache);

- (id)init {
  if ((self = [super init])) {
    iconOperationQueue_ = [[NSOperationQueue alloc] init];
    if ([GTMSystemVersion isSnowLeopardOrGreater]) {
      [iconOperationQueue_ setName:@"com.google.qsb.hgsiconcache"];
    }
    advancedCache_ = [[HGSLRUCache alloc] initWithCacheSize:kIconCacheSize
                                                  callBacks:&kLRUCacheCallbacks
                                               evictContext:self];
    basicCache_ = [[HGSLRUCache alloc] initWithCacheSize:kIconCacheSize
                                               callBacks:&kLRUCacheCallbacks
                                            evictContext:self];
    placeHolderIcon_ = [[NSImage imageNamed:@"blue-placeholder"] retain];
    compoundPlaceHolderIcon_
      = [[NSImage imageNamed:NSImageNameMultipleDocuments] retain];
  }
  return self;
}

// COV_NF_START
// Singleton, so this is never called.
- (void)dealloc {
  [iconOperationQueue_ cancelAllOperations];
  [iconOperationQueue_ release];
  [advancedCache_ release];
  [basicCache_ release];
  [placeHolderIcon_ release];

  [super dealloc];
}
// COV_NF_END

- (NSImage *)placeHolderIcon {
  return placeHolderIcon_;
}

- (NSImage *)compoundPlaceHolderIcon {
  return compoundPlaceHolderIcon_;
}

- (NSImage *)cachedIconForResult:(HGSResult *)result {
  NSString *urlString = IconAdvancedURIStringForResult(result);
  NSImage *icon = [self cachedIconForKey:urlString fromCache:advancedCache_];
  return icon;
}

- (NSImage *)cachedBasicIconForResult:(HGSResult *)result {
  NSString *urlString = IconBasicURIStringForResult(result);
  NSImage *icon = [self cachedIconForKey:urlString fromCache:basicCache_];
  return icon;
}

- (HGSIconProvider *)iconProviderForResult:(HGSResult *)result
                           skipPlaceholder:(BOOL)skipPlaceholder {
  return [[[HGSIconProvider alloc] initWithResult:result
                                  skipPlaceholder:skipPlaceholder] autorelease];
}

- (NSImage *)cachedIconForKey:(NSString *)key fromCache:(HGSLRUCache *)cache {
  NSImage *icon = nil;
  @synchronized(cache) {
    icon = (NSImage *)[cache valueForKey:key];
  }
  return [[icon retain] autorelease];
}

- (NSImage *)cachedIconForKey:(NSString *)key {
  return [self cachedIconForKey:key fromCache:advancedCache_];
}

- (void)cacheIcon:(NSImage *)icon
           forKey:(NSString *)key
            cache:(HGSLRUCache *)cache {
  if (icon) {
    // Create up cached values in the sizes we care about
    NSImage *newIcon
      = [[[NSImage alloc] initWithSize:NSMakeSize(96, 96)] autorelease];
    NSUInteger sizes[] = { 96, 32, 16 };
    size_t totalSize = 0;
    for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); ++i) {
      NSBitmapImageRep *imageRep
        = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                   pixelsWide:sizes[i]
                                                   pixelsHigh:sizes[i]
                                                bitsPerSample:8
                                              samplesPerPixel:4
                                                     hasAlpha:YES
                                                     isPlanar:NO
                                               colorSpaceName:NSCalibratedRGBColorSpace
                                                 bitmapFormat:0
                                                  bytesPerRow:0
                                                 bitsPerPixel:0] autorelease];
      NSGraphicsContext *gc
        = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
      [NSGraphicsContext saveGraphicsState];
      [NSGraphicsContext setCurrentContext:gc];
      [gc setImageInterpolation:NSImageInterpolationHigh];
      [icon drawInRect:GTMNSRectOfSize(NSMakeSize(sizes[i], sizes[i]))
              fromRect:GTMNSRectOfSize([icon size])
             operation:NSCompositeCopy
              fraction:1.0];
      [NSGraphicsContext restoreGraphicsState];
      [newIcon addRepresentation:imageRep];
      // * 4 because we have 4 samples for pixel
      // / 8 because we have 8 pixels in a byte
      size_t repImageSize = ([imageRep pixelsHigh]
                             * [imageRep pixelsWide]
                             * [imageRep bitsPerSample] * 4 / 8);
      totalSize += repImageSize;
    }
    @synchronized(cache) {
      [cache setValue:newIcon forKey:key size:totalSize];
    }
  }
}

- (void)cacheIcon:(NSImage *)icon forKey:(NSString *)key {
  [self cacheIcon:icon forKey:key cache:advancedCache_];
}

- (void)cacheBasicIcon:(NSImage *)icon forResult:(HGSResult *)result {
  NSString *basicURI = IconBasicURIStringForResult(result);
  if (basicURI) {
     [self cacheIcon:icon forKey:basicURI cache:basicCache_];
  }
}

// Return an image that has a round rectangle frame and a drop shadow
- (NSImage *)imageWithRoundRectAndDropShadow:(NSImage *)image {
  if (!image) return nil;

  NSSize preferredSize = [self preferredIconSize];
  NSRect borderRect = GTMNSRectOfSize(preferredSize);
  borderRect = NSInsetRect(borderRect, 8.0, 8.0);
  //NSImageRep *bestRep = [image gtm_bestRepresentationForSize:borderRect.size];
  //@rcarmo patch for 10.6+
  NSImageRep *bestRep = [image bestRepresentationForRect:borderRect context:nil hints:nil];

  NSRect bestRepRect = GTMNSRectOfSize([bestRep size]);
  NSRect drawRect = GTMNSScaleRectToRect(bestRepRect,
                                         borderRect,
                                         GTMScaleProportionally,
                                         GTMRectAlignCenter);
  drawRect = NSIntegralRect(drawRect);
  NSRect insetRect = NSInsetRect(drawRect, 0.5, 0.5);

  CGColorSpaceRef cspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  GTMCFAutorelease(cspace);
  CGContextRef cgContext
    = CGBitmapContextCreate(NULL,
                            preferredSize.width,
                            preferredSize.height,
                            8,
                            32 * preferredSize.width,
                            cspace,
                            kCGBitmapByteOrder32Host
                            | kCGImageAlphaPremultipliedLast);
  GTMCFAutorelease(cgContext);

  NSGraphicsContext *nsContext
    = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext
                                                 flipped:NO];
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:nsContext];
  NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
  [aShadow setShadowOffset:NSMakeSize(0, -1)];
  [aShadow setShadowBlurRadius:2];
  [aShadow set];
  [nsContext setImageInterpolation:NSImageInterpolationHigh];
  CGContextBeginTransparencyLayer(cgContext, NULL);
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:insetRect
                                                       xRadius:2.0
                                                       yRadius:2.0];
  [nsContext saveGraphicsState];
  [path setClip];
  [bestRep drawInRect:drawRect];
  [nsContext restoreGraphicsState];
  [path setLineWidth:1.0];
  [[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.25] setStroke];
  [path stroke];
  CGContextEndTransparencyLayer(cgContext);
  [NSGraphicsContext restoreGraphicsState];

  NSImage *formattedImage
    = [[[NSImage alloc] initWithSize:preferredSize] autorelease];
  CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
  GTMCFAutorelease(cgImage);
  NSBitmapImageRep *imageRep
    = [[[NSBitmapImageRep alloc] initWithCGImage:cgImage] autorelease];
  [formattedImage addRepresentation:imageRep];
  return formattedImage;
}

- (NSSize)preferredIconSize {
  return NSMakeSize(96.0, 96.0);
}

- (void)setValueOnMainThread:(NSDictionary *)args {
  GTMAssertRunningOnMainThread();
  HGSResult *result = [args objectForKey:kHGSIconProviderResultKey];
  NSString *key = [args objectForKey:kHGSIconProviderAttrKey];
  NSImage *icon = [args objectForKey:kHGSIconProviderValueKey];
  NSString *uri = [args objectForKey:kHGSIconProviderURIKey];
  [result willChangeValueForKey:key];
  [self cacheIcon:icon forKey:uri];
  [result didChangeValueForKey:key];
}

- (void)setIcon:(NSImage *)icon
      forResult:(HGSResult *)result {
  NSString *uriString = IconAdvancedURIStringForResult(result);
  NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                        result, kHGSIconProviderResultKey,
                        icon, kHGSIconProviderValueKey,
                        kHGSObjectAttributeIconKey, kHGSIconProviderAttrKey,
                        uriString, kHGSIconProviderURIKey,
                        nil];
  [self performSelectorOnMainThread:@selector(setValueOnMainThread:)
                         withObject:args
                      waitUntilDone:NO];
}

- (NSOperationQueue *)iconOperationQueue {
  return iconOperationQueue_;
}
@end

@implementation HGSIconProvider

@synthesize icon = icon_;
@dynamic result;

- (id)initWithResult:(HGSResult *)result skipPlaceholder:(BOOL)skipPlaceholder {
  if ((self = [super init])) {
    [self setResult:result];
    HGSIconCache *cache = [HGSIconCache sharedIconCache];
    // Check to see if we have a cached icon
    NSImage *icon = [cache cachedIconForResult:result];
    if (!icon) {
      // No cached icon
      // Check to see if we have a cached basic icon
      icon = [cache cachedBasicIconForResult:result];
      if (!icon && !skipPlaceholder) {
        basicOperation_
          = [[HGSInvocationOperation alloc] initWithTarget:self
                                                  selector:@selector(basicDiskLoad:operation:)
                                                    object:nil];
      }
      NSString *urlString = IconURLStringForResult(result);
      if ([urlString hasPrefix:@"file:"]) {
        advancedOperation_
          = [[HGSInvocationOperation alloc] initWithTarget:self
                                                  selector:@selector(advancedDiskLoad:operation:)
                                                    object:nil];
      } else {
        // Explicitly without the colon, as we will take https as well.
        if ([urlString hasPrefix:@"http"]) {
          NSURL *url = [NSURL URLWithString:urlString];
          NSURLRequest *request = [NSURLRequest requestWithURL:url];
          GDataHTTPFetcher *fetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
          advancedOperation_
            = [[HGSFetcherOperation alloc] initWithTarget:self
                                               forFetcher:fetcher
                                        didFinishSelector:@selector(httpFetcher:finishedWithData:operation:)
                                          didFailSelector:@selector(httpFetcher:failedWithError:operation:)];
        }
      }
    }
    if (!icon) {
      if (!skipPlaceholder) {
       icon = [cache placeHolderIcon];
      }
    }
    if (icon) {
      [self setIcon:icon];
    }
    if (!icon && skipPlaceholder) {
      [self basicDiskLoad:nil operation:nil];
    }
    NSOperationQueue *iconOperationQueue = [cache iconOperationQueue];
    if (basicOperation_) {
      [iconOperationQueue addOperation:basicOperation_];
    }
    if (advancedOperation_) {
      [iconOperationQueue addOperation:advancedOperation_];
    }
  }
  return self;
}

- (void)dealloc {
  [basicOperation_ release];
  [advancedOperation_ release];
  [self setIcon:nil];
  [super dealloc];
}

- (HGSResult *)result {
  HGSResult *result = nil;
  @synchronized (self) {
    result = [result_ retain];
  }
  return [result autorelease];
}

- (void)setResult:(HGSResult *)result {
  @synchronized (self) {
    result_ = result;
  }
}

- (void)invalidate {
  [self setResult:nil];
  [basicOperation_ cancel];
  [advancedOperation_ cancel];
}

- (void)basicDiskLoad:(id)ignored operation:(NSOperation *)op {
  if ([op isCancelled]) return;
  HGSResult *result = [self result];
  if (!result) return;

  NSString *urlString = IconURLStringForResult(result);
  if (!urlString) return;
  NSImage *icon = nil;
  if ([urlString hasPrefix:@"file://"]) {
    if (!icon) {
      NSUInteger fromIndex = [urlString hasPrefix:@"file://localhost"] ? 16 : 7;
      NSString *urlPath = [urlString substringFromIndex:fromIndex];
      urlPath
        = [urlPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      NSWorkspace *ws = [NSWorkspace sharedWorkspace];
      icon = [ws iconForFile:urlPath];
    }
  } else {
    NSURL *url = [NSURL URLWithString:urlString];
    icon = FileSystemImageForURL(url);
  }
  if ([op isCancelled]) return;
  if (icon) {
    [self setIcon:icon];
    HGSIconCache *cache = [HGSIconCache sharedIconCache];
    [cache cacheBasicIcon:icon forResult:result];
    [cache setIcon:icon forResult:result];
  }

}

- (void)advancedDiskLoad:(id)ignored operation:(NSOperation *)op {
  if ([op isCancelled]) return;
  HGSResult *result = [self result];
  if (!result) return;

  NSString *urlString = IconURLStringForResult(result);
  NSImage *icon = nil;
  if (urlString) {
    NSString *extension = [[urlString pathExtension] lowercaseString];
    NSArray *ignoreArray
      = [NSArray arrayWithObjects:@"prefpane", @"app", @"framework", nil];
    BOOL ignoreQuickLook = [ignoreArray containsObject:extension];
    ignoreQuickLook &= ![urlString hasPrefix:@"file:///"];

    if (!ignoreQuickLook) {
      NSURL *url = [NSURL URLWithString:urlString];

      NSDictionary *dict
        = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                      forKey:(NSString *)kQLThumbnailOptionIconModeKey];
      CGImageRef ref = QLThumbnailImageCreate(kCFAllocatorDefault,
                                              (CFURLRef)url,
                                              CGSizeMake(96, 96),
                                              (CFDictionaryRef)dict);
      if ([op isCancelled]) {
        if (ref) {
          CFRelease(ref);
        }
        return;
      }

      if (ref) {
        NSBitmapImageRep *bitmapImageRep
          = [[NSBitmapImageRep alloc] initWithCGImage:ref];
        if (bitmapImageRep) {
          NSSize bitmapSize = [bitmapImageRep size];
          icon = [[[NSImage alloc] initWithSize:bitmapSize] autorelease];
          [icon addRepresentation:bitmapImageRep];
          [bitmapImageRep release];
        }
        CFRelease(ref);
      }
    }
    if (icon) {
      [self setIcon:icon];
      HGSIconCache *cache = [HGSIconCache sharedIconCache];
      [cache setIcon:icon forResult:result];
    }
  }
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData
          operation:(NSOperation *)operation {
  if ([operation isCancelled]) return;
  HGSResult *result = [self result];
  if (!result) return;

  NSImage *favicon = [[[NSImage alloc] initWithData:retrievedData] autorelease];
  NSURL *url = [[fetcher request] URL];
  NSImage *icon = nil;
  HGSIconCache *cache = [HGSIconCache sharedIconCache];
  if ([[url absoluteString] hasSuffix:@"favicon.ico"]) {
    NSImage *baseImage = FileSystemImageForURL(url);
    NSSize iconSize = [cache preferredIconSize];
    NSSize baseImageSize = NSMakeSize(32, 32);
    NSSize faviconSize = NSMakeSize(16, 16);
    [baseImage setSize:baseImageSize];
    [favicon setSize:faviconSize];
    icon = [[[NSImage alloc] initWithSize:iconSize] autorelease];
    NSBitmapImageRep *imageRep
      = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                 pixelsWide:baseImageSize.width
                                                 pixelsHigh:baseImageSize.height
                                              bitsPerSample:8
                                            samplesPerPixel:4
                                                   hasAlpha:YES
                                                   isPlanar:NO
                                             colorSpaceName:NSCalibratedRGBColorSpace
                                               bitmapFormat:0
                                                bytesPerRow:0
                                               bitsPerPixel:0] autorelease];
    NSGraphicsContext *gc
      = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:gc];
    [baseImage drawInRect:GTMNSRectOfSize(baseImageSize)
                 fromRect:GTMNSRectOfSize(baseImageSize)
                operation:NSCompositeCopy fraction:1.0];
    [favicon drawInRect:NSMakeRect(baseImageSize.width / 2,
                                   0,
                                   baseImageSize.height / 2,
                                   baseImageSize.width / 2)
               fromRect:GTMNSRectOfSize(faviconSize)
              operation:NSCompositeSourceOver
               fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    [icon addRepresentation:imageRep];

    baseImageSize = iconSize;
    faviconSize = NSMakeSize(32, 32);
    [baseImage setSize:baseImageSize];
    [favicon setScalesWhenResized:YES];
    [favicon setSize:faviconSize];
    imageRep
      = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                 pixelsWide:baseImageSize.width
                                                 pixelsHigh:baseImageSize.height
                                              bitsPerSample:8
                                            samplesPerPixel:4
                                                   hasAlpha:YES
                                                   isPlanar:NO
                                             colorSpaceName:NSCalibratedRGBColorSpace
                                               bitmapFormat:0
                                                bytesPerRow:0
                                               bitsPerPixel:0] autorelease];
    gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:gc];
    [baseImage drawInRect:GTMNSRectOfSize(baseImageSize)
                 fromRect:GTMNSRectOfSize(baseImageSize)
                operation:NSCompositeCopy
                 fraction:1.0];
    [favicon drawInRect:NSMakeRect(56,8,32,32)
               fromRect:GTMNSRectOfSize(faviconSize)
              operation:NSCompositeSourceOver
               fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    [icon addRepresentation:imageRep];
  } else {
    [favicon setScalesWhenResized:YES];
    [favicon setSize:NSMakeSize(32,32)];
    icon = favicon;
  }
  if (icon) {
    [self setIcon:icon];
    [cache setIcon:icon forResult:result];
  }
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error
          operation:(NSOperation *)operation {
}

@end

static const void *LRURetain(CFAllocatorRef allocator, const void *value) {
  return [(id)value retain];
}

static void LRURelease(CFAllocatorRef allocator, const void *value) {
  // We want to autorelease (as opposed to release) because we want the
  // actual dealloc of the item to occur outside the "cache" lock.
  // We had a bug where dealloc'ing an image caused us to deadlock
  // because we had the NSAppKitLock in thread 1 and were waiting
  // on the HGSIconProvider advancedCache_ lock, and in thread 2 we had the
  // HGSIconProvider advancedCache_ lock and were waiting on NSAppKitLock.
  // By switching the release to an autorelease, we should get out of the
  // cache lock on thread 2, before attempting to release the image which
  // acquires the NSAppKitLock.

  //  Thread 1...
  //  928 -[NSTableView _drawContentsAtRow:column:withCellFrame:]
  //    928 -[QSBViewTableViewCell drawWithFrame:inView:]
  //      928 -[NSView addSubview:]
  //        928 -[NSView _setWindow:]
  //          928 CFArrayApplyFunction
  //            928 __NSViewRecursionHelper
  //              928 -[NSControl _setWindow:]
  //                928 -[NSView _setWindow:]
  //                  928 -[QSBResultIconView viewDidMoveToWindow]
  //                    928 -[NSView displayIfNeeded]
  //                      928 -[NSView _sendViewWillDrawInRect:]
  //                        928 -[NSView viewWillDraw]
  //                          928 -[NSTableView viewWillDraw]
  //                            928 -[NSView viewWillDraw]
  //                              928 -[NSView viewWillDraw]
  //                                928 -[QSBResultIconView viewWillDraw]
  //                                  928 -[HGSResult valueForKey:]
  //                                    928 -[HGSResult provideValueForKey:result:]
  //                                      928 -[HGSIconProvider provideIconForResult:loadLazily:useCache:]
  //                                        928 -[HGSIconProvider cachedIconForKey:]
  //                                          928 pthread_mutex_lock
  //                                            928 semaphore_wait_signal_trap
  //                                              928 semaphore_wait_signal_trap
  //  Thread 2...
  //  928 -[HGSInvocationOperation intermediateInvocation:]
  //    928 -[HGSIconOperation performDiskLoad:]
  //      928 -[HGSIconProvider cacheIcon:forKey:]
  //        928 -[HGSLRUCache setValue:forKey:size:]
  //          928 -[HGSLRUCache removeValueForKey:]
  //            928 CFDictionaryRemoveValue
  //              928 HGSLRUCacheEntryRelease
  //                928 LRURelease
  //                  928 -[NSImage dealloc]
  //                    928 -[NSImage _setRepresentationListCache:]
  //                      928 _CFRelease
  //                        928 __CFArrayReleaseValues
  //                          928 CFRelease
  //                            928 -[NSIconRefBitmapImageRep dealloc]
  //                              928 -[NSBitmapImageRep dealloc]
  //                                928 SetCustomCGColorSpace
  //                                  928 _NSAppKitLock
  //                                    928 -[NSRecursiveLock lock]
  //                                      928 pthread_mutex_lock
  //                                        928 semaphore_wait_signal_trap
  //                                          928 semaphore_wait_signal_trap
  [(id)value autorelease];
}

static Boolean LRUEqual(const void *value1, const void *value2) {
  return [(id)value1 isEqual:(id)value2];
}

static CFHashCode LRUHash(const void *value) {
  return [(id)value hash];
}

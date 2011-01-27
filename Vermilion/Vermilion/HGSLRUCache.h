//
//  HGSLRUCache.h
//
//  LRU caching container with CF-container-like callback semantics.
//
//  TODO(aharper): Consider implementing LRU-SP (Kai Cheng, Yahiko Kambayashi).
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

#import <Foundation/Foundation.h>


//////////////////////////////////////////////////////////////////////////
#pragma mark Callbacks
//////////////////////////////////////////////////////////////////////////

// Like various CF container types callers supply us with callbacks that
// specify functions we call to manage the cache keys and values.

// Callback types
typedef const void *(*HGSLRUCacheRetainCallBack)(CFAllocatorRef allocator, const void *value);
typedef void (*HGSLRUCacheReleaseCallBack)(CFAllocatorRef allocator, const void *value);
typedef Boolean (*HGSLRUCacheEqualCallBack)(const void *value1, const void *value2);
typedef CFHashCode (*HGSLRUCacheHashCallBack)(const void *value);
typedef BOOL (*HGSLRUEvictionHashCallBack)(const void *key, const void *value, void *context);

// Callbacks
typedef struct {
  CFIndex                      version;
  HGSLRUCacheRetainCallBack    keyRetain;
  HGSLRUCacheReleaseCallBack   keyRelease;
  HGSLRUCacheEqualCallBack     keyEqual;
  HGSLRUCacheHashCallBack      keyHash;
  HGSLRUCacheRetainCallBack    valueRetain;
  HGSLRUCacheReleaseCallBack   valueRelease;
  HGSLRUEvictionHashCallBack   evict;
} HGSLRUCacheCallBacks;


//////////////////////////////////////////////////////////////////////////
#pragma mark Basic Cache Interface
//////////////////////////////////////////////////////////////////////////

// LRU cache implementation where the caller supplies the needed callbacks.
// Similar semantics to a CF container.
//
// NOTE: Cache deallocation does _not_ trigger eviction callbacks.
//
@interface HGSLRUCache : NSObject {
 @protected
  size_t                        cacheSize_;
  HGSLRUCacheCallBacks          *callBacks_;
  CFDictionaryKeyCallBacks      dictKeyCallBacks_;
  CFMutableDictionaryRef        cache_;  // strong
  void                          *lruHead_,
                                *lruTail_;  // weak
  size_t                        currentSize_;
  void                          *evictContext_;  // weak
}

// Designated initializer
//
// Args:
//   size: Number of bytes to hold in the cache. Note that this limit
//         only applies to values stored in the cache. Cache keys and other
//         overhead are not accounted for (if your cache keys are large this
//         may be a problem).
//   callBacks: A properly filled in HGSLRUCacheCallBacks structure.
//   evictContext: Context pointer passed to the eviction callback (may be
//                 NULL). This is weakly held by the cache, it is the
//                 caller's responsibility to clean up.
//
- (id)initWithCacheSize:(size_t)size
              callBacks:(HGSLRUCacheCallBacks *)callBacks
           evictContext:(void *)evictContext;

// Obtain a value from the cache (if the cache contains that value). If the
// cache does not contain the value its up to the caller to obtain the value
// and populate the cache using the setCacheValue:... methods.
//
// Args:
//   key: Cache key (must be compatible with HGSLRUCacheCallBacks)
//
// Returns:
//   Pointer to the cache value (caller must retain, value is not copied)
//   or NULL if the value is not in the cache.
//
- (const void *)valueForKey:(const void *)key;

// Force the removal of a cached value, erasing all knowledge of the key and
// value. Removal from the cache is _not_ the same as eviction, and the
// eviction callbacks are not triggered. Essentially this method is used
// to make the cache completely forget about some cached key/value.
//
// NOTE: Improper use of this call will prevent cache auto-tuning from
//       operating correctly.
//
- (void)removeValueForKey:(const void *)key;

// Add or replace a value to the cache given its key and size. Value size must
// be small enough to fit in the cache. Replacing a current cache value with
// the same key does not trigger eviction callbacks (it is presumed the caller
// is updating the cache).
//
// NOTE: No attempt is made to cost-analyze large values vs. small. If you
// insert a value that consumes all cache space all other values are evicted.
// Adding a value to the cache triggers immediate eviction callbacks till
// the cache has enough space to hold the new value. It is the caller's
// responsibility to handle any locking in this case.
//
// Args:
//  value: Cache value (must be compatible with HGSLRUCacheCallBacks)
//  key: Cache key (must be compatible with HGSLRUCacheCallBacks)
//  size: Bytes of the cache value (not the cache key). Only cache value sizes
//        are accounted for.
//
// Returns:
//  YES on successful cache, NO if the value is too large for the cache or
//  any other error (including failures from eviction callbacks).
//
- (BOOL)setValue:(const void *)value forKey:(const void *)key size:(size_t)size;

// Get a count of the number of cached values
//
// Returns:
//   Current cached element count
//
- (CFIndex)count;

// Populate caller supplied arrays with pointers to all cache keys and values.
//
// Note: Arrays are filled in eviction order from least-likely to evict to
//       most-likely to evict.
//
// Args:
//   keys: Caller-supplied pointer array, or NULL if no keys are desired.
//         Caller is responsible for sizing the array to [HGSLRUCache count]
//   values: Caller-supplied pointer array or NULL if no values are desired.
//           Again, caller must size appropriately.
//
- (void)getKeys:(const void **)keys values:(const void **)values;

@end

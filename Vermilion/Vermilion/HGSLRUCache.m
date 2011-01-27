//
//  HGSLRUCache.m
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

#import "HGSLRUCache.h"
#import "HGSLog.h"

// Although the cache looks like a dictionary to the caller, internally
// it is actually one (or more for future implementations like LRU-SP)
// linked lists where list members are also placed in a dictionary for
// keyed access. These structures and routines support the linked list and
// dictionary usage.

typedef struct HGSLRUCacheEntryStruct {
  int                             retainCount;
  HGSLRUCacheCallBacks            *callbacks;
  size_t                          size;
  const void                      *key;
  const void                      *value;
  struct HGSLRUCacheEntryStruct   *previous;
  struct HGSLRUCacheEntryStruct   *next;
} HGSLRUCacheEntry;

static const void * HGSLRUCacheEntryRetain(CFAllocatorRef allocator,
                                            const void *value) {

  // Don't null check value, we'd rather crash
  ((HGSLRUCacheEntry *)value)->retainCount++;
  return value;

} // HGSLRUCacheEntryRetain

static void HGSLRUCacheEntryRelease(CFAllocatorRef allocator,
                                    const void *value) {

  HGSLRUCacheEntry *cacheEntry = (HGSLRUCacheEntry *)value;
  // Don't null check value, we'd rather crash
  cacheEntry->retainCount--;
  if (cacheEntry->retainCount < 1) {
    // Free key and value (both are always present in LRU)
    cacheEntry->callbacks->keyRelease(allocator, cacheEntry->key);
    cacheEntry->callbacks->valueRelease(allocator, cacheEntry->value);
    // Don't clean up link list here, if we have a bug that leaves them
    // wrong we want a bad access later
    CFAllocatorDeallocate(allocator, cacheEntry);
  }

} // HGSLRuCacheEntryRelease

static CFDictionaryValueCallBacks gHGSLRUCacheEntryDictionaryValueCallBacks = {
  0,
  &HGSLRUCacheEntryRetain,
  &HGSLRUCacheEntryRelease,
  NULL,
  NULL
}; // gHGSLRUCacheEntryDictionaryValueCallBacks


@implementation HGSLRUCache

- (id)initWithCacheSize:(size_t)size
              callBacks:(HGSLRUCacheCallBacks *)callBacks
           evictContext:(void *)evictContext {

  self = [super init];
  if (!self) return nil;

  // Sanity
  if (!callBacks || (callBacks->version != 0) || !size) {
    [self release];
    return nil;
  }

  // Copy setup
  cacheSize_ = size;
  callBacks_ = callBacks;
  evictContext_ = evictContext;

  // Set up the dictionary key callbacks. Since the cache keys are
  // direct-access only we have no intermediate structure.
  dictKeyCallBacks_.version = 0;
  dictKeyCallBacks_.retain = callBacks_->keyRetain;
  dictKeyCallBacks_.release = callBacks_->keyRelease;
  dictKeyCallBacks_.copyDescription = NULL;
  dictKeyCallBacks_.equal = callBacks_->keyEqual;
  dictKeyCallBacks_.hash = callBacks_->keyHash;

  // Create the cache dictionary and set
  cache_ = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                     0,
                                     &dictKeyCallBacks_,
                                     &gHGSLRUCacheEntryDictionaryValueCallBacks);
  if (!cache_) {
    // COV_NF_START
    [self release];
    return nil;
    // COV_NF_END
  }

  return self;

} // initWithCacheSize:callBacks:

- (void)dealloc {

  if (cache_) CFRelease(cache_);
  [super dealloc];

} // dealloc

- (const void *)valueForKey:(const void *)key {

  // Look for the value in the cache
  HGSLRUCacheEntry *cacheEntry = (HGSLRUCacheEntry *)CFDictionaryGetValue(cache_, key);
  if (!cacheEntry) return NULL;  // no cache hit

  // If its already at the head assume everything is already OK
  if (lruHead_ == cacheEntry) return cacheEntry->value;

  // Remove from list middle, previous must exist (else we would have
  // been at head above)
  assert(cacheEntry->previous);
  cacheEntry->previous->next = cacheEntry->next;
  if (cacheEntry->next) cacheEntry->next->previous = cacheEntry->previous;

  // Remove from tail if its there (single element case where head == tail not
  // possible because head check above would have short-circuited above)
  assert(lruTail_);
  assert(lruTail_ != lruHead_);
  if (lruTail_ == cacheEntry) lruTail_ = cacheEntry->previous;

  // Move hit to head, head must already exist so it can become our next
  assert(lruHead_);
  cacheEntry->previous = NULL;
  cacheEntry->next = lruHead_;
  cacheEntry->next->previous = cacheEntry;
  lruHead_ = cacheEntry;

  return cacheEntry->value;

} // valueForKey

- (void)removeValueForKey:(const void *)key {

  HGSLRUCacheEntry *cacheEntry 
    = (HGSLRUCacheEntry *)CFDictionaryGetValue(cache_, key);
  if (!cacheEntry) return;  // No bookkeeping

  // Remove from head
  if (lruHead_ == cacheEntry) {
    assert(!cacheEntry->previous);
    lruHead_ = cacheEntry->next;
  }

  // Remove from tail
  if (lruTail_ == cacheEntry) {
    assert(!cacheEntry->next);
    lruTail_ = cacheEntry->previous;
  }

  // Remove from list middle
  if (cacheEntry->previous) cacheEntry->previous->next = cacheEntry->next;
  if (cacheEntry->next) cacheEntry->next->previous = cacheEntry->previous;

  // Fix size
  assert(currentSize_ >= cacheEntry->size);
  currentSize_ -= cacheEntry->size;

  // Remove from dictionary (this releases the entry, |cacheEntry| invalid
  // from here on)
  CFDictionaryRemoveValue(cache_, key);

} // removeValueForKey:

- (BOOL)setValue:(const void *)value forKey:(const void *)key size:(size_t)size {

  // Remove any prior value for this key. Doing this before even checking
  // whether the new object fits in cache is correct. We should interpret
  // the new value for the key as an indication that our old value for that
  // key is bad, so remove the old cache value before signaling failure.
  [self removeValueForKey:key];

  // Too big to fit at all?
  if (size > cacheSize_) return NO;

  // Remove from tail till there is space
  while (currentSize_ > (cacheSize_ - size)) {
    assert(lruTail_);
    // Evict
    if (callBacks_->evict) {
      if (!callBacks_->evict(((HGSLRUCacheEntry *)lruTail_)->key,
                             ((HGSLRUCacheEntry *)lruTail_)->value,
                             evictContext_)) {
        HGSLog(@"HGSLRUCache eviction failure.");
        return NO;
      }
    }
    // Remove
    [self removeValueForKey:((HGSLRUCacheEntry *)lruTail_)->key];
  }

  // Create a new cache entry
  HGSLRUCacheEntry *newEntry = CFAllocatorAllocate(kCFAllocatorDefault, 
                                                   sizeof(HGSLRUCacheEntry), 0);
  if (!newEntry) return NO;
  newEntry->retainCount = 1;  // Creation just to be proper about it.
  newEntry->callbacks = callBacks_;
  newEntry->size = size;
  newEntry->key = callBacks_->keyRetain(kCFAllocatorDefault, key);
  newEntry->value = callBacks_->valueRetain(kCFAllocatorDefault, value);
  newEntry->previous = NULL;
  newEntry->next = lruHead_;

  // Add to the dict
  CFDictionarySetValue(cache_, key, newEntry);

  // Dict has it now, release
  newEntry->retainCount--;

  // Fix head
  if (lruHead_) ((HGSLRUCacheEntry *)lruHead_)->previous = newEntry;
  lruHead_ = newEntry;

  // Fix tail if this is the first insert
  if (!lruTail_) lruTail_ = newEntry;

  // Update size
  currentSize_ += size;

  // Success
  return YES;

} // setValue:forKey:size:

- (CFIndex)count {

  return CFDictionaryGetCount(cache_);

} // count

- (void)getKeys:(const void **)keys values:(const void **)values {
  if (keys || values) {
    HGSLRUCacheEntry *current = (HGSLRUCacheEntry *)lruHead_;
    while (current) {
      if (keys) {
        *keys = current->key;
        keys++;
      }
      if (values) {
        *values = current->value;
        values++;
      }
      current = current->next;
    }
  } 
} // getKeys:values:

@end

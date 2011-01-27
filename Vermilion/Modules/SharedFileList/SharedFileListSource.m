//
//  SharedFileListSource.m
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
#import "GTMGarbageCollection.h"
#import "GTMSystemVersion.h"

// This is the LSSharedFileListItemRef for the item. Allows us to get at
// the icon and other properties as needed.
static NSString* const kObjectAttributeSharedFileListItem = 
  @"ObjectAttributeSharedFileListItem";

@interface SharedFileListStorage : NSObject {
 @private
  LSSharedFileListRef list_;
  UInt32 seed_;
  NSArray *results_;
}

@property(readonly) LSSharedFileListRef list;
@property(readwrite, nonatomic, assign) UInt32 seed;
@property(readwrite, nonatomic, retain) NSArray *results;

- (id)initWithList:(LSSharedFileListRef)list;
@end

// Private API that we are using as a workaround to 
// rdar://6602133
// LSSharedFileListItemResolve can trigger a LSShared file list change 
// notification
// Basically this would get us into an infinite loop if someone opened a file
// off of a server. ( http://code.google.com/p/qsb-mac/issues/detail?id=186 )
// This was on 10.5.6.
extern CFDataRef LSSharedFileListItemCopyAliasData(LSSharedFileListItemRef item);

@implementation SharedFileListStorage

@synthesize seed = seed_;
@synthesize results = results_;

- (id)init {
  HGSLog(@"Bad init of %@ use initWithList:", [self class]);
  return [self initWithList:nil];
}

- (id)initWithList:(LSSharedFileListRef)list {
  if ((self = [super init])) {
    if (!list) {
      [self release];
      self = nil;
    } else {
      list_ = list;
      CFRetain(list_);
    }
  }
  return self;
}

- (void)dealloc {
  if (list_) {
    CFRelease(list_);
  }
  [results_ release];
  [super dealloc];
}

- (LSSharedFileListRef)list {
  return list_;
}
@end

@interface SharedFileListSource : HGSMemorySearchSource {
@private
  NSMutableArray *storage_;  // SharedFileListStorage
}
- (void)loadFileLists;
- (void)observeFileLists:(BOOL)doObserve;
- (void)listChanged:(LSSharedFileListRef)list;
- (void)indexObjectsForList:(LSSharedFileListRef)list;
- (SharedFileListStorage *)storageForList:(LSSharedFileListRef)list;
@end

static void ListChanged(LSSharedFileListRef inList, void *context);

@implementation SharedFileListSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    CFStringRef lists[] = {
      kLSSharedFileListRecentServerItems,
      kLSSharedFileListFavoriteItems,
      kLSSharedFileListFavoriteVolumes,
      kLSSharedFileListRecentApplicationItems,
      kLSSharedFileListRecentDocumentItems,
    };
    size_t listsSize = sizeof(lists) / sizeof(lists[0]);
    storage_ = [[NSMutableArray alloc] initWithCapacity:listsSize];
    for (size_t i = 0; i < listsSize; ++i) {
      LSSharedFileListRef list = LSSharedFileListCreate(NULL, lists[i], NULL);
      if (!list) continue;
      [self indexObjectsForList:list];
      CFRelease(list);
    }
    [self loadFileLists];
    [self observeFileLists:YES];
  }
  return self;
}

- (void)dealloc {
  [self observeFileLists:NO];
  [storage_ release];
  [super dealloc];
}

- (void)observeFileLists:(BOOL)doObserve {
  CFRunLoopRef mainLoop = CFRunLoopGetMain();
  for (SharedFileListStorage *storage in storage_) {
    LSSharedFileListRef listRef = [storage list];
    if (doObserve) {
      LSSharedFileListAddObserver(listRef,
                                  mainLoop,
                                  kCFRunLoopDefaultMode,
                                  ListChanged,
                                  self);
    } else {
      LSSharedFileListRemoveObserver(listRef,
                                     mainLoop,
                                     kCFRunLoopDefaultMode,
                                     ListChanged,
                                     self);
    }      
  }
}

- (void)indexObjectsForList:(LSSharedFileListRef)list {
  UInt32 seed;
  NSArray *items =
    (NSArray *)GTMCFAutorelease(LSSharedFileListCopySnapshot(list, &seed));
  NSMutableArray *results = [NSMutableArray arrayWithCapacity:[items count]];
  for (id item in items) {
    LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
    OSStatus err = noErr;
    NSString *path = nil;
    if ([GTMSystemVersion isSnowLeopardOrGreater]) {
      CFURLRef cfURL = NULL;
      err = LSSharedFileListItemResolve(itemRef, 
                                        kLSSharedFileListNoUserInteraction
                                        | kLSSharedFileListDoNotMountVolumes, 
                                        &cfURL, NULL);
      if (err) continue;
      NSURL *url = GTMCFAutorelease(cfURL);
      path = [url path];
    } else {
      // This next chunk of code is to work around rdar://6602133 where
      // pre-Snow Leopard there is a bug in LSSharedFileListItemResolve
      // causing it to infinite loop.
      NSData *aliasData 
        = GTMCFAutorelease(LSSharedFileListItemCopyAliasData(itemRef));
      if (!aliasData) continue;
      AliasRecord *aliasRecord = (AliasRecord*)[aliasData bytes];
      AliasHandle alias = NULL;
      err = PtrToHand(aliasRecord, (Handle *)&alias, [aliasData length]);
      if (err) continue;
      err = FSCopyAliasInfo (alias, NULL, NULL, (CFStringRef *)&path, NULL, NULL);
      [path autorelease];
      DisposeHandle((Handle)alias);
      if (err) continue;
    }    
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                item, kObjectAttributeSharedFileListItem,
                                nil];
    
    HGSUnscoredResult *result = [HGSUnscoredResult resultWithFilePath:path
                                                               source:self
                                                           attributes:attributes];
    if (result) {
      [results addObject:result];
    }
  }
  SharedFileListStorage *storage = [self storageForList:list];
  // If we have storage, update it, otherwise create a new one.
  if (!storage) {
    storage = [[[SharedFileListStorage alloc] initWithList:list] autorelease];
    [storage_ addObject:storage];
  }
  [storage setResults:results];
  [storage setSeed:seed];
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeIconKey]) {
    id item = [result valueForKey:kObjectAttributeSharedFileListItem];
    if (item) {
      LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
      IconRef iconRef = LSSharedFileListItemCopyIconRef(itemRef);
      if (iconRef) {
        value = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
        ReleaseIconRef(iconRef);
      }
    }
  }
  if (!value) {
    value = [super provideValueForKey:key result:result];
  }
  
  return value;
}

- (HGSScoredResult *)postFilterScoredResult:(HGSScoredResult *)scoredResult 
                            matchesForQuery:(HGSQuery *)query
                               pivotObjects:(HGSResultArray *)pivotObjects {
  // Filter out any documents that are no longer named or located where
  // we remembered them being.
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [scoredResult filePath];
  if (!path || ![fm fileExistsAtPath:path isDirectory:NULL]) {
    scoredResult = nil;
  }
  return scoredResult;
}

// Reset our HGSMemorySource index with all of our values.
- (void)loadFileLists {
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  for (SharedFileListStorage* storage in storage_) {
    for (HGSResult *result in [storage results]) {
      [database indexResult:result];   
    }
  }
  [self replaceCurrentDatabaseWith:database];
}

// The list has changed, so we reindex it and then update our master
// index for all of our entries. Only update if the seed has changed.
- (void)listChanged:(LSSharedFileListRef)list {
  SharedFileListStorage *storage = [self storageForList:list];
  UInt32 oldSeed = [storage seed];
  if (oldSeed != LSSharedFileListGetSeedValue(list)) {
    [self indexObjectsForList:list];
    [self loadFileLists];
  }
}

// Given a list, return our SharedFileListStorage record if we have
// one.
- (SharedFileListStorage *)storageForList:(LSSharedFileListRef)list {
  SharedFileListStorage *storage = nil;
  for (storage in storage_) {
    if ([storage list] == list) break;
  }
  return storage;
}

// Trampoline to get us back into Objective-C from our C callback.
static void ListChanged(LSSharedFileListRef inList, void *context) {
  SharedFileListSource *object = (SharedFileListSource *)context;
  [object listChanged:inList];
}

@end

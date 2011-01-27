//
//  WebBookmarksSource.m
//
//  Copyright (c) 2008-2009 Google Inc. All rights reserved.
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

#import "WebBookmarksSource.h"
#import "GTMFileSystemKQueue.h"

@interface WebBookmarksSource ()
- (void)pathCheckTimer:(NSTimer *)timer;
- (void)fileChanged:(GTMFileSystemKQueue *)queue
              event:(GTMFileSystemKQueueEvents)event;
- (void)updateIndexForPath:(NSString *)path operation:(NSOperation*)op;
@end

@implementation WebBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration
            browserTypeName:(NSString *)browserTypeName
                fileToWatch:(NSString *)path {
  if ((self = [super initWithConfiguration:configuration])) {
    browserTypeName_ = [browserTypeName copy];
    path_ = [path copy];
    [self pathCheckTimer:nil];
    if (fileKQueue_) {
      // Force an indexing at startup.
      // Startup lag shouldn't be much of an issue, as it will immediately
      // spawn an operation.
      [self fileChanged:fileKQueue_ event:kGTMFileSystemKQueueWriteEvent];
    }
  }
  return self;
}

- (void)dealloc {
  [indexingOperation_ release];
  [pathCheckTimer_ release];
  [fileKQueue_ release];
  [browserTypeName_ release];
  [super dealloc];
}

- (void)uninstall {
  [indexingOperation_ cancel];
  [pathCheckTimer_ invalidate];
  [super uninstall];
}

- (void)pathCheckTimer:(NSTimer *)timer {
  GTMFileSystemKQueueEvents queueEvents = (kGTMFileSystemKQueueDeleteEvent
                                           | kGTMFileSystemKQueueWriteEvent
                                           | kGTMFileSystemKQueueRenameEvent);
  fileKQueue_
    = [[GTMFileSystemKQueue alloc] initWithPath:path_
                                      forEvents:queueEvents
                                  acrossReplace:YES
                                         target:self
                                         action:@selector(fileChanged:event:)];
  if (!fileKQueue_) {
    // the file we are looking for isn't around, so we'll set a timer
    // so we can look for it in the future
    [pathCheckTimer_ release];
    pathCheckTimer_
      = [[NSTimer scheduledTimerWithTimeInterval:60
                                          target:self
                                        selector:@selector(pathCheckTimer:)
                                        userInfo:nil
                                         repeats:NO] retain];
  }
}

- (void)indexResultNamed:(NSString *)name
                     URL:(NSString *)urlString
         otherAttributes:(NSDictionary *)otherAttributes
                    into:(HGSMemorySearchSourceDB *)database {
  if (!name || !urlString) {
    HGSLogDebug(@"Missing name (%@) or url (%@) for bookmark. Source %@",
                name, urlString, self);
    return;
  }
  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag
                         | eHGSNameMatchRankFlag];
  NSMutableDictionary *attributes
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       urlString, kHGSObjectAttributeSourceURLKey,
       rankFlags, kHGSObjectAttributeRankFlagsKey,
       @"star-flag", kHGSObjectAttributeFlagIconNameKey,
       nil];
  if (otherAttributes) {
    [attributes addEntriesFromDictionary:otherAttributes];
  }

  NSString* type = [NSString stringWithFormat:@"%@.%@",
                    kHGSTypeWebBookmark, browserTypeName_];
  HGSUnscoredResult* result
    = [HGSUnscoredResult resultWithURI:urlString
                                  name:name
                                  type:type
                                source:self
                            attributes:attributes];
  [database indexResult:result];
}

- (void)fileChanged:(GTMFileSystemKQueue *)queue
              event:(GTMFileSystemKQueueEvents)event {
  [indexingOperation_ cancel];
  [indexingOperation_ release];
  indexingOperation_
    = [[HGSInvocationOperation alloc] initWithTarget:self
                                            selector:@selector(updateIndexForPath:operation:)
                                              object:path_];
  [[HGSOperationQueue sharedOperationQueue] addOperation:indexingOperation_];
}

- (NSString *)domainURLForURLString:(NSString *)urlString {
  // This is parsed manually rather than round-tripped through NSURL so that
  // we can get domains from invalid URLs (like Camino search bookmarks).
  NSString *domainString = nil;
  NSRange schemeEndRange = [urlString rangeOfString:@"://"];
  if (schemeEndRange.location != NSNotFound) {
    NSUInteger domainStartIndex = NSMaxRange(schemeEndRange);
    NSRange domainRange = NSMakeRange(domainStartIndex,
                                      [urlString length] - domainStartIndex);
    NSRange pathStartRange = [urlString rangeOfString:@"/"
                                            options:0
                                              range:domainRange];
    if (pathStartRange.location == NSNotFound) {
      domainString = urlString;
    } else {
      domainString = [urlString substringToIndex:pathStartRange.location];
    }
  }
  return domainString;
}

- (void)updateIndexForPath:(NSString *)path operation:(NSOperation *)operation {
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  [self updateDatabase:database forPath:path operation:operation];
  if (![indexingOperation_ isCancelled]) {
    [self replaceCurrentDatabaseWith:database];
  }
}

- (void)updateDatabase:(HGSMemorySearchSourceDB *)database
               forPath:(NSString *)path
             operation:(NSOperation *)operation {
  [self doesNotRecognizeSelector:_cmd];
}
@end

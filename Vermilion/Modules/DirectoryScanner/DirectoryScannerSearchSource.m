//
//  DirectoryScannerSearchSource.m
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
#import "GTMFileSystemKQueue.h"

@interface DirectoryScannerSearchSource : HGSMemorySearchSource {
 @private
  NSString *path_;
  GTMFileSystemKQueue *kQueue_;
}
- (void)recacheContents;
- (void)directoryChanged:(GTMFileSystemKQueue *)queue
              eventFlags:(GTMFileSystemKQueueEvents)flags;
@end

@implementation DirectoryScannerSearchSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    path_ = [configuration objectForKey:@"rootPath"];
    path_ = [[path_ stringByStandardizingPath] retain];

    if (![self loadResultsCache]) {
      [self recacheContents];
    } else {
      [self performSelector:@selector(recacheContents)
                   withObject:nil
                   afterDelay:10.0];
    }

    kQueue_ = [[GTMFileSystemKQueue alloc] initWithPath:path_
                                              forEvents:kGTMFileSystemKQueueWriteEvent
                                          acrossReplace:NO
                                                 target:self
                                                 action:@selector(directoryChanged:eventFlags:)];
  }
  return self;
}

- (void)dealloc {
  [kQueue_ release];
  kQueue_ = nil;
  [path_ release];
  path_ = nil;
  [super dealloc];
}

- (void)directoryChanged:(GTMFileSystemKQueue *)queue
               eventFlags:(GTMFileSystemKQueueEvents)flags {
  // Retain ourself long enough to avoid a race condition in dealloc
  // See http://code.google.com/p/qsb-mac/issues/detail?id=575
  [[self retain] autorelease];
  [self recacheContents];
}

- (NSString *)displayName {
  return [[NSFileManager defaultManager] displayNameAtPath:path_];
}
- (NSImage *)icon {
  return [[NSWorkspace sharedWorkspace] iconForFile:path_];
}

- (void)recacheContents {
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];

  NSFileManager *manager = [NSFileManager defaultManager];
  NSError *error = nil;
  NSArray *array = [manager contentsOfDirectoryAtPath:path_ error:&error];
  if (error) {
    HGSLog(@"Unable to get contents of %@ (%@)", path_, error);
  }

  for (NSString *subpath in array) {
    LSItemInfoRecord infoRec;
    subpath = [path_ stringByAppendingPathComponent:subpath];
    NSURL *subURL = [NSURL fileURLWithPath:subpath];
    OSStatus status = paramErr;
    if (subURL) {
      status = LSCopyItemInfoForURL((CFURLRef)subURL,
                                    kLSRequestBasicFlagsOnly,
                                    &infoRec);
    }
    if (status) {
      // For some odd reason /dev always returns nsvErr.
      // Radar 6759537 - Getting URL info on /dev return -35 nsvErr
      if (![subpath isEqualToString:@"/dev"]) {
        HGSLogDebug(@"Unable to LSCopyItemInfoForURL (%d) for %@",
                    status, subURL);
      }
      continue;
    }
    if (infoRec.flags & kLSItemInfoIsInvisible) continue;
    if ([[subpath lastPathComponent] hasPrefix:@"."]) continue;


    HGSUnscoredResult *result = [HGSUnscoredResult resultWithFilePath:subpath
                                                               source:self
                                                           attributes:nil];
    [database indexResult:result];
  }
  [self replaceCurrentDatabaseWith:database];
  [self saveResultsCache];
}

@end

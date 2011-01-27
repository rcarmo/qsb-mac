//
//  HGSSafariBookmarksSource.m
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

#import "WebBookmarksSource.h"

//
// HGSSafariBookmarksSource
//
// Implements a Search Source for finding Safari Bookmarks.
//
@interface HGSSafariBookmarksSource : WebBookmarksSource 
- (void)indexSafariBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database 
                          operation:(NSOperation *)operation;
- (void)indexBookmark:(NSDictionary*)dict 
                 into:(HGSMemorySearchSourceDB *)database;
@end

@implementation HGSSafariBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  NSArray *libraryDirArray
    = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                          NSUserDomainMask,
                                          YES);
  if (![libraryDirArray count]) {
    // COV_NF_START
    // Library is always there
    HGSLog(@"Unable to find ~/Library");
    [self release];
    return nil;
    // COV_NF_END
  }
  NSString *libraryDir = [libraryDirArray objectAtIndex:0];
  NSString *fileToWatch = [libraryDir stringByAppendingPathComponent:@"Safari"];
  fileToWatch = [fileToWatch stringByAppendingPathComponent:@"Bookmarks.plist"];
  return [super initWithConfiguration:configuration
                      browserTypeName:@"safari"
                          fileToWatch:fileToWatch];
}

#pragma mark -

- (void)indexSafariBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database 
                          operation:(NSOperation *)operation {
  NSString *title = [dict objectForKey:@"Title"];
  if ([title isEqualToString:@"Archive"]) return; // Skip Archive folder

  NSEnumerator *childEnum = [[dict objectForKey:@"Children"] objectEnumerator];
  NSDictionary *child;
  while ((child = [childEnum nextObject])) {
    if ([operation isCancelled]) return;
    NSString *type = [child objectForKey:@"WebBookmarkType"];
    if ([type isEqualToString:@"WebBookmarkTypeLeaf"]) {
      [self indexBookmark:child into:database];
    } else if ([type isEqualToString:@"WebBookmarkTypeList"]) {
      [self indexSafariBookmarksForDict:child
                                   into:database
                              operation:operation];
    }
  }
}

- (void)indexBookmark:(NSDictionary*)dict 
                 into:(HGSMemorySearchSourceDB *)database {
  NSString* title = [[dict objectForKey:@"URIDictionary"] objectForKey:@"title"];
  NSString* urlString = [dict objectForKey:@"URLString"];
  
  if (!title || !urlString) {
    return;
  }
  [self indexResultNamed:title URL:urlString otherAttributes:nil into:database];
}

- (void)updateDatabase:(HGSMemorySearchSourceDB *)database
               forPath:(NSString *)path 
             operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict) {
      [self indexSafariBookmarksForDict:dict into:database operation:operation];
    }
  }
}

@end

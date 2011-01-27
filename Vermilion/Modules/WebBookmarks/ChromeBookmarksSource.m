//
//  ChromeBookmarksSource.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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
#import <JSON/JSON.h>

static NSString *const kChromeBookmarksSourceSubdirectoryKey
  = @"ChromeBookmarksSourceSubdirectory";

@interface ChromeBookmarksSource : WebBookmarksSource
- (void)indexChromeBookmark:(NSDictionary *)dict
                       into:(HGSMemorySearchSourceDB *)database;
- (void)indexChromeBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database
                          operation:(NSOperation *)operation;
@end

@implementation ChromeBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  NSArray *appSupportDirArray
    = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                          NSUserDomainMask,
                                          YES);
  if (![appSupportDirArray count]) {
    // COV_NF_START
    // App support is always there
    HGSLog(@"Unable to find ~/Library/Application Support/");
    [self release];
    return nil;
    // COV_NF_END
  }
  NSString *appSupportDir = [appSupportDirArray objectAtIndex:0];
  NSString *appSupportSubDir
    = [configuration objectForKey:kChromeBookmarksSourceSubdirectoryKey];
  NSString *fileToWatch
    = [appSupportDir stringByAppendingPathComponent:appSupportSubDir];
  fileToWatch
    = [fileToWatch stringByAppendingPathComponent:@"Default/Bookmarks"];

  return [super initWithConfiguration:configuration
                      browserTypeName:@"chrome"
                          fileToWatch:fileToWatch];
}

- (void)indexChromeBookmark:(NSDictionary*)dict
                       into:(HGSMemorySearchSourceDB *)database {
  NSString* nameString = [dict objectForKey:@"name"];
  NSString* urlString = [dict objectForKey:@"url"];
  if (nameString && urlString) {
    [self indexResultNamed:nameString 
                       URL:urlString 
           otherAttributes:nil 
                      into:database];
  }
}

- (void)indexChromeBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database 
                          operation:(NSOperation *)operation{
  NSArray *children = [dict objectForKey:@"children"];
  if (!children) {
    [self indexChromeBookmark:dict into:database];
  } else {
    for (NSDictionary *child in children) {
      if ([operation isCancelled]) return;
      [self indexChromeBookmarksForDict:child 
                                   into:database 
                              operation:operation];
    }
  }
}

- (void)updateDatabase:(HGSMemorySearchSourceDB *)database
               forPath:(NSString *)path 
             operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    NSString *json = [NSString stringWithContentsOfFile:path
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    NSDictionary *roots = [[json JSONValue] objectForKey:@"roots"];
    if (roots) {
      for (NSString *name in roots) {
        NSDictionary *dict = [roots objectForKey:name];
        [self indexChromeBookmarksForDict:dict 
                                     into:database 
                                operation:operation];
      }
    }
  }
}

@end

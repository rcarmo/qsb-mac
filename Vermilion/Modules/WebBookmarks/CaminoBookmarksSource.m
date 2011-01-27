//
//  HGSCaminoBookmarksSource.m
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

@interface HGSCaminoBookmarksSource : WebBookmarksSource
- (void)indexCaminoBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database
                          operation:(NSOperation *)operation;
- (void)indexBookmark:(NSDictionary*)dict
                 into:(HGSMemorySearchSourceDB *)database;
@end

@implementation HGSCaminoBookmarksSource

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
  NSString *fileToWatch = [appSupportDir stringByAppendingPathComponent:@"Camino"];
  fileToWatch = [fileToWatch stringByAppendingPathComponent:@"Bookmarks.plist"];
  
  return [super initWithConfiguration:configuration
                      browserTypeName:@"camino"
                          fileToWatch:fileToWatch];
}

- (void)indexCaminoBookmarksForDict:(NSDictionary *)dict
                               into:(HGSMemorySearchSourceDB *)database
                          operation:(NSOperation *)operation {
  NSArray *children = [dict objectForKey:@"Children"];
  if (children) {
    for (NSDictionary *child in children) {
      if ([operation isCancelled]) return;
      [self indexCaminoBookmarksForDict:child
                                   into:database
                              operation:operation];
    }
  } else {
    [self indexBookmark:dict into:database];
  }
}

- (void)indexBookmark:(NSDictionary*)dict 
                 into:(HGSMemorySearchSourceDB *)database {
  NSString* title = [dict objectForKey:@"Title"];
  NSString* urlString = [dict objectForKey:@"URL"];
  if (!title || !urlString) {
    return;
  }
  
  if ([urlString rangeOfString:@"%s"].location != NSNotFound) {
    // If it couldn't make a URL because it choked on a search template
    // marker, just use the domain as a best-gues raw URL.
    urlString = [self domainURLForURLString:urlString];
  }
  if (!urlString) {
    return;
  }
  
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSDate* lastVisit = [dict objectForKey:@"LastVisitedDate"];
  if (lastVisit) {
    [attributes setObject:lastVisit forKey:kHGSObjectAttributeLastUsedDateKey];
  }

  NSString *nameString = title;

  // Pre-parse the name into terms for faster searching, and store them.
  NSString* shortcut = [dict objectForKey:@"Keyword"];
  if (shortcut) {
    // add the shortcut for the nameString so it will be counted as a name match
    // when searching
    nameString = [nameString stringByAppendingFormat:@" %@", shortcut];
    // If it has a shortcut, it may be a search bookmark; if it is, mark it
    // appropriately.
    NSRange searchMarkerRange = [urlString rangeOfString:@"%s"];
    if (searchMarkerRange.location != NSNotFound) {
      NSMutableString* searchTemplate 
        = [NSMutableString stringWithString:urlString];
      [searchTemplate replaceCharactersInRange:searchMarkerRange 
                                    withString:@"{searchterms}"];
      [attributes setObject:searchTemplate 
                     forKey:kHGSObjectAttributeWebSearchTemplateKey];
    }
  }
  [self indexResultNamed:nameString 
                     URL:urlString 
         otherAttributes:attributes
                    into:database];
}


- (void)updateDatabase:(HGSMemorySearchSourceDB *)database
               forPath:(NSString *)path 
             operation:(NSOperation *)operation {
  if (![operation isCancelled]) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (dict) {
      [self indexCaminoBookmarksForDict:dict into:database operation:operation];
    }
  }
}

@end

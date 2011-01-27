//
//  HGSNavSuggestSource.m
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

#import "HGSNavSuggestSource.h"

#if TARGET_OS_IPHONE
#import "GMOCompletionSourceNotifications.h"
#endif  // TARGET_OS_IPHONE

#if ENABLE_SUGGEST_SOURCE_SQLITE_CACHING
#import "HGSSQLiteBackedCache.h"
#endif  // ENABLE_SUGGEST_SOURCE_SQLITE_CACHING

static NSString* const kHGSNavSuggestUrl =
  @"%@/complete/search?"
#if TARGET_OS_IPHONE
  @"client=iphoneapp"
#endif
  @"&nav=2"       // Two nav sugests
  @"&hjson=t"     // Horizontal JSON. http://wiki/Main/GoogleSuggestServerAPI
  @"&types=t"     // Add type of suggest (SuggestResults::SuggestType)
  @"&hl=%%@"      // Language (eg. en)
  @"&q=%%@";      // Partial query.

static NSUInteger const kHGSDefaultMaxResults = 2;

@interface HGSSuggestSource (Private)
- (NSArray *)filteredSuggestionsWithResponse:(NSArray *)response
                                   withQuery:(HGSQuery *)query;
@end

@implementation HGSNavSuggestSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  NSString *navSuggestHost
    = [[HGSSourceConfigProvider defaultConfig] navSuggestHost];
  NSString *baseURL = [NSString stringWithFormat:kHGSNavSuggestUrl, navSuggestHost];
  self = [self initWithConfiguration:configuration
                             baseURL:baseURL];
  return self;
}

- (void)initializeCache {
#if ENABLE_SUGGEST_SOURCE_SQLITE_CACHING
  NSString* cachePath = [[HGSSourceConfigProvider defaultConfig] navSuggestCacheDbPath];
  if (cachePath) {
    cache_ = [[HGSSQLiteBackedCache alloc] initWithPath:cachePath];
  }
#else
  cache_ = [[NSMutableDictionary alloc] init];  // Runtime cache only.
#endif
}

#pragma mark HGSSuggestSource

- (NSArray *)filteredSuggestionsWithResponse:(NSArray *)response
                                   withQuery:(HGSQuery *)query {
  NSArray* suggestions = [super filteredSuggestionsWithResponse:response
                                                      withQuery:query];
  // Only grab the Navsuggest ones.
  NSMutableArray *navSuggestions = [NSMutableArray array];
  NSEnumerator *enumerator = [suggestions objectEnumerator];
  HGSObject* suggestion = nil;
  while ((suggestion = [enumerator nextObject])) {
    if ([[suggestion type] isEqualToString:(NSString*)kHGSUTTypeGoogleNavSuggestResult]) {
      [navSuggestions addObject:suggestion];
    }
  }
  return navSuggestions;
}

@end

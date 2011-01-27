//
//  OpenSearchSuggestSource.m
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

#import <Vermilion/HGSQuery.h>
#import <Vermilion/HGSResult.h>
#import <Vermilion/HGSSearchTermScorer.h>
#import <Vermilion/HGSSuggestSource.h>
#import <Vermilion/HGSTokenizer.h>
#import <Vermilion/HGSType.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSString+URLArguments.h>

#if TARGET_OS_IPHONE
#import "GMOCompletionSourceNotifications.h"
#import "GMOSourceConfigProvider.h"
#endif  // TARGET_OS_IPHONE

#if ENABLE_SUGGEST_SOURCE_SQLITE_CACHING
#import "GMOSQLiteBackedCache.h"
#endif  // ENABLE_SUGGEST_SOURCE_SQLITE_CACHING

static const int kGMODefaultMaxResults = 1;

@interface OpenSearchSuggestSource : HGSSuggestSource
@end

@implementation OpenSearchSuggestSource
GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    // We are a valid source for any web page with a suggest template
    HGSResult *pivotObject = [query pivotObject];
    isValid 
      = [pivotObject valueForKey:kHGSObjectAttributeWebSuggestTemplateKey] != nil;
  }
  return isValid;
}

- (NSURL *)suggestUrl:(HGSSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSResult *pivotObject = [query pivotObject];
  NSString *urlFormat = [pivotObject valueForKey:kHGSObjectAttributeWebSuggestTemplateKey];
  urlFormat = [urlFormat stringByReplacingOccurrencesOfString:@"{searchterms}" withString:@"%@"];
  HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
  // use the raw query so the server can do it's own parsing of it.
  NSString *escapedToken 
    = [[tokenizedQueryString originalString] gtm_stringByEscapingForURLArgument];
  NSString *suggestUrlString 
    = [NSString stringWithFormat:urlFormat, escapedToken];
  return [NSURL URLWithString:suggestUrlString];
}

- (NSArray *)filteredSuggestionsWithResponse:(NSArray *)response
                                   withQuery:(HGSQuery *)query {
  if ([response count] < 2) return [NSArray array];
  NSArray* jsonSuggestions = [response objectAtIndex:1];

  if (![jsonSuggestions isKindOfClass:[NSArray class]]) return [NSArray array];

  NSMutableArray *suggestions =
    [[[NSMutableArray alloc] initWithCapacity:[jsonSuggestions count]] autorelease];
  NSEnumerator *suggestionsEnum = [jsonSuggestions objectEnumerator];
  NSString *suggestion = nil;
  HGSResult *pivotObject = [query pivotObject];
  id image = [pivotObject valueForKey:kHGSObjectAttributeIconKey];
  NSString *urlFormat = [pivotObject valueForKey:kHGSObjectAttributeWebSearchTemplateKey];
  urlFormat = [urlFormat stringByReplacingOccurrencesOfString:@"{searchterms}" withString:@"%@"];
  HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];

  while ((suggestion = [suggestionsEnum nextObject])) {
    NSString *urlString = [NSString stringWithFormat:urlFormat,
                           [suggestion gtm_stringByEscapingForURLArgument]];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                image, kHGSObjectAttributeIconKey, nil];
    HGSTokenizedString *tokenizedSuggestion = [HGSTokenizer tokenizeString:suggestion];
    NSIndexSet *matchedIndexes = nil;
    CGFloat score = HGSScoreTermForItem(tokenizedQueryString, tokenizedSuggestion, &matchedIndexes);
    HGSScoredResult *result = [HGSScoredResult resultWithURI:urlString
                                                        name:suggestion
                                                        type:HGS_SUBTYPE(kHGSTypeWebpage, @"opensearch") // TODO(alcor): more complete/better type
                                                      source:self
                                                  attributes:attributes
                                                       score:score
                                                       flags:0
                                              matchedTerm:tokenizedSuggestion
                                              matchedIndexes:matchedIndexes];
    [suggestions addObject:result];
  }
  return suggestions;
}

#pragma mark Caching

- (void)initializeCache {
  cache_ = [[NSMutableDictionary alloc] init];  // Runtime cache only.
}

- (void)cacheValue:(id)cacheValue forKey:(NSString *)key {
  [cache_ setObject:cacheValue forKey:key];
}

@end

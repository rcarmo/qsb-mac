//
//  WebSearchSource.m
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

#import "Vermilion/Vermilion.h"

#import <GTM/GTMDefines.h>
#import <GTM/GTMGarbageCollection.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <GTM/GTMGoogleSearch.h>

// TODO(dmaclach): should this be off webpage?
#define kHGSTypeSearchCorpus @"searchcorpus"

@interface WebSearchSource : HGSCallbackSearchSource
+ (NSString *)urlStringForQuery:(NSString *)queryString 
                   onSiteResult:(HGSResult *)result;
@end

#if TARGET_OS_IPHONE
#import "UTCoreTypes+Missing.h"
#import "GMOUserPreferences.h"
static NSString *const kWebSourceIconName = @"web-searchsubmit.png";
#else
static NSString *const kWebSourceIconName = @"blue-searchhistory";
#endif

static NSString * const kWebSourceSiteSearchOverrideKey = @"WebSourceSiteSearchURLFormat";

@implementation WebSearchSource

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    // We are a valid source for any web page
    HGSResult *pivotObject = [query pivotObject];
    if (pivotObject) {
      NSString *template
        = [pivotObject valueForKey:kHGSObjectAttributeWebSearchTemplateKey];
      BOOL allowsSearchSite = [pivotObject isOfType:kHGSTypeWebpage];
      isValid = (template!= nil) || allowsSearchSite;
    } else {
      HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
      isValid = [tokenizedQueryString originalLength] > 3;
    }
  }
  return isValid;
}

+ (NSString *)urlStringForQuery:(NSString *)queryString 
                   onSiteResult:(HGSResult *)result {
  NSString *template
    = [result valueForKey:kHGSObjectAttributeWebSearchTemplateKey];
  
  NSString *escapedString = [queryString gtm_stringByEscapingForURLArgument];
  NSString *urlString = nil;
  if (template && [escapedString length]) {
    urlString = [template stringByReplacingOccurrencesOfString:@"{searchterms}" 
                                                    withString:escapedString];
  } else {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *searchFormat = [ud stringForKey:kWebSourceSiteSearchOverrideKey];
    NSString *host = [[result url] host];
    if ([host length]) {
      if (!searchFormat) {
        GTMGoogleSearch *googleSearch = [GTMGoogleSearch sharedInstance];
        NSDictionary *arguments 
          = [NSDictionary dictionaryWithObject:host forKey:@"as_sitesearch"];
        urlString = [googleSearch searchURLFor:escapedString 
                                        ofType:GTMGoogleSearchWeb 
                                     arguments:arguments];
      } else {
        urlString = [NSString stringWithFormat:searchFormat,
                     escapedString, host];
      }
    }
  }
  return urlString;
}

- (BOOL)isSearchConcurrent {
  return YES;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSResult *pivotObject = [query pivotObject];
  if (pivotObject) {
    
    NSString *searchName
      = [pivotObject valueForKey:kHGSObjectAttributeWebSearchDisplayStringKey];
    if (!searchName) {
      NSString *searchLabel
        = HGSLocalizedString(@"Search %@",
                             @"Search <website|category> (eg. Wikipedia) (30 "
                             @"chars excluding <website>)");
      searchName = [NSString stringWithFormat:searchLabel,
                    [[pivotObject url] host]];
    }
    HGSTokenizedString *tokenizedQuery = [query tokenizedQueryString];
    NSString *queryString = [tokenizedQuery originalString];
    NSString *url = [[self class] urlStringForQuery:queryString 
                                       onSiteResult:pivotObject];
    if (url) {
      BOOL searchInline = NO;
#if TARGET_OS_IPHONE
      searchInline =
        [[pivotObject valueForKey:@"HGSObjectAttributeSearchInline"]
          boolValue];
#endif
      if (!searchInline) {
        NSImage *icon = [NSImage imageNamed:kWebSourceIconName];
        NSString *itemLabel
          = HGSLocalizedString(@"for \"%@\"",
                               @"[Search <website>] for <search_term> (30 "
                               @"chars excluding <search_term>)");
        NSString *details = [NSString stringWithFormat:itemLabel, queryString];
        NSDictionary *attributes
          = [NSDictionary dictionaryWithObjectsAndKeys:
             icon, kHGSObjectAttributeIconKey,
             details, kHGSObjectAttributeSnippetKey,
             nil];
        HGSScoredResult *placeholderItem 
          = [HGSScoredResult resultWithURI:url
                                      name:searchName
                                      type:kHGSTypeSearchCorpus
                                    source:self
                                attributes:attributes
                                     score:HGSCalibratedScore(kHGSCalibratedPerfectScore)
                                     flags:eHGSSpecialUIRankFlag
                               matchedTerm:tokenizedQuery
                            matchedIndexes:nil];
        [operation setRankedResults:[NSArray arrayWithObject:placeholderItem]];
      }
    }
  } else {
    HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
    NSString *name = [tokenizedQueryString originalString];
    GTMGoogleSearch *googleSearch = [GTMGoogleSearch sharedInstance];
    NSString *cleanedQuery = [name gtm_stringByEscapingForURLArgument];
    NSString *urlString = [googleSearch searchURLFor:cleanedQuery
                                              ofType:GTMGoogleSearchWeb
                                           arguments:nil];
    NSImage *blueIcon = [self imageNamed:@"blue-google-white.icns"];
    HGSAssert(blueIcon, nil);
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                blueIcon, kHGSObjectAttributeIconKey,
                                nil];
    HGSScoredResult *result 
      = [HGSScoredResult resultWithURI:urlString
                                  name:name
                                  type:kHGSTypeGoogleSearch
                                source:nil
                            attributes:attributes
                                 score:HGSCalibratedScore(kHGSCalibratedModerateScore)
                                 flags:0
                          matchedTerm:tokenizedQueryString
                        matchedIndexes:nil];
    [operation setRankedResults:[NSArray arrayWithObject:result]];
  }
      
  [operation finishQuery];
}

@end

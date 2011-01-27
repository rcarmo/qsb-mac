//
//  HGSSuggestSource.m
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

#import "HGSSuggestSource.h"
#import "HGSLog.h"
#import "HGSQuery.h"
#import "HGSTokenizer.h"
#import "HGSSearchTermScorer.h"
#import "HGSResult.h"
#import "HGSMixer.h"
#import "HGSPluginLoader.h"
#import "HGSDelegate.h"
#import "HGSType.h"

#import <GData/GDataHTTPFetcher.h>
#import "GTMDefines.h"
#import "GTMGarbageCollection.h"
#import "GTMMethodCheck.h"
#import "GTMNSString+URLArguments.h"
#import "GTMNSDictionary+URLArguments.h"
#import "JSON/JSON.h"
#import "NSString+ReadableURL.h"
#import "GTMNSNumber+64Bit.h"

#if TARGET_OS_IPHONE
#import "GMOCompletionSourceNotifications.h"
#import "GMONavSuggestSource.h"
#import "GMONetworkIndicator.h"
#import "GMOUserPreferences.h"
#else
#import "QSBPreferences.h"
#endif

static NSString* const kHGSGoogleSuggestBase
  = @"http://clients1.google.com/complete/search?";

static NSTimeInterval const kHGSNetworkTimeout = 10.0f;

typedef enum {
  kHGSSuggestTypeSuggest = 0,
  kHGSSuggestTypeNavSuggest = 5
} HGSSuggestType;

@interface HGSSuggestSource ()
// Initiate an HTTP request for Google Suggest(ions) with the given query.
- (void)startSuggestionsRequestForOperation:(HGSSearchOperation *)operation;
// Called when the suggestions were successfully fetched from the network.
- (void)suggestionsRequestCompleted:(NSArray *)suggestions
                       forOperation:(HGSSearchOperation *)operation;
// Called when the suggestions request failed.
- (void)suggestionsRequestFailed:(HGSSearchOperation *)operation;

// Parses data from an HTTP response (|responseData|), caches the parsed
// response as a plist and converts it into an array of HGSResult(s).
//
// Filtering of the results is also applied to the suggestions.
- (NSArray *)parseAndCacheResponseData:(NSData *)responseData
                             withQuery:(HGSQuery *)query;
// Returns suggestion results that are ready to be used in the UI. Performs
// the necessary filtering and normalization to the parse response data.
//
// |response| is expected to be a parse JSON response that consists of a
//            2 element NSArray, first element being the query and second
//            being an NSArray of the suggestions.
- (NSArray *)filteredSuggestionsWithResponse:(NSArray *)response
                                   withQuery:(HGSQuery *)query;

// Parses the |responseData| (expected to be a UTF-8 JSON string) into a
// Foundation-based NSArray representation suitable to be passed on to
// suggestionsWithResponse:withQuery:.
- (NSArray *)responseWithJSONData:(NSData *)responseData;
// Convert a parsed JSON response into HGSResult(s).
- (NSMutableArray *)suggestionsWithResponse:(NSArray *)response
                                  withQuery:(HGSQuery *)query;
// Language of suggestions
- (NSString *)suggestLanguage;
- (NSString *)clientID;

- (void)processQueue:(id)sender;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher didFail:(NSError *)error;

@end

@interface HGSSuggestSource (Filtering)
// Filters out suggestions that only add 1 or 2 characters to the query string.
// We expect that these are less useful to the users and add to the cluster.
// |results| will be modified by this method.
- (void)filterShortResults:(NSMutableArray *)results
           withQueryString:(HGSTokenizedString *)query;

// Filter out duplicate Google suggest results. (Doesn't touch navsuggest).
- (void)filterDuplicateSuggests:(NSMutableArray*)results;

// Filters out suggestions that do not have the same prefix (case-insensitive).
- (void)filterResults:(NSMutableArray *)results
        withoutPrefix:(NSString *)prefix;

#if TARGET_OS_IPHONE
// Truncates the display name of the suggestions if they have a common prefix
// with |query|.
- (void)truncateDisplayNames:(NSMutableArray *)results
             withQueryString:(HGSTokenizedString *)query;
#endif  // TARGET_OS_IPHONE

// Replaces URL-like results with a kHGSUTTypeWebPage suggestion.
- (void)replaceURLLikeResults:(NSMutableArray *)results;

// Removes all URL-like results.
- (void)filterWebPageResults:(NSMutableArray*)results;
@end

// Methods to deal with caching and abstracting the type of caching. Currently
// implemented a regular NSMutbaleDictionary and SQLite backed.
@interface HGSSuggestSource (Caching)
- (void)initializeCache;

// Called by cacheValue:forKey: on the main thread as to not confuse SQLite
// if we are using that for the cache backend.
- (void)cacheKeyValuePair:(NSArray *)keyValue;
// Returns the cached value of the key.
- (id)cachedObjectForKey:(id)key;
@end

// Methods to deal with the suggest fetching thread and the manipulation of the
// fetch queue.
@interface HGSSuggestSource (FetchQueue)
- (void)startSuggestionFetchingThread;
- (void)suggestionFetchingThread:(id)context;
- (HGSSearchOperation *)nextOperation;
- (void)addOperation:(HGSSearchOperation *)newOperation;
- (void)signalOperationCompletion;
@end

@implementation HGSSuggestSource
GTM_METHOD_CHECK(NSString, readableURLString);
GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);
GTM_METHOD_CHECK(NSNumber, gtm_numberWithCGFloat:);

#if TARGET_OS_IPHONE
- (NSSet *)pivotableTypes {
  // iPhone pivots on everything
  return [NSSet setWithObject:@"*"];
}
#endif

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger suggestCount = [prefs integerForKey:kGoogleSuggestCountKey];
    NSInteger navSuggestCount = [prefs integerForKey:kGoogleNavSuggestCountKey];

    // Don't show suggestions for queries under 3 letters,
    // and anything over 20 is probably a tweet or a text append, so we
    // can stop showing suggestions there too.
    NSUInteger length = [[query tokenizedQueryString] originalLength];
    if (length < 3 || length > 20) {
      isValid = NO;
    } else if (suggestCount + navSuggestCount <= 0) {
      isValid = NO;
    }
  }
  return isValid;
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  self = [self initWithConfiguration:configuration
                            baseURL:kHGSGoogleSuggestBase];
  return self;
}

- (id)initWithConfiguration:(NSDictionary *)configuration
                    baseURL:(NSString*)baseURL {
  if (![configuration objectForKey:kHGSExtensionIconImagePathKey]) {
    NSMutableDictionary *newConfig
      = [NSMutableDictionary dictionaryWithDictionary:configuration];
    configuration = newConfig;
  }
  if ((self = [super initWithConfiguration:configuration])) {
    suggestBaseUrl_ = [baseURL copy];
    operationQueue_ = [[NSMutableArray alloc] init];
    isReady_ = YES;
    continueRunning_ = YES;
    lastResult_ = nil;
    [self initializeCache];
    [self startSuggestionFetchingThread];
  }
  return self;
}

- (NSImage *)navIcon {
#if TARGET_OS_IPHONE
  return [UIImage imageNamed:@"web-nav.png"];
#else
  return [NSImage imageNamed:@"blue-nav.png"];
#endif
}

- (void)dealloc {
  continueRunning_ = NO;
  [suggestBaseUrl_ release];
  [operationQueue_ release];
  [lastResult_ release];
  [cache_ release];
  [super dealloc];
}

#pragma mark Caching

- (void)initializeCache {
  cache_ = [[NSMutableDictionary alloc] init];  // Runtime cache only.
}

- (void)cacheObject:(id)cacheObject forKey:(id)key {
  [cache_ setObject:cacheObject forKey:key];
}

- (void)cacheKeyObjectPair:(NSArray *)keyObject {
  [cache_ setObject:[keyObject objectAtIndex:1]
             forKey:[keyObject objectAtIndex:0]];
}

- (id)cachedObjectForKey:(id)key {
  // TODO(altse): Move this to main thread like the cacheObject:forKey: since
  //              SQLite does not seem to be thread-safe.
  if (cache_) {
    id value = [cache_ objectForKey:key];
//    if (value && [value respondsToSelector:@selector(substringWithRange:)]) {
//      HGSLogDebug(@"SuggestCache[%@] = %@", key, [value substringWithRange:NSMakeRange(0, 20)]);
//    } else {
//      HGSLogDebug(@"SuggestCache[%@] = %@", key, value);
//    }
    return value;
  } else {
    return nil;
  }
}

#pragma mark Suggestion Fetching Thread

- (void)startSuggestionFetchingThread {
  isReady_ = YES;
  [self performSelectorInBackground:@selector(suggestionFetchingThread:)
                         withObject:nil];
}

// This is a long running thread that will continiously service search
// operation requests in the |operationQueue_|.
- (void)suggestionFetchingThread:(id)context {
  BOOL isRunning = YES;
  const NSTimeInterval pollingInterval = 1.0;
  const NSTimeInterval autoreleaseInterval = 300.0;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [NSTimer scheduledTimerWithTimeInterval:pollingInterval
                                   target:self
                                 selector:@selector(processQueue:)
                                 userInfo:nil
                                 repeats:YES];

  do {
    NSAutoreleasePool *iterPool = [[NSAutoreleasePool alloc] init];
    isRunning = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:autoreleaseInterval]];
    [iterPool release];
  } while (isRunning && continueRunning_);

  [pool release];
}

- (void)stopFetching {
  continueRunning_ = NO;
}

-(void)processQueue:(id)sender {
  if (isReady_) {
    HGSSearchOperation *nextOperation = [[self nextOperation] retain];
    if (nextOperation) {
      isReady_ = NO;
      [self startSuggestionsRequestForOperation:nextOperation];  // retains nextOperation
      [nextOperation release];
    }
  }
}

// The |operationQueue| is checked for the last operation to run, and all the
// subsequent operations are discarded.
- (HGSSearchOperation *)nextOperation {
  @synchronized (operationQueue_) {
    if ([operationQueue_ count] > 0) {
      HGSSearchOperation *nextOperation = [[operationQueue_ lastObject] retain];
      for (NSUInteger i = 0; i < [operationQueue_ count] - 1; i++) {
        [[operationQueue_ objectAtIndex:i] finishQuery];
      }
      [operationQueue_ removeAllObjects];
      return [nextOperation autorelease];
    }
  }
  return nil;
}

// Adds an operation to the network operations queue.
- (void)addOperation:(HGSSearchOperation *)newOperation {
  @synchronized (operationQueue_) {
    [operationQueue_ addObject:newOperation];
  }
}

// Called to signal a network operation has completed and the instance is ready
// to start another request if there is one outstanding.
- (void)signalOperationCompletion {
  // TODO(altse): CFRunLoopStop?
#if TARGET_OS_IPHONE
  [[GMONetworkIndicator sharedNetworkIndicator] popEvent];
#endif  // TARGET_OS_IPHONE
  isReady_ = YES;
}

#pragma mark Suggestion Fetching

- (NSURL *)suggestUrl:(HGSSearchOperation *)operation {
  // use the raw query so the server can try to parse it.
  // This is escaped by the argument dictionary
  NSString *string = [[[operation query] tokenizedQueryString] originalString];

  NSMutableDictionary *argumentDictionary =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
     [self clientID], @"client",
     @"t",@"hjson", // Horizontal JSON. http://wiki/Main/GoogleSuggestServerAPI
     @"t", @"types", // Add type of suggest (SuggestResults::SuggestType)
     [self suggestLanguage], @"hl", // Language (eg. en)
     string, @"q", // Partial query.
     nil];

  // Enable spelling suggestions.
  [argumentDictionary setObject:@"t" forKey:@"spell"];

  // Enable calculator suggestions.
  //[argumentDictionary setObject:@"t" forKey:@"calc"];

  // Enable ads suggestions.
  //[argumentDictionary setObject:@"t" forKey:@"ads"];

  // Enable news suggestions.
  //[argumentDictionary setObject:@"t" forKey:@"news"];

  NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
  NSNumber *suggestCount = [prefs objectForKey:kGoogleSuggestCountKey];
  NSNumber *navSuggestCount = [prefs objectForKey:kGoogleNavSuggestCountKey];

  // Enable calculator suggestions.

  if ([suggestCount boolValue]) {
    // Allow the default number of suggestions to come back
    // We truncate these later
     [argumentDictionary setObject:[NSNumber numberWithInt:5]
                            forKey:@"complete"];
  }  else {
    [argumentDictionary setObject:@"f" forKey:@"complete"];
  }

  if ([navSuggestCount boolValue]) {
    [argumentDictionary setObject:navSuggestCount
                           forKey:@"nav"];
  }

  NSString *suggestUrlString = [suggestBaseUrl_ stringByAppendingString:
                                [argumentDictionary gtm_httpArgumentsString]];

  return [NSURL URLWithString:suggestUrlString];
}

- (void)startSuggestionsRequestForOperation:(HGSSearchOperation *)operation {
  // TODO(altse): On the iPhone, NSURL uses SQLite cache and that is not
  //              thread-safe. So we disable local HTTP caching.
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self suggestUrl:operation]
                                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                     timeoutInterval:kHGSNetworkTimeout];
  [request setHTTPShouldHandleCookies:NO];

  // Start the http fetch.
  GDataHTTPFetcher *fetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
  [fetcher setUserData:operation];
  [fetcher beginFetchWithDelegate:self
                didFinishSelector:@selector(httpFetcher:finishedWithData:)
                  didFailSelector:@selector(httpFetcher:didFail:)];

#if TARGET_OS_IPHONE
  [[GMONetworkIndicator sharedNetworkIndicator] pushEvent];
#endif  // TARGET_OS_IPHONE
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData {
  HGSSearchOperation *fetchedOperation = (HGSSearchOperation *)[[[fetcher userData] retain] autorelease];
  [fetcher setUserData:nil];  // Make sure this operation isn't retained.

  // Parse the result.
  HGSQuery *query = [fetchedOperation query];
  NSArray *suggestions = [self parseAndCacheResponseData:retrievedData withQuery:query];
  if (suggestions) {
    [self suggestionsRequestCompleted:suggestions
                         forOperation:fetchedOperation];
  } else {
    [self suggestionsRequestFailed:fetchedOperation];
  }

  [self signalOperationCompletion];
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
            didFail:(NSError *)error {
  HGSLog(@"httpFetcher failed: %@ %@", [error description], [[fetcher request] URL]);
  [self signalOperationCompletion];

  HGSSearchOperation *fetchedOperation = (HGSSearchOperation *)[fetcher userData];
  [self suggestionsRequestFailed:fetchedOperation];
}

#pragma mark -

- (void)suggestionsRequestCompleted:(NSArray *)suggestions
                       forOperation:(HGSSearchOperation *)operation {
  [operation performSelectorOnMainThread:@selector(setRankedResults:)
                              withObject:suggestions
                           waitUntilDone:YES];
  [operation performSelectorOnMainThread:@selector(finishQuery)
                              withObject:nil
                           waitUntilDone:YES];

  // Cache the last result.
  [self setLastResult:suggestions];
}

- (void)suggestionsRequestFailed:(HGSSearchOperation *)operation {
  [operation performSelectorOnMainThread:@selector(finishQuery)
                              withObject:nil
                           waitUntilDone:YES];
}

#pragma mark Response Data Manipulation

- (NSArray *)parseAndCacheResponseData:(NSData *)responseData
                             withQuery:(HGSQuery *)query {
  NSArray *cachedResponse = nil;
  NSArray *response = [self responseWithJSONData:responseData];
  if ([response isKindOfClass:[NSArray class]]) {
    // Add parse response to the cache.
    if ([response count] > 0) {
      [self cacheObject:response forKey:[query tokenizedQueryString]];
    }
    cachedResponse = [self filteredSuggestionsWithResponse:response
                                                 withQuery:query];
  }
  return cachedResponse;
}

- (NSArray *)filteredSuggestionsWithResponse:(NSArray *)response
                                   withQuery:(HGSQuery *)query {
  // Convert suggestions into HGSObjects.
  NSMutableArray *suggestions = [self suggestionsWithResponse:response
                                                      withQuery:query];

  // TODO(alcor): Don't filter for now, we need to decide whether to keep these
  // at all or to collapse them with like navsuggests
  // [self replaceURLLikeResults:suggestions];
  // [self filterWebPageResults:suggestions];

  HGSTokenizedString *queryString = [query tokenizedQueryString];
  [self filterShortResults:suggestions withQueryString:queryString];
#if TARGET_OS_IPHONE
  [self truncateDisplayNames:suggestions withQueryString:queryString];
#endif

  [self filterDuplicateSuggests:suggestions];
  [suggestions sortUsingFunction:HGSMixerScoredResultSort context:NULL];
  return suggestions;
}

// Parses the JSON response into Foundation objects.
- (NSArray *)responseWithJSONData:(NSData *)responseData {
  // Parse response.
  NSString *jsonResponse = [[[NSString alloc] initWithData:responseData
                                                  encoding:NSUTF8StringEncoding]
                            autorelease];
  NSArray *response = [jsonResponse JSONValue];

  if (!response) {
    HGSLog(@"Unable to parse JSON");
    return [NSArray array];
  }

  if ([response count] < 2) {
    HGSLog(@"JSON Response does not match expected format.");
    return [NSArray array];
  }
  return response;
}

- (NSMutableArray *)suggestionsWithResponse:(NSArray *)response
                                  withQuery:(HGSQuery *)query {
  // This is all documented here:
  // http://wiki.corp.google.com/twiki/bin/view/Main/GoogleSuggestServerAPI#_Horizontal_JSON
  if ([response count] < 2) {
    return [NSMutableArray array];
  }
  // Arg 0 is the query string
  // Arg 1 is the suggestions
  NSArray *suggestions = [response objectAtIndex:1];
  NSMutableArray *suggestionResults
    = [NSMutableArray arrayWithCapacity:[suggestions count]];
  for (NSArray *suggestionItem in suggestions) {
    // We request the type, so we should always have at least 3 args.
    if (!([suggestionItem isKindOfClass:[NSArray class]] &&
          [suggestionItem count] > 2)) {
      HGSLog(@"Unexpected suggestion %@ from response: %@ for query: %@",
             suggestionItem, response, query);
      continue;
    }

    // For suggest arg 0 will be the suggestion
    // For NavSuggest arg 0 will be the URL
    NSString *suggestionString = [suggestionItem objectAtIndex:0];
    if ([suggestionString respondsToSelector:@selector(stringValue)]) {
      suggestionString = [(id)suggestionString stringValue];
    } else if (![suggestionString isKindOfClass:[NSString class]]) {
      HGSLog(@"Unexpected suggestionString %@ from suggestion: %@ from "
             @"response: %@ for query: %@",
             suggestionString, suggestionItem, response, query);
      continue;
    }

    // For both suggest and navsuggest arg 2 is the type.
    NSNumber *nsType = [suggestionItem objectAtIndex:2];
    if (![nsType isKindOfClass:[NSNumber class]]) {
      HGSLog(@"Unexpected type %@ from suggestion: %@ from "
             @"response: %@ for query: %@",
             nsType, suggestionItem, response, query);
      continue;
    }

    NSInteger suggestionType = [nsType intValue];
    NSDictionary *attributes = nil;
    NSString *urlString = nil;
    NSString *name = nil;
    NSString *type = nil;
    CGFloat score = 0;
    NSIndexSet *matchedIndexes = nil;
    HGSTokenizedString *matchedTerm = nil;
    HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
    if (suggestionType == kHGSSuggestTypeSuggest) {
      NSString *escapedSuggestion
        = [suggestionString gtm_stringByEscapingForURLArgument];
      urlString = [NSString stringWithFormat:@"googlesuggest://%@",
                   escapedSuggestion];
      // TODO(altse): JSON response includes the type of the suggestion, we
      //              should import the enums.
      //              if (row[2] == 'calc') HGSCompletionTypeCalc;
      //              if (row[2] is integer) HGSCompletionTypeSuggest;
      matchedTerm = [HGSTokenizer tokenizeString:suggestionString];
      score = HGSScoreTermForItem(tokenizedQueryString,
                                  matchedTerm,
                                  &matchedIndexes);
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                    suggestionString, kHGSObjectAttributeStringValueKey,
                    [self navIcon], kHGSObjectAttributeIconKey,
                    nil];
      name = suggestionString;
      type = kHGSTypeGoogleSuggest;
    } else if (suggestionType == kHGSSuggestTypeNavSuggest) {
      // For Nav Suggest arg 1 is the name,
      name = [suggestionItem objectAtIndex:1];
      if ([name respondsToSelector:@selector(stringValue)]) {
        name = [(id)name stringValue];
      }
      if (!([name isKindOfClass:[NSString class]] && [name length] > 1)) {
        HGSLog(@"Unexpected name %@ for navsuggestion: %@ from response: %@ "
               @"for query: %@",
               name, suggestionItem, response, query);
        continue;
      }

      BOOL isSecure = [suggestionString hasPrefix:@"https://"];
      if (!isSecure && ![suggestionString hasPrefix:@"http://"]) {
        suggestionString
          = [NSString stringWithFormat:@"http://%@", suggestionString];
      }
      urlString = suggestionString;
      HGSTokenizedString *tokenizedURL = [HGSTokenizer tokenizeString:urlString];
      NSNumber *yesValue = [NSNumber numberWithBool:YES];
      NSUInteger idx = isSecure ? [@"https://" length] : [@"http://" length];
      NSString *urlPath = [urlString substringFromIndex:idx];
      HGSTokenizedString *tokenizedPath = [HGSTokenizer tokenizeString:urlPath];
      NSIndexSet *matchedIndexes1 = nil;
      NSIndexSet *matchedIndexes2 = nil;
      CGFloat score1 = HGSScoreTermForItem(tokenizedQueryString,
                                           tokenizedURL,
                                           &matchedIndexes1);
      CGFloat score2 = HGSScoreTermForItem(tokenizedQueryString,
                                           tokenizedPath,
                                           &matchedIndexes2);
      if (score1 > score2) {
        score = score1;
        matchedIndexes = matchedIndexes1;
        matchedTerm = tokenizedURL;
      } else {
        score = score2;
        matchedIndexes = matchedIndexes2;
        matchedTerm = tokenizedPath;
      }
      attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                    yesValue, kHGSObjectAttributeAllowSiteSearchKey,
                    yesValue, kHGSObjectAttributeIsSyntheticKey,
                    urlString, kHGSObjectAttributeSourceURLKey,
                    nil];
      type = kHGSTypeGoogleNavSuggest;
    }
    if (urlString) {
      HGSScoredResult *navsuggestion = [HGSScoredResult resultWithURI:urlString
                                                                 name:name
                                                                 type:type
                                                               source:self
                                                           attributes:attributes
                                                                score:score
                                                                flags:0
                                                      matchedTerm:matchedTerm
                                                       matchedIndexes:matchedIndexes];
      if (navsuggestion) {
        [suggestionResults addObject:navsuggestion];
      } else {
        HGSLog(@"Unable to create result with uri: %@ name: %@ attributes: %@",
               urlString, name, attributes);
      }
    }
  }

  return suggestionResults;
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeIconKey]) {
    value = [self navIcon];
  }
  if (!value) {
    value = [super provideValueForKey:key result:result];
  }
  return value;
}
//
- (void)filterWebPageResults:(NSMutableArray*)results {
  NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
  NSEnumerator *enumerator = [results objectEnumerator];
  HGSResult *result;
  for (NSUInteger i = 0; (result = [enumerator nextObject]); ++i) {
    if ([result conformsToType:kHGSTypeWebpage]) {
      [toRemove addIndex:i];
    }
  }
  [results removeObjectsAtIndexes:toRemove];
}

// Replaces suggestions that look like URLs
- (void)replaceURLLikeResults:(NSMutableArray *)results {
  for (NSUInteger i = 0; i < [results count]; i++) {
    HGSScoredResult *result = [results objectAtIndex:i];
    if (![result isOfType:kHGSTypeGoogleSuggest])
      continue;

    NSString *suggestion = [result valueForKey:kHGSObjectAttributeStringValueKey];
    // TODO(altse): Check for other TLDs too.
    if ([suggestion hasSuffix:@".com"] ||
        [suggestion hasPrefix:@"www."]) {
      NSString *normalized = [suggestion stringByReplacingOccurrencesOfString:@" "
                                                                   withString:@""];
      NSURL *url = [[[NSURL alloc] initWithScheme:@"http"
                                             host:normalized
                                             path:@"/"] autorelease];
      NSDictionary *attributes
        = [NSDictionary dictionaryWithObjectsAndKeys:
           suggestion, kHGSObjectAttributeStringValueKey,
           nil];
      HGSScoredResult *urlResult
        = [HGSScoredResult resultWithURI:[url absoluteString]
                                    name:suggestion
                                    type:kHGSTypeWebpage
                                  source:self
                              attributes:attributes
                                   score:[result score]
                                   flags:[result rankFlags]
                             matchedTerm:[result matchedTerm]
                          matchedIndexes:[result matchedIndexes]];
      [results replaceObjectAtIndex:i withObject:urlResult];
    }
  }
}

// Remove suggestions that are too short.
- (void)filterShortResults:(NSMutableArray *)results
           withQueryString:(HGSTokenizedString *)query {
  NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
  NSUInteger queryLength = [query originalLength];
  NSUInteger lengthThreshold = 2;
  NSEnumerator *enumerator = [results objectEnumerator];
  HGSResult *result;
  for (NSUInteger i = 0; (result = [enumerator nextObject]); ++i) {
    if ([result isOfType:kHGSTypeGoogleSuggest] &&
        ([[result valueForKey:kHGSObjectAttributeStringValueKey] length]
         < queryLength + lengthThreshold)) {
      [toRemove addIndex:i];
    }
  }
  [results removeObjectsAtIndexes:toRemove];
}

#if TARGET_OS_IPHONE
// Truncate the display name for suggestions that have a common prefix with
// the query.
- (void)truncateDisplayNames:(NSMutableArray *)results
             withQueryString:(HGSTokenizedString *)query {
  NSUInteger queryLength = [query originalLength];
  if (queryLength < 4) {
    return;
  }

  //NSString *ellipsisCharacter = @"+";
  NSString *ellipsisCharacter = [NSString stringWithFormat:@"%C",0x2025];

  // Work out the word boundaries.
  // TODO(alcor): this probably need to use a real tokenizer to be i18n happy
  BOOL onlyTruncateOnWordBreak = YES;
  NSCharacterSet *breakerSet = [NSCharacterSet characterSetWithCharactersInString:@" .-"];
  NSString *ellipsisableString = nil;
  NSInteger lastSpace = NSNotFound;
  if (onlyTruncateOnWordBreak) {
    lastSpace = [query rangeOfCharacterFromSet:breakerSet
                                       options:NSBackwardsSearch].location;
    if (lastSpace != NSNotFound) {
      ellipsisableString = [query substringToIndex:lastSpace];
    }
  }

  NSEnumerator *enumerator = [results objectEnumerator];
  HGSResult *result;
  while ((result = [enumerator nextObject])) {
    // Only truncate suggestions
    if (![result isOfType:kHGSTypeGoogleSuggest])
      continue;

    NSString *suggestion = [result valueForKey:kHGSObjectAttributeStringValueKey];
    if ((queryLength < [suggestion length]) &&
        [[suggestion lowercaseString] hasPrefix:[query lowercaseString]]) {
      BOOL nextCharacterIsBreak = [breakerSet characterIsMember:[suggestion characterAtIndex:queryLength]];
      NSString *searchString = query;
      if (onlyTruncateOnWordBreak && !nextCharacterIsBreak) {
        searchString = ellipsisableString;
      }

      NSRange searchRange = NSMakeRange(0, MIN([suggestion length], queryLength));

      if (!searchString) continue;

      suggestion = [suggestion stringByReplacingOccurrencesOfString:searchString
                                                         withString:ellipsisCharacter
                                                            options:NSCaseInsensitiveSearch | NSAnchoredSearch
                                                              range:searchRange];
      [result setValue:suggestion forKey:kHGSObjectAttributeNameKey];
    }
  }
}

#endif  // TARGET_OS_IPHONE

// Filters out all the results that do not have suggestions with the same
// prefix.
- (void)filterResults:(NSMutableArray *)results withoutPrefix:(NSString *)prefix {
  NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
  NSEnumerator *enumerator = [results objectEnumerator];
  HGSResult *result;
  for (NSUInteger i = 0; (result = [enumerator nextObject]); ++i) {
    if (([result isOfType:kHGSTypeGoogleNavSuggest]
         || [result isOfType:kHGSTypeGoogleSuggest])
        && ![[result valueForKey:kHGSObjectAttributeStringValueKey] hasPrefix:prefix]) {
      [toRemove addIndex:i];
    }
  }
  [results removeObjectsAtIndexes:toRemove];
}

// Filter out duplicates
- (void)filterDuplicateSuggests:(NSMutableArray*)results {
  NSMutableSet* seenLabels = [NSMutableSet set];
  NSMutableIndexSet* toRemove = [NSMutableIndexSet indexSet];
  NSEnumerator *enumerator = [results objectEnumerator];
  HGSResult *result;
  for (NSUInteger i = 0; (result = [enumerator nextObject]); ++i) {
    if ([result isOfType:kHGSTypeGoogleSuggest]) {
      if ([seenLabels containsObject:[result valueForKey:kHGSObjectAttributeStringValueKey]]) {
        [toRemove addIndex:i];
      } else {
        [seenLabels addObject:[result valueForKey:kHGSObjectAttributeStringValueKey]];
      }
    }
  }
  [results removeObjectsAtIndexes:toRemove];
}

- (void)setLastResult:(NSArray *)lastResult {
  [lastResult_ autorelease];
  lastResult_ = [lastResult copy];
}

- (NSString *)suggestLanguage {
  NSString *suggestedLanguage = nil;
  suggestedLanguage = [[[HGSPluginLoader sharedPluginLoader] delegate] suggestLanguage];
  if (!suggestedLanguage) {
    // TODO(altse): Should this be "en" or "en_US" ? Right now it is just "en"
    suggestedLanguage = @"en";  // Default, just in case.
  }
  return suggestedLanguage;
}

- (NSString *)clientID {
  NSString *clientID = nil;
  clientID = [[[HGSPluginLoader sharedPluginLoader] delegate] clientID];
  if (!clientID) {
    clientID = @"unknown";
  }
  return clientID;
}

#pragma mark HGSCallSearchSource Implementation

- (BOOL)isSearchConcurrent {
  return YES;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  _GTMDevAssert([operation isConcurrent],
                @"Implementation expects the operation to be set to concurrent.");
  HGSTokenizedString *queryTerm = [query tokenizedQueryString];

#if TARGET_OS_IPHONE
  // iPhone lets more in during isValidSourceForQuery:
  if ([queryTerm length] == 0) {
    [operation setResults:nil];
    [operation finishQuery];
    return;
  }
#endif

  // Return a result from the cache if it exists.
  NSArray *cachedResponse = [self cachedObjectForKey:queryTerm];
  if (cachedResponse) {
    NSArray *suggestions = [self filteredSuggestionsWithResponse:cachedResponse
                                                       withQuery:query];
    if ([suggestions count] > 0) {
      [operation setRankedResults:suggestions];
      [operation finishQuery];
      [self setLastResult:suggestions];
      return;
    }
  }

#if TARGET_OS_IPHONE
  // Latency hiding by synthetically giving results based on our previous
  // real result. Uses the last "fetched" result and gives out all the  ones
  // with a matching prefix.
  if (lastResult_) {
    NSMutableArray *suggestions = [NSMutableArray arrayWithArray:lastResult_];
    [self filterResults:suggestions withoutPrefix:queryTerm];
    [self filterShortResults:suggestions withQueryString:queryTerm];
    [self truncateDisplayNames:suggestions withQueryString:queryTerm];
    if ([suggestions count] > 0) {
      [operation setRankedResults:suggestions];
    }
  }
#endif

  [self addOperation:operation];
}

#pragma mark Clearing Cache

- (void)resetHistoryAndCache {
  if (cache_ && [cache_ respondsToSelector:@selector(removeAllObjects)]) {
    [cache_ removeAllObjects];
  }
}

@end

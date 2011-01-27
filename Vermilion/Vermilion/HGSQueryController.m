//
//  HGSQueryController.m
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

#import "HGSQueryController.h"
#import "HGSQuery.h"
#import "HGSResult.h"
#import "HGSAction.h"
#import "HGSSearchSource.h"
#import "HGSSearchOperation.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSSearchSourceRanker.h"
#import "HGSMixer.h"
#import "HGSLog.h"
#import "HGSTypeFilter.h"
#import "HGSDTrace.h"
#import "HGSOperation.h"
#import "HGSMemorySearchSource.h"
#import "HGSBundle.h"
#import "HGSTokenizer.h"
#import "HGSPluginLoader.h"
#import "HGSDelegate.h"
#import <mach/mach_time.h>

NSString *const kHGSQueryControllerWillStartNotification
  = @"HGSQueryControllerWillStartNotification";
NSString *const kHGSQueryControllerDidFinishNotification
  = @"HGSQueryControllerDidFinishNotification";
NSString *const kHGSQueryControllerDidUpdateResultsNotification
  = @"HGSQueryControllerDidUpdateResultsNotification";

NSString *const kQuerySlowSourceTimeoutSecondsPrefKey = @"slowSourceTimeout";

// These are stored in an NSDictionary keyed by HGSTypeFilters.
// There is one per type filter.
// It caches the results that we have already found for that particular filter,
// as well as the maximum index that we have checked for each source.
// The indexes are in the same order as
@interface HGSConformingResultCache : NSObject {
 @private
  NSMutableArray *results_;
  NSMutableData *indexes_;
}
+ (id)cacheWithIndexCount:(NSUInteger)count;
- (id)initWithIndexCount:(NSUInteger)count;
- (NSMutableArray *)results;
- (NSUInteger *)indexes;
@end

@interface HGSQueryController()
- (void)cancelPendingSearchOperations:(NSTimer*)timer;
- (void)invalidateSlowSourceTimer;
- (void)searchOperationWillStart:(NSNotification *)notification;
- (void)searchOperationDidFinish:(NSNotification *)notification;
- (void)searchOperationDidUpdateResults:(NSNotification *)notification;
@end

@implementation HGSQueryController

+ (void)initialize {
  if (self == [HGSQueryController class]) {
    NSDictionary *defaultsDict
      = [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:60.0]
                                    forKey:kQuerySlowSourceTimeoutSecondsPrefKey];
    NSUserDefaults *sd = [NSUserDefaults standardUserDefaults];
    [sd registerDefaults:defaultsDict];
  }
}

- (id)initWithQuery:(HGSQuery*)query {
  if ((self = [super init])) {
    queryOperations_ = [[NSMutableArray alloc] init];
    pendingQueryOperations_ = [[NSMutableArray alloc] init];
    queryOperationsWithResults_ = [[NSMutableSet alloc] init];
    parsedQuery_ = [query retain];
    conformingResultsCache_ = [[NSMutableDictionary alloc] init];
    emptySet_ = [[NSSet alloc] init];
  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [self cancel];
  [conformingResultsCache_ release];
  [queryOperations_ release];
  [parsedQuery_ release];
  [pendingQueryOperations_ release];
  [queryOperationsWithResults_ release];
  [emptySet_ release];
  [super dealloc];
}

- (void)startQuery {
  // Spin through the Sources checking to see if they are valid for the source
  // and kick off the SearchOperations.
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSQueryControllerWillStartNotification object:self];
  HGSSearchSourceRanker *sourceRanker
    = [HGSSearchSourceRanker sharedSearchSourceRanker];
  for (HGSSearchSource *source in [sourceRanker orderedSourcesByPerformance]) {
    // Check if the source likes the query string
    if ([source isValidSourceForQuery:parsedQuery_]) {
      HGSSearchOperation* operation;
      operation = [source searchOperationForQuery:parsedQuery_];
      if (operation) {
        [nc addObserver:self
               selector:@selector(searchOperationWillStart:)
                   name:kHGSSearchOperationWillStartNotification
                 object:operation];
        [nc addObserver:self
               selector:@selector(searchOperationDidFinish:)
                   name:kHGSSearchOperationDidFinishNotification
                 object:operation];
        [nc addObserver:self
               selector:@selector(searchOperationDidUpdateResults:)
                   name:kHGSSearchOperationDidUpdateResultsNotification
                 object:operation];
        [queryOperations_ addObject:operation];
        [pendingQueryOperations_ addObject:operation];
      }
    }
  }
  NSArray *sourceIdentifiersToRunOnMainThread 
    = [[[HGSPluginLoader sharedPluginLoader] delegate] sourcesToRunOnMainThread];
  NSUInteger sourceCount = [sourceIdentifiersToRunOnMainThread count];
  NSMutableArray *operationsToRunOnMainThread 
    = [NSMutableArray arrayWithCapacity:sourceCount];
  for (HGSSearchOperation *operation in queryOperations_) {
    NSString *identifier = [[operation source] identifier];
    if ([sourceIdentifiersToRunOnMainThread containsObject:identifier]) {
      [operationsToRunOnMainThread addObject:operation];
    } else {
      [operation runOnCurrentThread:NO];
    }
  }
  for (HGSSearchOperation *operation in operationsToRunOnMainThread) {
    [operation runOnCurrentThread:YES];
  }
  // Normally we inform the observer that we are done when the last source
  // reports in; if we don't have any sources that will never happen, so just
  // call the query done immediately.
  if ([queryOperations_ count] == 0) {
    [nc postNotificationName:kHGSQueryControllerDidFinishNotification
                      object:self];
  } else {
    // we kick off a timer to pull the plug on any really slow sources.
    NSUserDefaults *sd = [NSUserDefaults standardUserDefaults];
    NSTimeInterval slowSourceTimeout
      = [sd doubleForKey:kQuerySlowSourceTimeoutSecondsPrefKey];
    HGSAssert(!slowSourceTimer_,
              @"We shouldn't start a timer without it having been invalidated");
    slowSourceTimer_
      = [NSTimer scheduledTimerWithTimeInterval:slowSourceTimeout
                                         target:self
                                       selector:@selector(cancelPendingSearchOperations:)
                                       userInfo:nil
                                        repeats:NO];
  }
}

- (void)invalidateSlowSourceTimer {
  // There are cases where slowSourceTimer_ is the last object holding
  // onto self. We don't want to disappear immediately when slowSourceTimer
  // is invalidated, so we do a retain/autorelease to make sure that we
  // survive until the end of this autorelease pool.
  if (slowSourceTimer_) {
    [[self retain] autorelease];
    [slowSourceTimer_ invalidate];
    slowSourceTimer_ = nil;
  }
}

- (void)cancelPendingSearchOperations:(NSTimer*)timer {
  [self invalidateSlowSourceTimer];
  if ([self queriesFinished]) return;

  NSUserDefaults *sd = [NSUserDefaults standardUserDefaults];
  BOOL doLog = [sd boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey];

  // Loop back to front so we can remove things as we go
  for (NSUInteger idx = [pendingQueryOperations_ count]; idx > 0; --idx) {
    HGSSearchOperation *operation
      = [pendingQueryOperations_ objectAtIndex:(idx - 1)];

    // If it thinks it's finished, but in our pending list, it means we have yet
    // to get our notification, so we won't cancel it since we should get that
    // shortly on the next spin of the main run loop.
    if (![operation isFinished]) {
      if (doLog) {
        HGSLog(@"Took too much time, canceling SearchOperation %@", operation);
      }
      [operation cancel];
    }
  }
}

- (HGSQuery *)query {
  return parsedQuery_;
}

// stops the query
- (void)cancel {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  for (HGSSearchOperation* operation in queryOperations_) {
    [nc removeObserver:self name:nil object:operation];
    [operation cancel];
  }
  [self invalidateSlowSourceTimer];
  cancelled_ = YES;
}

- (BOOL)queriesFinished {
  return ([pendingQueryOperations_ count] == 0) ? YES : NO;
}

- (BOOL)isCancelled {
  return cancelled_;
}

- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)typeFilter {
  NSUInteger count = 0;
  for(HGSSearchOperation *op in queryOperationsWithResults_) {
    HGSSearchSource *source = [op source];
    HGSTypeFilter *sourceFilter = [source resultTypeFilter];
    if ([sourceFilter intersectsWithFilter:typeFilter]) {
      NSUInteger opCount = [op resultCountForFilter:typeFilter];
      count += opCount;
    }
  }
  return count;
}

- (HGSConformingResultCache *)cachedResultsForFilter:(HGSTypeFilter *)filter {
  HGSConformingResultCache *cache
    = [conformingResultsCache_ objectForKey:filter];
  if (!cache) {
    NSUInteger opsCount = [queryOperationsWithResults_ count];
    cache = [HGSConformingResultCache cacheWithIndexCount:opsCount];
    [conformingResultsCache_ setObject:cache forKey:filter];
  }
  return cache;
}

- (NSArray *)rankedResultsInRange:(NSRange)range
                       typeFilter:(HGSTypeFilter *)typeFilter
                 removeDuplicates:(BOOL)removeDuplicates {
  NSArray *finalRankedResults = nil;
  NSUInteger maxRange = NSMaxRange(range);
  @synchronized (conformingResultsCache_) {
    HGSConformingResultCache *cache = [self cachedResultsForFilter:typeFilter];
    NSMutableArray *rankedResults = [cache results];
    NSUInteger *opsIndexes = [cache indexes];
    NSUInteger rankedCount = [rankedResults count];
    if (maxRange > rankedCount) {
      NSArray *queryOperationsWithResults
        = [queryOperationsWithResults_ allObjects];
      NSUInteger opsCount = [queryOperationsWithResults count];
      NSUInteger *opsMaxIndexes = malloc(sizeof(NSUInteger) * opsCount);
      NSUInteger j = 0;
      for (HGSSearchOperation *op in queryOperationsWithResults) {
        HGSSearchSource *source = [op source];
        HGSTypeFilter *sourceFilter = [source resultTypeFilter];
        NSUInteger maxIndex = 0;
        if ([sourceFilter intersectsWithFilter:typeFilter]) {
          maxIndex = [op resultCountForFilter:typeFilter];
        }
        opsMaxIndexes[j] = maxIndex;
        j = j + 1;
      }
      while (maxRange > rankedCount) {
        HGSScoredResult *newRankedResult = nil;
        NSUInteger indexToIncrement = 0;
        for (NSUInteger i = 0; i < opsCount; ++i) {
          HGSScoredResult *testRankedResult = nil;
          NSUInteger opMaxIndex = opsMaxIndexes[i];
          for (NSUInteger opIndex = opsIndexes[i];
               opIndex < opMaxIndex;
               ++opIndex) {
            // Operations can return nil results.
            HGSSearchOperation *op
              = [queryOperationsWithResults objectAtIndex:i];
            testRankedResult = [op sortedRankedResultAtIndex:opIndex
                                                  typeFilter:typeFilter];
            if (testRankedResult) {
              NSInteger compare = NSOrderedAscending;
              if (newRankedResult) {
                compare = HGSMixerScoredResultSort(testRankedResult,
                                                   newRankedResult, nil);
              }
              if (compare == NSOrderedAscending) {
                newRankedResult = testRankedResult;
                indexToIncrement = i;
              }
              break;
            }
          }
        }
        // If we have a result first check for duplicates and do a merge
        if (newRankedResult) {
          if (removeDuplicates) {
            NSUInteger resultIndex = 0;
            for (HGSScoredResult *scoredResult in rankedResults) {
              if ([scoredResult isDuplicate:newRankedResult]) {
                NSInteger order = HGSMixerScoredResultSort(newRankedResult,
                                                           scoredResult,
                                                           NULL);
                if (order == NSOrderedAscending) {
                  newRankedResult
                    = [newRankedResult resultByAddingAttributesFromResult:scoredResult];
                } else {
                  newRankedResult
                    = [scoredResult resultByAddingAttributesFromResult:newRankedResult];
                }
                [rankedResults replaceObjectAtIndex:resultIndex
                                         withObject:newRankedResult];
                newRankedResult = nil;
                break;
              }
              ++resultIndex;
            }
          }
          // or else add it.
          if (newRankedResult) {
            [rankedResults addObject:newRankedResult];
            ++rankedCount;
          }
          ++opsIndexes[indexToIncrement];
        } else {
          break;
        }
      }
      free(opsMaxIndexes);
    }
    if (range.location < rankedCount) {
      NSUInteger totalLength = rankedCount - range.location;
      range.length = MIN(totalLength, range.length);
      finalRankedResults = [rankedResults subarrayWithRange:range];
    }
  }
  return finalRankedResults;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@ - Predicate:%@ Operations:%@",
          [super description], parsedQuery_, queryOperations_];
}

#pragma mark Notifications

- (void)searchOperationWillStart:(NSNotification *)notification {
  HGSSearchOperation *operation = [notification object];
  if (VERMILION_SEARCH_START_ENABLED()) {
    HGSSearchSource *source = [operation source];
    HGSQuery *query = [operation query];
    NSString *ptr = [NSString stringWithFormat:@"%p", operation];
    NSString *queryString = [[query tokenizedQueryString] originalString];
    VERMILION_SEARCH_START((char *)[[source identifier] UTF8String],
                           (char *)[queryString UTF8String],
                           (char *)[ptr UTF8String]);
  }
}

//
// -searchOperationDidFinish:
//
// Called when a single operation has completed (or been cancelled). There may
// be other sources still working. We send a "first tier completed" notification
// when we count that we've gotten enough "operation finished" notices to match
// the number of first-tier operations (after de-bouncing).
//
- (void)searchOperationDidFinish:(NSNotification *)notification {
  HGSSearchOperation *operation = [notification object];
  HGSAssert([pendingQueryOperations_ containsObject:operation],
            @"ERROR: Received duplicate finished notifications from operation %@",
            [operation description]);

  [pendingQueryOperations_ removeObject:operation];
  HGSSearchSource *source = [operation source];

  // If this is the last query operation to complete then report as overall
  // query completion and cancel our timer.
  if ([self queriesFinished]) {
    [self invalidateSlowSourceTimer];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kHGSQueryControllerDidFinishNotification
                      object:self];
  }
  if (VERMILION_SEARCH_FINISH_ENABLED()) {
    HGSQuery *query = [operation query];
    NSString *ptr = [NSString stringWithFormat:@"%p", operation];
    NSString *queryString = [[query tokenizedQueryString] originalString];
    VERMILION_SEARCH_FINISH((char *)[[source identifier] UTF8String],
                            (char *)[queryString UTF8String],
                            (char *)[ptr UTF8String]);
  }
}

//
// -searchOperationDidUpdateResults:
//
// Called when a source has added more results.
//
- (void)searchOperationDidUpdateResults:(NSNotification *)notification {
  HGSSearchOperation *operation = [notification object];
  @synchronized (self) {
    [queryOperationsWithResults_ addObject:operation];
  }
  @synchronized (conformingResultsCache_) {
    [conformingResultsCache_ removeAllObjects];
  }
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSQueryControllerDidUpdateResultsNotification
                    object:self];
}

@end

@implementation HGSConformingResultCache
+ (id)cacheWithIndexCount:(NSUInteger)count {
  return [[[[self class] alloc] initWithIndexCount:count] autorelease];
}

- (id)initWithIndexCount:(NSUInteger)count {
  if ((self = [super init])) {
    results_ = [[NSMutableArray alloc] init];
    indexes_ = [[NSMutableData alloc] initWithLength:count * sizeof(NSUInteger)];
  }
  return self;
}

- (void)dealloc {
  [results_ release];
  [indexes_ release];
  [super dealloc];
}

- (NSMutableArray *)results {
  return results_;
}

- (NSUInteger *)indexes {
  return (NSUInteger *)[indexes_ mutableBytes];
}

@end

//
//  HGSSimpleArraySearchOperation.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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

#import "HGSSimpleArraySearchOperation.h"
#import "HGSLog.h"
#import "NSNotificationCenter+MainThread.h"
#import "GTMMethodCheck.h"
#import "HGSMixer.h"
#import "HGSResult.h"
#import "HGSTypeFilter.h"
#import "HGSActionArgument.h"
#import "HGSQuery.h"

@implementation HGSSimpleArraySearchOperation
GTM_METHOD_CHECK(NSNotificationCenter, hgs_postOnMainThreadNotificationName:object:userInfo:);

- (void)dealloc {
  [results_ release];
  [super dealloc];
}

// call to replace the results of the operation with something more up to date.
// Threadsafe, can be called from any thread. Tells observers about the
// presence of new results on the main thread.
- (void)setRankedResults:(NSArray*)results {
  if ([self isCancelled]) return;
  HGSAssert(![self isFinished], @"setting results after the query is done?");
  // No point in telling the observers there weren't results.  The source
  // should be calling finishQuery shortly to let it know it's done.
  NSUInteger resultsCount = [results count];
  if (resultsCount == 0) return;
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  HGSQuery *query = [self query];
  HGSActionArgument *actionArg = [query actionArgument];
  if (actionArg) {
    HGSTypeFilter *argTypeFilter = [actionArg typeFilter];
    NSMutableArray *actionScoredResults 
      = [NSMutableArray arrayWithCapacity:resultsCount];
    [actionArg willScoreForQuery:query];
    for (HGSScoredResult *result in results) {
      // Filter out all types that our action arg won't take.
      if (![argTypeFilter isValidType:[result type]]) {
        continue;
      }
      result = [actionArg scoreResult:result forQuery:query];
      if (result) {
        [actionScoredResults addObject:result];
      }
    }
    [actionArg didScoreForQuery:query];
    results = actionScoredResults;
  } 
  NSArray *sortedResults 
    = [results sortedArrayUsingFunction:HGSMixerScoredResultSort context:nil];
  @synchronized (self) {
    [results_ autorelease];
    results_ = [sortedResults retain];
  }
  [nc hgs_postOnMainThreadNotificationName:kHGSSearchOperationDidUpdateResultsNotification
                                    object:self
                                  userInfo:nil];
}

- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)filter {
  NSUInteger count = 0;
  @synchronized (self) {
    if ([filter allowsAllTypes]) {
      count = [results_ count];
    } else {
      for(HGSResult *result in results_) {
        if ([filter isValidType:[result type]]) {
          count += 1;
        }
      } 
    }
  }
  return count;
}

- (NSArray *)sortedRankedResultsInRange:(NSRange)range
                             typeFilter:(HGSTypeFilter *)typeFilter {
  NSArray *sortedResults = nil;
  if ([typeFilter allowsAllTypes]) {
    @synchronized (self) {
      NSRange fullRange = NSMakeRange(0, [results_ count]);
      NSRange newRange = NSIntersectionRange(fullRange, range);
      if (newRange.length) {
        sortedResults = [results_ subarrayWithRange:newRange];
      }
    }
  } else {
    sortedResults = [super sortedRankedResultsInRange:range 
                                           typeFilter:typeFilter];
  }
  return sortedResults;
}

- (HGSScoredResult *)sortedRankedResultAtIndex:(NSUInteger)idx
                                    typeFilter:(HGSTypeFilter *)typeFilter  {
  HGSScoredResult *result = nil;
  NSUInteger count = 0;
  @synchronized (self) {
    if ([typeFilter allowsAllTypes]) {
      result = [results_ objectAtIndex:idx];
    } else {
      for (result in results_) {
        if ([typeFilter isValidType:[result type]]) {
          if (count == idx) {
            break;
          } else {
            ++count;
          }
        }
      }
    }
  }
  return result;
}

@end

//
//  HGSQueryController.h
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
//

#import <Foundation/Foundation.h>
#import <GTM/GTMDefines.h>

@class HGSQuery;
@class HGSTypeFilter;

/*!
 @header
 @discussion HGSQueryController
*/

/*!
  Handles performing a single query across multiple search sources and ranking
  the results. The query is complete when |observer| is given the "did finish"
  notification. Clients can provide their own subclass of HGSMixer to override
  various aspects of ranking and duplicate detection.
*/
@interface HGSQueryController : NSObject {
 @private
  NSMutableArray* queryOperations_;
  /*! 
   Unfinished query operations. 
  */
  NSMutableArray* pendingQueryOperations_;  
  /*! 
   Query operations that have reported at least some results 
  */
  NSMutableSet *queryOperationsWithResults_; 
  BOOL cancelled_;
  HGSQuery* parsedQuery_;
  __weak NSTimer* slowSourceTimer_;
  NSMutableDictionary *conformingResultsCache_;
  NSSet *emptySet_;
}

- (id)initWithQuery:(HGSQuery*)query;

- (HGSQuery *)query;

/*!
  Ask information about the completion status for the queries to each source.
*/
- (BOOL)queriesFinished;

/*!
  Has the query been cancelled.
*/
- (BOOL)isCancelled;

/*!
  Start the query by creating a HGSSearchOperation for each search source.
  These hide whether or not they are threaded.
*/
- (void)startQuery;
  
/*!
  Stops the query
*/
- (void)cancel;

/*!
 Returns the number of results for filter typeFilter.
*/
- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)typeFilter;

/*!
 Returns a set of results based on the current results we have from the query.
 @param range The range of results to return
 @param typeFilter The filter to apply to the results
 @param removeDuplicates Do we want duplicates removed. This takes considerably
        more time.
*/
- (NSArray *)rankedResultsInRange:(NSRange)range
                       typeFilter:(HGSTypeFilter *)typeFilter
                 removeDuplicates:(BOOL)removeDuplicates;
@end

#pragma mark Notifications

/*!
  Sent when the query will start.  Object is the QueryController.
*/
GTM_EXTERN NSString *const kHGSQueryControllerWillStartNotification;

/*!
  Sent when the query has completed. May be called even when there are more
  results that are possible, but the query has been stopped by the user or by
  the query reaching a time threshhold.  Object is the QueryController.
*/
GTM_EXTERN NSString *const kHGSQueryControllerDidFinishNotification;

/*!
 Sent when there are new results available. Object is the QueryController.
*/
GTM_EXTERN NSString *const kHGSQueryControllerDidUpdateResultsNotification;

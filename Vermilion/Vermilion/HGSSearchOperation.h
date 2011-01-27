//
//  HGSSearchOperation.h
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

#import <Foundation/Foundation.h>
#import <GTM/GTMDefines.h>

/*!
  @header
  @discussion HGSSearchOperation
*/

@class HGSQuery;
@class HGSSearchSource;
@class HGSScoredResult;
@class HGSTypeFilter;

/*!
 Combines a search source and a query into an operation that will be executed
 to get results.
*/
@interface HGSSearchOperation : NSObject {
 @private
  BOOL finished_;
  BOOL queryCancelled_;
  NSOperation *operation_;
  HGSSearchSource *source_;
  HGSQuery *query_;
  uint64_t queueTime_;
  uint64_t runTime_;
}

@property (readonly, retain) HGSSearchSource *source;
@property (readonly, retain) HGSQuery *query;
@property (readonly, assign) uint64_t runTime;
@property (readonly, assign) uint64_t queueTime;
/*!
 Is YES if the source will handle its own threading, or not require a
 thread at all. The default is for sources to be non-concurrent (a thread will
 be created on its behalf).
 */
@property (readonly, assign, getter=isConcurrent) BOOL concurrent;
@property (readonly, assign, getter=isFinished) BOOL finished;
@property (readonly, assign, getter=isCancelled) BOOL cancelled;
@property (readonly, retain) NSString *displayName;

- (id)initWithQuery:(HGSQuery*)query source:(HGSSearchSource *)source;

/*!
 Call to indicate the query has been completed. Tells the observer on the main
 thread.  This will be called for for the operation is it is NOT concurrent.
 If an operation returns YES for isConcurrent, then the search operation must
 call this to notify the source when it is done.
*/
- (void)finishQuery;

/*!
 Cancels this operation and clears the observer so no more notification will
 come in.
*/
- (void)cancel;

/*!
 Called to get the operation going. Set |onThread| to YES to run it immediately 
 on the current thread, otherwise it will be posted to an NSOperationQueue.
*/
- (void)runOnCurrentThread:(BOOL)onThread;
@end

/*!
 Methods you must override in subclasses of HGSSearchOperation.
*/
@interface HGSSearchOperation (PureVirtualMethods)
/*!
 Called to do the actual work and communicate with the search source. The
 source can periodically call |-setResults| to push the results into the
 observer and make them available for the UI. |-setResults| must be called at
 least once, usually at the end of the query, unless there are no results.  If
 your search operation returns |YES| for isConcurrent, then you *must* call
 finishQuery when you are complete to single when you are done pushing
 results.
 */
- (void)main;

/*!
 Return the sorted results in the given range.
 @seealso //google_vermilion_ref/occ/instm/HGSSearchOperation(PureVirtualMethods)/sortedRankedResultAtIndex:typeFilter: sortedRankedResultAtIndex:typeFilter:
*/
- (NSArray *)sortedRankedResultsInRange:(NSRange)range
                             typeFilter:(HGSTypeFilter *)typeFilter;

/*!
 Return the result from the sorted results at idx.
 @seealso //google_vermilion_ref/occ/instm/HGSSearchOperation(PureVirtualMethods)/sortedRankedResultsInRange:typeFilter: sortedRankedResultsInRange:typeFilter:
*/
- (HGSScoredResult *)sortedRankedResultAtIndex:(NSUInteger)idx
                                    typeFilter:(HGSTypeFilter *)typeFilter;

/*!
 Return number of results once filter has been applied.
*/
- (NSUInteger)resultCountForFilter:(HGSTypeFilter *)filter;

/*!
 Disables updates to the operation result list. This should be called before 
 iterating through the list of results to prevent the result list from changing 
 during the iteration.
 @seealso //google_vermilion_ref/occ/instm/HGSSearchOperation(PureVirtualMethods)/enableUpdates enableUpdates
*/
- (void)disableUpdates;

/*!
 Re-enables updates to the query result list. This should be called when
 finished iterating through the list of results, to allow changes to the result
 list to occur.
 @seealso //google_vermilion_ref/occ/instm/HGSSearchOperation(PureVirtualMethods)/disableUpdates disableUpdates
*/
- (void)enableUpdates;

@end


#pragma mark Notifications

/*!
 Posted when a search operation starts.
 Object is the search operation.
*/
GTM_EXTERN NSString *const kHGSSearchOperationWillStartNotification;

/*!
 Posted when the search has completed. May be called even when there are
 more results that are possible, but the search has been stopped by the
 user or by the search reaching a time threshhold. 
 Object is the search operation.
 */
GTM_EXTERN NSString *const kHGSSearchOperationDidFinishNotification;

/*!
 Posted when a search operation is cancelled.
 Object is the search operation.
*/
GTM_EXTERN NSString *const kHGSSearchOperationWasCancelledNotification;

/*!
 Posted when results are updated for this source.
 Object is the search operation.
*/
GTM_EXTERN NSString *const kHGSSearchOperationDidUpdateResultsNotification;

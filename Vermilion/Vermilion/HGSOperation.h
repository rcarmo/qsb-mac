//
//  HGSOperation.h
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

/*!
 @header NSInvocationOperation and NSOperationQueue Specializations
*/

#import <Foundation/Foundation.h>

@class GDataHTTPFetcher;

/*!
 An operation that releases its target and userData immediately after it is
 finished either by finishing or cancelling.

 NSInvocationOperations retain their targets until they are released. This
 makes it easy to cause retain loops, by doing something like this:
 myMemberVar = [[NSInvocationOperation alloc] initWithTarget:self...];
 Even if you cancel an NSInvocationOperation it doesn't release its target.
*/
@interface HGSInvocationOperation : NSOperation {
 @private
  id target_;
  SEL selector_;
  id userData_;
}

- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)userData;

@end

/*!
 An operation that wraps around a fetcher. All callbacks will be made on the
 operation thread.
*/
@interface HGSFetcherOperation : NSOperation {
 @private
  GDataHTTPFetcher *fetcher_;
  id target_;
  SEL didFinishSel_;
  SEL didFailSel_;
  BOOL finished_;
}

@property (readonly, retain) GDataHTTPFetcher *fetcher;

/*!
 @param target The target for the finished and failed selectors.
 @param fetcher The fetcher to run.
 @param didFinishSel A selector to run when the fetcher is done. Must be of the
        form:
 <p><code>
   - (void)httpFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)retrievedData
             operation:(NSOperation *)operation;
 </code></p>
        This selector will be called on the operation thread.
 @param failedSel A selector to run when the fetcher has an error. Must be of the
        form:
 <p><code>
   - (void)httpFetcher:(GDataHTTPFetcher *)fetcher
       failedWithError:(NSError *)error
             operation:(NSOperation *)operation;
 </code></p>
        This selector will be called on the operation thread.
*/
- (id)initWithTarget:(id)target
          forFetcher:(GDataHTTPFetcher *)fetcher
   didFinishSelector:(SEL)didFinishSel
     didFailSelector:(SEL)failedSel;
@end

/*!
 Shared operation queue that can be used so we don't have multiple unnecessary
 operation queues created.
*/
@interface HGSOperationQueue : NSOperationQueue

+ (HGSOperationQueue *)sharedOperationQueue;

@end

//
//  HGSOperationTest.m
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
#import "GTMSenTestCase.h"
#import "HGSOperation.h"
#import <GData/GDataHTTPFetcher.h>

static const useconds_t kNetworkOperationLength = 500000; // microseconds

// Use a prefix instead of full URL in case we are running our tests in a
// non-US based country
static NSString * const kGoogleUrlPrefix = @"http://www.google.";
static NSString * const kGoogle404Url = @"http://www.google.com/dfhasjhdfkhdgkshg";
static NSString * const kGoogleNonExistentUrl = @"http://sgdfgsdfsewfgsd.corp.google.com/";

@interface HGSFetcherOperationTest : GTMTestCase {
 @private
  BOOL          finishedWithDataIsRunning_;
  BOOL          finishedWithData_;
  BOOL          failedWithStatus_;
  BOOL          failedWithError_;
}
@end

@implementation HGSFetcherOperationTest

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData
          operation:(NSOperation *)operation {
  finishedWithData_ = YES;
  STAssertNotNil(fetcher, @"finishedWithData got a nil GDataHTTPFetcher");
  STAssertNotNil(fetcher, @"finishedWithData got a nil retrievedData");
  STAssertNotEquals([retrievedData length], (NSUInteger)0,
               @"finishedWithData got an empty retrievedData");
  STAssertTrue([[[[fetcher request] URL] absoluteString] hasPrefix:kGoogleUrlPrefix],
               @"finishedWithData URL incorrect %@, [[fetcher request] URL]");

  // Simulate a long-running operation that gets cancelled. This operation will
  // start off non-cancelled. Signal the condition variable
  // to let testNetworkOperations know we're running, which will give it a
  // chance cancel us. Then, sleep for a couple of seconds after signalling
  // the condition to give testNetworkOperations a chance to cancel.
  NSCondition *condition = [fetcher userData];
  STAssertFalse([operation isCancelled],
                @"finishedWithData operation was cancelled");
  [condition lock];
  finishedWithDataIsRunning_ = YES;
  [condition signal];
  [condition unlock];
  usleep(kNetworkOperationLength); // testNetworkOperations is now cancelling...
  STAssertTrue([operation isCancelled],
               @"finishedWithData operation was not cancelled");
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error
          operation:(NSOperation *)operation {
  // Just confirm that both GDataHTTPFetcher's status errors and network errors
  // come to this callback.
  if ([[error domain] isEqual:kGDataHTTPFetcherStatusDomain]) {
    failedWithStatus_ = YES;

    NSInteger status = [error code];
    NSString *urlString = [[[fetcher request] URL] absoluteString];
    if ([urlString isEqual:kGoogle404Url]) {
      STAssertEquals(status, (NSInteger)404, @"failedWithStatus expected a 404 response");
    } else if ([urlString hasPrefix:kGoogleUrlPrefix]) {
      STFail(@"Google home page request failed (%@)", urlString);
      NSCondition *condition = [fetcher userData];
      [condition lock];
      finishedWithDataIsRunning_ = YES;
      [condition signal];
      [condition unlock];
    } else if ([urlString isEqual:kGoogleNonExistentUrl]) {
      // Depending on how DNS is done, we could get a 503 or a non
      // kGDataHTTPFetcherStatusDomain error. So we set failedWithError_ in
      // both cases.
      failedWithError_ = YES;
    }
  } else {
    failedWithError_ = YES;

    NSCondition *condition = [fetcher userData];
    [condition lock];
    finishedWithDataIsRunning_ = YES;
    [condition signal];
    [condition unlock];
  }
}

- (void)testNetworkOperations {
  NSOperationQueue *queue = [HGSOperationQueue sharedOperationQueue];
  NSCondition *condition = [[[NSCondition alloc] init] autorelease];

  // Request Google's home page
  NSString *googleURL = [kGoogleUrlPrefix stringByAppendingString:@"com"];
  NSURL *url = [NSURL URLWithString:googleURL];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  GDataHTTPFetcher *fetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
  [fetcher setUserData:condition];
  NSOperation *networkOp
    = [[[HGSFetcherOperation alloc] initWithTarget:self
                                        forFetcher:fetcher
                                 didFinishSelector:@selector(httpFetcher:finishedWithData:operation:)
                                   didFailSelector:@selector(httpFetcher:failedWithError:operation:)]
       autorelease];
  STAssertNotNil(networkOp, @"failed to create network op for %@", googleURL);
  [queue addOperation:networkOp];
  [condition lock];
  while (!finishedWithDataIsRunning_) {
    [condition wait];
  }
  [networkOp cancel];
  [condition unlock];

  // Request a non-existent Google page
  url = [NSURL URLWithString:kGoogle404Url];
  request = [NSURLRequest requestWithURL:url];
  fetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
  networkOp
     = [[[HGSFetcherOperation alloc] initWithTarget:self
                                         forFetcher:fetcher
                                  didFinishSelector:@selector(httpFetcher:finishedWithData:operation:)
                                    didFailSelector:@selector(httpFetcher:failedWithError:operation:)]
       autorelease];
  STAssertNotNil(networkOp, @"failed to create network op for %@", kGoogle404Url);
  [queue addOperation:networkOp];

  // Request a non-existent web site
  url = [NSURL URLWithString:kGoogleNonExistentUrl];
  request = [NSURLRequest requestWithURL:url];
  fetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
  networkOp
     = [[[HGSFetcherOperation alloc] initWithTarget:self
                                         forFetcher:fetcher
                                  didFinishSelector:@selector(httpFetcher:finishedWithData:operation:)
                                    didFailSelector:@selector(httpFetcher:failedWithError:operation:)]
       autorelease];
  STAssertNotNil(networkOp, @"failed to create network op for %@", kGoogleNonExistentUrl);
  [queue addOperation:networkOp];

  [queue waitUntilAllOperationsAreFinished];

  STAssertTrue(finishedWithData_,
               @"finishedWithData: not called by network operation");
  STAssertTrue(failedWithStatus_,
               @"failedWithError: not called for status by network operation");
  STAssertTrue(failedWithError_,
               @"failedWithError: not called for network error by network operation");
}

@end

@interface HGSInvocationOperationTest : GTMTestCase
@end

@implementation HGSInvocationOperationTest
// TODO(dmaclach): Flesh this out.
@end


//
//  HGSOperation.m
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

#import "HGSOperation.h"
#import <GTM/GTMDebugSelectorValidation.h>
#import <GTM/GTMObjectSingleton.h>
#import <GData/GDataHTTPFetcher.h>

@interface HGSFetcherOperation ()
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData;

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error;

- (void)fetcherStoppedNotification:(NSNotification *)notification;

@property(readwrite, assign, getter=isFinished) BOOL finished;
@property (readwrite, retain) id target;

@end

@interface HGSInvocationOperation ()
@property (readwrite, retain) id target;
@property (readwrite, retain) id userData;
@end

@implementation HGSInvocationOperation

@synthesize target = target_;
@synthesize userData = userData_;

- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)userData {
  if ((self = [super init])) {
    GTMAssertSelectorNilOrImplementedWithArguments(target,
                                                   sel,
                                                   @encode(id),
                                                   @encode(NSOperation *),
                                                   NULL);
    [self setTarget:target];
    [self setUserData:userData];
    selector_ = sel;
  }
  return self;
}

- (void)dealloc {
  [self setTarget:nil];
  [self setUserData:nil];
  [super dealloc];
}

- (void)cancel {
  [self setTarget:nil];
  [self setUserData:nil];
  [super cancel];
}

-(void)main {
  // We get userData first because we don't want a race condition between
  // getting the userData and getting the target. Cancel clears the target
  // first.
  id userData = [self userData];
  id target = [self target];
  if (target) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    @try {
      [target performSelector:selector_ withObject:userData withObject:self];
    }
    @catch(NSException *e) {
      NSLog(@"Exception %@ thrown in operation: %@", e, self);
    }
    @catch(...) {
      NSLog(@"Unknown Exception thrown in operation: %@", self);
      // Do not rethrow exceptions.
    }
    [pool release];
  }
  [self setTarget:nil];
  [self setUserData:nil];
}

@end


static void HGSFetcherOperationStartFetch(void *info) {
  HGSFetcherOperation *op = (HGSFetcherOperation *)info;
  GDataHTTPFetcher *fetcher = [op fetcher];
  [fetcher beginFetchWithDelegate:op
                didFinishSelector:@selector(httpFetcher:finishedWithData:)
                  didFailSelector:@selector(httpFetcher:failedWithError:)];
}

@implementation HGSFetcherOperation

@synthesize finished = finished_;
@synthesize target = target_;
@synthesize fetcher = fetcher_;

- (id)initWithTarget:(id)target
          forFetcher:(GDataHTTPFetcher *)fetcher
   didFinishSelector:(SEL)didFinishSel
     didFailSelector:(SEL)failedSel {
  GTMAssertSelectorNilOrImplementedWithArguments(target,
                                                 didFinishSel,
                                                 @encode(GDataHTTPFetcher *),
                                                 @encode(NSData *),
                                                 @encode(NSOperation *),
                                                 NULL);
  GTMAssertSelectorNilOrImplementedWithArguments(target,
                                                 failedSel,
                                                 @encode(GDataHTTPFetcher *),
                                                 @encode(NSError *),
                                                 @encode(NSOperation *),
                                                 NULL);
  if ((self = [super init])) {
    fetcher_ = [fetcher retain];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(fetcherStoppedNotification:)
               name:kGDataHTTPFetcherStoppedNotification
             object:fetcher_];
    [self setTarget:target];
    didFinishSel_ = didFinishSel;
    didFailSel_ = failedSel;
  }
  return self;
}

- (void)cancel {
  [self setTarget:nil];
  [fetcher_ stopFetching];
  [super cancel];
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:kGDataHTTPFetcherStoppedNotification
              object:fetcher_];
  [fetcher_ release];
  [self setTarget:nil];
  [super dealloc];
}

- (void)fetcherStoppedNotification:(NSNotification *)notification {
  [self setFinished:YES];
  CFRunLoopRef rl = CFRunLoopGetCurrent();
  CFRunLoopStop(rl);
}

- (void)main {
  @try {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    CFRunLoopSourceContext context;
    bzero(&context, sizeof(context));
    context.info = self;
    context.perform = HGSFetcherOperationStartFetch;
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &context);
    CFRunLoopSourceSignal(source);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(runloop, source, kCFRunLoopDefaultMode);
    [self setFinished:NO];
    while (![self isFinished]) {
      CFRunLoopRun();
    }
    CFRunLoopRemoveSource(runloop, source, kCFRunLoopDefaultMode);
    CFRelease(source);
    [pool release];
  }
  @catch(NSException *e) {
    NSLog(@"Exception %@ thrown in operation: %@", e, self);
  }
  @catch(...) {
    NSLog(@"Unknown Exception thrown in operation: %@", self);
    // Do not rethrow exceptions.
  }
  [target_ release];
  target_ = nil;
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData {
  id target = [self target];
  if (target) {
    NSMethodSignature *sig = [target_ methodSignatureForSelector:didFinishSel_];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:target_];
    [invocation setSelector:didFinishSel_];
    [invocation setArgument:&fetcher_ atIndex:2];
    [invocation setArgument:&retrievedData atIndex:3];
    [invocation setArgument:&self atIndex:4];
    [invocation invoke];
  }

}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error {
  id target = [self target];
  if (target) {
    NSMethodSignature *sig = [target_ methodSignatureForSelector:didFailSel_];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
    [invocation setTarget:target_];
    [invocation setSelector:didFailSel_];
    [invocation setArgument:&fetcher_ atIndex:2];
    [invocation setArgument:&error atIndex:3];
    [invocation setArgument:&self atIndex:4];
    [invocation invoke];
  }
}

@end

@implementation HGSOperationQueue

GTMOBJECT_SINGLETON_BOILERPLATE(HGSOperationQueue, sharedOperationQueue);

@end

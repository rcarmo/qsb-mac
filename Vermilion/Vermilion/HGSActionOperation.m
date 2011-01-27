//
//  HGSActionOperation.m
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

#import "HGSActionOperation.h"
#import <GTM/GTMMethodCheck.h>

#import "HGSAction.h"
#import "HGSLog.h"
#import "HGSOperation.h"
#import "HGSActionArgument.h"
#import "NSNotificationCenter+MainThread.h"

@interface HGSActionOperation ()
@property (readwrite, retain)  NSMutableDictionary *arguments;
@property (readwrite, retain)  HGSAction *action;
@end

@implementation HGSActionOperation
GTM_METHOD_CHECK(NSNotificationCenter, hgs_postOnMainThreadNotificationName:object:userInfo:);

@synthesize action = action_;
@synthesize arguments = arguments_;

- (id)initWithAction:(HGSAction *)action arguments:(NSDictionary *)args {
  if ((self = [super init])) {
    action_ = [action retain];
    if (args) {
      arguments_ = [args mutableCopy];
    } else {
      arguments_ = [[NSMutableDictionary alloc] init];
    }
  }
  return self;
}

- (id)init {
  return [self initWithAction:nil arguments:nil];
}

- (void)dealloc {
  [action_ release];
  [arguments_ release];
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[HGSActionOperation alloc] initWithAction:[self action]
                                          arguments:[self arguments]];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return [[HGSMutableActionOperation alloc] initWithAction:[self action]
                                                 arguments:[self arguments]];
}

- (HGSResultArray *)argumentForKey:(NSString *)key {
  HGSResultArray *argument = nil;
  @synchronized(arguments_) {
    argument = [arguments_ objectForKey:key];
  }
  return argument;
}

- (BOOL)isValid {
  HGSAction *action = [self action];
  BOOL isValid = action != nil;
  if (isValid) {
    NSArray *argumentsToFill = [action arguments];
    for (HGSActionArgument *arg in argumentsToFill) {
      if (![arg isOptional]) {
        NSString *identifier = [arg identifier];
        if (![self argumentForKey:identifier]) {
          isValid = NO;
          break;
        }
      }
    }
  }
  return isValid;
}

- (void)performedAction:(NSDictionary *)results {
  NSMutableDictionary *userInfo = nil;
  @synchronized (arguments_) {
    userInfo = [NSMutableDictionary dictionaryWithDictionary:arguments_];
  }
  [userInfo addEntriesFromDictionary:results];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center postNotificationName:kHGSActionDidPerformNotification
                        object:action_
                      userInfo:userInfo];
}

- (void)performActionOperation:(id)ignored {
  BOOL result = [self isValid];
  HGSResultArray *results = nil;
  if (result) {
    NSDictionary *arguments = nil;
    @synchronized (arguments_) {
      arguments = [NSDictionary dictionaryWithDictionary:arguments_];
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center hgs_postOnMainThreadNotificationName:kHGSActionWillPerformNotification
                                          object:action_
                                        userInfo:arguments];
    @try {
      // Adding exception handler as we are potentially calling out
      // to third party code here that could be nasty to us.
      if ([action_ returnedResultsTypeFilter]) {
        results = [action_ performReturningResultsWithInfo:arguments];
        result = results != nil;
      } else {
        result = [action_ performWithInfo:arguments];
      }
    }
    @catch (NSException *e) {
      result = NO;
      HGSLog(@"Exception thrown performing action: %@ (%@)", action_, e);
    }
  }
  NSNumber *success = [NSNumber numberWithBool:result ? YES : NO];
  NSMutableDictionary *actionResults
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       success, kHGSActionCompletedSuccessfullyKey, nil];
  if (results) {
    [actionResults setObject:results forKey:kHGSActionResultsKey];
  }
  [self performSelectorOnMainThread:@selector(performedAction:)
                         withObject:actionResults
                      waitUntilDone:NO];
}

- (void)performAction {
  SEL selector = @selector(performActionOperation:);
  if ([action_ mustRunOnMainThread]) {
    [self performSelector:selector withObject:nil afterDelay:0];
  } else {
    NSInvocationOperation *op
      = [[[NSInvocationOperation alloc] initWithTarget:self
                                              selector:selector
                                                object:nil] autorelease];
    [[HGSOperationQueue sharedOperationQueue] addOperation:op];
  }
}

@end

@implementation HGSMutableActionOperation

- (void)reset {
  [self setAction:nil];
  NSMutableDictionary *args = [self arguments];
  @synchronized(args) {
    [args removeAllObjects];
  }
}

- (void)setArgument:(HGSResultArray *)argument forKey:(NSString *)key {
  NSMutableDictionary *args = [self arguments];
  @synchronized(args) {
    if (!argument) {
      [args removeObjectForKey:key];
    } else {
      [args setObject:argument forKey:key];
    }
  }
}

- (void)setAction:(HGSAction *)action {
  [super setAction:action];
}

@end

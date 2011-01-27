//
//  HGSCallbackSearchSource.m
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

#import "HGSCallbackSearchSource.h"
#import "HGSLog.h"
#import "HGSSearchOperation.h"
#import "HGSTokenizer.h"

@implementation HGSCallbackSearchSource

- (HGSSearchOperation *)searchOperationForQuery:(HGSQuery *)query {
  HGSCallbackSearchOperation* searchOp
    = [[[HGSCallbackSearchOperation alloc] initWithQuery:query
                                                  source:self] autorelease];
  return searchOp;
}

@end

@implementation HGSCallbackSearchSource (ProtectedMethods)

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  // Must be overridden
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
    HGSLog(@"ERROR: CallbackSource %@ forgot to override performSearchOperation:.",
           [self class]);
  }
  [self doesNotRecognizeSelector:_cmd];
}

- (BOOL)isSearchConcurrent {
  return NO;
}

@end

@implementation HGSCallbackSearchOperation

- (id)initWithQuery:(HGSQuery *)query 
             source:(HGSCallbackSearchSource *)callbackSource {
  if ((self = [super initWithQuery:query source:callbackSource])) {
    if (!callbackSource) {
      HGSLogDebug(@"Tried to create a CallbackSearchSource's operation w/o the "
                  @"search source.");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@ callbackSource:%@",
          [super description], [self source]];
}

- (BOOL)isConcurrent {
  return [(HGSCallbackSearchSource*)[self source] isSearchConcurrent];
}

- (void)main {
  [(HGSCallbackSearchSource*)[self source] performSearchOperation:self];
}

- (NSString *)displayName {
  return [[self source] displayName];
}

@end

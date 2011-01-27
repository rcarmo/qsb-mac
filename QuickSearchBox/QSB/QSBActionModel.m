//
//  QSBActionModel.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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

#import "QSBActionModel.h"

#import <Vermilion/Vermilion.h>

#import "QSBSearchController.h"
#import "QSBTableResult.h"

@implementation QSBActionModel

@synthesize actionOperation = actionOperation_;
@synthesize selectedTableResult = selectedTableResult_;

- (id)init {
  if ((self = [super init])) {
    searchControllers_ = [[NSMutableArray alloc] init];
    actionOperation_ = [[HGSMutableActionOperation alloc] init];
  }
  return self;
}

- (void)dealloc {
  [searchControllers_ release];
  [actionOperation_ release];
  [selectedTableResult_ release];
  [super dealloc];
}

- (QSBSearchController *)activeSearchController {
  return [searchControllers_ lastObject];
}

- (void)pushSearchController:(QSBSearchController *)controller {
  HGSAssert(controller, @"Controller can't be nil");
  [searchControllers_ addObject:controller];
}

- (void)popSearchController {
  [searchControllers_ removeLastObject];
}

- (NSUInteger)searchControllerCount {
  return [searchControllers_ count];
}

- (QSBSearchController *)searchControllerAtIndex:(NSUInteger)idx {
  HGSAssert(idx < [self searchControllerCount], 
            @"searchControllerAtIndex idx %d out of range", idx);
  return [searchControllers_ objectAtIndex:idx];
}

- (void)reset {
  [self setSelectedTableResult:nil];
  [searchControllers_ removeAllObjects];
  [actionOperation_ reset];
}

- (BOOL)canPivot {
  return [selectedTableResult_ isPivotable];
}

- (BOOL)canUnpivot {
  return [self searchControllerCount] > 1;
}

@end



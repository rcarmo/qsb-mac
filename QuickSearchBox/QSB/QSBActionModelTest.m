//
//  QSBActionModelTest.m
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

#import "GTMSenTestCase.h"

#import <OCMock/OCMock.h>

#import "QSBActionModel.h"
#import "QSBSearchController.h"
#import "QSBTableResult.h"

@interface QSBActionModelTest : GTMTestCase
@end

@implementation QSBActionModelTest

- (void)testModel {
  // Test creation and initial state
  QSBActionModel *model = [[QSBActionModel alloc] init];
  STAssertNotNil(model, nil);
  STAssertNotNil([model actionOperation], nil);
  STAssertNil([model activeSearchController], nil);
  STAssertNil([model selectedTableResult], nil);
  STAssertFalse([model canPivot], nil);
  STAssertFalse([model canUnpivot], nil);
  
  // Add a bogus controller
  STAssertThrows([model pushSearchController:nil], nil);
                 
  // Add a real controller
  id searchController = [OCMockObject mockForClass:[QSBSearchController class]];
  [model pushSearchController:searchController];
  STAssertEquals([model activeSearchController], searchController, nil);
  STAssertEquals([model searchControllerCount], (NSUInteger)1, nil);
  STAssertFalse([model canUnpivot], nil);
  
  // Add a second controller
  id searchController2 = [OCMockObject mockForClass:[QSBSearchController class]];
  [model pushSearchController:searchController2];
  STAssertEquals([model activeSearchController], searchController2, nil);
  STAssertEquals([model searchControllerCount], (NSUInteger)2, nil);
  STAssertEquals([model searchControllerAtIndex:0], searchController, nil);
  STAssertTrue([model canUnpivot], nil);

  // Pop a controller
  [model popSearchController];
  STAssertEquals([model activeSearchController], searchController, nil);
  STAssertEquals([model searchControllerCount], (NSUInteger)1, nil);
  STAssertFalse([model canUnpivot], nil);
                 
  // Check out of bounds index
  STAssertThrows([model searchControllerAtIndex:1], nil);

  // Check canPivot
  id tableResult = [OCMockObject mockForClass:[QSBTableResult class]];
  [[[tableResult expect] andReturnValue:[NSNumber numberWithBool:YES]] 
   isPivotable];
  [model setSelectedTableResult:tableResult];
  STAssertTrue([model canPivot], nil);
  
  // Check reset
  [model reset];
  STAssertNil([model activeSearchController], nil);
  STAssertNil([model selectedTableResult], nil);
  STAssertFalse([model canPivot], nil);
  STAssertFalse([model canUnpivot], nil);
  
  // Check destruction
  [model release];
}

@end

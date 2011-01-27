//
//  HGSActionOperationTest.m
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


#import "GTMSenTestCase.h"
#import <OCMock/OCMock.h>

#import "HGSActionOperation.h"
#import "HGSActionArgument.h"
#import "HGSAction.h"
#import "HGSResult.h"
#import "HGSType.h"

@interface HGSActionOperationTest : GTMTestCase
@end

@implementation HGSActionOperationTest
- (void)testActionOperationCreation {
  HGSMutableActionOperation *op = [[HGSMutableActionOperation alloc] init];
  STAssertNotNil(op, nil);
  STAssertNil([op action], nil);
  
  HGSAction *testAction = [[[HGSAction alloc] init] autorelease];
  NSDictionary *args = [NSDictionary dictionary];
  HGSActionOperation *op2 
    = [[[HGSActionOperation alloc] initWithAction:testAction 
                                        arguments:args] autorelease];
  STAssertEquals([op2 action], testAction, nil);
  STAssertNil([op2 argumentForKey:@"Foo"], nil);
}

- (void)testActionOperationArguments {
  HGSMutableActionOperation *op = [[HGSMutableActionOperation alloc] init];
  STAssertNotNil(op, nil);
  HGSUnscoredResult *result = [HGSUnscoredResult resultWithURI:@"foo:foo" 
                                                          name:@"foo"
                                                          type:kHGSTypeFile 
                                                        source:nil 
                                                    attributes:nil];
  HGSResultArray *array = [HGSResultArray arrayWithResult:result];
  STAssertNotNil(array, nil);
  
  HGSResultArray *results = [op argumentForKey:@"testKey"];
  STAssertNil(results, nil);

  [op setArgument:array forKey:@"testKey"];
  results = [op argumentForKey:@"testKey"];
  STAssertEqualObjects(results, array, nil);
  
  // Try doing some copies.
  
  HGSActionOperation *op2 = [[op copy] autorelease];
  STAssertNotNil(op2, nil);
  results = [op2 argumentForKey:@"testKey"];
  STAssertEqualObjects(results, array, nil);
  
  [op setArgument:nil forKey:@"testKey"];
  results = [op argumentForKey:@"testKey"];
  STAssertNil(results, nil);
  
  results = [op2 argumentForKey:@"testKey"];
  STAssertEqualObjects(results, array, nil);
  
  op = [[op2 mutableCopy] autorelease];
  results = [op argumentForKey:@"testKey"];
  STAssertEqualObjects(results, array, nil);
  
  [op setArgument:nil forKey:@"testKey"];
  results = [op argumentForKey:@"testKey"];
  STAssertNil(results, nil);  
}

- (void)testActionOperationReset {
  HGSMutableActionOperation *op = [[HGSMutableActionOperation alloc] init];
  STAssertNotNil(op, nil);
  HGSUnscoredResult *result = [HGSUnscoredResult resultWithURI:@"foo:foo" 
                                                          name:@"foo"
                                                          type:kHGSTypeFile 
                                                        source:nil 
                                                    attributes:nil];
  HGSResultArray *array = [HGSResultArray arrayWithResult:result];
  STAssertNotNil(array, nil);
    
  [op setArgument:array forKey:@"testKey"];
  HGSResultArray *results = [op argumentForKey:@"testKey"];
  STAssertEqualObjects(results, array, nil);
  
  [op reset];
  results = [op argumentForKey:@"testKey"];
  STAssertNil(results, nil);
}

- (void)testActionOperationIsValid {
  id action = [OCMockObject mockForClass:[HGSAction class]];
  id arg1 = [OCMockObject mockForClass:[HGSActionArgument class]];
  id arg2 = [OCMockObject mockForClass:[HGSActionArgument class]];
  NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                        @"Foo", @"Arg1",
                        @"Bar", @"Arg2",
                        nil];
  NSArray *actionArgs = [NSArray arrayWithObjects:arg1, arg2, nil];
  HGSMutableActionOperation *op 
    = [[[HGSMutableActionOperation alloc] initWithAction:action 
                                               arguments:args] autorelease];
  STAssertNotNil(op, nil);
  BOOL no = NO;
  BOOL yes = YES;
  id nilId = nil;
  
  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg1 expect] andReturn:@"Arg1"] identifier];
  [[[arg2 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg2 expect] andReturn:@"Arg2"] identifier];
  STAssertTrue([op isValid], nil);
  [arg1 verify];
  [arg2 verify];
  [action verify];
  
  // Test nil action
  HGSAction *oldAction = [op action];
  [op setAction:nil];
  STAssertFalse([op isValid], nil);
  [op setAction:oldAction];
  
  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(yes)] isOptional];
  [[[arg2 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg2 expect] andReturn:@"Arg2"] identifier];
  STAssertTrue([op isValid], nil);
  [arg1 verify];
  [arg2 verify];
  [action verify];
  
  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg1 expect] andReturn:@"Arg1"] identifier];
  [[[arg2 expect] andReturnValue:OCMOCK_VALUE(yes)] isOptional];
  STAssertTrue([op isValid], nil);
  [arg1 verify];
  [action verify];
  
  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(yes)] isOptional];
  [[[arg2 expect] andReturnValue:OCMOCK_VALUE(yes)] isOptional];
  STAssertTrue([op isValid], nil);
  [arg1 verify];
  [arg2 verify];
  [action verify];
  
  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(nilId)] identifier];
  STAssertFalse([op isValid], nil);

  [[[action expect] andReturn:actionArgs] arguments];
  [[[arg1 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg1 expect] andReturn:@"Arg1"] identifier];
  [[[arg2 expect] andReturnValue:OCMOCK_VALUE(no)] isOptional];
  [[[arg2 expect] andReturn:OCMOCK_VALUE(nilId)] identifier];
  STAssertFalse([op isValid], nil);
  [arg1 verify];
  [arg2 verify];
  [action verify];
  
  [op reset];
  STAssertFalse([op isValid], nil);
}

// TODO(dmaclach): Add tests for performAction

@end

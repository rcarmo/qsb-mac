//
//  HGSQueryTest.m
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
#import "HGSTokenizer.h"
#import "HGSQuery.h"
#import "HGSTokenizer.h"
#import "HGSResult.h"

@interface HGSQueryTest : GTMTestCase
@end

@implementation HGSQueryTest

- (void)testInit {
  STAssertNil([[[HGSQuery alloc] initWithTokenizedString:nil
                                          actionArgument:nil
                                         actionOperation:nil
                                           pivotObjects:nil
                                              queryFlags:0] autorelease],
              nil);
  STAssertNotNil([[[HGSQuery alloc] initWithString:@""
                                    actionArgument:nil
                                   actionOperation:nil
                                      pivotObjects:nil
                                        queryFlags:0] autorelease],
                 nil);
  HGSQuery *query = [[[HGSQuery alloc] initWithString:@"a"
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:nil
                                           queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  
  // For completeness ;-)
  NSString *desc = [query description];
  STAssertNotNil(desc, nil);
}

- (void)testPivotObjects {
  HGSQuery *query  = [[[HGSQuery alloc] initWithString:@"abc"
                                        actionArgument:nil
                                       actionOperation:nil
                                         pivotObjects:nil
                                            queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  STAssertNil([query pivotObjects], nil);
  STAssertNil([query pivotObject], nil);
  
  NSArray *array = [NSArray arrayWithObject:@"a"];
  HGSResultArray *pivotObjects = [HGSResultArray arrayWithResults:array];
  query  = [[[HGSQuery alloc] initWithString:nil
                              actionArgument:nil
                             actionOperation:nil
                              pivotObjects:pivotObjects
                                  queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  STAssertEqualObjects([query pivotObjects], pivotObjects, nil);
  STAssertEqualObjects([query pivotObject], @"a", nil);
  
  array = [NSArray arrayWithObjects:@"a", @"b", nil];
  pivotObjects = [HGSResultArray arrayWithResults:array];
  query  = [[[HGSQuery alloc] initWithString:@"abc"
                              actionArgument:nil
                             actionOperation:nil
                              pivotObjects:pivotObjects
                                  queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  STAssertEqualObjects([query pivotObjects], pivotObjects, nil);
  STAssertNil([query pivotObject], nil);
}

@end

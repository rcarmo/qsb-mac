//
//  HGSTypeFilterTest.m
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

#import <Foundation/Foundation.h>
#import "GTMSenTestCase.h"

#import "HGSTypeFilter.h"
#import "HGSType.h"

@interface HGSTypeFilterTest : GTMTestCase
@end

@implementation HGSTypeFilterTest
- (void)testBasicFilters {
  STAssertNotNil([HGSTypeFilter allTypesSet], nil);
  HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
  STAssertNotNil(filter, nil);
  STAssertTrue([filter allowsAllTypes], nil);
  NSSet *fileSet = [NSSet setWithObject:kHGSTypeFile];
  filter = [HGSTypeFilter filterWithConformTypes:fileSet];
  STAssertNotNil(filter, nil);
  STAssertFalse([filter allowsAllTypes], nil);
  STAssertTrue([filter isValidType:kHGSTypeFile], nil);
  HGSTypeFilter *filter2 = [HGSTypeFilter filterWithDoesNotConformTypes:fileSet];
  STAssertNotNil(filter2, nil);
  STAssertFalse([filter2 allowsAllTypes], nil);
  STAssertFalse([filter2 isValidType:kHGSTypeFile], nil);
  STAssertFalse([filter intersectsWithFilter:filter2], nil);
  NSSet *textFileSet = [NSSet setWithObject:kHGSTypeTextFile];
  filter2 = [HGSTypeFilter filterWithConformTypes:textFileSet];
  STAssertTrue([filter intersectsWithFilter:filter2], nil);
}

// TODO(dmaclach): Add some more tests here. Sigh...
@end

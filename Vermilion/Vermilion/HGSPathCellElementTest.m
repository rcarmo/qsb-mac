//
//  HGSPathCellElementTest.m
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
#import "HGSPathCellElement.h"
#import "QSBHGSResultAttributeKeys.h"

@interface HGSPathCellElementTest : GTMTestCase 
@end

@implementation HGSPathCellElementTest

- (void)testInit {
  STAssertNotNil([HGSPathCellElement elementWithTitle:nil url:nil], nil);

  HGSPathCellElement *elemA
    = [[[HGSPathCellElement alloc] initElementWithTitle:nil
                                                    url:nil
                                                  image:nil] autorelease];
  STAssertNotNil(elemA, nil);
  STAssertEqualObjects([elemA title], @"", nil);
  STAssertNil([elemA url], nil);
  STAssertNil([elemA image], nil);

  NSURL *urlB = [NSURL URLWithString:@"http://www.google.com/B"];
  NSImage* imageB = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
  STAssertNotNil(imageB, @"couldn't create image");
  HGSPathCellElement *elemB
  = [[[HGSPathCellElement alloc] initElementWithTitle:@"TITLE B"
                                                  url:urlB
                                                image:imageB] autorelease];
  STAssertNotNil(elemB, nil);
  STAssertEqualObjects([elemB title], @"TITLE B", nil);
  STAssertEqualObjects([elemB url], urlB, nil);
  STAssertEqualObjects([elemB image], imageB, nil);
  
  NSURL *urlC = [NSURL URLWithString:@"http://www.google.com/C"];
  NSImage* imageC = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
  STAssertNotNil(imageC, @"couldn't create image");
  HGSPathCellElement *elemC
    = [[[HGSPathCellElement alloc] initElementWithTitle:@"TITLE C"
                                                    url:urlC
                                                  image:imageC] autorelease];
  STAssertNotNil(elemC, nil);
  STAssertEqualObjects([elemC title], @"TITLE C", nil);
  STAssertEqualObjects([elemC url], urlC, nil);
  STAssertEqualObjects([elemC image], imageC, nil);
}

- (void)testPathCellArrayWithElement {
  NSURL *urlA = [NSURL URLWithString:@"http://www.google.com/A"];
  NSURL *urlB = [NSURL URLWithString:@"http://www.google.com/B"];
  NSArray *elements
    = [NSArray arrayWithObjects:
       [HGSPathCellElement elementWithTitle:@"CELL A" url:urlA],
       [HGSPathCellElement elementWithTitle:@"CELL B" url:urlB],
       nil];
  NSArray *cellArray = [HGSPathCellElement pathCellArrayWithElements:elements];
  STAssertNotNil(cellArray, nil);
  STAssertEquals([cellArray count], (NSUInteger)2, nil);

  NSDictionary *cellA = [cellArray objectAtIndex:0];
  STAssertNotNil(cellA, nil);
  NSString *cellTitleA = [cellA objectForKey:kQSBPathCellDisplayTitleKey];
  STAssertEqualObjects(cellTitleA, @"CELL A", nil);
  NSURL *cellURLA = [cellA objectForKey:kQSBPathCellURLKey];
  STAssertEqualObjects(cellURLA, urlA, nil);

  NSDictionary *cellB = [cellArray objectAtIndex:1];
  STAssertNotNil(cellB, nil);
  NSString *cellTitleB = [cellB objectForKey:kQSBPathCellDisplayTitleKey];
  STAssertEqualObjects(cellTitleB, @"CELL B", nil);
  NSURL *cellURLB = [cellB objectForKey:kQSBPathCellURLKey];
  STAssertEqualObjects(cellURLB, urlB, nil);
}

@end

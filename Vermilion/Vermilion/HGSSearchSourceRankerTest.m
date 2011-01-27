//
//  HGSSearchSourceRankerTest.m
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

#import "HGSSearchSourceRanker.h"
#import "HGSExtensionPoint.h"
#import "HGSSearchSource.h"

@interface HGSSearchSourceRankerTest : GTMTestCase {
 @private
  HGSSearchSourceRanker *ranker_;
  id sourcesPoint_;
}

@end

@implementation HGSSearchSourceRankerTest

- (void)setUp {
  NSBundle *bundle = [NSBundle bundleForClass:[HGSSearchSourceRanker class]];
  STAssertNotNil(bundle, nil);
  NSString *plistPath 
    = [bundle pathForResource:@"HGSSearchSourceRankerCalibration"
                     ofType:@"plist"];
  STAssertNotNil(plistPath, nil);
  NSArray *array = [NSArray arrayWithContentsOfFile:plistPath];
  STAssertNotNil(array, nil);
  
  sourcesPoint_ = [[OCMockObject mockForClass:[HGSExtensionPoint class]] retain];
  ranker_ = [[HGSSearchSourceRanker alloc] initWithRankerData:array
                                                 sourcesPoint:sourcesPoint_];
  STAssertNotNil(ranker_, nil);
}

- (void)tearDown {
  [ranker_ release];
  [sourcesPoint_ release];
}

- (void)testOrderedSources {
  id bundle = [OCMockObject mockForClass:[NSBundle class]];
  NSString *name = @"searchSourceRankerTestActionsSource";
  [[[bundle expect] andReturn:name] qsb_localizedInfoPListStringForKey:name];
  HGSSimpleNamedSearchSource *source1
    = [HGSSimpleNamedSearchSource sourceWithName:name
                                      identifier:@"com.google.qsb.actions.source"
                                          bundle:bundle];
  STAssertNotNil(source1, nil);
  
  name = @"searchSourceRankerTestApplicationsSource";
  [[[bundle expect] andReturn:name] qsb_localizedInfoPListStringForKey:name];
  HGSSimpleNamedSearchSource *source2
    = [HGSSimpleNamedSearchSource sourceWithName:name
                                      identifier:@"com.google.qsb.applications.source"
                                          bundle:bundle];
  STAssertNotNil(source2, nil);

  
  name = @"searchSourceRankerTestSpotlightSource";
  [[[bundle expect] andReturn:name] qsb_localizedInfoPListStringForKey:name];
  HGSSimpleNamedSearchSource *source3
    = [HGSSimpleNamedSearchSource sourceWithName:name
                                      identifier:@"com.google.qsb.spotlightfiles.source"
                                          bundle:bundle];
  STAssertNotNil(source3, nil);
  NSArray *sources = [NSArray arrayWithObjects:source3, source1, source2, nil];
  
  [[[sourcesPoint_ expect] andReturn:sources] extensions];
  NSArray *orderedSources = [ranker_ orderedSourcesByPerformance];
  NSArray *expectedOrder = [NSArray arrayWithObjects:source2, source1, source3, nil];
  STAssertEqualObjects(orderedSources, expectedOrder, nil);
}

- (void)testDescription {
  id bundle = [OCMockObject mockForClass:[NSBundle class]];
  NSString *name = @"searchSourceRankerTestDescriptionSource";
  [[[bundle expect] andReturn:name] qsb_localizedInfoPListStringForKey:name];
  HGSSimpleNamedSearchSource *source
    = [HGSSimpleNamedSearchSource sourceWithName:name
                                      identifier:@"com.google.qsb.test.source"
                                          bundle:bundle];
  NSArray *sources = [NSArray arrayWithObject:source];
  [[[sourcesPoint_ expect] andReturn:sources] extensions];
  NSString *description = [ranker_ description];
  STAssertNotNil(description, nil);
}

@end

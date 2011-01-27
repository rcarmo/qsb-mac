//
//  ShortcutsTest.m
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

#import "HGSUnitTestingUtilities.h"
#import "QSBSearchWindowController.h"
#import "QSBTableResult.h"
#import "QSBSearchController.h"
#import "QSBResultsWindowController.h"
#import "QSBActionModel.h"
#import "QSBActionPresenter.h"

#pragma mark Mocked Up QSB Classes

// A collection of mocked up objects. We aren't using OCMock because we don't
// want to bring QSB classes into our binary.
@interface ShortcutTestQSBTableResult : NSObject {
 @private
  HGSScoredResult *representedResult_;
}

@property (readonly, retain) HGSResult *representedResult;

@end

@implementation ShortcutTestQSBTableResult

@synthesize representedResult = representedResult_;

- (id)initWithRankedResult:(HGSScoredResult *)result {
  if ((self = [super init])) {
    representedResult_ = [result retain];
  }
  return self;
}

- (void)dealloc {
  [representedResult_ release];
  [super dealloc];
}

@end

@interface ShortcutTestSearchController : NSObject {
 @private
  HGSTokenizedString *query_;
}
@end

@implementation ShortcutTestSearchController
- (id)initWithTokenizedQueryString:(HGSTokenizedString *)query {
  if ((self = [super init])) {
    query_ = [query retain];
  }
  return self;
}

- (void)dealloc {
  [query_ release];
  [super dealloc];
}

- (id)tokenizedQueryString {
  return query_;
}

@end

@interface ShortcutTestQSBActionPresenter : NSObject {
 @private
  ShortcutTestQSBTableResult *result_;
  ShortcutTestSearchController *controller_;
}
@end

@implementation ShortcutTestQSBActionPresenter
- (id)initWithTableResult:(ShortcutTestQSBTableResult *)result
         searchController:(ShortcutTestSearchController *)controller {
  if ((self = [super init])) {
    result_ = [result retain];
    controller_ = [controller retain];
  }
  return self;
}

- (void)dealloc {
  [result_ release];
  [controller_ release];
  [super dealloc];
}

- (BOOL)canPivot {
  return YES;
}

- (BOOL)canUnpivot {
  return NO;
}

- (id)activeSearchController {
  return controller_;
}

- (id)selectedTableResult {
  return result_;
}

@end

#pragma mark -
#pragma mark Actual Test Code

@interface ShortcutsSourceTest : HGSSearchSourceAbstractTestCase {
 @private
  BOOL foundResult_;
}
- (void)emptyResults:(NSNotification *)notification;
- (void)singlePivotDidUpdateResultsNotification:(NSNotification *)notification;
@end

@implementation ShortcutsSourceTest
  
- (id)initWithInvocation:(NSInvocation *)invocation {
  self = [super initWithInvocation:invocation 
                       pluginNamed:@"Shortcuts" 
               extensionIdentifier:@"com.google.qsb.shortcuts.source"];
  return self;
}

- (void)testEmptySource {
  HGSSearchSource *source = [self source];
  HGSQuery *query = [[HGSQuery alloc] initWithString:@"i" 
                                      actionArgument:nil
                                     actionOperation:nil
                                        pivotObjects:nil 
                                          queryFlags:0];
  HGSSearchOperation *op = [source searchOperationForQuery:query];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self 
             selector:@selector(emptyResults:) 
                 name:kHGSSearchOperationDidUpdateResultsNotification 
               object:op];
  [op runOnCurrentThread:YES];
  NSRunLoop *rl = [NSRunLoop currentRunLoop];
  [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
  [center removeObserver:self];
}

- (void)emptyResults:(NSNotification *)notification {
  STFail(@"Shouldn't get here with no results");
}

- (void)testSinglePivot {
  // Create up a result
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *resultPath = [bundle pathForResource:@"SampleContact" 
                                          ofType:@"abcdp"];
  STAssertNotNil(resultPath, nil);
  HGSSearchSource *source = [HGSUnitTestingSource sourceWithBundle:bundle];
  STAssertNotNil(source, nil);
  HGSScoredResult *scoredResult = [HGSScoredResult resultWithFilePath:resultPath 
                                                               source:source
                                                           attributes:nil
                                                                score:0
                                                                flags:0
                                                          matchedTerm:nil 
                                                       matchedIndexes:nil];
  STAssertNotNil(scoredResult, nil);
  
  // Fake a pivot on it
  id tableResult = [[[ShortcutTestQSBTableResult alloc] 
                     initWithRankedResult:scoredResult] autorelease];
  STAssertNotNil(tableResult, nil);
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  HGSTokenizedString *queryString 
    = [HGSTokenizer tokenizeString:@"shortcut.test.query.string.blah"];
  id searchController 
    = [[[ShortcutTestSearchController alloc] 
        initWithTokenizedQueryString:queryString] autorelease];
  id actionPresenter 
    = [[[ShortcutTestQSBActionPresenter alloc] initWithTableResult:tableResult
                                                  searchController:searchController]
       autorelease];
  [center postNotificationName:kQSBActionPresenterWillPivotNotification
                        object:actionPresenter
                      userInfo:nil];
  
  // Perform a search on that pivot now
  HGSQuery *query = [[[HGSQuery alloc] initWithTokenizedString:queryString
                                                actionArgument:nil
                                               actionOperation:nil
                                                  pivotObjects:nil 
                                                    queryFlags:0] autorelease];
  HGSSearchOperation *op = [[self source] searchOperationForQuery:query];
  [center addObserver:self
             selector:@selector(singlePivotDidUpdateResultsNotification:) 
                 name:kHGSSearchOperationDidUpdateResultsNotification 
               object:op];
  foundResult_ = NO;
  
  // run ourself, and spin the runloop
  [op runOnCurrentThread:YES];

  NSRunLoop *rl = [NSRunLoop currentRunLoop];
  [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];

  [center removeObserver:self 
                    name:kHGSSearchOperationDidUpdateResultsNotification 
                  object:op];
  STAssertTrue(foundResult_, nil);
}

- (void)singlePivotDidUpdateResultsNotification:(NSNotification *)notification {
  HGSSearchOperation *op = [notification object];
  HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
  NSUInteger count = [op resultCountForFilter:filter];
  STAssertTrue(count > 0, nil);
  HGSScoredResult *scoredResult = [op sortedRankedResultAtIndex:0
                                                     typeFilter:filter];
  STAssertEqualObjects([scoredResult displayName], @"SampleContact.abcdp", nil);
  foundResult_ = YES;
}

// TODO(dmaclach): Add more ShortcutsTests when time is available.
// - Specifically adding multiple items and pivoting back and forth to
// see which one stays in the first position.
// - Adding an item which exists, and then deleting it, and making sure that
// it gets cleaned up.
// - Make sure that writing out and reading in function correctly.
// Others...
@end


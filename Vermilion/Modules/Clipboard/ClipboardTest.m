//
//  ClipboardTest.m
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
static NSString *const kClipboardTestString = @"Lazarus Long Text";

@interface ClipboardSourceTest : HGSSearchSourceAbstractTestCase {
 @private
  NSArray *results_;
}
- (void)gotResults:(NSNotification *)notification;
@end

@interface ClipboardCopyActionTest : HGSActionAbstractTestCase
@end

@implementation ClipboardSourceTest
  
- (id)initWithInvocation:(NSInvocation *)invocation {
  self = [super initWithInvocation:invocation 
                       pluginNamed:@"Clipboard" 
               extensionIdentifier:@"com.google.qsb.clipboard.source"];
  return self;
}

- (void)testSource {
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  NSData *stringData 
    = [kClipboardTestString dataUsingEncoding:NSUTF8StringEncoding];
  [pb setData:stringData forType:NSStringPboardType];
  NSRunLoop *rl = [NSRunLoop currentRunLoop];
  [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
  HGSSearchSource *source = [self source];
  HGSQuery *query = [[HGSQuery alloc] initWithString:@"Lazarus" 
                                      actionArgument:nil
                                     actionOperation:nil
                                        pivotObjects:nil 
                                          queryFlags:0];
  HGSSearchOperation *op = [source searchOperationForQuery:query];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self 
             selector:@selector(gotResults:) 
                 name:kHGSSearchOperationDidUpdateResultsNotification 
               object:op];
  STAssertNil(results_, nil);
  [op runOnCurrentThread:YES];
  [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1]];
  STAssertEquals([results_ count], (NSUInteger)1, nil);
  HGSResult *result = [results_ objectAtIndex:0];
  STAssertEqualObjects([result displayName], kClipboardTestString, nil);
  [results_ release];
  results_ = nil;
}

- (void)gotResults:(NSNotification *)notification {
  HGSSearchOperation *op = [notification object];
  HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
  NSRange resultRange = NSMakeRange(0, [op resultCountForFilter:filter]);
  results_ = [op sortedRankedResultsInRange:resultRange
                                 typeFilter:filter];
  STAssertNotNil(results_, nil);
  [results_ retain];
  
}

@end

@implementation ClipboardCopyActionTest

- (id)initWithInvocation:(NSInvocation *)invocation {
  self = [super initWithInvocation:invocation 
                       pluginNamed:@"Clipboard" 
               extensionIdentifier:@"com.google.qsb.clipboard.action.copy"];
  return self;
}

- (void)testCopy {

  HGSSearchSource *textSource
    = (HGSSearchSource *)[self extensionWithIdentifier:@"com.google.qsb.core.textinput.source"
                                       fromPluginNamed:@"CorePlugin"
                              extensionPointIdentifier:kHGSSourcesExtensionPoint
                                              delegate:nil];
  STAssertNotNil(textSource, nil);
  HGSUnscoredResult *textResult 
    = [HGSUnscoredResult resultWithURI:@"userinput:text"
                                  name:@"Lazarus Long"
                                  type:kHGSTypeTextUserInput
                                source:textSource
                            attributes:nil];
  STAssertNotNil(textResult, nil);
  HGSResultArray *array = [HGSResultArray arrayWithResult:textResult];
  STAssertNotNil(array, nil);
  HGSAction *action = [self action];
  STAssertNotNil(action, nil);
  
  // Things we want to copy should have clipbard data attached to them
  BOOL isGood = [action appliesToResults:array];
  STAssertFalse(isGood, nil);
  
  // Attach some clipboard data
  NSDictionary *pasteBoardValue 
    = [NSDictionary dictionaryWithObject:kClipboardTestString
                                  forKey:NSStringPboardType];
  NSDictionary *attributes 
    = [NSDictionary dictionaryWithObject:pasteBoardValue 
                                  forKey:kHGSObjectAttributePasteboardValueKey];
  HGSResult *newResult = [textResult resultByAddingAttributes:attributes];
  STAssertNotNil(newResult, nil);
  array = [HGSResultArray arrayWithResult:newResult];
  STAssertNotNil(array, nil);
  isGood = [action appliesToResults:array];
  STAssertTrue(isGood, nil);
  NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                        array, kHGSActionDirectObjectsKey, nil];
  
  // Perform copy
  isGood = [action performWithInfo:info];
  STAssertTrue(isGood, nil);
  
  // Check to make sure the values actually made it to the clipboard.
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  NSData *data = [pb dataForType:NSStringPboardType];
  NSString *dataString = [[NSString alloc] initWithData:data 
                                               encoding:NSUTF8StringEncoding];
  STAssertEqualObjects(dataString, kClipboardTestString, nil);
}

@end


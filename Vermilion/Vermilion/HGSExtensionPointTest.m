//
//  HGSExtensionPointTest.m
//  GoogleDesktop
//
//  Created by Mike Pinkerton on 6/4/08.
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

#import "GTMSenTestCase.h"
#import "HGSCoreExtensionPoints.h"

@interface HGSExtensionPointTest : GTMTestCase {
  BOOL gotPointDidAddNotification_;
  BOOL gotPointWillRemoveNotification_;
  BOOL gotPointDidRemoveNotification_;
}
@end

@interface BaseTestExtension : NSObject {
  NSString *identifier_;
}
- (id)initWithIdentifier:(NSString *)identifier;
- (NSString *)identifier;
@end

@implementation BaseTestExtension
- (id)initWithIdentifier:(NSString *)identifier {
  if ((self = [super init])) {
    identifier_ = [identifier copy];
  }
  return self;
}

- (NSString *)identifier {
  return identifier_;
}

@end

@interface MyTestExtension : BaseTestExtension
@end

@implementation MyTestExtension
@end

@interface MyOtherTestExtension : BaseTestExtension
@end

@implementation MyOtherTestExtension
@end

@interface DifferentTestExtension : BaseTestExtension
@end

@implementation DifferentTestExtension
@end


@implementation HGSExtensionPointTest

- (void)testKindOfClassChanging {
  // create a new extension point, giving it a class
  HGSExtensionPoint* newPoint
    = [HGSExtensionPoint pointWithIdentifier:@"testProtocolChanging"];
  STAssertNotNil(newPoint, @"");
  [newPoint setKindOfClass:[MyTestExtension class]];

  // create new objects that implement the protocol and verify it's valid
  MyTestExtension* extension 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test1"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"protocol check failed");
  extension = [[[MyTestExtension alloc] initWithIdentifier:@"test2"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"protocol check failed");
  extension = [[[MyTestExtension alloc] initWithIdentifier:@"test3"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"protocol check failed");
  extension = [[[MyTestExtension alloc] initWithIdentifier:@"test4"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"protocol check failed");
  extension = [[[MyTestExtension alloc] initWithIdentifier:@"test5"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"protocol check failed");

  // check there are 5
  NSArray* extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)5,
                 @"not all extensions present");

  // change to a derivative class, should retain all elements of the list
  [newPoint setKindOfClass:[MyOtherTestExtension class]];
  extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)0,
                 @"extra extensions present");

  // change to a different class, should remove all elements of the list
  [newPoint setKindOfClass:[DifferentTestExtension class]];
  extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)0,
                 @"extra extensions present");
}

- (void)testProtocol {
  // create a new extension point, giving it a kind of class
  HGSExtensionPoint* newPoint
    = [HGSExtensionPoint pointWithIdentifier:@"testProtocol"];
  STAssertNotNil(newPoint, @"");
  [newPoint setKindOfClass:[MyTestExtension class]];

  // create a new object that inherits from the class and verify it's valid
  MyTestExtension* extension 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test1"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension],
               @"kind of class check failed");

  // create a new object that inherits from some other class and make sure
  // it fails to add correclty.
  DifferentTestExtension* badExtension
    = [[[DifferentTestExtension alloc] init] autorelease];
  STAssertFalse([newPoint extendWithObject:badExtension],
                @"kind of class check failed");
}

- (void)testExtendingPoint {
  HGSExtensionPoint* newPoint
    = [HGSExtensionPoint pointWithIdentifier:@"testExtendingPoint"];
  STAssertNotNil(newPoint, @"extension point creation failed");
  [newPoint setKindOfClass:[MyTestExtension class]];
  
  // test extending with nil object. There should be zero extensions at this
  // point.
  STAssertFalse([newPoint extendWithObject:nil],
                @"incorrectly added nil object");
  NSArray* extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)0,
                 @"oddly has some extensions");
  
  // add some unique extensions
  MyTestExtension* extension1 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test1"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension1],
               @"extend failed");
  MyTestExtension* extension2 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test2"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension2],
               @"extend failed");
  MyTestExtension* extension3 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test3"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension3],
               @"extend failed");
  MyTestExtension* extension4 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test4"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension4],
               @"extend failed");
  MyTestExtension* extension5 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test5"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension5],
               @"extend failed");
  MyTestExtension* extension6 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test6"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension6],
               @"extend failed");

  // check there are 6
  extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)6,
                 @"not all extensions present");
  
  // check that adding the same id does not add a new item
  MyTestExtension* extension7 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test6"] autorelease];
  STAssertFalse([newPoint extendWithObject:extension7],
                @"extend failed");

  // check there are 6
  extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)6,
                 @"not all extensions present");

  // check that adding the same extension again does not add a new item
  STAssertFalse([newPoint extendWithObject:extension6],
                @"extend failed");

  // check there are 6
  extensionList = [newPoint extensions];
  STAssertEquals([extensionList count], (NSUInteger)6,
                 @"not all extensions present");

  // check searching for identifiers
  MyTestExtension* result = [newPoint extensionWithIdentifier:@"test1"];
  STAssertEqualObjects(result, extension1, @"didn't find last object with id");
  [newPoint removeExtension:result];
  STAssertNil([newPoint extensionWithIdentifier:@"test1"], @"didn't remove");
  result = [newPoint extensionWithIdentifier:@"not found"];
  STAssertNil(result, @"found something with an identifier we didn't expect");
  result = [newPoint extensionWithIdentifier:nil];
  STAssertNil(result, @"found something with an identifier that was nil");

  NSString *description = [newPoint description];
  STAssertTrue([description hasPrefix:@"HGSExtensionPoint, Class: 'MyTestExte"
                @"nsion', Extensions: ("], @"Bad Description: %@", description);
}

- (void)pointDidAddNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class], [HGSExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  MyTestExtension *extension = [userInfo objectForKey:kHGSExtensionKey];
  STAssertEquals([extension identifier], @"test1", nil);
  gotPointDidAddNotification_ = YES;
}

- (void)pointDidRemoveNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class], [HGSExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  MyTestExtension *extension = [userInfo objectForKey:kHGSExtensionKey];
  STAssertEquals([extension identifier], @"test1", nil);
  gotPointDidRemoveNotification_ = YES;
}

- (void)pointWillRemoveNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class], [HGSExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  MyTestExtension *extension = [userInfo objectForKey:kHGSExtensionKey];
  STAssertEquals([extension identifier], @"test1", nil);
  gotPointWillRemoveNotification_ = YES;
}

- (void)addExtensionToPoint:(HGSExtensionPoint *)point {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  MyTestExtension* extension 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test2"] autorelease];
  [point extendWithObject:extension];
  [pool release];
}

- (void)testNotification {
  HGSExtensionPoint* newPoint
    = [HGSExtensionPoint pointWithIdentifier:@"testNotification"];
  STAssertNotNil(newPoint, @"extension point creation failed");
  [newPoint setKindOfClass:[MyTestExtension class]];

  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(pointDidAddNotification:)
             name:kHGSExtensionPointDidAddExtensionNotification
           object:newPoint];
  [nc addObserver:self selector:@selector(pointDidRemoveNotification:)
             name:kHGSExtensionPointDidRemoveExtensionNotification
           object:newPoint];
  [nc addObserver:self selector:@selector(pointWillRemoveNotification:)
             name:kHGSExtensionPointWillRemoveExtensionNotification
           object:newPoint];
  
  MyTestExtension* extension1 
    = [[[MyTestExtension alloc] initWithIdentifier:@"test1"] autorelease];
  STAssertTrue([newPoint extendWithObject:extension1],
               @"extend failed");

  STAssertTrue(gotPointDidAddNotification_, 
               @"failed to get notification for add");

  [newPoint removeExtension:extension1];
  STAssertTrue(gotPointDidRemoveNotification_, 
               @"failed to get notification for remove");
  STAssertTrue(gotPointWillRemoveNotification_, 
               @"failed to get notification for remove");
  
  [nc removeObserver:self];
}

@end

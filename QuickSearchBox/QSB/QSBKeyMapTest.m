//
//  QSBKeyMapTest.m
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

#import "GTMSenTestCase.h"
#import "QSBKeyMap.h"

@interface QSBKeyMapTest : GTMTestCase
@end

@implementation QSBKeyMapTest
- (void)testKeyMap {
  // No real way to test these two, but we can execute the code
  QSBKeyMap *gdkeymap = [QSBKeyMap currentKeyMap];
  [gdkeymap description];
  
  KeyMapByteArray keyMapByteArray;
  
  // Test basic init
  gdkeymap = [[[QSBKeyMap alloc] init] autorelease];
  [gdkeymap getKeyMap:(KeyMap*)(&keyMapByteArray)];
  for (size_t i = 0; i < sizeof(keyMapByteArray); ++i) {
    STAssertEquals(keyMapByteArray[i], (UInt8)0, nil);
  }
  
  // Test NULL keyMap
  [gdkeymap getKeyMap:NULL];
  
  // Test adding
  QSBKeyMap *gdkeymap2 = [gdkeymap keyMapByAddingKey:kVK_Command];
  
  // Test equality
  STAssertFalse([gdkeymap isEqual:gdkeymap2], nil);
  STAssertFalse([gdkeymap isEqual:@"foo"], nil);
  STAssertNotEquals([gdkeymap hash], [gdkeymap2 hash], nil);
  STAssertNotEquals([gdkeymap2 hash], (NSUInteger)0, nil);
  STAssertEquals([gdkeymap hash], (NSUInteger)0, nil);
  
  // Test copy
  gdkeymap = [[gdkeymap2 copy] autorelease];
  STAssertEqualObjects(gdkeymap, gdkeymap2, nil);
  STAssertTrue([gdkeymap containsAnyKeyIn:gdkeymap2], nil);
  
  gdkeymap = [gdkeymap2 keyMapByInverting];
  STAssertNotEqualObjects(gdkeymap, gdkeymap2, nil);
  STAssertFalse([gdkeymap containsAnyKeyIn:gdkeymap2], nil);
  
  // init with keymap
  gdkeymap = [[[QSBKeyMap alloc] initWithKeys:nil count:4] autorelease];
  STAssertNotNil(gdkeymap, nil);
  
  UInt16 keys[] = { kVK_Command };
  gdkeymap = [[[QSBKeyMap alloc] initWithKeys:keys count:0] autorelease];
  STAssertNotNil(gdkeymap, nil);

  gdkeymap = [[[QSBKeyMap alloc] initWithKeys:keys count:1] autorelease];
  STAssertEqualObjects(gdkeymap, gdkeymap2, nil);
}
@end

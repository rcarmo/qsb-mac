//
//  ClipboardActions.m
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

#import <Vermilion/Vermilion.h>
#import "ClipboardSearchSource.h"

@interface ClipboardCopyAction : HGSAction
@end

@implementation ClipboardCopyAction
- (BOOL)appliesToResult:(HGSResult *)result {
  return [result valueForKey:kHGSObjectAttributePasteboardValueKey] != nil;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL didCopy = NO;
  NSPasteboard *pb = [info objectForKey:kClipboardAttributePasteboardKey];
  if (!pb) {
    pb = [NSPasteboard generalPasteboard];
  }
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  if ([directObjects count] == 1) {
    NSDictionary *values
      = [[directObjects objectAtIndex:0]
         valueForKey:kHGSObjectAttributePasteboardValueKey];
    if (values) {
      [pb declareTypes:[values allKeys] owner:nil];
      for (NSString *type in values) {
        id value = [values objectForKey:type];
        BOOL goodWrite = NO;
        if ([value isKindOfClass:[NSURL class]]) {
          [value writeToPasteboard:pb];
          goodWrite = YES;
        } else if ([value isKindOfClass:[NSArray class]] 
                   || [value isKindOfClass:[NSDictionary class]]) {
          goodWrite = [pb setPropertyList:value forType:type];
        } else if ([value isKindOfClass:[NSString class]]) {
          goodWrite = [pb setString:value forType:type];
        } else if ([value isKindOfClass:[NSData class]]) {
          goodWrite = [pb setData:value forType:type];
        } 
        if (!goodWrite) {
          HGSLogDebug(@"Unable to write class %@ (%@) for type %@",
                      [value class], value, type);
        }
        didCopy |= goodWrite;
      }
    }
  }
  return didCopy;
}

@end

//
//  TextActions.m
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

#import <Vermilion/Vermilion.h>
#import "GTMLargeTypeWindow.h"

@interface TextLargeTypeAction : HGSAction
@end

@implementation TextLargeTypeAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    NSString *name = nil;
    if ([directObjects count] == 1) {
      HGSResult *directObject = [directObjects objectAtIndex:0];
      NSDictionary *value 
        = [directObject valueForKey:kHGSObjectAttributePasteboardValueKey];
      if (value) {
        name = [value objectForKey:NSStringPboardType];
      }
    }
    if (!name) {
      name = [directObjects displayName];
    }
    GTMLargeTypeWindow *largeTypeWindow
      = [[GTMLargeTypeWindow alloc] initWithString:name];
    [largeTypeWindow setReleasedWhenClosed:YES];
    [largeTypeWindow makeKeyAndOrderFront:self];
    success = YES;
  }
  return success;
}

@end

@interface TextAppendToFileAction : HGSAction
@end

@implementation TextAppendToFileAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = YES;
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *files
    = [info objectForKey:@"com.google.core.text.action.appendtofile.file"];
  NSError *error = nil;
  for (HGSResult *text in directObjects) {
    NSDictionary *value 
      = [text valueForKey:kHGSObjectAttributePasteboardValueKey];
    NSString *textValue = [value objectForKey:NSStringPboardType];
    if (textValue) {
      for (HGSResult *file in files) {
        NSString *filePath = [file filePath];
        NSStringEncoding encoding;
        NSMutableString *contents 
          = [NSMutableString stringWithContentsOfFile:filePath 
                                         usedEncoding:&encoding 
                                                error:&error];
        if (contents) {
          if (![contents hasSuffix:@"\r"]) {
            [contents appendString:@"\r"];
          }
          [contents appendString:textValue];
          if (![contents writeToFile:filePath atomically:YES 
                            encoding:encoding 
                               error:&error]) {
            break;
          }
        } else {
          break;
        }
      }
    }
    if (error) break;
  }
  if (error) {
    [NSApp presentError:error];
    wasGood = NO;
  }
  return wasGood;
}

@end


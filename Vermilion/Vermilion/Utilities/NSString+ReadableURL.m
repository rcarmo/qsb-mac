//
//  NSString+ReadableURL.m
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

#import "NSString+ReadableURL.h"


@implementation NSString (ReadableURL)

// NOTE: NSURL+DisplayHelpers in shared is similiar to this.
- (NSString*)readableURLString {
  NSMutableString* readableURL = [NSMutableString stringWithString:self];

  // 1. remove "http://"
  if ([readableURL hasPrefix:@"http://"]) {
    [readableURL deleteCharactersInRange:NSMakeRange(0, 7)];
  }
  // 2. remove the "www." prefix
  if ([readableURL hasPrefix:@"www."]) {
    [readableURL deleteCharactersInRange:NSMakeRange(0, 4)];
  }
  // 3. remove a trailing '?'
  if ([readableURL hasSuffix:@"?"]) {
    [readableURL deleteCharactersInRange:NSMakeRange([readableURL length] - 1, 1)];
  }
  // 4. remove a trailing '/'
  if ([readableURL hasSuffix:@"/"]) {
    [readableURL deleteCharactersInRange:NSMakeRange([readableURL length] - 1, 1)];
  }
  // 5. remove "/index.(html,raw,php,asp)"
  NSRange loc = [readableURL rangeOfString:@"/index."
                                   options:(NSBackwardsSearch |
                                            NSCaseInsensitiveSearch)];
  if (loc.location != NSNotFound) {
    NSString *pageLeaf =
      [[readableURL substringFromIndex:(loc.location + loc.length)] lowercaseString];
    if ([pageLeaf isEqual:@"html"] ||
        [pageLeaf isEqual:@"htm"] ||
        [pageLeaf isEqual:@"php"] ||
        [pageLeaf isEqual:@"asp"] ||
        [pageLeaf isEqual:@"raw"]) {
      [readableURL deleteCharactersInRange:NSMakeRange(loc.location,
                                                       [readableURL length] - loc.location)];
    }
  }

  return readableURL;
}

@end

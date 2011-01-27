//
//  NSArray+CommonPrefixDetection.m
//
//  Created by J. Nicholas Jitkoff on 6/5/08.
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

#import "NSArray+CommonPrefixDetection.h"

@implementation NSArray (CorePluginCommonPrefixDetection)

- (NSString *)commonPrefixForStringsWithOptions:(NSStringCompareOptions)options {

  BOOL backwards = (options & NSBackwardsSearch) > 0;

  NSEnumerator *stringEnumerator = [self objectEnumerator];
  NSString *thisString;
  NSString *bestString = [stringEnumerator nextObject];

  while ([bestString length] > 0 &&
         (thisString = [stringEnumerator nextObject])) {
    if ([thisString isKindOfClass:[NSString class]]) {
      NSUInteger bestLength = [bestString length];
      NSUInteger thisLength = [thisString length];
      NSUInteger minLength = MIN(bestLength, thisLength);

      for (NSUInteger i = 0; i < minLength; i++) {
        if (backwards) {
          if ([bestString characterAtIndex:bestLength - i - 1]
              != [thisString characterAtIndex:thisLength - i - 1]) {
            bestString = [bestString substringFromIndex:bestLength - i];
            break;
          }
        } else {
          if ([bestString characterAtIndex:i] 
              != [thisString characterAtIndex:i]) {
            bestString = [bestString substringToIndex:i];
            break;
          }
        }
      }
      
      // Truncate the prefix to the minimum length.
      bestLength = [bestString length];
      if (bestLength > 0 &&
          minLength > 0 &&
          minLength < bestLength) {
        if (backwards) {
          bestString = [bestString substringFromIndex:(bestLength - minLength)];
        } else {
          bestString = [bestString substringToIndex:minLength];
        }
      }
    }
  }
  
  // TODO(altse): Move the breaker characters definition to a common header.
  // TODO(alcor): Include hypen as a breaker, but take care of In-N-Out cases
  NSCharacterSet *breakerSet 
    = [NSCharacterSet characterSetWithCharactersInString:@":|*><"];
  NSStringCompareOptions opts = backwards ? 0 : NSBackwardsSearch;
  NSUInteger breakerOffset 
    = [bestString rangeOfCharacterFromSet:breakerSet options:opts].location;
  
  // Also check for a hyphen with spaces around. We special case this to avoid
  // breaking on things like In-N-Out
  if (breakerOffset == NSNotFound) {
    breakerOffset 
      = [bestString rangeOfString:@" - " options:opts].location;
    // Move right one character to skip the space
    if (breakerOffset != NSNotFound) breakerOffset++; 
  }
  
  // Don't accept a common prefix unless ends in a breaker
  if (breakerOffset == NSNotFound) return nil;

  if (backwards) {
    //Include an extra character if space is the next character
    if ((breakerOffset > 0) &&
        ([bestString characterAtIndex:breakerOffset - 1] == ' ')) {
      breakerOffset--;
    }
    return [bestString substringFromIndex:breakerOffset];
  } else {
    //Include an extra character if space is the next character
    if (([bestString length] > breakerOffset + 1) &&
        ([bestString characterAtIndex:breakerOffset + 1] == ' ')) {
      breakerOffset++;
    }
    return [bestString substringToIndex:breakerOffset + 1];
  }
  return nil;
}
@end

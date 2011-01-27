//
//  NSColor+Naming.m
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

#import "NSColor+Naming.h"

@implementation NSColor (CrayonColorNaming)

- (NSString *)crayonName {
  
  NSColor *thisColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  
  CGFloat bestDistance = FLT_MAX;
  NSString *bestColorKey = nil;
  
  NSColorList *colors = [NSColorList colorListNamed:@"Crayons"];
  NSEnumerator *enumerator = [[colors allKeys] objectEnumerator];
  NSString *key = nil;
  while ((key = [enumerator nextObject])) {
    NSColor *thatColor = [colors colorWithKey:key];
    thatColor = [thatColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    
    CGFloat colorDistance = fabs([thisColor redComponent] 
                                 - [thatColor redComponent]);
    colorDistance += fabs([thisColor blueComponent] 
                          - [thatColor blueComponent]);
    colorDistance += fabs([thisColor greenComponent] 
                          - [thatColor greenComponent]);
    colorDistance = sqrt(colorDistance);
    
    if (colorDistance < bestDistance) {
      bestDistance = colorDistance; 
      bestColorKey = key;
    }
  }
  bestColorKey = [[NSBundle bundleWithPath:@"/System/Library/Colors/Crayons.clr"]
                  localizedStringForKey:bestColorKey
                  value:bestColorKey 
                  table:@"Crayons"]; 
  
  return bestColorKey;
}
@end

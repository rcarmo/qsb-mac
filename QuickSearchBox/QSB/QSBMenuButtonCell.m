//
//  QSBMenuButtonCell.m
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

#import "QSBMenuButtonCell.h"
#import "GTMNSBezierPath+RoundRect.h"


@implementation QSBMenuButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)aView {
  
  if ([[self title] length]) {
    NSRect tokenRect = NSInsetRect(cellFrame, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath gtm_bezierPathWithRoundRect:tokenRect cornerRadius:2.5];
    
    [[NSColor colorWithCalibratedRed:0.8706f green:0.9059f blue:0.9725f alpha:0.5f] setFill];
    [[NSColor colorWithCalibratedRed:0.6431f green:0.7412f blue:0.9255f alpha:0.75f] setStroke];
    [path fill];
    [path stroke];
  }
  [self drawInteriorWithFrame:cellFrame inView:aView];
}

- (NSRect)drawingRectForBounds:(NSRect)theRect {
  theRect = NSInsetRect(theRect, 4.0, 4.0);  
  return theRect;
}

- (NSSize)cellSize {
  NSSize size = [super cellSize];
  if ([[self title] length]) {
    size.width += 10.0;
  }
  size.width = MIN(size.width, 128.0);
  size.height = [[self controlView] frame].size.height;
  return size;
}


@end

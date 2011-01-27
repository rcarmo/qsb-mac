//
//  QSBPathComponentCell.m
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

#import "QSBPathComponentCell.h"

#import <GTM/GTMLinearRGBShading.h>
#import <GTM/GTMNSBezierPath+Shading.h>
#import <GTM/GTMMethodCheck.h>

@implementation QSBPathComponentCell

GTM_METHOD_CHECK(NSBezierPath, gtm_fillAxiallyFrom:to:extendingStart:extendingEnd:shading:);

- (BOOL)needsHighlighting {
  return needsHighlighting_;
}

- (void)setNeedsHighlighting:(BOOL)value {
  needsHighlighting_ = value;
}

// Draw the cell with some special highlighting: a gray underline.
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  NSColor *startColor = nil;
  NSColor *endColor = nil;
  
  if ([self isHighlighted]) {
    startColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    endColor = [NSColor whiteColor];
  } else if (needsHighlighting_) {
    startColor = [NSColor whiteColor];
    endColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
  } else {
    startColor = [NSColor whiteColor];
    endColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
  }
  
  GTMLinearRGBShading *shading = 
    [GTMLinearRGBShading shadingFromColor:startColor
                                  toColor:endColor
                           fromSpaceNamed:NSCalibratedRGBColorSpace];

  CGFloat indent = NSHeight(cellFrame) / 4.0;
   
  NSBezierPath *strokePath = [NSBezierPath bezierPath];
  [strokePath 
     moveToPoint:NSMakePoint(NSMaxX(cellFrame) - indent, NSMinY(cellFrame))];
  [strokePath 
     lineToPoint:NSMakePoint(NSMaxX(cellFrame) + indent, NSMidY(cellFrame))];
  [strokePath 
     lineToPoint:NSMakePoint(NSMaxX(cellFrame) - indent, NSMaxY(cellFrame))];  

  NSBezierPath *fillPath = [[strokePath copy] autorelease];
  [fillPath 
     lineToPoint:NSMakePoint(NSMinX(cellFrame) - indent, NSMaxY(cellFrame))];
  [fillPath 
     lineToPoint:NSMakePoint(NSMinX(cellFrame) + indent, NSMidY(cellFrame))];
  [fillPath 
     lineToPoint:NSMakePoint(NSMinX(cellFrame) - indent, NSMinY(cellFrame))];
  [fillPath closePath];
  
  [fillPath gtm_fillAxiallyFrom:NSMakePoint(0, NSMinY(cellFrame))
                         to:NSMakePoint(0, NSMaxY(cellFrame))
             extendingStart:YES
               extendingEnd:YES
                    shading:shading];

  [[NSColor colorWithCalibratedWhite:0.0 alpha:0.2] setStroke];
  [strokePath stroke];
  
  NSRect borderRect = cellFrame;
  borderRect.size.height = 1;
  borderRect.origin.x -= indent;
  [endColor setFill];
  
  NSRectFill(borderRect);
  [NSGraphicsContext saveGraphicsState];
  [super drawInteriorWithFrame:cellFrame inView:controlView];
  [NSGraphicsContext restoreGraphicsState];
}

@end

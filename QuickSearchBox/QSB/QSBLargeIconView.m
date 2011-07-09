//
//  QSBLargeIconView.m
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

#import "QSBLargeIconView.h"
#import "GTMNSImage+Scaling.h"
#import "GTMGeometryUtils.h"
#import "GTMNSObject+KeyValueObserving.h"

@implementation QSBLargeIconView

- (void)drawRect:(NSRect)rect {
  NSRect bounds = [self bounds];
  NSImage *image = [[self cell] image];
  
  //NSImageRep *bestRep = [image gtm_bestRepresentationForSize:bounds.size];
  // patched by @rcarmo for 10.6+
  NSImageRep *bestRep = [image bestRepresentationForRect:bounds context:nil hints:nil];
  NSSize size = [bestRep size];
  [image setSize:size];
  
  CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();   
  if (!cspace) return;
  
  CGContextRef context = 
    CGBitmapContextCreate(NULL,
                          NSWidth(bounds),
                          NSHeight(bounds),
                          8,            // bits per component
                          NSWidth(bounds) * sizeof(UInt32), // bytes per pixel
                          cspace,
                          kCGImageAlphaPremultipliedFirst);
  CGColorSpaceRelease(cspace);
  if (context) {
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *nsGraphicsContext = 
      [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
    [NSGraphicsContext setCurrentContext:nsGraphicsContext];
    
    NSSize drawSize = size; 
    // Allow us to scale up to 4x if we have an image that is too small
    if (drawSize.width < NSWidth(bounds)) {
      drawSize.width *= 4;
      drawSize.height *= 4;
    }
  
    NSRect canvasDrawRect
      = GTMNSScaleRectToRect(GTMNSRectOfSize(drawSize),
                             bounds, 
                             GTMScaleProportionally,
                             GTMRectAlignCenter);
    
    // If we are scaling up more than 2x, use pixelly interpolation
    if (canvasDrawRect.size.width / size.width >= 2.0) {      
      [nsGraphicsContext setImageInterpolation:NSImageInterpolationNone]; 
    } else {
      [nsGraphicsContext setImageInterpolation:NSImageInterpolationHigh];
    }
        
    [image drawInRect:canvasDrawRect
             fromRect:GTMNSRectOfSize(size)
            operation:NSCompositeSourceOver
             fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    CGRect drawRect = NSRectToCGRect(bounds);
    
    CGImageRef cgimage = CGBitmapContextCreateImage(context);
    if (cgimage) {
      CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], 
                         drawRect,
                         cgimage);
      CGImageRelease(cgimage);
    }
    CGContextRelease(context);
  }  
}

@end

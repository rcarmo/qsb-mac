//
//  QSBMoreResultsResultCell.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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

#import "QSBMoreResultsResultCell.h"
#import <Vermilion/Vermilion.h>
#import <GTM/GTMNSObject+KeyValueObserving.h>
#import <GTM/GTMMethodCheck.h>
#import "QSBTableResult.h"

// Standard drawing options.
static const NSInteger kQSBMoreResultsResultCellDrawingOptions
  = (NSStringDrawingUsesLineFragmentOrigin 
     | NSStringDrawingTruncatesLastVisibleLine);

// We handle the "source result" and the "show all" display with the same
// cell. All of the magic numbers in this file are based upon empirical
// measurements.
@implementation QSBMoreResultsResultCell

GTM_METHOD_CHECK(NSObject, gtm_addObserver:forKeyPath:selector:userInfo:options:);
GTM_METHOD_CHECK(NSObject, gtm_removeObserver:forKeyPath:selector:);
GTM_METHOD_CHECK(NSObject, gtm_stopObservingAllKeyPaths);

- (void)drawSourceResult:(QSBSourceTableResult *)result 
               withFrame:(NSRect)cellFrame 
                  inView:(NSView *)controlView {
  // Draw title.
  NSRect textFrame = NSMakeRect(cellFrame.origin.x + 110, 
                                cellFrame.origin.y + 5, 
                                cellFrame.size.width - 124, 0);
  NSAttributedString *title = [result titleString];
  [title drawWithRect:textFrame 
              options:kQSBMoreResultsResultCellDrawingOptions];
  
  // Draw category name.
  NSString *category = [result categoryName];
  if (category) {
    textFrame = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y + 2, 85, 17);
    NSColor *secondaryTitleColor = [QSBTableResult secondaryTitleColor];
    NSMutableParagraphStyle *paraStyle 
      = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [paraStyle setAlignment:NSRightTextAlignment];
    NSDictionary *attributes 
      = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSFont systemFontOfSize:13], NSFontAttributeName,
         secondaryTitleColor, NSForegroundColorAttributeName,
         paraStyle, NSParagraphStyleAttributeName,
         nil];
    [category drawWithRect:textFrame
                   options:kQSBMoreResultsResultCellDrawingOptions
                attributes:attributes];
  }
  
  // Fix up our image drawing to look pretty.
  NSGraphicsContext *context = [NSGraphicsContext currentContext];
  NSImageInterpolation interpolation = [context imageInterpolation];
  [context setImageInterpolation:NSImageInterpolationHigh];
  
  // Draw the display icon.
  NSImage *image = [result displayIcon];
  if (image) {
    NSRect destRect = NSMakeRect(cellFrame.origin.x + 89, 
                                 cellFrame.origin.y + 3, 16, 16);
    NSSize imageSize = [image size];
    NSRect sourceRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
    [NSGraphicsContext saveGraphicsState];
    if ([controlView isFlipped]) {
      // Flip our context to draw the image right side up. This is part
      // of the graphics state so it is restored below.
      NSAffineTransform *transform = [NSAffineTransform transform];
      [transform translateXBy:destRect.origin.x yBy:NSMaxY(destRect)];
      [transform scaleXBy:1.0 yBy:-1.0];
      [transform concat];
    }
    destRect.origin = NSZeroPoint;
    [image drawInRect:destRect 
             fromRect:sourceRect 
            operation:NSCompositeSourceOver 
             fraction:1];
    [NSGraphicsContext restoreGraphicsState];
  }
  
  // Draw the pivotable arrow if applicable.
  if ([result isPivotable]) {
    image = [NSImage imageNamed:@"ChildArrow"];
    NSRect destRect = NSMakeRect(cellFrame.size.width - 10, 
                                 cellFrame.origin.y + 6, 6, 10);
    NSSize imageSize = [image size];
    NSRect sourceRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
    [image drawInRect:destRect 
             fromRect:sourceRect 
            operation:NSCompositeSourceOver 
             fraction:1];
  }
  
  // Image interpolation is not part of the graphics state, so we
  // reset it ourselves.
  [context setImageInterpolation:interpolation];
}

- (void)drawShowAllResult:(QSBShowAllTableResult *)result 
                withFrame:(NSRect)cellFrame 
                   inView:(NSView *)controlView {
  // Draw the showall button.
  NSImage *image = [NSImage imageNamed:@"ShowAllButton"];
  NSRect destRect = NSMakeRect(cellFrame.origin.x + 88, 
                               cellFrame.origin.y + 3, 16, 16);
  NSSize imageSize = [image size];
  NSRect sourceRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
  BOOL imageIsFlipped = [image isFlipped];
  [image setFlipped:YES];
  [image drawInRect:destRect 
           fromRect:sourceRect 
          operation:NSCompositeSourceOver 
           fraction:1];
  [image setFlipped:imageIsFlipped];
  
  // Draw the title.
  NSRect textFrame = NSMakeRect(cellFrame.origin.x + 110, 
                                cellFrame.origin.y + 5, 
                                cellFrame.size.width - 124, 0);
  NSAttributedString *title = [result titleString];
  [title drawWithRect:textFrame 
              options:kQSBMoreResultsResultCellDrawingOptions];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  QSBTableResult *result = [self representedObject];
  if ([result isKindOfClass:[QSBSourceTableResult class]]) {
    QSBSourceTableResult *sourceResult = (QSBSourceTableResult *)result;
    [self drawSourceResult:sourceResult withFrame:cellFrame inView:controlView];
  } else if ([result isKindOfClass:[QSBShowAllTableResult class]]) {
    QSBShowAllTableResult *showResult = (QSBShowAllTableResult *)result;
    [self drawShowAllResult:showResult withFrame:cellFrame inView:controlView];
  }
}

- (void)dealloc {
  [self gtm_stopObservingAllKeyPaths];
  [super dealloc];
}

- (void)displayIconChanged:(GTMKeyValueChangeNotification *)notification {
  [(NSControl *)[self controlView] updateCell:self];
}

- (void)setRepresentedObject:(id)anObject {
  id oldObject = [self representedObject];
  if ([oldObject isKindOfClass:[QSBSourceTableResult class]]) {
    [oldObject gtm_removeObserver:self 
                       forKeyPath:@"displayIcon" 
                         selector:@selector(displayIconChanged:)];
  }
  if ([anObject isKindOfClass:[QSBSourceTableResult class]]) {
    [anObject gtm_addObserver:self 
                   forKeyPath:@"displayIcon" 
                     selector:@selector(displayIconChanged:) 
                     userInfo:nil 
                      options:0];
  }
  [super setRepresentedObject:anObject];
}

@end

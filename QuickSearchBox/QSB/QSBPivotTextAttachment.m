//
//  QSBPivotTextAttachment.m
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

#import "QSBPivotTextAttachment.h"

#import <Vermilion/Vermilion.h>
#import <GTM/GTMNSBezierPath+RoundRect.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMTypeCasting.h>

#import "QSBSearchController.h"

// Some layout constants.
// The cell frame width is laid out like this
// | XInset | ImageXPad | ImageDim | ImageXPad | Title | RightPad | XInset |
// Title is limited to kQSBPivotCellMaxTitleLength and is tail truncated
// The cell frame height is laid out like this (rotated 90 deg)
// | YInset | ImageDim Centered in cell frame | YInset |
// where the cell frame is of height kQSBPivotCellHeight.
// See -[QSBTextPivotAttachmentCell cellSize] where this is all laid out.
static const CGFloat kQSBPivotCellRightPadding = 6;
static const CGFloat kQSBPivotCellImageXPadding = 6;
static const CGFloat kQSBPivotCellImageDimension = 24;
static const CGFloat kQSBPivotCellHeight = 28;
static const CGFloat kQSBPivotCellMaxTitleLength = 100;
static const CGFloat kQSBPivotCellXInset = 2.5;
static const CGFloat kQSBPivotCellYInset = 0.5;

@implementation QSBPivotTextAttachment

- (id)initWithSearchController:(QSBSearchController *)controller {
  if ((self = [super initWithFileWrapper:nil])) {
    QSBPivotTextAttachmentCell *cell
      = [[QSBPivotTextAttachmentCell alloc] initWithSearchController:controller];
    [self setAttachmentCell:cell];
    [cell release];
  }
  return self;
}

@end

@interface QSBPivotTextAttachmentCell ()

- (NSDictionary *)titleAttributes;
- (NSFont *)titleFont;
- (BOOL)isActionCell;

@end

@implementation QSBPivotTextAttachmentCell

GTM_METHOD_CHECK(NSBezierPath, gtm_bezierPathWithRoundRect:cornerRadius:);

- (id)initWithSearchController:(QSBSearchController *)controller {
  if ((self = [super init])) {
    [self setRepresentedObject:controller];
    NSSize titleSize = NSMakeSize(kQSBPivotCellMaxTitleLength, 
                                  kQSBPivotCellHeight);
    NSDictionary *titleAttributes = [self titleAttributes];
    NSString *title = [self title];
    titleBounds_ 
      = [title boundingRectWithSize:titleSize
                            options:NSStringDrawingUsesLineFragmentOrigin
                         attributes:titleAttributes];
  }
  return self;
}

#pragma mark Private Methods

- (BOOL)isActionCell {
  QSBSearchController *controller = GTM_STATIC_CAST(QSBSearchController, 
                                                    [self representedObject]);
  HGSResultArray *pivotObjects = [controller pivotObjects];
  return [pivotObjects conformsToType:kHGSTypeAction];
}

- (NSFont *)titleFont {
  CGFloat fontHeight = [NSFont systemFontSizeForControlSize:NSMiniControlSize];
  NSFont *font = [NSFont systemFontOfSize:fontHeight];
  return font;
}

- (NSDictionary *)titleAttributes {
  NSMutableParagraphStyle *paraStyle
    = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  [paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
  return [NSDictionary dictionaryWithObjectsAndKeys:
          [self titleFont], NSFontAttributeName,
          paraStyle, NSParagraphStyleAttributeName,
          nil];
}

#pragma mark NSCell Overrides

- (NSString *)title {
  QSBSearchController *controller = GTM_STATIC_CAST(QSBSearchController, 
                                                    [self representedObject]);
  HGSResultArray *pivotObjects = [controller pivotObjects];
  return [pivotObjects displayName];
}

- (void)setTitle:(NSString *)title {
  // Title is taken from the representedObject.
  HGSAssert(NO, @"Can't set title!");
}

- (NSImage *)image {
  QSBSearchController *controller = GTM_STATIC_CAST(QSBSearchController, 
                                                    [self representedObject]);
  HGSResultArray *pivotObjects = [controller pivotObjects];
  return [pivotObjects icon];
}

- (void)setImage:(NSImage *)image {
  // Image is taken from the representedObject.
  HGSAssert(NO, @"Can't set image!");
}

#pragma mark NSTextAttachmentCell Protocol

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  NSString *title = [self title];
  if ([title length]) {
    cellFrame = [self drawingRectForBounds:cellFrame];
    NSRect tokenRect = NSInsetRect(cellFrame, kQSBPivotCellXInset, 
                                   kQSBPivotCellYInset);
    NSBezierPath *path 
      = [NSBezierPath gtm_bezierPathWithRoundRect:tokenRect
                                     cornerRadius:kQSBPivotCellXInset];

    BOOL isAction = [self isActionCell];
    
    // Color constants chosen by alcor.
    CGFloat blueFill = isAction ? 231.0f : 248.0f;
    CGFloat greenFill = isAction ? 248.0f : 231.0f;
    CGFloat blueStroke = isAction ? 189.0f : 236.0f;
    CGFloat greenStroke = isAction ? 236.0f : 189.0f;

    [[NSColor colorWithCalibratedRed:222.0f / 255.0f
                               green:greenFill / 255.0f
                                blue:blueFill / 255.0f
                               alpha:0.5f] setFill];
    [[NSColor colorWithCalibratedRed:164.0f / 255.0f
                               green:greenStroke / 255.0f
                                blue:blueStroke / 255.0f
                               alpha:0.75f] setStroke];
    [path fill];
    [path stroke];
    NSDictionary *titleAttributes = [self titleAttributes];
    NSRect titleBounds = titleBounds_;
    titleBounds.origin.x = (NSMinX(cellFrame) +
                            kQSBPivotCellImageXPadding +
                            kQSBPivotCellImageDimension +
                            kQSBPivotCellImageXPadding);
    titleBounds.origin.y = NSMidY(cellFrame) - NSHeight(titleBounds_) / 2;
    [title drawWithRect:titleBounds
                options:NSStringDrawingUsesLineFragmentOrigin
             attributes:titleAttributes];
    NSRect iconBounds
      = NSMakeRect(NSMinX(cellFrame) + kQSBPivotCellImageXPadding,
                   NSMidY(cellFrame) - kQSBPivotCellImageDimension / 2,
                   kQSBPivotCellImageDimension,
                   kQSBPivotCellImageDimension);
    NSRect imageRect = NSZeroRect;
    NSImage *image = [self image];
    NSSize imageSize = [image size];
    imageRect.size = imageSize;
    [NSGraphicsContext saveGraphicsState];
    if ([controlView isFlipped]) {
      // Cells are usually drawn in flipped views so we must flip our context to
      // draw the image. This is part of the graphics state, so it's restored
      // below.
      NSAffineTransform *transform = [NSAffineTransform transform];
      [transform translateXBy:NSMinX(cellFrame) + kQSBPivotCellImageXPadding
                          yBy:NSMaxY(iconBounds)];
      [transform scaleXBy:1.0 yBy:-1.0];
      [transform concat];
    }
    iconBounds.origin = NSZeroPoint;
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    NSImageInterpolation interpolation = [context imageInterpolation];
    [context setImageInterpolation:NSImageInterpolationHigh];
    [image drawInRect:iconBounds
             fromRect:imageRect
            operation:NSCompositeSourceOver
             fraction:1.0];
    
    // Image interpolation is not part of the graphics state, and must be
    // restored by hand.
    [context setImageInterpolation:interpolation];
    [NSGraphicsContext restoreGraphicsState];
  }
}

- (BOOL)wantsToTrackMouse {
  return NO;
}

- (void)highlight:(BOOL)flag
        withFrame:(NSRect)cellFrame
           inView:(NSView *)controlView {
  // We don't allow selection and highlighting.
}

- (BOOL)trackMouse:(NSEvent *)theEvent
            inRect:(NSRect)cellFrame ofView:(NSView *)controlView
      untilMouseUp:(BOOL)flag {
  // We don't track the mouse right now
  return NO;
}

- (NSSize)cellSize {
  NSSize size = NSMakeSize(kQSBPivotCellXInset
                           + kQSBPivotCellImageXPadding
                           + kQSBPivotCellImageDimension
                           + kQSBPivotCellImageXPadding
                           + NSWidth(titleBounds_)
                           + kQSBPivotCellRightPadding
                           + kQSBPivotCellXInset,
                           kQSBPivotCellHeight);
  // Make width integral so that we don't get blurring occuring.
  size.width = floor(size.width + 0.5);
  return size;
}

- (NSPoint)cellBaselineOffset {
  return NSMakePoint(0, 0);
}

- (void)setAttachment:(NSTextAttachment *)anObject {
  attachment_ = anObject;
}

- (NSTextAttachment *)attachment {
  return attachment_;
}

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
       characterIndex:(NSUInteger)charIndex {
  [self drawWithFrame:cellFrame inView:controlView];
}

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView
       characterIndex:(NSUInteger)charIndex
        layoutManager:(NSLayoutManager *)layoutManager {
  [self drawWithFrame:cellFrame inView:controlView characterIndex:charIndex];
}

- (BOOL)wantsToTrackMouseForEvent:(NSEvent *)theEvent
                           inRect:(NSRect)cellFrame
                           ofView:(NSView *)controlView
                 atCharacterIndex:(NSUInteger)charIndex {
  return [self wantsToTrackMouse];
}

- (BOOL)trackMouse:(NSEvent *)theEvent
            inRect:(NSRect)cellFrame
            ofView:(NSView *)controlView
  atCharacterIndex:(NSUInteger)charIndex
      untilMouseUp:(BOOL)flag {
  return [self trackMouse:theEvent
                   inRect:cellFrame
                   ofView:controlView
             untilMouseUp:flag];
}

- (NSRect)cellFrameForTextContainer:(NSTextContainer *)textContainer
               proposedLineFragment:(NSRect)lineFrag
                      glyphPosition:(NSPoint)position
                     characterIndex:(NSUInteger)charIndex {
  NSSize size = [self cellSize];
  NSRect frame = NSMakeRect(position.x, position.y, size.width, size.height);
  return frame;
}

@end

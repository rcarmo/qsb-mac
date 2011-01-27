//
//  QSBPathCell.m
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

#import "QSBPathCell.h"
#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>
#import <GTM/GTMLinearRGBShading.h>
#import <GTM/GTMNSBezierPath+Shading.h>
#import <GTM/GTMMethodCheck.h>

#import "QSBPathComponentCell.h"

// TODO(mrossetti): Remove workaround once we get a fix from Apple.
// This includes the declaration of _hoveredCell and _setHoveredCell
// as well as the override of _setHoveredCell.

// This workaround approach takes advantage of two undocumented methods
// of NSPathCell: _hoveredCell and _setHoveredCell.  We intercept calls
// to _setHoveredCell and change the highlighting settings for the old
// and new cells appropriately.

// Declare the required but private NSPathCell functions necessary
// for marking a pathComponentCell as being hovered or not.
@interface NSPathCell (UnofficialAccessToPrivateMethods)

- (id)_hoveredCell;
- (void)_setHoveredCell:(NSPathComponentCell*)pathComponentCell;

@end


@implementation QSBPathCell

GTM_METHOD_CHECK(NSBezierPath, gtm_fillAxiallyFrom:to:extendingStart:extendingEnd:shading:);

// Stipulate that HGSPathComponentCell is to be used for the
// pathComponentCells.  We may want to consider allowing the
// delegate to specify the class to be used while providing
// a suitable default pathComponentCell class.
//
+ (Class)pathComponentCellClass {
  return [QSBPathComponentCell class];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {

  NSColor *startColor = [NSColor whiteColor];
  NSColor *endColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
  
  GTMLinearRGBShading *shading = [GTMLinearRGBShading shadingFromColor:startColor
                                                               toColor:endColor
                                                        fromSpaceNamed:NSCalibratedRGBColorSpace];
  NSRect clipRect = cellFrame;
  clipRect.size.height += 10.0;
  clipRect.origin.y -= 10.0; // flipped context
  NSBezierPath *path = [NSBezierPath bezierPathWithRect:cellFrame];
  [path gtm_fillAxiallyFrom:NSMakePoint(0, NSMinY(cellFrame))
                         to:NSMakePoint(0, NSMaxY(cellFrame))
             extendingStart:YES
               extendingEnd:YES
                    shading:shading];
  
  NSRect borderRect = cellFrame;
  borderRect.size.height = 1;
  [endColor setFill];
  NSRectFill(borderRect);
  
  [self drawInteriorWithFrame:cellFrame inView:controlView];
}


// Intercept the setting of the newly hovered pathComponentCell so that
// we can unmark the old hovered cell and then mark the newly hovered cell.
- (void)_setHoveredCell:(NSPathComponentCell *)cell {
  QSBPathComponentCell *newCell = (QSBPathComponentCell *)cell;
  QSBPathComponentCell *oldCell = (QSBPathComponentCell *)[self _hoveredCell];
  [super _setHoveredCell:cell];
  if (newCell != oldCell) {
    [oldCell setNeedsHighlighting:NO];
    [newCell setNeedsHighlighting:([newCell URL] ? YES : NO)];
  }
}

- (void)setObjectValue:(id <NSCopying>)object {
  NSObject *value = (NSObject *)object;
  if ([value isKindOfClass:[NSArray class]]) {
    // Iterate over our array contents, setting up each cell.
    NSArray *pathCells = (NSArray *)value;
    NSMutableArray *componentCells = [NSMutableArray arrayWithCapacity:[pathCells count]];
    NSEnumerator *cellEnum = [pathCells objectEnumerator];
    NSDictionary *cellDict = nil;
    CGFloat fontSize = [NSFont systemFontSizeForControlSize:[self controlSize]];
    NSFont *cellFont = [NSFont systemFontOfSize:fontSize];
    while ((cellDict = [cellEnum nextObject])) {
      QSBPathComponentCell *newCell = [[[QSBPathComponentCell alloc] init] autorelease];
      NSURL *cellURL = [cellDict objectForKey:kQSBPathCellURLKey];
      if (cellURL) {
        [newCell setURL:cellURL];
      }
      NSString *cellTitle = [cellDict objectForKey:kQSBPathCellDisplayTitleKey];
      if (cellTitle) {
        [newCell setTitle:cellTitle];
      }
      NSImage *cellImage = [cellDict objectForKey:kQSBPathCellImageKey];
      if (cellImage) {
        [newCell setImage:cellImage];
      }
      
      // Set cell attributes
      [newCell setFont:cellFont];
      
      [componentCells addObject:newCell];
    }
    
    [self setPathComponentCells:componentCells];
  }
  else {
    [super setObjectValue:object];
  }
}

@end

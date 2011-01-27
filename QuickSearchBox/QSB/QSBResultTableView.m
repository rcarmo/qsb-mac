//
//  QSBResultTableView.m
//
//  Copyright (c) 2006-2008 Google Inc. All rights reserved.
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

#import "QSBResultTableView.h"
#import "QSBTableResult.h"
#import "QSBResultsViewBaseController.h"
#import "GTMGeometryUtils.h"
#import "GTMLinearRGBShading.h"
#import "GTMMethodCheck.h"
#import "GTMNSBezierPath+RoundRect.h"
#import "GTMNSBezierPath+Shading.h"
#import "HGSResult.h"
#import "HGSLog.h"

@interface QSBResultTableView ()
- (CGFloat)selectionLeftInset;
- (CGFloat)selectionRightInset;
- (CGFloat)selectionCornerRadius;
// Determine the rows in the table view which are visible within
// the enclosing scroll view's clip region.  If nothing is visible
// or there are no rows return a range with a length of 0.
- (NSRange)visibleRows;

// Determine a row's visibility.
- (BOOL)rowIsVisible:(NSInteger)row;
@end

@implementation QSBResultTableView

GTM_METHOD_CHECK(NSBezierPath, gtm_fillAxiallyFrom:to:extendingStart:extendingEnd:shading:);
GTM_METHOD_CHECK(NSBezierPath, gtm_bezierPathWithRoundRect:cornerRadius:);

@synthesize maxTableHeight = maxTableHeight_;
@synthesize minTableHeight = minTableHeight_;

- (void)highlightSelectionInClipRect:(NSRect)rect {
  NSInteger selectedRow = [self selectedRow];
  if (selectedRow != -1) {
    NSColor *highlightColor = [NSColor selectedTextBackgroundColor];
    NSColor *highlightBottom = [highlightColor colorWithAlphaComponent:0.85];
    NSColor *highlightTop = [highlightColor colorWithAlphaComponent:0.6];

    NSRect selectedRect = [self rectOfRow:selectedRow];
    selectedRect = NSInsetRect(selectedRect, 0.5, 0.5);
    selectedRect.origin.x += [self selectionLeftInset];
    selectedRect.size.width -= [self selectionRightInset];
    CGFloat cornerRadius = [self selectionCornerRadius];
    NSBezierPath *roundPath 
      = [NSBezierPath gtm_bezierPathWithRoundRect:selectedRect
                                     cornerRadius:cornerRadius];
    
    GTMLinearRGBShading *shading 
      = [GTMLinearRGBShading shadingFromColor:highlightBottom
                                      toColor:highlightTop 
                               fromSpaceNamed:NSCalibratedRGBColorSpace];
    [roundPath gtm_fillAxiallyFrom:GTMNSMidMaxY(selectedRect) 
                                to:GTMNSMidMinY(selectedRect)
                    extendingStart:YES 
                      extendingEnd:YES 
                           shading:shading];
    [highlightColor set];
    [roundPath stroke];
  }
}

- (id)_highlightColorForCell:(NSCell *)cell {
  return nil;
}

- (void)drawGridInClipRect:(NSRect)rect {
}

- (void)awakeFromNib {
  [self setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
  minTableHeight_ = 42.0;
  maxTableHeight_ = 1024.0;
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes 
                       atPoint:(NSPoint)mouseDownPoint {
  NSUInteger row = [rowIndexes firstIndex];
  NSInteger resultsIndex = [self columnWithIdentifier:@"Results"];
  NSRect cellFrame = [self frameOfCellAtColumn:resultsIndex row:row];
  BOOL canDrag = NSPointInRect(mouseDownPoint, cellFrame);
  if (canDrag) {
    id datasource = [self dataSource];
    QSBTableResult *qsbResult = [datasource tableResultForRow:row];
    canDrag = [qsbResult isKindOfClass:[QSBSourceTableResult class]];
  }
  return canDrag;
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows 
                            tableColumns:(NSArray *)tableColumns 
                                   event:(NSEvent*)dragEvent 
                                  offset:(NSPointPointer)dragImageOffset {
  NSUInteger row = [dragRows firstIndex];
  id datasource = [self dataSource];
  NSImage *image = nil;
  QSBTableResult *qsbResult = [datasource tableResultForRow:row];
  if ([qsbResult isKindOfClass:[QSBSourceTableResult class]]) {
    HGSScoredResult *hgsResult 
      = [(QSBSourceTableResult*)qsbResult representedResult];
    image = [hgsResult valueForKey:kHGSObjectAttributeImmediateIconKey];
    image = [[image copy] autorelease];
    [image setScalesWhenResized:YES];
    [image setSize:NSMakeSize(32, 32)];
  }
  return image;
}

- (BOOL)isOpaque {
  return NO;  
}


- (BOOL)selectFirstSelectableRowByIncrementing:(BOOL)incrementing 
                                    startingAt:(NSInteger)firstRow {
  BOOL haveSelection = NO;
  if (firstRow > -1) {
    id delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(tableView:shouldSelectRow:)]
        && ![delegate tableView:self shouldSelectRow:firstRow]) {
      NSInteger currSelection = firstRow;
      int offset = incrementing ? 1 : -1;
      do {
        currSelection += offset;
        if (currSelection >= [self numberOfRows]) {
          currSelection = 0;
        } else if (currSelection < 0) {
          currSelection = [self numberOfRows] - 1;
        }
      } while (![delegate tableView:self shouldSelectRow:currSelection]
               && currSelection != firstRow);
      if (currSelection == firstRow) {
        [self selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        haveSelection = NO;
      } else {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:currSelection] 
          byExtendingSelection:NO];
        haveSelection = YES;
      }
    } else {
      [self selectRowIndexes:[NSIndexSet indexSetWithIndex:firstRow] 
        byExtendingSelection:NO];
      haveSelection = YES;
    }
    [self scrollRowToVisible:[self selectedRow]];
  }
  return haveSelection;
}

- (NSRange)visibleRows {
  NSRange visibleRows = NSMakeRange(NSNotFound, 0);
  NSView *contentView = [self superview];
  NSScrollView *scrollView = (NSScrollView *)[contentView superview];
  NSScroller *scroller = [scrollView verticalScroller];
  if (contentView && scrollView && scroller) {
    NSRect contentFrame = [contentView frame];
    CGFloat scrollPercentage = [scroller floatValue];
    CGFloat tableHeight = NSHeight([self frame]);
    CGFloat contentHeight = NSHeight(contentFrame);
    CGFloat contentOffset = (tableHeight - contentHeight) * scrollPercentage;
    contentFrame.origin.y = contentOffset;
    visibleRows = [self rowsInRect:contentFrame];
  }
  return visibleRows;
}

- (BOOL)rowIsVisible:(NSInteger)row {
  return (row >= 0 && NSLocationInRange(row, [self visibleRows]));
}

- (CGFloat)selectionLeftInset {
  //Stroke left and right outside the clipping area
  return -1;
}

- (CGFloat)selectionRightInset {
  //Stroke left and right outside the clipping area
  return -2;
}

- (CGFloat)selectionCornerRadius {
  return 0.0;
}

- (NSRect)adjustScroll:(NSRect)newVisible {
  NSRect adjustRect = [super adjustScroll:newVisible];
  NSRange visibleRows = [self visibleRows];
  if (!NSEqualRanges(visibleRowRange_, visibleRows)) {
    id delegate = [self delegate];
    SEL changedVisibleRows = @selector(qsbTableView:changedVisibleRowsFrom:to:);
    if ([delegate respondsToSelector:changedVisibleRows]) {
      [delegate qsbTableView:self 
      changedVisibleRowsFrom:visibleRowRange_ 
                          to:visibleRows];
    }
    visibleRowRange_ = visibleRows;
  }
  return adjustRect;
}

- (CGFloat)tableHeight {
  // All of the view components have a fixed height relationship.  Base all
  // calculations on the change in the scrollview's height.  The scrollview's
  // height is determined from the tableview's height but within limits.
  
  // Determine the new tableview height.
  CGFloat newTableHeight = 0.0;
  NSInteger lastCellRow = [self numberOfRows] - 1;
  if (lastCellRow > -1) {
    NSRect firstCellFrame = [self frameOfCellAtColumn:0 row:0];
    NSRect lastCellFrame = [self frameOfCellAtColumn:0 
                                                 row:lastCellRow];
    newTableHeight = fabs(NSMinY(firstCellFrame) - NSMaxY(lastCellFrame));
  }
  CGFloat minTableHeight = [self minTableHeight];
  CGFloat maxTableHeight = [self maxTableHeight];
  newTableHeight = MAX(newTableHeight, minTableHeight);
  newTableHeight = MIN(newTableHeight, maxTableHeight);
  return newTableHeight;
}

- (void)reloadData {
  [super reloadData];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kQSBResultTableViewDidReloadData object:self];
}

#pragma mark NSResponder Overrides

- (void)moveUp:(id)sender {
  if ([[self delegate] respondsToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:sender];
  } else {
    [self selectFirstSelectableRowByIncrementing:NO
                                      startingAt:[self selectedRow] - 1];
  }
}

- (void)moveDown:(id)sender {
  if ([[self delegate] respondsToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:sender];
  } else {
    [self selectFirstSelectableRowByIncrementing:YES
                                      startingAt:[self selectedRow] + 1];
  }
}

- (void)moveToBeginningOfDocument:(id)sender {
  [self selectFirstSelectableRowByIncrementing:YES
                                    startingAt:0];
}

- (void)scrollToBeginningOfDocument:(id)sender {
  [self moveToBeginningOfDocument:sender];
}

- (void)moveToEndOfDocument:(id)sender {
  NSInteger lastRow = [self numberOfRows] - 1;
  [self selectFirstSelectableRowByIncrementing:NO
                                    startingAt:lastRow];
}

- (void)scrollToEndOfDocument:(id)sender {
  [self moveToEndOfDocument:sender];
}

- (void)moveDownAndModifySelection:(id)sender {
  [self moveDown:sender];
}

- (void)moveUpAndModifySelection:(id)sender {
  [self moveUp:sender];
}

- (void)scrollWheel:(NSEvent *)event {
  if ([event deltaY] < 0) {
    [self moveDown:self];
  } else if ([event deltaY] > 0) {
    [self moveUp:self];
  }    
}

- (void)noop:(id)sender {
  // Currently holding down ctrl key and shift while doing up/down arrow
  // sends out a noop: command.
  NSEvent *theEvent = [[self window] currentEvent];
  if ([theEvent modifierFlags] & (NSControlKeyMask | NSShiftKeyMask)) {
    NSString *chars = [theEvent characters];
    if ([chars length] == 1) {
      unichar theChar = [chars characterAtIndex:0];
      if (theChar == NSUpArrowFunctionKey) {
        [self moveUp:sender];
      } else if (theChar == NSDownArrowFunctionKey) {
        [self moveDown:sender];
      }
    }
  }
}

- (void)scrollPageUp:(id)sender {
  // Scroll so that the first visible row is now shown at the bottom, but
  // select the top visible row, and adjust so it is shown top-aligned.
  NSRange visibleRows = [self visibleRows];
  if (visibleRows.length) {
    NSInteger newBottomRow = visibleRows.location;
    [self scrollRowToVisible:0];
    [self scrollRowToVisible:newBottomRow];
    visibleRows = [self visibleRows];
    [self selectFirstSelectableRowByIncrementing:YES
                                      startingAt:visibleRows.location];
    [self scrollRowToVisible:[self numberOfRows] - 1];
    [self scrollRowToVisible:[self selectedRow]];
  }
}

- (void)scrollPageDown:(id)sender {
  // Scroll so that the last visible row is now show at the top.
  NSRange visibleRows = [self visibleRows];
  if (visibleRows.length) {
    NSInteger newRow = visibleRows.location + visibleRows.length - 1;
    if ([self selectFirstSelectableRowByIncrementing:YES
                                          startingAt:newRow]) {
      NSUInteger rowCount = [self numberOfRows];
      [self scrollRowToVisible:rowCount - 1];
      [self scrollRowToVisible:newRow];
    }
  }
}

- (void)insertNewline:(id)sender {
  // This sends an action up to QSBResultsViewBaseController which takes care
  // of dispatching it appropriately.
  BOOL handled = [NSApp sendAction:@selector(qsb_pickCurrentTableResult:) 
                                to:nil 
                              from:self];
  HGSAssert(handled, nil);
}

@end

//
//  QSBMenuButton.m
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

#import "QSBMenuButton.h"

@implementation QSBMenuButton

static const CGFloat kQSBMenuButtonYOffset = 4.0;
static const CGFloat kQSBMenuButtonScreenPadding = 64.0;

- (void)mouseDown:(NSEvent *)theEvent {
  NSCell *cell = [self cell];
  NSWindow *window = [self window];
  NSRect frame = [self frame];
  
  [cell setHighlighted:YES];
  
  // Calculate bottom left point of cell
  
  NSPoint clickPoint = NSMakePoint(menuOffset_.x, 
                                   menuOffset_.y + NSHeight(frame));
  
  if (NSMaxX([[window screen] frame])
      - NSMaxX([window frame]) < kQSBMenuButtonScreenPadding) {
    clickPoint.x += NSWidth(frame); 
  }
  
  clickPoint = [self convertPoint:clickPoint toView:nil];
  
  // NSMenus appear too high
  clickPoint.y -= kQSBMenuButtonYOffset;
  
  NSEvent *newEvent = [NSEvent mouseEventWithType:NSRightMouseDown
                                         location:clickPoint
                                    modifierFlags:[theEvent modifierFlags]
                                        timestamp:[theEvent timestamp]
                                     windowNumber:[window windowNumber]
                                          context:[theEvent context]
                                      eventNumber:[theEvent eventNumber]
                                       clickCount:[theEvent clickCount]
                                         pressure:0];
  
  [NSMenu popUpContextMenu:[self menu] withEvent:newEvent 
                   forView: self withFont:[self font]];
  [cell setHighlighted:NO];
}


- (void)drawRect:(NSRect)rect {
  if ([self state] && drawsBackground_) {
    [[NSColor selectedMenuItemColor]set];
    NSRectFill([self bounds]);
  }
  [super drawRect:rect];
}

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

- (BOOL)acceptsFirstResponder {
  return NO;
}

- (BOOL)performKeyEquivalent:(NSEvent*)event {
  // Give the menu a chance to handle the event even though it's not showing.
  BOOL handled = NO;
  if ([[self menu] performKeyEquivalent:event]) {
    handled = YES;
  } else {
    handled = [super performKeyEquivalent:event];
  }
  return handled;
}

- (NSPoint)menuOffset { 
  return menuOffset_; 
}

- (void)setMenuOffset:(NSPoint)newMenuOffset {
  menuOffset_ = newMenuOffset;
}

- (BOOL)drawsBackground { 
  return drawsBackground_; 
}

- (void)setDrawsBackground:(BOOL)flag {
  drawsBackground_ = flag;
}

@end

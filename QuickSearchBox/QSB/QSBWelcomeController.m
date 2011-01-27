//
//  QSBWelcomeController.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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

#import "QSBWelcomeController.h"
#import "QSBSearchWindowController.h"

@implementation QSBWelcomeController

- (id)init {
  return [super initWithWindowNibName:@"WelcomeWindow"];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  QSBCustomPanel *window = (QSBCustomPanel *)[self window];
  [window setCanBecomeKeyWindow:NO];
  [window setAlphaValue:0.0];
  [window orderFront:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
  [self autorelease];
}

- (void)setHidden:(BOOL)hidden {
  NSWindow *window = [self window];
  CGFloat alphaValue = hidden ? 0.0 : 1.0;
  NSTimeInterval duration = hidden ? kQSBHideDuration : kQSBShowDuration;
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:duration];
  [[window animator] setAlphaValue:alphaValue];
  [NSAnimationContext endGrouping];
}

@end

@implementation QSBWelcomeWindow

- (void)setParentWindow:(NSWindow *)parentWindow {
  [super setParentWindow:parentWindow];
  if (parentWindow) {
    NSRect welcomeFrame = [self frame];
    CGFloat welcomeWidth = NSWidth(welcomeFrame);
    CGFloat welcomeHeight = NSHeight(welcomeFrame);
    NSRect parentFrame = [parentWindow frame];
    CGFloat parentWidth = NSWidth(parentFrame);
    CGFloat hOffset = (parentWidth - welcomeWidth) / 2.0;
    CGFloat hPosition = parentFrame.origin.x + hOffset;
    CGFloat vPosition = parentFrame.origin.y + 45.0 - welcomeHeight;
    [self setFrameOrigin:NSMakePoint(hPosition, vPosition)];
  }
}

@end

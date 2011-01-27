//
//  QSBUserMessenger.m
//
//  Copyright 2009 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import <QuartzCore/QuartzCore.h>

#import "QSBUserMessenger.h"
#import "GTMGeometryUtils.h"
#import "GTMMethodCheck.h"
#import "GTMNSBezierPath+RoundRect.h"

// Default amount of time to fade the window in and out.
static const NSTimeInterval kUserMessageFadeTime = 0.333;

// Default amount of time to present the message.
static const NSTimeInterval kGTMUserMessagePresentationTime = 3.0;

// The width of the frame around the message.
static const CGFloat kFrameWidth = 16.0;

// Maximum width of window within screen.
static const CGFloat kScreenWidthPercentage = 0.9;  // 90%

// 'Optimum' width of message over window.
static const CGFloat kAnchorWidthPercentage = 1.3;  // 130%

// Minimum width to consider for anchor window.
static const CGFloat kMinimumAnchorWidth = 500.0;

// Default distance below top of anchor window to show first message.
static const CGFloat kAnchorVerticalOffset = 75.0;

// Default separation between concurrently showing messages.
static const CGFloat kIntermessageGap = 10.0;

// Amount of space separating image, if any, from text.
static const CGFloat kImageGap = 8.0;

// Alpha value for our backing window
static const CGFloat kTwoThirdsAlpha = 0.66;


// A view with a gray rounded-rect presentation.
@interface QSBUserMessageBackgroundView : NSView
@end


@interface QSBUserMessenger ()

// Prepare the plain NSString in |summary| to be presented in the first line
// of th emessage by formatting it as an attributed string in bold system 20
// pt. font, by formatting |description| in system 12 pt. for the second line.
- (void)setNextPlainMessageToPresent:(NSString *)summary
                         description:(NSString *)description;

// Common setter for the attributed message string.
- (void)setNextAttributedMessageToPresent:(NSAttributedString *)message;

// Image size is constrained to 128x128.
- (void)setNextImageToPresent:(NSImage *)image;

// Immediately present the queued message.
- (void)presentMessage;

// Once the message view has been prepared, this method will do the
// actual presentation by inserting it into the window.
- (void)presentMessageView:(NSView*)messageView
              withDuration:(NSTimeInterval)duration;

// Method called when it's time to take down a message.
- (void)messageExpired:(NSTimer *)timer;

// Fade in or out a view.  If |view| is nil then animate self.
- (void)animateView:(NSView *)view withEffect:(NSString*)effect;

// Don't anchor to a window that is closing.
- (void)anchorWindowWillClose:(NSNotification *)notification;

// Determine a good frame to give the message view considering the
// anchor window and screen. If we don't have an anchor window this use
// the application's key window.  If there's no key window, then center 
// on main screen.
- (NSRect)proposedMessageFrame;

// Create a view which will contain the image and text views.
- (NSView *)makeContainerViewWithFrame:(NSRect)frame;

// Called just before the application shuts down.  Will cancel any
// outstanding message timers.
- (void)applicationWillTerminate:(NSNotification *)notification;

// Given a proposed frame, returns a frame that fully exposes 
// the proposed frame on |screen| as close to it's original position as 
// possible.
// Args:
//    proposedFrame - the frame to be adjusted to fit on the screen
//    respectingDock - if YES, we won't cover the dock.
//    screen - the screen the rect is on
// Returns:
//   The frame rect offset such that if used to position the window
//   will fully exposes the window on the screen. If the proposed
//   frame is bigger than the screen, it is anchored to the upper
//   left.  The size of the proposed frame is never adjusted.
- (NSRect)fullyExposedFrameForFrame:(NSRect)proposedFrame
                     respectingDock:(BOOL)respectingDock
                           onScreen:(NSScreen *)screen;

@end


@implementation QSBUserMessenger

@synthesize ignoreKeyWindow = ignoreKeyWindow_;
@synthesize presentationTime = presentationTime_;
@synthesize fadeInTime = fadeInTime_;  
@synthesize fadeOutTime = fadeOutTime_;
@synthesize anchorVerticalOffset = anchorVerticalOffset_;
@synthesize intermessageGap = intermessageGap_;
@synthesize anchorWidthPercentage = anchorWidthPercentage_;
@synthesize minimumAnchorWidth = minimumAnchorWidth_;
@synthesize screenWidthPercentage = screenWidthPercentage_;

- (id)initWithAnchorWindow:(NSWindow *)anchorWindow {
  NSUInteger mask = NSBorderlessWindowMask | NSNonactivatingPanelMask;
  NSRect starterFrame = NSMakeRect(0.0, 0.0, 50.0, 50.0);
  if ((self = [super initWithContentRect:starterFrame
                               styleMask:mask
                                 backing:NSBackingStoreBuffered
                                   defer:NO])) {
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:NO];
    [self setHidesOnDeactivate:NO];
    [self setHasShadow:NO];
    [self setIgnoresMouseEvents:YES];
    
    // Add a content view.
    NSView *contentView
      = [[[NSView alloc] initWithFrame:starterFrame] autorelease];
    NSUInteger resizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView setAutoresizingMask:resizingMask];
    [self setContentView:contentView];
    [self setLevel:NSStatusWindowLevel];

    [self setAnchorWindow:anchorWindow];

    messages_ = [[NSMutableArray alloc] init];
    timers_ = [[NSMutableArray alloc] init];
    
    // Set defaults.
    [self setPresentationTime:kGTMUserMessagePresentationTime];
    nextMessagePresentationTime_ = kGTMUserMessagePresentationTime;
    [self setAnchorVerticalOffset:kAnchorVerticalOffset];
    [self setIntermessageGap:kIntermessageGap];
    [self setAnchorWidthPercentage:kAnchorWidthPercentage];
    [self setMinimumAnchorWidth:kMinimumAnchorWidth];
    [self setScreenWidthPercentage:kScreenWidthPercentage];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self 
           selector:@selector(applicationWillTerminate:) 
               name:NSApplicationWillTerminateNotification 
             object:nil];
      
  }
  return self;
}

- (void)dealloc {
  [messages_ release];
  [timers_ release];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [anchorWindow_ release];
  [nextAttributedMessageToPresent_ release];
  [nextImageToPresent_ release];
  [super dealloc];
}


- (void)showPlainMessage:(NSString *)message {
  [self setNextPlainMessageToPresent:message description:nil];
  [self presentMessage];
}

#pragma mark Immediate Message presentation

- (void)showAttributedMessage:(NSAttributedString *)summary {
  [self setNextAttributedMessageToPresent:summary];
  [self presentMessage];
}

- (void)showAttributedMessage:(NSAttributedString *)summary
                        image:(NSImage *)image {
  [self setNextAttributedMessageToPresent:summary];
  [self setNextImageToPresent:image];
  [self presentMessage];
}

- (void)showPlainMessage:(NSString *)summary
             description:(NSString *)description
                   image:(NSImage *)image {
  [self setNextPlainMessageToPresent:summary description:description];
  [self setNextImageToPresent:image];
  [self presentMessage];
}

- (void)showImage:(NSImage *)image {
  [self setNextImageToPresent:image];
  [self presentMessage];
}

#pragma mark Incremental Message Composition

- (void)setNextMessagePresentationTime:(NSTimeInterval)duration {
  nextMessagePresentationTime_ = duration;
}

- (void)presentMessage {
  if (nextAttributedMessageToPresent_ || nextImageToPresent_) {
    // Create the view that will contain the message.  It will be no more
    // than 50% wider than the anchor window.  So we first see how wide
    // it would be without constraint and if within bounds we just use
    // that width, otherwise we let the constraining rect grow vertically.
    // If we have stacked message still showing then we grow the window
    // vertically and stick this one on the end.
    NSRect proposedFrame = [self proposedMessageFrame];
    
    // Figure out some things about the image, if any.
    NSImageView *imageView = nil;
    CGFloat imageWidth = 0.0;
    CGFloat imageHeight = 0.0;
    CGFloat imageGap = 0.0;
    if (nextImageToPresent_) {
      imageWidth = MIN([nextImageToPresent_ size].width, 128.0);
      imageHeight = MIN([nextImageToPresent_ size].height, 128.0);
      NSRect imageFrame
        = NSMakeRect(kFrameWidth, kFrameWidth, imageWidth, imageHeight);
      imageView = [[[NSImageView alloc] initWithFrame:imageFrame]
                   autorelease];
      [imageView setImageScaling:NSScaleProportionally];
      [imageView setImage:nextImageToPresent_];
      imageGap = kImageGap;
    }
    NSTextView *textView = nil;
    CGFloat textWidth = 0.0;
    CGFloat textHeight = 0.0;
    if (nextAttributedMessageToPresent_) {
      // Figure out a frame for the text.
      NSRect textFrame = proposedFrame;
      textFrame.size.width -= ((kFrameWidth * 2.0) + imageWidth + imageGap);
      textFrame.origin
        = NSMakePoint(kFrameWidth + imageWidth + imageGap, kFrameWidth);
      textView = [[[NSTextView alloc] initWithFrame:textFrame]
                              autorelease];
      [textView setEditable:NO];
      [textView setSelectable:NO];
      [textView setDrawsBackground:NO];
      [[textView textStorage]
       setAttributedString:nextAttributedMessageToPresent_];
      // Figure out the best framing for the text.
      NSSize minTextSize = NSMakeSize(12.0, 12.0);
      [textView setMinSize:minTextSize];
      [textView setHorizontallyResizable:YES];
      [textView sizeToFit];
      NSRect newTextFrame = [textView frame];
      textHeight = NSHeight(newTextFrame);
      textWidth = NSWidth(newTextFrame);
    }

    // Adjust the proposed frame now that we know about our text and image.
    CGFloat newProposedHeight
      = MAX(imageHeight, textHeight) + (kFrameWidth * 2.0);
    CGFloat deltaHeight = newProposedHeight - NSHeight(proposedFrame);
    proposedFrame.size.height = newProposedHeight;
    // If we've got a window, the initial position is just below the
    // top of the window.
    proposedFrame.origin.y -= (deltaHeight / 2.0);  // Default position.
    NSWindow *anchorWindow = [self anchorWindow];
    if (!anchorWindow) {
      anchorWindow = [NSApp keyWindow];
    }
    if (anchorWindow) {
      NSRect anchorFrame = [anchorWindow frame];
      proposedFrame.origin.y
        = anchorFrame.origin.y + NSHeight(anchorFrame)
          - kAnchorVerticalOffset - newProposedHeight;
    }
    CGFloat newProposedWidth
      = imageWidth + textWidth + (kFrameWidth * 2.0) + imageGap;
    CGFloat deltaWidth = newProposedWidth - proposedFrame.size.width;
    proposedFrame.size.width = newProposedWidth;
    proposedFrame.origin.x -= deltaWidth / 2.0;
    
    // Create container view.
    NSView *containerView = [self makeContainerViewWithFrame:proposedFrame];
    if (textView) {
      [containerView addSubview:textView];
      // Adjust the image view's y origin.
      if (imageView) {
        NSRect newImageFrame = [imageView frame];
        newImageFrame.origin.y
          = proposedFrame.size.height - kFrameWidth - imageHeight;
        [imageView setFrame:newImageFrame];
      }
    }
    
    if (imageView) {
      [containerView addSubview:imageView];
    }
    
    // Now add the message view to our window.
    [self presentMessageView:containerView 
                withDuration:nextMessagePresentationTime_];
  }
  
  // Reset for next presentation.
  [nextAttributedMessageToPresent_ autorelease];
  nextAttributedMessageToPresent_ = nil;
  [nextImageToPresent_ autorelease];
  nextImageToPresent_ = nil;
  nextMessagePresentationTime_ = [self presentationTime];
}

#pragma mark Support and Utility Methods

- (void)setAnchorWindow:(NSWindow *)anchorWindow {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  if (anchorWindow_) {
    [nc removeObserver:self
                  name:NSWindowWillCloseNotification
                object:anchorWindow_];
  }
  if (anchorWindow) {
    [nc addObserver:self 
           selector:@selector(anchorWindowWillClose:) 
               name:NSWindowWillCloseNotification 
             object:anchorWindow];
  }
  anchorWindow_ = anchorWindow;
}

- (NSWindow *)anchorWindow {
  return anchorWindow_;
}

#pragma mark Private Methods

- (void)setNextPlainMessageToPresent:(NSString *)summary
                         description:(NSString *)description {
  NSMutableAttributedString *attributedMessage = nil;
  if (summary || description) {
    NSMutableParagraphStyle *paragraphStyle
      = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    NSShadow *textShadow = [[[NSShadow alloc] init] autorelease];
    [textShadow setShadowOffset:NSMakeSize(5, -5)];
    [textShadow setShadowBlurRadius:10];
    NSColor *shadowColor = [NSColor colorWithCalibratedWhite:0 
                                                       alpha:kTwoThirdsAlpha];
    [textShadow setShadowColor:shadowColor];
    
    // Set up the first line with the bold summary.
    if (summary) {
      NSFont *boldFont = [NSFont boldSystemFontOfSize:24.0];
      NSDictionary *attributes
        = [NSDictionary dictionaryWithObjectsAndKeys:
           [NSColor whiteColor], NSForegroundColorAttributeName,
           paragraphStyle, NSParagraphStyleAttributeName,
           textShadow, NSShadowAttributeName,
           boldFont, NSFontAttributeName,
           nil];
      attributedMessage
        = [[[NSMutableAttributedString alloc] initWithString:summary
                                                  attributes:attributes]
           autorelease];
    }
    // Add a second line with the descriptive text.
    if (description) {
      if (attributedMessage) {
        description = [NSString stringWithFormat:@"\r%@", description];
      }
      NSFont *systemFont12 = [NSFont systemFontOfSize:12.0];
      
      NSDictionary *attributes
        = [NSDictionary dictionaryWithObjectsAndKeys:
           [NSColor whiteColor], NSForegroundColorAttributeName,
           paragraphStyle, NSParagraphStyleAttributeName,
           textShadow, NSShadowAttributeName,
           systemFont12, NSFontAttributeName,
           nil];
      NSMutableAttributedString *attributedDescription
        = [[[NSMutableAttributedString alloc] initWithString:description
                                                  attributes:attributes]
           autorelease];
      if (attributedMessage) {
        [attributedMessage appendAttributedString:attributedDescription];
      } else {
        attributedMessage = attributedDescription;
      }
    }
  }
  [self setNextAttributedMessageToPresent:attributedMessage];
}

- (void)setNextAttributedMessageToPresent:(NSAttributedString *)message {
  [nextAttributedMessageToPresent_ autorelease];
  nextAttributedMessageToPresent_ = [message copy];
}

- (void)setNextImageToPresent:(NSImage *)image {
  [nextImageToPresent_ autorelease];
  nextImageToPresent_ = [image retain];
}

- (void)presentMessageView:(NSView*)messageView
              withDuration:(NSTimeInterval)duration {
  NSRect proposedFrame = [messageView frame];
  if ([messages_ count]) {
    // There are existing messages still being shown.  Append this one below.
    NSRect currentFrame = [self frame];
    NSRect newFrame = currentFrame;
    // TODO(mrossetti): Iterate through existing messages and shrink window
    // if some really wide message has already gone away.
    CGFloat proposedWidth = NSWidth(proposedFrame);
    CGFloat currentWidth = NSWidth(currentFrame);
    CGFloat deltaX = (proposedWidth - currentWidth) / 2.0;
    if (deltaX > 0.0) {
      // We've got to widen the window.
      newFrame.size.width = proposedWidth;
      newFrame.origin.x -= deltaX;
      proposedFrame.origin = NSZeroPoint;
    } else {
      // Adjust the new view's origin.
      proposedFrame.origin = NSMakePoint(-deltaX, 0.0);
    }
    [messageView setFrameOrigin:proposedFrame.origin];

    // Grow the window downward.
    CGFloat addedHeight = NSHeight(proposedFrame) + kIntermessageGap;
    newFrame.size.height += addedHeight;
    newFrame.origin.y -= addedHeight;
    // TODO(mrossetti): Must force on screen.
    [self setFrame:newFrame display:YES];
    NSView *contentView = [self contentView];
    [messageView setAlphaValue:0];
    [contentView addSubview:messageView];
    [self animateView:messageView withEffect:NSViewAnimationFadeInEffect];
  } else {
    // This is the only message being presented so we use its frame
    // for the window position.
    [messageView setFrameOrigin:NSZeroPoint];
    NSView *contentView = [self contentView];
    [self setFrame:proposedFrame display:YES];
    [contentView addSubview:messageView];
    [self makeKeyAndOrderFront:self];
  }

  // Set a timer to hide and remove this message.
  [messages_ addObject:messageView];
  NSTimer *messageTimer
    = [NSTimer scheduledTimerWithTimeInterval:duration 
                                       target:self 
                                     selector:@selector(messageExpired:) 
                                     userInfo:messageView 
                                      repeats:NO];
  [timers_ addObject:messageTimer];
}

- (void)messageExpired:(NSTimer *)timer {
  NSView *messageView = [timer userInfo];
  [messages_ removeObject:messageView];
  [timers_ removeObject:timer];
  // Fade out the view if there are others which haven't expired, otherwise
  // hide the window.
  if ([timers_ count]) {
    [self animateView:messageView withEffect:NSViewAnimationFadeOutEffect];
  } else {
    [self orderOut:self];
  }
  [messageView removeFromSuperview];
}

- (void)anchorWindowWillClose:(NSNotification *)notification {
  [self setAnchorWindow:nil];
}

- (NSRect)proposedMessageFrame {
  NSRect proposedFrame = NSZeroRect;
  NSWindow *anchorWindow = [self anchorWindow];
  if (!anchorWindow && ![self ignoreKeyWindow]) {
    anchorWindow = [NSApp keyWindow];
  }
  if (anchorWindow) {
    proposedFrame = [anchorWindow frame];
    CGFloat windowWidth = proposedFrame.size.width;
    proposedFrame.size.width *= kAnchorWidthPercentage;
    if (proposedFrame.size.width < kMinimumAnchorWidth) {
      proposedFrame.size.width = kMinimumAnchorWidth;
    }
    // Make sure anchorWidth is less than screen width.
    NSScreen *windowScreen = [anchorWindow screen];
    NSRect screenFrame = [windowScreen frame];
    CGFloat screenWidth = NSWidth(screenFrame) * kScreenWidthPercentage;
    if (proposedFrame.size.width > screenWidth) {
      proposedFrame.size.width = screenWidth;
    }
    // Adjust the anchorFrame horizontal position.
    CGFloat deltaX = (proposedFrame.size.width - windowWidth) / 2.0;
    proposedFrame.origin.x -= deltaX;
    // Assume full screen height is available.
    proposedFrame.size.height = NSHeight(screenFrame);
    proposedFrame.origin.y = 0.0;
  } else {
    // Default to the main screen allowing up to 90% of the width of the screen.
    proposedFrame = [[NSScreen mainScreen] frame];
    CGFloat screenWidth = NSWidth(proposedFrame);
    proposedFrame.size.width = screenWidth * kScreenWidthPercentage;
    proposedFrame.origin.x = (screenWidth - proposedFrame.size.width) / 2.0;
  }
  return proposedFrame;
}

- (NSView *)makeContainerViewWithFrame:(NSRect)frame {
  QSBUserMessageBackgroundView *containerView 
    = [[[QSBUserMessageBackgroundView alloc] initWithFrame:frame] 
       autorelease];
  // We want this view to horizontally center in its window and to maintain
  // a constant position relative to the top of the window.
  NSUInteger resizingMask
    = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin;
  [containerView setAutoresizingMask:resizingMask];
  return containerView;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  for (NSTimer *timer in timers_) {
    [timer invalidate];
  }
}

// TODO(mrossetti): Create a GTMNSScreen utility for performing the following
// and make it generally available to all clients of GTM.
- (NSRect)fullyExposedFrameForFrame:(NSRect)proposedFrame
                     respectingDock:(BOOL)respectingDock
                           onScreen:(NSScreen *)screen {
  // If we can't find a screen for this window, use the main one.
  if (!screen) {
    screen = [NSScreen mainScreen];
  }
  NSRect screenFrame = respectingDock ? [screen visibleFrame] : [screen frame];
  if (!NSContainsRect(screenFrame, proposedFrame)) {
    if (proposedFrame.origin.y < screenFrame.origin.y) {
      proposedFrame.origin.y = screenFrame.origin.y;
    }
    if (proposedFrame.origin.x + NSWidth(proposedFrame) > 
        screenFrame.origin.x + NSWidth(screenFrame)){
      proposedFrame.origin.x
        = screenFrame.origin.x + NSWidth(screenFrame) - NSWidth(proposedFrame);
    }    
    if (proposedFrame.origin.x < screenFrame.origin.x) {
      proposedFrame.origin.x = screenFrame.origin.x;
    }
    if (proposedFrame.origin.y + NSHeight(proposedFrame) > 
        screenFrame.origin.y + NSHeight(screenFrame)){
      proposedFrame.origin.y
        = screenFrame.origin.y + NSHeight(screenFrame) - NSHeight(proposedFrame);
    }
  }
  return proposedFrame;
}

- (void)keyDown:(NSEvent *)theEvent {
  [self close];
}

- (void)resignKeyWindow {
  [super resignKeyWindow];
  if ([self isVisible]) {
    [self close];
  }
}

- (void)makeKeyAndOrderFront:(id)sender {
  [super makeKeyAndOrderFront:sender];
  [self animateView:nil withEffect:NSViewAnimationFadeInEffect];
}

- (void)orderFront:(id)sender {
  [super orderFront:sender];
  [self animateView:nil withEffect:NSViewAnimationFadeInEffect];
}

- (void)orderOut:(id)sender {
  [self animateView:nil withEffect:NSViewAnimationFadeOutEffect];
  [super orderOut:sender];
}  

- (void)animateView:(NSView *)view withEffect:(NSString*)effect {
  id target = view;
  if (!target) {
    target = self;
  }
  NSDictionary *fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
                          target, NSViewAnimationTargetKey,
                          effect, NSViewAnimationEffectKey,
                          nil];
  NSArray *animation = [NSArray arrayWithObject:fadeIn];
  NSViewAnimation *viewAnim 
    = [[[NSViewAnimation alloc] initWithViewAnimations:animation] autorelease];
  [viewAnim setDuration:kUserMessageFadeTime];
  [viewAnim setAnimationBlockingMode:NSAnimationBlocking];
  [viewAnim startAnimation];
}

@end

@implementation QSBUserMessageBackgroundView

GTM_METHOD_CHECK(NSBezierPath, gtm_appendBezierPathWithRoundRect:cornerRadius:);

- (BOOL)isOpaque {
  return NO;
}

- (void)drawRect:(NSRect)rect {
  rect = [self bounds];
  NSBezierPath *roundedPath = [NSBezierPath bezierPath];
  CGFloat minRadius = MIN(NSWidth(rect), NSHeight(rect)) * 0.5f;
  [roundedPath gtm_appendBezierPathWithRoundRect:rect 
                                     cornerRadius:MIN(minRadius, 16.0)];
  [roundedPath addClip];  
  [[NSColor colorWithDeviceWhite:0 alpha:kTwoThirdsAlpha] set];
  NSRectFill(rect);
}

@end

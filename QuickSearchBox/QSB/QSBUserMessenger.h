//
//  QSBUserMessenger.h
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

#import <Cocoa/Cocoa.h>
#import "GTMDefines.h"


// QSBUserMessenger presents an image and/or some text in a panel
// window.  This is intended to give the user some confirmation of an
// action being performed that otherwise would not manifest completion
// or failure.  The default behavior presents this panel horizontally
// centered over the application's key window, near the top for a short
// period of time.  If additional messages are set for this window
// before the previously presented messages have expired then the new
// message is presented below the most recent message, expanding
// the window vertically.  Many or long simultaneous messages may
// result in more recent messages being shown off-screen -- not good.
// TODO(mrossetti): Manage messages that would appear off-screen as a
// result of a message 'storm'.
//
@interface QSBUserMessenger : NSPanel {
 @private
  __weak NSWindow *anchorWindow_;
  NSMutableArray *messages_;  // Array of message views being presented.
  NSMutableArray *timers_;  // Array of message timers not yet expired.
  // If NO then in the absence of a anchor window present messages over
  // the application's key window; if YES present messages over the
  // screen if there is no anchor window.
  BOOL ignoreKeyWindow_;
  // Number of seconds a message is to be presented.  The default is 3.0
  // seconds.  Individual messages can temporarily override this time.
  NSTimeInterval presentationTime_;
  // Length of fade-in time for new message in seconds.  The default
  // is 0.333 seconds.
  NSTimeInterval fadeInTime_;  
  // Length of fade-out time for expired message in seconds.  The default
  // is 0.333 seconds.
  NSTimeInterval fadeOutTime_;
  // Distance from top of anchor window to first message.
  CGFloat anchorVerticalOffset_;
  CGFloat intermessageGap_;  // Gap between messages.
  // The maximum width of a message window as a percentage of the anchor
  // window width.  The default is 130%, expressed as 1.3f.
  CGFloat anchorWidthPercentage_;
  // Minimum effective anchor window size useful in cases of really
  // narrow anchor windows.  The default is 500 px.
  CGFloat minimumAnchorWidth_;
  // The maximum width of the message window as a percentage of the main
  // screen when no anchor window has been specified.  The default is 90%
  // expressed as 0.9f.
  CGFloat screenWidthPercentage_;
  
  // Message staging
  NSAttributedString *nextAttributedMessageToPresent_;
  NSImage *nextImageToPresent_;
  NSTimeInterval nextMessagePresentationTime_;
}

@property (nonatomic, assign) BOOL ignoreKeyWindow;
@property (nonatomic, assign) NSTimeInterval presentationTime;
@property (nonatomic, assign) NSTimeInterval fadeInTime;  
@property (nonatomic, assign) NSTimeInterval fadeOutTime;
@property (nonatomic, assign) CGFloat anchorVerticalOffset;
@property (nonatomic, assign) CGFloat intermessageGap;
@property (nonatomic, assign) CGFloat anchorWidthPercentage;
@property (nonatomic, assign) CGFloat minimumAnchorWidth;
@property (nonatomic, assign) CGFloat screenWidthPercentage;

// Initialize so that we present over |anchorWindow|.  If |anchorWindow| is
// nil then we present over -[NSApp keyWindow].  Designated initializer.
- (id)initWithAnchorWindow:(NSWindow *)anchorWindow;

// Message presentation methods.

// Present a string in bold 20 pt. system font.
- (void)showPlainMessage:(NSString *)summary;

// Present an attributed string.  This string may be multi-line and have
// varying font and paragraph attributes.
- (void)showAttributedMessage:(NSAttributedString *)summary
                        image:(NSImage *)image;

// Present a message with the first line being the |summary| presented in
// bold 20 pt. bolf system font, the second line being the |description| 
// presented in 12 pt. systen font, with an image on the left.  At least
// one of |summary|, |description|, and |image| must not be nil otherwise
// nothing is presented. The image is constrained to 128x128 px.
- (void)showPlainMessage:(NSString *)summary
             description:(NSString *)description
                   image:(NSImage *)image;

// Present just an image with the image constrained to 128x128 px.
- (void)showImage:(NSImage *)image;

// Override the presentation time for the next message to be presented.
- (void)setNextMessagePresentationTime:(NSTimeInterval)duration;

// Set/get the anchor window.
- (void)setAnchorWindow:(NSWindow *)anchorWindow;
- (NSWindow *)anchorWindow;

@end

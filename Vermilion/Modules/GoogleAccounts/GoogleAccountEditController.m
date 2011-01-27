//
//  GoogleAccountEditController.m
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

#import "GoogleAccountEditController.h"
#import "GoogleAccount.h"

@implementation GoogleAccountEditController

@synthesize captchaImage = captchaImage_;
@synthesize captchaText = captchaText_;

- (void)dealloc {
  [captchaImage_ release];
  [captchaText_ release];
  [super dealloc];
}

- (void)awakeFromNib {
  [super awakeFromNib];

  GoogleAccount *account = (GoogleAccount *)[self account];
  NSWindow *window = [self window];
  NSRect windowFrame = [window frame];
  CGFloat deltaHeight = 0.0;
  BOOL adjustWindow = NO;
  
  // Show the "Is a Google Apps account" text field.
  if ([account isKindOfClass:[GoogleAppsAccount class]]) {
    // Adjust the window height by enough to accommodate the button height
    // and the interspace gap (8.0).
    deltaHeight = NSHeight([googleAppsTextField_ frame]) + 8.0;
    [googleAppsTextField_ setHidden:NO];
    adjustWindow = YES;
  }
  
  // The captcha must be collapsed prior to first presentation.
  if (![captchaContainerView_ isHidden]) {
    CGFloat containerHeight = NSHeight([captchaContainerView_ frame]);
    deltaHeight -= containerHeight;
    adjustWindow = YES;
    [captchaContainerView_ setHidden:YES];
    [captchaTextField_ setEnabled:NO];
    [self setCaptchaText:@""];
    [self setCaptchaImage:nil];
    [account setCaptchaImage:nil];
  }
  
  if (adjustWindow) {
    windowFrame.origin.y -= deltaHeight;
    windowFrame.size.height += deltaHeight;
    [window setFrame:windowFrame display:YES];
  }
}

- (IBAction)acceptEditAccountSheet:(id)sender {
  // If we're showing a captcha then we need to pass along the captcha text
  // to the account for authentication.
  if ([self captchaImage]) {
    NSString *captchaText = [self captchaText];
    GoogleAccount *account = (GoogleAccount *)[self account];
    [account setCaptchaText:captchaText];
  }
  [super acceptEditAccountSheet:sender];
}

- (BOOL)canGiveUserAnotherTry {
  BOOL canGiveUserAnotherTry = NO;
  // If the last authentication attempt resulted in a captcha request then
  // we want to expand the account setup sheet and show the captcha.
  GoogleAccount *account = (GoogleAccount *)[self account];
  NSImage *captchaImage = [account captchaImage];
  BOOL resizeNeeded
    = ([self captchaImage] == nil) ? YES : NO;  // leftover captcha?
  NSWindow *window = [self window];
  if (captchaImage) {
    // Install the captcha image, enable the captcha text field,
    // expand the window to show the captcha.
    [captchaTextField_ setEnabled:YES];
    [self setCaptchaImage:captchaImage];
    
    if (resizeNeeded) {
      CGFloat containerHeight = NSHeight([captchaContainerView_ frame]);
      NSRect windowFrame = [window frame];
      windowFrame.origin.y -= containerHeight;
      windowFrame.size.height += containerHeight;
      [[window animator] setFrame:windowFrame display:YES];
    }
    
    [[captchaContainerView_ animator] setHidden:NO];
    [window makeFirstResponder:captchaTextField_];
    canGiveUserAnotherTry = YES;
    [account setCaptchaImage:nil];  // We've used it all up.
  } else {
    [window makeFirstResponder:passwordField_];
  }
  return canGiveUserAnotherTry;
}

- (IBAction)openGoogleHomePage:(id)sender {
  [GoogleAccount openGoogleHomePage];
}

@end

//
//  GoogleAccountSetUpViewController.m
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

#import "GoogleAccountSetUpViewController.h"
#import "GoogleAccount.h"


@interface GoogleAccountSetUpViewController ()

@property (nonatomic, getter=isGoogleAppsCheckboxShowing)
  BOOL googleAppsCheckboxShowing;
@property (nonatomic, getter=isWindowSizesDetermined) BOOL windowSizesDetermined;

// Pre-determine the various window heights.
- (void)determineWindowSizes;

// Determine height of window based on checkbox and captcha presentation.
- (CGFloat)windowHeightWithCheckboxShowing:(BOOL)googleAppsCheckboxShowing
                            captchaShowing:(BOOL)captchaShowing;
@end


@implementation GoogleAccountSetUpViewController

@synthesize captchaImage = captchaImage_;
@synthesize captchaText = captchaText_;
@synthesize googleAppsAccount = googleAppsAccount_;
@synthesize googleAppsCheckboxShowing = googleAppsCheckboxShowing_;
@synthesize windowSizesDetermined = windowSizesDetermined_;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[GoogleAccount class]];
  return self;
}

- (void)dealloc {
  [captchaImage_ release];
  [captchaText_ release];
  [super dealloc];
}

- (IBAction)openGoogleHomePage:(id)sender {
  [GoogleAccount openGoogleHomePage];
}

- (IBAction)acceptSetupAccountSheet:(id)sender {
  BOOL isAppsAccount = [self isGoogleAppsAccount];
  
  if (!isAppsAccount) {
    // Special test for Google corporate accounts.
    NSString *accountName = [self accountName];
    NSRange atRange = [accountName rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
      NSString *domain = [accountName substringFromIndex:atRange.location];
      isAppsAccount = [GoogleAccount isMatchToGoogleDomain:domain];
    }
  }
  Class accountClass = (isAppsAccount)
                       ? [GoogleAppsAccount class]
                       : [GoogleAccount class];
  [self setAccountTypeClass:accountClass];
  [super acceptSetupAccountSheet:sender];
}


- (BOOL)canGiveUserAnotherTryOffWindow:(NSWindow *)window {
  BOOL canGiveUserAnotherTry = NO;
  // If the last authentication attempt resulted in a captcha request then
  // we want to expand the account setup sheet and show the captcha.
  GoogleAccount *account = (GoogleAccount *)[self account];
  NSImage *captchaImage = [account captchaImage];
  BOOL resizeNeeded = ([self captchaImage] == nil);  // leftover captcha?
  if (captchaImage) {
    // Install the captcha image, enable the captcha text field,
    // expand the window to show the captcha.
    [captchaTextField_ setEnabled:YES];
    [self setCaptchaImage:captchaImage];

    if (resizeNeeded) {
      BOOL googleAppsCheckboxShowing = [self isGoogleAppsCheckboxShowing];
      CGFloat newHeight
        = [self windowHeightWithCheckboxShowing:googleAppsCheckboxShowing
                                 captchaShowing:YES];
      NSRect windowFrame = [window frame];
      CGFloat deltaHeight = newHeight - NSHeight(windowFrame);
      windowFrame.size.height = newHeight;
      windowFrame.origin.y -= deltaHeight;
      [[window animator] setFrame:windowFrame display:YES];
    }
    
    [[captchaContainerView_ animator] setHidden:NO];
    [window makeFirstResponder:captchaTextField_];
    canGiveUserAnotherTry = YES;
    [account setCaptchaImage:nil];  // We've used it all up.
  } else if (resizeNeeded) {
    BOOL googleAppsCheckboxShowing = [self isGoogleAppsCheckboxShowing];
    CGFloat newHeight
      = [self windowHeightWithCheckboxShowing:googleAppsCheckboxShowing
                               captchaShowing:NO];
    NSRect windowFrame = [window frame];
    CGFloat deltaHeight = newHeight - NSHeight(windowFrame);
    windowFrame.size.height = newHeight;
    windowFrame.origin.y -= deltaHeight;
    [[window animator] setFrame:windowFrame display:YES];
  }
  return canGiveUserAnotherTry;
}

- (void)setGoogleAppsAccount:(BOOL)googleAppsAccount {
  if (googleAppsAccount != googleAppsAccount_) {
    googleAppsAccount_ = googleAppsAccount;
    // Create an account of the appropriate type, hosted or non-hosted.
    NSString *userName = [self accountName];
    Class accountClass
      = (googleAppsAccount) ? [GoogleAppsAccount class] : [GoogleAccount class];
    HGSSimpleAccount *account
      = [[[accountClass alloc] initWithName:userName] autorelease];
    
    [self setAccount:account];
  }
}

- (void)setAccount:(HGSSimpleAccount *)account {
  // Remember the old captchaToken.
  GoogleAccount *oldAccount = (GoogleAccount *)[self account];
  NSString *oldToken = [oldAccount captchaToken];
  NSString *captchaToken
    = (oldToken) ? [NSString stringWithString:oldToken] : nil;
  [super setAccount:account];
  // If we're showing a captcha then we need to pass along the captcha text
  // to the account for authentication.
  if (captchaToken) {
    GoogleAccount *newAccount = (GoogleAccount *)account;
    NSString *captchaText = [self captchaText];
    [newAccount setCaptchaText:captchaText];
    [newAccount setCaptchaToken:captchaToken];
  }
  [self setCaptchaImage:nil];
}

- (void)setAccountName:(NSString *)userName {
  [super setAccountName:userName];
  
  BOOL showCheckbox = NO;
  if (userName) {
    NSString *gmailDomain = HGSLocalizedString(@"@gmail.com", 
                                               @"The gmail domain extension.");
    NSRange atRange = [userName rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
      NSString *domainString = [userName substringFromIndex:atRange.location];
      NSUInteger gmailDomainLength = [gmailDomain length];
      NSUInteger domainLength = [domainString length];
      if (domainLength) {
        showCheckbox = YES;
        if (domainLength <= gmailDomainLength) {
          NSRange domainRange = NSMakeRange(0, domainLength);
          NSComparisonResult gmailResult
            = [gmailDomain compare:domainString
                           options:NSCaseInsensitiveSearch
                             range:domainRange];
          showCheckbox = (gmailResult != NSOrderedSame);
        }
        // If it's not a match to gmail.com then see if it is a
        // Google corporate domain match.
        if (showCheckbox) {
          showCheckbox
            = ![GoogleAccount isPartialMatchToGoogleDomain:domainString];
        }
      }
    }
  }
  if (showCheckbox != [self isGoogleAppsCheckboxShowing]) {
    // Cautionary note: The reason we use isGoogleAppsCheckboxShowing to
    // control the hiding and showing of the checkbox is because the
    // -[NSControl hidden] accessor is not a reliable indicator due
    // to our use of animations--the control's isHidden does not get
    // updated until the animation has completed.
    [self setGoogleAppsCheckboxShowing:showCheckbox];
    [googleAppsCheckbox_ setEnabled:showCheckbox];
    [[googleAppsCheckbox_ animator] setHidden:!showCheckbox];
    if (!showCheckbox) {
      [self setGoogleAppsAccount:NO];
    }

    BOOL captchaShowing = [self captchaImage] != nil;
    CGFloat newHeight = [self windowHeightWithCheckboxShowing:showCheckbox
                                               captchaShowing:captchaShowing];
    NSWindow *window = [captchaContainerView_ window];
    NSRect windowFrame = [window frame];
    CGFloat deltaHeight = newHeight - NSHeight(windowFrame);
    windowFrame.size.height = newHeight;
    windowFrame.origin.y -= deltaHeight;
    [[window animator] setFrame:windowFrame display:YES];
  }
}

#pragma mark GoogleAccountSetUpViewController Private Methods

- (void)loadView {
  [super loadView];
  
  // Hide the captcha section.
  [captchaContainerView_ setHidden:YES];
  CGFloat containerHeight = NSHeight([captchaContainerView_ frame]);
  NSView *view = [self view];  // Resize
  NSSize frameSize = [view frame].size;
  frameSize.height -= containerHeight;
  
  // Hide the Google Apps checkbox.
  CGFloat checkboxHeight = NSHeight([googleAppsCheckbox_ frame]) + 4.0;
  [self setGoogleAppsCheckboxShowing:NO];
  [googleAppsCheckbox_ setHidden:YES];
  [googleAppsCheckbox_ setEnabled:NO];
  frameSize.height -= checkboxHeight;
  
  [view setFrameSize:frameSize];
  
  [captchaTextField_ setEnabled:NO];
  [self setCaptchaText:@""];
  [self setCaptchaImage:nil];
}

- (void)determineWindowSizes {
  // This assumes that the window has been resized to fit the view and the
  // view is not showing the checkbox of captcha.
  NSWindow *parentWindow = [captchaContainerView_ window];
  CGFloat checkboxHeight = NSHeight([googleAppsCheckbox_ frame]) + 4.0;;
  CGFloat captchaHeight = NSHeight([captchaContainerView_ frame]);
  
  windowHeightNoCheckboxNoCaptcha_ = NSHeight([parentWindow frame]);
  windowHeightNoCheckboxCaptcha_
    = windowHeightNoCheckboxNoCaptcha_ + captchaHeight;
  windowHeightCheckboxNoCaptcha_
    = windowHeightNoCheckboxNoCaptcha_ + checkboxHeight;
  windowHeightCheckboxCaptcha_
    = windowHeightNoCheckboxCaptcha_ + checkboxHeight;
  [self setWindowSizesDetermined:YES];
}

- (CGFloat)windowHeightWithCheckboxShowing:(BOOL)googleAppsCheckboxShowing
                            captchaShowing:(BOOL)captchaShowing {
  if (![self isWindowSizesDetermined]) {
    [self determineWindowSizes];
  }
  CGFloat newHeight = 0.0;
  if (googleAppsCheckboxShowing) {
    newHeight = (captchaShowing)
                ? windowHeightCheckboxCaptcha_
                : windowHeightCheckboxNoCaptcha_;
  } else {
    newHeight = (captchaShowing)
                ? windowHeightNoCheckboxCaptcha_
                : windowHeightNoCheckboxNoCaptcha_;
  }
  return newHeight;
}

- (void)setCaptchaImage:(NSImage *)captcha {
  if (captcha != captchaImage_) {
    BOOL didShow = (captchaImage_ != nil);
    BOOL willShow =  (captcha != nil);
    [captchaImage_ release];
    captchaImage_ = [captcha retain];
    // Show/hide the captcha image area.
    if (didShow != willShow) {
      BOOL googleAppsCheckboxShowing = [self isGoogleAppsCheckboxShowing];
      CGFloat newHeight
        = [self windowHeightWithCheckboxShowing:googleAppsCheckboxShowing
                                 captchaShowing:willShow];
      NSWindow *window = [captchaContainerView_ window];
      NSRect windowFrame = [window frame];
      CGFloat deltaHeight = newHeight - NSHeight(windowFrame);
      windowFrame.size.height = newHeight;
      windowFrame.origin.y -= deltaHeight;
      
      [captchaTextField_ setEnabled:willShow];
      [self setCaptchaText:nil];
      [[window animator] setFrame:windowFrame display:YES];
      if (willShow) {
        [[captchaContainerView_ animator] setHidden:NO];
      } else {
        [window makeFirstResponder:userNameField_];
        [captchaContainerView_ setHidden:YES];
      }
    }
  }
}

@end

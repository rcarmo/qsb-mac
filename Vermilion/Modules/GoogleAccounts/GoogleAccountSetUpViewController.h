//
//  GoogleAccountSetUpViewController.h
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

/*!
  @header
  @discussion
*/

#import "QSBSetUpSimpleAccountViewController.h"

/*!
 A controller which manages a view used to specify a Google account
 name and password during the setup process.

 NOTE: This class exposed here purely to satisfy Interface Builder.
*/
@interface GoogleAccountSetUpViewController : QSBSetUpSimpleAccountViewController {
 @private
  IBOutlet NSView *captchaContainerView_;
  IBOutlet NSTextField *captchaTextField_;
  IBOutlet NSTextField *userNameField_;
  IBOutlet NSButton *googleAppsCheckbox_;
  
  NSImage *captchaImage_;
  NSString *captchaText_;
  BOOL googleAppsAccount_;
  // Have to use |googleAppsCheckboxShowing| because we animate showing of
  // the checkbox and the 'hidden' atttribute of the checkbox field is not
  // reliable until the animation has completed.
  BOOL googleAppsCheckboxShowing_;
  BOOL windowSizesDetermined_;  // NO until we've calculated window sizes.
  // Precalculated window heights to accommodate animations.  A delta cannot
  // be calculated as needed because the window might be in the middle of
  // an animation and thus its height not yet finalized.
  CGFloat windowHeightNoCheckboxNoCaptcha_;
  CGFloat windowHeightCheckboxNoCaptcha_;
  CGFloat windowHeightNoCheckboxCaptcha_;
  CGFloat windowHeightCheckboxCaptcha_;
}

/*! The captcha image presented to the user. */
@property (nonatomic, retain) NSImage *captchaImage;

/*! The captcha text typed by the user. */
@property (nonatomic, copy) NSString *captchaText;

/*! YES for a Google Apps account. */
@property (nonatomic, getter=isGoogleAppsAccount) BOOL googleAppsAccount;

/*! Open google.com in the user's preferred browser. */
- (IBAction)openGoogleHomePage:(id)sender;

@end

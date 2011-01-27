//
//  GoogleAccount.h
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

#import <Vermilion/Vermilion.h>

// NOTE: This class exposed here purely to satisfy Interface Builder.

// A class which manages a Google account.
//
@interface GoogleAccount : HGSSimpleAccount {
 @private
  // The presence of a captchaImage_ indicates that one such should be shown
  // to the user and the resulting captchaText be included in the
  // authentication reply.  The consumer of this image (i.e. the UI) should
  // clear the captcha image and text prior to the next authentication attempt.
  NSImage *captchaImage_;  // The captcha image presented to the user.
  NSString *captchaText_;  // The user's response.
  NSString *captchaToken_;  // Captcha token.
  // Set by and only useful within authentication.
  BOOL authCompleted_;
  // Set by authentication handler to indicate success or not.
  BOOL authSucceeded_;
  // Set to YES of the account failed to authenticate as HOSTED but
  // succeeded as HOSTED_OR_GOOGLE during setup account.  This flag
  // is saved in the account configuration.
  BOOL forceNonHosted_;
}

@property (nonatomic, retain) NSImage *captchaImage;
@property (nonatomic, copy) NSString *captchaText;
@property (nonatomic, copy) NSString *captchaToken;

// Open google.com in the user's preferred browser.
+ (BOOL)openGoogleHomePage;

// Determine if the supplied domain is a full match to a Google corp domain.
+ (BOOL)isMatchToGoogleDomain:(NSString *)domain;

// Determine if the supplied domain is a partial match to a Google corp domain.
+ (BOOL)isPartialMatchToGoogleDomain:(NSString *)domain;

@end


// A class which manages a Google Apps account.
//
@interface GoogleAppsAccount : GoogleAccount
@end

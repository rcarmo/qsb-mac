//
//  QSBSimpleAccountSetUpViewController.h
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
 @header A view controller useful for editing a 'simple' account.
 @discussion Provides a base class for a view controller used
 by account type extensions for setting the credentials for a
 'simple' account, that is one that has an account name and a
 password.
 */

#import <QSBPluginUI/QSBSetUpAccountViewController.h>

/*!
 A controller which manages a view used to specify a new account's
 name and password during the setup process.  
*/
@interface QSBSetUpSimpleAccountViewController : QSBSetUpAccountViewController {
 @private
  NSString *accountName_;
  NSString *accountPassword_;
}

/*! The user name/account name for the account being set up. */
@property (nonatomic, copy) NSString *accountName;

/*! The password for the account being set up. */
@property (nonatomic, copy) NSString *accountPassword;

/*! Called when the user presses 'OK'. */
- (IBAction)acceptSetupAccountSheet:(id)sender;

/*!
 When authentication fails, this is called to see if remediation is possible.
 Pass along the window off of which we can hang an alert, if so desired.
 See description of -[HGSSimpleAccountEditController canGiveUserAnotherTry]
 for an explanation.
*/
- (BOOL)canGiveUserAnotherTryOffWindow:(NSWindow *)window;

/*!
 Used to present an alert message to the user mentioning the account name.
*/
- (void)presentMessageOffWindow:(NSWindow *)parentWindow
                    withSummary:(NSString *)summary
              explanationFormat:(NSString *)format
                     alertStyle:(NSAlertStyle)style;
@end

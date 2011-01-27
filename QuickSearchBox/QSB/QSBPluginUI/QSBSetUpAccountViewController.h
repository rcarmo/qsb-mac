//
//  QSBSetUpAccountViewController.h
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

/*!
 @header A view controller useful for setting up an account.
 @discussion Provides a base class for a view controller used
 when adding a new account of a certain account type via the 
 QSB preferences window.
 */

#import <Cocoa/Cocoa.h>

@class HGSAccount;

/*!
  A controller which manages a view used to set up a new account.
  
  If you provide a plugin that adds an account type which the user can
  set up and edit then you should also supply a customization of this
  view controller class (and a companion nib) used for specifying the
  credentials for an account of this account type.  If the account
  type you are adding follows the most common pattern of requiring
  a user/account name and a password then consider basing your
  account edit controller on QSBSetUpSimpleAccountWindowController.

  The view associated with this controller gets injected into a window
  provided by the user interface of the client.
*/

@interface QSBSetUpAccountViewController : NSViewController {
 @private
  HGSAccount *account_;  // The account, once created.
  __weak NSWindow *parentWindow_;
  Class accountTypeClass_;
}

/*! The account being edited. */
@property (nonatomic, retain) HGSAccount *account;

/*!   The window off of which to hang any alerts. */
@property (nonatomic, assign) NSWindow *parentWindow;

/*! The Class of the account being set up. */
@property (nonatomic, assign) Class accountTypeClass;

/*! Designated initializer. */
- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
     accountTypeClass:(Class)accountTypeClass;

/*!
  Called when user presses 'Cancel'.
*/
- (IBAction)cancelSetupAccountSheet:(id)sender;

/*!
 Used to present an alert message to the user mentioning.
 */
- (void)presentMessageOffWindow:(NSWindow *)parentWindow
                    withSummary:(NSString *)summary
                    explanation:(NSString *)explanation
                     alertStyle:(NSAlertStyle)style;

@end

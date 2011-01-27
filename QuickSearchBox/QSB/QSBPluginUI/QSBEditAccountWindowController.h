//
//  QSBEditAccountWindowController.h
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
 @header A window controller useful for editing an account.
 @discussion Provides a base class for a window controller used
 by account type extensions for editing the credentials for the
 account.
*/

#import <Cocoa/Cocoa.h>

@class HGSAccount;

/*!
  A controller which manages a window used to edit an account.
  
  If you provide a plugin that adds an account type which the user can
  set up and edit then you should also supply a customization of this
  window controller class (and a companion nib) used for editing a
  previously set up account of the account type.  If the account
  type you are adding follows the most common pattern of requiring
  a user/account name and a password then consider basing your
  account edit controller on QSBEditSimpleAccountWindowController.
*/
@interface QSBEditAccountWindowController : NSWindowController {
 @private
  HGSAccount *account_;
}

/*! The account being edited. */
@property (nonatomic, retain, readonly) HGSAccount *account;

/*! Designated initializer. */
- (id)initWithWindowNibName:(NSString *)windowNibName
                    account:(HGSAccount *)account;

/*!
  Called when the user presses 'OK'.  The default implementation dismisses
  the edit window and marks the account as authenticated.  Your subclass
  would usually override and not call up to this implementation.

  This implementation provided by QSBEditSimpleAccountWindowController,
  which derives from this controller class, authenticates the password
  and, if authenticated, dismissses the edit window and marks the account
  as authenticated.  Otherwise it checks to see if the user can be given
  another attempt and, if not, presents an alert.
*/
- (IBAction)acceptEditAccountSheet:(id)sender;

/*!
  Called when user presses 'Cancel'.  The default implementation dismisses
  the edit window and is usually the desired behavior.
*/
- (IBAction)cancelEditAccountSheet:(id)sender;

@end

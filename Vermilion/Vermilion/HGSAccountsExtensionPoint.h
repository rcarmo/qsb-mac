//
//  HGSAccountsExtensionPoint.h
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
 @header Accounts Extension Point
 
 The accounts extension point manages all known account types, prototypical
 account extensions and active accounts.
 */

#import <Vermilion/HGSExtensionPoint.h>

/*!
  An extension point that maintains an inventory of all accounts
  available to sources and actions as well as a list of all
  registered account types.
 
  NOTE: Not thread-safe.
*/
@interface HGSAccountsExtensionPoint : HGSExtensionPoint

/*!
  Register all accounts contained in the array of dictionaries as while
  restoring from preferences.  This method will not send notification of
  newly added accounts.
*/
- (void)addAccountsFromArray:(NSArray *)accountsArray;

/*! Returns a dictionary describing all registered accounts. */
- (NSArray *)accountsAsArray;

/*!
  A convenience method that returns an array of all acccounts
  with a given type.
*/
- (NSArray *)accountsForType:(NSString *)type;

@end

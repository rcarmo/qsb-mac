//
//  HGSActionOperation.h
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
 @discussion HGSActionOperation
*/

#import <Foundation/Foundation.h>

@class HGSAction;
@class HGSResultArray;

/*!
 HGSActionOperation represents an action and the arguments to pass to that
 action so that it can be performed.
*/
@interface HGSActionOperation : NSObject<NSCopying, NSMutableCopying> {
 @private
  HGSAction * action_;
  NSMutableDictionary *arguments_;
}

/*!
 The action that the operation will perform.
*/
@property (readonly, retain) HGSAction *action;

/*!
 Create an action with the given action and arguments.
 Designated initializer.
 @param action The action to perform.
 @param args The arguments to pass to the action.
 @result An HGSActionOperation.
*/
- (id)initWithAction:(HGSAction *)action arguments:(NSDictionary *)args;

/*!
 Perform the action with the current arguments.
*/
- (void)performAction;

/*!
 Verifies that an action operation has all the required components for it to
 be able to perform.
 @result Returns YES if the operation has an action, and has values for all
         of its required arguments.
*/
- (BOOL)isValid;

/*!
 Returns an argument for a given key if that argument has been set.
 @param key The key for the argument you want the value for.
            The key for a given argument is the value set for
            kHGSActionArgumentIdentifierKey.
 @result The argument. Returns nil if there is no argument set for the key.
*/
- (HGSResultArray*)argumentForKey:(NSString *)key;

@end

/*!
 An action operation that can be modified.
*/
@interface HGSMutableActionOperation : HGSActionOperation

/*!
 Set an argument for a given key to arg. If that argument has already been set
 it will be replaced by arg. If arg is nil, the argument will be removed.
 @param arg The value to set the argument identified by key to.
 @param key The key for the argument you want the value for.
            The key for a given argument is the value set for
            kHGSActionArgumentIdentifierKey.
*/
- (void)setArgument:(HGSResultArray*)arg forKey:(NSString *)key;

/*!
 Reset an action operation back to a default state. Remove all arguments, and
 set the action to nil.
*/
- (void)reset;

/*!
 Set the action that the operation will perform.
*/
- (void)setAction:(HGSAction *)action;
@end

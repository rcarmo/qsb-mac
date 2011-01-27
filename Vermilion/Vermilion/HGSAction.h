//
//  HGSAction.h
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
 @discussion HGSAction
*/

#import <Vermilion/HGSExtension.h>

@class HGSTypeFilter;
@class HGSResult;
@class HGSResultArray;
@class HGSActionArgument;
@class HGSActionOperation;

/*!
  @class HGSAction
  @discussion
  The base class for actions. An action describes something that can be done.
  Actions can have zero or more arguments. The primary argument for an action
  (if is has one), is known as its direct object. The other arguments for an
  action can be made required or optional.
  Actions can also return a result so that they can be chained together.
*/
@interface HGSAction : HGSExtension {
 @private
  HGSTypeFilter *directObjectTypeFilter_;
  NSSet *otherTerms_;
  BOOL causesUIContextChange_;
  BOOL mustRunOnMainThread_;
  HGSTypeFilter *returnedResultsTypeFilter_;
  NSArray *arguments_;
}

/*!
  The types of direct objects that are valid for this action.
  If directObjectTypeFilter is nil, then the action is shown in the first
  layer of search results.
  @result The value of "HGSActionDirectObjectTypes" from config dict.
*/
@property (readonly, retain) HGSTypeFilter *directObjectTypeFilter;

/*!
 The types of results that this action returns.
 If returnedResultsTypeFilter is nil, then the action does not return
 any results.
 @result The value of "HGSActionDirectObjectTypes" from config dict.
 */
@property (readonly, retain) HGSTypeFilter *returnedResultsTypeFilter;

/*!
  Should this action appear in global search results list (ie-no pivot).
  @result Defautls to YES if directObjectTypes is nil.
*/
@property (readonly, assign) BOOL showInGlobalSearchResults;

/*!
  Does the action cause a UI Context change? In the case of QSB, should we hide
  the QSB before performing the action.
  @result YES or the value of "HGSActionDoesActionCauseUIContextChange" from
          config dict.
*/
@property (readonly, assign) BOOL causesUIContextChange;

/*!
 Do you have to run this action on the main thread? Most actions should be able
 to be run in any thread.
 @result NO or the value of "HGSActionMustRunOnMainThread" from config dict.
*/
@property (readonly, assign) BOOL mustRunOnMainThread;

/*!
 Other terms that match this action when searching for it other than its name.
 @result nil or the value of "HGSActionOtherTerms" from config dict.
*/
@property (readonly, retain) NSSet *otherTerms;

/*!
 Other arguments that this action can accept (aside from the directObject)
 @result nil or the value of "HGSActionArguments" from config dict.
*/
@property (readonly, retain) NSArray *arguments;

/*!
  Does the action apply to an individual result. The calling code will check
  that the results are all one of the types listed in directObjectTypes before
  calling this. Do not call this to check if an action is valid for a given
  result. Always turn the result into a result array and call
  appliesToResults:. This is only for subclassers to override.
  @result Defaults to YES
*/
- (BOOL)appliesToResult:(HGSResult *)result;

/*!
  Does the action apply to the array of results. First check to see if the
  action supports the results' types as specified in the action's 
  directObjectTypes and, if it is supported, then check to see if the type
  is excluded as specified in th action's excludedDirectObjectTypes.
  Normally you want to override appliesToResult:, which appliesToResults:
  will call.  If you DO override this method then you will usually want to also
  call this inherited method at some point so that directObjectTypes/
  excludedDirectObjectTypes filtering can be applied.
  @result YES if all the results in the array conform to directObjectTypes/
          excludedDirectObjectTypes and they each pass appliesToResult:.
*/
- (BOOL)appliesToResults:(HGSResultArray *)results;

/*!
  returns the name to display in the UI for this action. May change based on
  the contents of |result|, but the base class ignores it.
  @result Defaults to displayName.

*/
- (NSString*)displayNameForResults:(HGSResultArray*)results;

/*!
  returns the icon to display in the UI for this action. May change based on
  the contents of |result|, but the base class ignores it.
  @result Defaults to generic action icon.
*/
- (NSImage *)displayIconForResults:(HGSResultArray*)results;

/*!
 Subclassers override to perform the action if the action does not return
 results.
 
 <b>Do not call this method directly. Wrap your action up in an
 HGSActionOperation and use that instead.</b>
 
 @param info contains a key/value pair for each argument being passed to the
 action. kHGSActionDirectObjectsKey represent the direct objects.
 Arguments will be HGSResultArrays (even if it's a single object).
 @result YES if action performed.
*/
- (BOOL)performWithInfo:(NSDictionary *)info;

/*!
 Subclassers override to perform the action if it returns results.
 
 <b>Do not call this method directly. Wrap your action up in an
 HGSActionOperation and use that instead.</b>
 
 @param info contains a key/value pair for each argument being passed to the
 action. kHGSActionDirectObjectsKey represent the direct objects.
 Arguments will be HGSResultArrays (even if it's a single object).
 @result array of results. nil, or empty array implies the action failed.
*/
- (HGSResultArray *)performReturningResultsWithInfo:(NSDictionary *)info;

/*!
  Return the next action argument to fill in based on the state of the
  operation that we are creating.
  @param operation the current operation that we are creating
  @result the argument to fill in. nil if there are no more arguments.
*/
- (HGSActionArgument *)nextArgumentToFillIn:(HGSActionOperation *)operation;

@end

/*!
  kHGSValidateActionBehaviorsPrefKey is a boolean preference that the engine
  can use to enable extra logging about Action behaviors to help developers
  make sure their Action is acting right.  The pref should be set before launch
  to ensure it is all possible checks are done.
*/
#define kHGSValidateActionBehaviorsPrefKey @"HGSValidateActionBehaviors"

/*!
  The key for the direct objects for performWithInfo:results:. 
 
  Type is HGSResultsArray.
  @see //google_vermilion_ref/occ/instm/HGSAction/performWithInfo:results: performWithInfo:results:
*/
extern NSString* const kHGSActionDirectObjectsKey;

/*!
 The key for the arguments for performWithInfo:results: results. 
 
 Type is NSDictionary.
 @see //google_vermilion_ref/occ/instm/HGSAction/performWithInfo:results: performWithInfo:results:
*/
extern NSString* const kHGSActionArgumentsKey;

/*!
 Configuration key for direct object types that the action supports.
 Default is nil, which means that the action is a global action, and not
 result specific.
 
 Type is NSString, NSArray or NSSet. '*' matches all types.
*/
extern NSString* const kHGSActionDirectObjectTypesKey;

/*!
 Configuration key for direct object types that the action specifically
 does not support and which filters the types allowed by
 kHGSActionDirectObjectTypesKey.
 Default is nil, which means that no filtering is performed.
 
 Type is NSString, NSArray or NSSet. '*' is not allowed.
*/
extern NSString* const kHGSActionExcludedDirectObjectTypesKey;

/*!
 Configuration key for whether the action should cause a UI context change
 away from QSB. If there's a context change QSB will disappear.
 Default is YES.
 
 Type is BOOL.
*/
extern NSString* const kHGSActionDoesActionCauseUIContextChangeKey;

/*!
 Configuration key for result types that the action returns.
 Default is nil, which means that the action does not return results.
 
 Type is NSString, NSArray or NSSet. '*' matches all types.
*/
extern NSString* const kHGSActionReturnedResultsTypesKey;

/*!
 Configuration key for result types types that the action specifically
 does not return and which filters the types allowed by
 kHGSActionReturnedResultsTypesKey.
 Default is nil, which means that no filtering is performed.
 
 Type is NSString, NSArray or NSSet. '*' is not allowed.
*/
extern NSString* const kHGSActionExcludedReturnedResultsTypesKey;

/*!
 Configuration key for whether the action needs to run on the main thread.
 Default is NO.
 
 Type is BOOL.
 */
extern NSString* const kHGSActionMustRunOnMainThreadKey;

/*!
 Configuration key for other terms that match for this action. 
 
 Type is NSString, or NSArray of NSString.
*/
extern NSString* const kHGSActionOtherTermsKey;

/*!
 Configuration key for other arguments for this action. 
 
 Type is NSArray or NSDictionary
*/
extern NSString* const kHGSActionArgumentsKey;

/*!
 Notification sent to notification center to announce that
 an action will be performed.

 Object is the action (HGSAction *)

 The userInfo argument contains an entry for each argument keyed by name.
 Usually has HGSActionDirectObjects representing the direct objects for the
 action.
*/
extern NSString *const kHGSActionWillPerformNotification;

/*!
 Notification sent to notification center to announce that
 an action was attempted (not necessarily that it did succeed)
 
 Object is the action (HGSAction *)
 
 The userInfo argument contains an entry for each argument keyed by name.
 Usually has HGSActionDirectObjects representing the direct objects for the
 action.
 The userInfo also contains a value for HGSActionCompletedSuccessfully 
 designating if the action was successful.
*/
extern NSString *const kHGSActionDidPerformNotification;

/*!
 Key for kHGSActionDidPerformNotification. BOOL as NSNumber.
*/
extern NSString* const kHGSActionCompletedSuccessfullyKey;  

/*!
 Key for kHGSActionDidPerformNotification. Represents the result (if any)
 of an action. Type is HGSResultArray.
*/
extern NSString* const kHGSActionResultsKey;  

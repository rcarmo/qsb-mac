//
//  HGSActionArgument.h
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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
 @discussion HGSActionArgument
*/

#import <Foundation/Foundation.h>

@class HGSTypeFilter;
@class HGSScoredResult;
@class HGSQuery;
@class HGSActionArgumentSource;
@class HGSSearchSource;

/*!
 All of the routines that an action argument is required to implement.
 Done as a protocol, so that if users choose to supply their own class
 for arguments to actions, that they are not required to subclass
 HGSActionArgument (although in most cases they will).
*/
@protocol HGSActionArgument

/*! Is this argument an optional one. */
@property (readonly, nonatomic, assign, getter=isOptional) BOOL optional;

/*! 
 Identifier for the argument. Each argument for an action must have a unique
 identifier. This is not to be displayed to the user.
 */
@property (readonly, nonatomic, retain) NSString *identifier;

/*! 
 Localized name of the argument for user display.
 */
@property (readonly, nonatomic, retain) NSString *displayName;

/*!
 Describes the valid types for the argument.
 */
@property (readonly, nonatomic, retain) HGSTypeFilter *typeFilter;

/*!
 A description for the argument that can be displayed.
 */

@property (readonly, nonatomic, retain) NSString *displayDescription;

/*!
 Localized synonyms for the argument. Again these must be unique across
 all arguments for a given action.
 */
@property (readonly, nonatomic, retain) NSSet *displayOtherTerms;

- (id)initWithConfiguration:(NSDictionary *)configuration;

/*!
 This argument will be requested to score multiple objects against
 query. This is a no-op by default, but allows action arguments to
 set up for scoring.
*/
- (void)willScoreForQuery:(HGSQuery *)query;

/*!
 This argument has been requested to score multiple objects against
 query. This is a no-op by default, but allows action arguments to
 clean up after scoring.
 */
- (void)didScoreForQuery:(HGSQuery *)query;

/*!
 Given a scored result, rescore it based on the arguments knowledge of the
 action being performed, the other arguments passed to the action etc.
 Base implementation just returns result.
 @param result The result as already scored by the query system.
 @param query The query to score against.
 @result The newly scored result. 
 */
- (HGSScoredResult *)scoreResult:(HGSScoredResult *)result 
                        forQuery:(HGSQuery *)query;

@optional

/*!
 Return a custom set of results for this argument based on query.
 If implemented, the action argument will be asked to return values.
 @param query The query to return results for.
 @param source The source to create the results for.
 @result An array of HGSScoredResults.
*/
- (NSArray *)resultsForQuery:(HGSQuery *)query source:(HGSSearchSource *)source;

@end

/*!
 @class HGSActionArgument
 @discussion
 Describes an argument that an action may have.
*/
@interface HGSActionArgument : NSObject <HGSActionArgument> {
 @private
  BOOL optional_;
  NSString *identifier_;
  NSString *displayName_;
  HGSTypeFilter *typeFilter_;
  NSString *displayDescription_;
  NSSet *displayOtherTerms_;
}

/*!
 Return the action argument source, which is the source responsible for
 returning custom results for actions.
*/
+ (HGSActionArgumentSource *)defaultActionArgumentSource;
@end

/*!
 Bundle for getting localized strings.
 
 Type is NSBundle. Required.
*/
extern NSString* const kHGSActionArgumentBundleKey;


/*!
 Identifier for the action argument.
 
 Type is NSString. Required.
*/
extern NSString* const kHGSActionArgumentIdentifierKey;

/*!
 Configuration key for the supported object types for the action argument.
 
 Type is NSString, NSArray or NSSet. '*' matches all types. Required.
 */
extern NSString* const kHGSActionArgumentSupportedTypesKey;

/*!
 Configuration key for the unsupported object types for the action argument.
 Default is nil, which means that no filtering is performed.
 
 Type is NSString, NSArray or NSSet. '*' is not allowed. Optional.
*/
extern NSString* const kHGSActionArgumentUnsupportedTypesKey;

/*!
 Configuration key for whether the argument is optional.
 Default is NO. Optional.
 
 Type is Boolean.
 */
extern NSString* const kHGSActionArgumentOptionalKey;

/*!
 Configuration key for the name of the argument. This is localized.
 
 Type is NSString. Optional unless kHGSActionArgumentOptionalKey is YES, then
 it is required.
*/
extern NSString* const kHGSActionArgumentUserVisibleNameKey;

/*!
 Configuration key for other terms that match for this action argument. These
 are localized.
 
 Type is NSString, or NSArray of NSString. Optional.
 */
extern NSString* const kHGSActionArgumentUserVisibleOtherTermsKey;

/*!
 Configuration key for the description of the argument. This is localized.
 Default is nil. Optional.
 
 Type is NSString.
*/
extern NSString* const kHGSActionArgumentUserVisibleDescriptionKey;

/*!
 Identifier for name of the class to be instantiated for this argument.
 
 Type is NSString. Optional.
*/
extern NSString* const kHGSActionArgumentClassKey;

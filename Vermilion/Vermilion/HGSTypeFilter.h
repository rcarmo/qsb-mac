//
//  HGSTypeFilter.h
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
 @discussion HGSTypeFilter
*/

#import <Foundation/Foundation.h>

/*!
  HGSTypeFilter represents a filter that allows certain types of results to
  pass, and blocks other ones. It is made up of a set of types that an object
  can conform to, and a set of objects that it doesn't conform to.
*/
@interface HGSTypeFilter : NSObject <NSCopying> {
 @private
  NSSet *conformTypes_;
  NSSet *doesNotConformTypes_;
  NSUInteger hash_;
}

/*!
 @result A set that represents all types.
*/
+ (NSSet *)allTypesSet;

/*! 
  @result A filter that allows all types through it. 
*/
+ (id)filterAllowingAllTypes;

/*! 
  @result A filter that allows all objects that conform to conformTypes through. 
*/
+ (id)filterWithConformTypes:(NSSet *)conformTypes;

/*! 
  @result A filter that allows all objects that do not conform to 
          doesNotConformTypes through. 
*/
+ (id)filterWithDoesNotConformTypes:(NSSet *)doesNotConformTypes;

/*! 
  Creates a filter.
  @param conformTypes Types the filter show allow pass
  @param doesNotConformTypes Types the filter should block.
  @result A filter.
*/
+ (id)filterWithConformTypes:(NSSet *)conformTypes
         doesNotConformTypes:(NSSet *)doesNotConformTypes;

/*! 
  Creates a filter.
  @param conformTypes Types the filter show allow pass
  @param doesNotConformTypes Types the filter should block.
  @result A filter.
*/
- (id)initWithConformTypes:(NSSet *)conformTypes
       doesNotConformTypes:(NSSet *)doesNotConformTypes;

/*! 
  Checks the validity of type as far as the filter is concerned.
  @param type The type to check.
  @result Returns YES if the filter would let this type pass.
*/
- (BOOL)isValidType:(NSString *)type;

/*!
  Checks to see if filter and self have any types that are mutually acceptable.
  @param filter The other filter too test.
  @result YES if there is at least one type that is mutually acceptable to
          both self and filter.
*/
- (BOOL)intersectsWithFilter:(HGSTypeFilter *)filter;

/*!
 @result YES if this filter allows all types to pass.
*/
- (BOOL)allowsAllTypes;

@end

/*! 
 Get an HGSType for a given path.
 @param path Path to get the HGSType for.
 @result HGSType of path.
*/
NSString *HGSTypeForPath(NSString *path);

/*! 
 Get an HGSType for a given UTType.
 @param utType Type to get the HGSType for.
 @result HGSType of utType.
*/
NSString *HGSTypeForUTType(CFStringRef utType);

/*!
 Check to see if one type conforms to another.
 @param type1 Type to check.
 @param type2 Type to conform to.
 @result YES if type1 conforms to type2
*/
BOOL HGSTypeConformsToType(NSString *type1, NSString *type2);

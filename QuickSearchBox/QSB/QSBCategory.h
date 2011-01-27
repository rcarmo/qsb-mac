//
//  QSBCategory.h
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

#import <Foundation/Foundation.h>

@class HGSResult;
@class HGSTypeFilter;

// Describes a category in terms of the types that it conforms to.
// Also contains it's name (localized, unlocalized and singular).
@interface QSBCategory : NSObject <NSCopying> {
 @private
  HGSTypeFilter *typeFilter_;
  NSString *name_;
  NSString *localizedName_;
  NSString *localizedSingularName_;
}

@property (readonly, retain) NSString *name;
@property (readonly, retain) HGSTypeFilter *typeFilter;
@property (readonly, retain) NSString *localizedName;
@property (readonly, retain) NSString *localizedSingularName;

- (BOOL)isResultMember:(HGSResult *)result;
- (BOOL)isValidType:(NSString *)type;
- (NSComparisonResult)compare:(QSBCategory *)category;
@end

// Manages the collections of categories that QSB recognizes.
@interface QSBCategoryManager : NSObject {
 @private
  NSArray *categories_;
  QSBCategory *otherCategory_;
}
+ (QSBCategoryManager *)sharedManager;
- (QSBCategory *)categoryForType:(NSString *)type;
- (NSArray *)categories;
@end




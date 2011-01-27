//
//  QSBCategoryTest.m
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

#import "GTMSenTestCase.h"
#import "QSBCategory.h"
#import "QSBCategories.h"
#import "GTMDefines.h"
#import "HGSType.h"

@interface QSBCategoryTest : GTMTestCase
@end

@implementation QSBCategoryTest

- (void)testBasicCategories {
  QSBCategoryManager *mgr = [QSBCategoryManager sharedManager];
  STAssertNotNil(mgr, nil);
  NSArray *categories = [mgr categories];
  STAssertEquals([categories count], (NSUInteger)11, nil);
}

- (void)testCategoryForType {
  struct {
    NSString *type;
    NSString *name;
  } typeToNameMap[] = {
    { kHGSTypeContact, GTM_NSSTRINGIFY(QSB_CATEGORY_CONTACTS_NAME) },
    { kHGSTypeFile, GTM_NSSTRINGIFY(QSB_CATEGORY_DOCS_NAME) },
    { kHGSTypeEmail, GTM_NSSTRINGIFY(QSB_CATEGORY_MESSAGES_NAME) },
    { kHGSTypeWebpage, GTM_NSSTRINGIFY(QSB_CATEGORY_WEBPAGES_NAME) },
    { kHGSTypeOnebox, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeAction, GTM_NSSTRINGIFY(QSB_CATEGORY_ACTIONS_NAME) },
    { kHGSTypeText, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeScript, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeDateTime, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeGeolocation, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeSearch, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeSuggest, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeDirectory, GTM_NSSTRINGIFY(QSB_CATEGORY_FOLDERS_NAME) },
    { kHGSTypeTextFile, GTM_NSSTRINGIFY(QSB_CATEGORY_DOCS_NAME) },
    { kHGSTypeFileApplication, GTM_NSSTRINGIFY(QSB_CATEGORY_APPS_NAME) },
    { kHGSTypeWebBookmark, GTM_NSSTRINGIFY(QSB_CATEGORY_WEBPAGES_NAME) },
    { kHGSTypeWebHistory, GTM_NSSTRINGIFY(QSB_CATEGORY_WEBPAGES_NAME) },
    { kHGSTypeWebApplication, GTM_NSSTRINGIFY(QSB_CATEGORY_APPS_NAME) },
    { kHGSTypeGoogleSuggest, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeGoogleNavSuggest, GTM_NSSTRINGIFY(QSB_CATEGORY_WEBPAGES_NAME) },
    { kHGSTypeGoogleSearch, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeFileMedia, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeFileMusic, GTM_NSSTRINGIFY(QSB_CATEGORY_MUSIC_NAME) },
    { kHGSTypeFileImage, GTM_NSSTRINGIFY(QSB_CATEGORY_IMAGES_NAME) },
    { kHGSTypeFileMovie, GTM_NSSTRINGIFY(QSB_CATEGORY_MOVIES_NAME) },
    { kHGSTypeFilePDF, GTM_NSSTRINGIFY(QSB_CATEGORY_DOCS_NAME) },
    { kHGSTypeFilePresentation, GTM_NSSTRINGIFY(QSB_CATEGORY_DOCS_NAME) },
    { kHGSTypeFileFont, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeFileCalendar, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeWebMedia, GTM_NSSTRINGIFY(QSB_CATEGORY_WEBPAGES_NAME) },
    { kHGSTypeWebMusic, GTM_NSSTRINGIFY(QSB_CATEGORY_MUSIC_NAME) },
    { kHGSTypeWebImage, GTM_NSSTRINGIFY(QSB_CATEGORY_IMAGES_NAME) },
    { kHGSTypeWebMovie, GTM_NSSTRINGIFY(QSB_CATEGORY_MOVIES_NAME) },
    { kHGSTypeFilePhotoAlbum, GTM_NSSTRINGIFY(QSB_CATEGORY_IMAGES_NAME) }, 
    { kHGSTypeWebPhotoAlbum, GTM_NSSTRINGIFY(QSB_CATEGORY_IMAGES_NAME) },
    { kHGSTypeTextUserInput, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeTextPhoneNumber, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeTextEmailAddress, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeTextInstantMessage, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
    { kHGSTypeTextAddress, GTM_NSSTRINGIFY(QSB_CATEGORY_OTHERS_NAME) },
  };
  QSBCategoryManager *mgr = [QSBCategoryManager sharedManager];
  for (size_t i = 0; i < sizeof(typeToNameMap) / sizeof(typeToNameMap[0]); ++i) {
    QSBCategory *category = [mgr categoryForType:typeToNameMap[i].type];
    NSString *name = [category name];
    STAssertEqualObjects(typeToNameMap[i].name, name, 
                         @"Type: %@", typeToNameMap[i].type);
  }
}

- (void)testCategoryCompare {
  QSBCategoryManager *mgr = [QSBCategoryManager sharedManager];
  QSBCategory *otherCategory = [mgr categoryForType:kHGSTypeOnebox];
  STAssertNotNil(otherCategory, nil);
  QSBCategory *musicCategory = [mgr categoryForType:kHGSTypeFileMusic];
  STAssertNotNil(musicCategory, nil);
  
  // We don't know for sure which way this comparison will go depending
  // on the locale we run out tests in.
  NSComparisonResult result = [otherCategory compare:musicCategory];
  STAssertNotEquals(result, (NSComparisonResult)NSOrderedSame, nil);
}

- (void)testCategoryNames {
  QSBCategoryManager *mgr = [QSBCategoryManager sharedManager];
  QSBCategory *imageCategory = [mgr categoryForType:kHGSTypeWebImage];
  STAssertNotNil(imageCategory, nil);
  NSString *name = [imageCategory name];
  STAssertNotNil(name, nil);
  NSString *localizedName = [imageCategory localizedName];
  STAssertNotNil(localizedName, nil);
  NSString *singularName = [imageCategory localizedSingularName];
  STAssertNotNil(singularName, nil);
  
  STAssertNotEqualObjects(name, singularName, nil);
  STAssertNotEqualObjects(name, localizedName, nil);
  STAssertNotEqualObjects(singularName, localizedName, nil);
}

@end

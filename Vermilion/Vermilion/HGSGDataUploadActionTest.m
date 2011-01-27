//
//  HGSGDataUploadActionTest.m
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
#import <Vermilion/Vermilion.h>
#import <GData/GData.h>
#import <OCMock/OCMock.h>

@interface HGSGDataUploadActionTest : GTMTestCase 
@end

// An upload action class which does not implement the required methods.
@interface BadUploadAction : HGSGDataUploadAction {
 @private
  BOOL selectorDetectorHit_;
}

@property (readonly, assign) BOOL selectorDetectorHit;
@end

@implementation BadUploadAction

@synthesize selectorDetectorHit = selectorDetectorHit_;

- (void)doesNotRecognizeSelector:(SEL)aSelector {
  selectorDetectorHit_ = YES;
}

@end


@implementation HGSGDataUploadActionTest

- (void)testMIMETypeDetection {
  id resultMockA = [OCMockObject mockForClass:[HGSResult class]];
  [[[resultMockA expect] andReturn:@"fakepath.jpg"] filePath];
  NSString *typeA = [HGSGDataUploadAction mimeTypeForResult:resultMockA];
  STAssertEqualStrings(@"image/jpeg", typeA, nil);

  id resultMockB = [OCMockObject mockForClass:[HGSResult class]];
  [[[resultMockB expect] andReturn:@"fakepath.woohoo"] filePath];
  [[[resultMockB expect] andReturn:kHGSTypeFilePDF] type];
  NSString *typeB = [HGSGDataUploadAction mimeTypeForResult:resultMockB];
  STAssertEqualStrings(@"application/pdf", typeB, nil);
}

- (void)testMissingImplementations {
  OCMockObject *bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"fakeAction"] 
   qsb_localizedInfoPListStringForKey:@"fakeAction"];
  OCMockObject *mockAccount = [OCMockObject mockForClass:[HGSSimpleAccount class]];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 bundleMock, kHGSExtensionBundleKey,
                                 @"fakeIdentifier", kHGSExtensionIdentifierKey,
                                 @"fakeAction", kHGSExtensionUserVisibleNameKey,
                                 mockAccount, kHGSExtensionAccountKey,
                                 nil];
  BadUploadAction *missingUploadURLAction
    = [[[BadUploadAction alloc] initWithConfiguration:configuration] autorelease];
  STAssertNotNil(missingUploadURLAction, nil);
  STAssertNil([missingUploadURLAction uploadURL], nil);
  STAssertTrue([missingUploadURLAction selectorDetectorHit], nil);

  BadUploadAction *missingServiceClassAction
    = [[[BadUploadAction alloc] initWithConfiguration:configuration] autorelease];
  STAssertNotNil(missingServiceClassAction, nil);
  STAssertNil([missingServiceClassAction uploadURL], nil);
  STAssertTrue([missingServiceClassAction selectorDetectorHit], nil);

  BadUploadAction *missingServiceNameAction
    = [[[BadUploadAction alloc] initWithConfiguration:configuration] autorelease];
  STAssertNotNil(missingServiceNameAction, nil);
  STAssertNil([missingServiceNameAction uploadURL], nil);
  STAssertTrue([missingServiceNameAction selectorDetectorHit], nil);

  BadUploadAction *missingServiceIconAction
    = [[[BadUploadAction alloc] initWithConfiguration:configuration] autorelease];
  STAssertNotNil(missingServiceIconAction, nil);
  STAssertNil([missingServiceIconAction uploadURL], nil);
  STAssertTrue([missingServiceIconAction selectorDetectorHit], nil);
}

// TODO(mrossetti): Add an upload test expected to succeed.
// The challenge is the need to have a keychain entry which we can access
// in the -[HGSGDataUploadAction uploadService] method.

@end

//
//  HGSExtensionTest.m
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


#import "GTMSenTestCase.h"
#import "HGSExtension.h"

#import <OCMock/OCMock.h>

#import "HGSBundle.h"

@interface HGSExtensionTest : GTMTestCase 
@end

@interface NSSet_HGSExtensionTest : GTMTestCase 
@end

@interface NSBundle_HGSExtensionTest : GTMTestCase 
@end

@implementation HGSExtensionTest
- (void)testInit {
  // Test bad init inputs
  HGSExtension *extension = [[HGSExtension alloc] init];
  STAssertNil(extension, nil);
  extension = [[HGSExtension alloc] initWithConfiguration:nil];
  STAssertNil(extension, nil);
  extension = [[HGSExtension alloc] 
               initWithConfiguration:[NSDictionary dictionary]];
  STAssertNil(extension, nil);

  // Mock up case where we don't have an identifier
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:nil] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:nil] 
   pathForResource:@"QSBInfo" ofType:@"plist"];
  NSDictionary *config = 
    [NSDictionary dictionaryWithObject:bundleMock 
                                forKey:kHGSExtensionBundleKey];
  extension = [[HGSExtension alloc] initWithConfiguration:config];
  STAssertNil(extension, nil);
  [bundleMock verify];
  
  bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  struct {
    NSString *value;
    NSString *key;
  } stubValuesAndKeys[] = {
    // things called to get an identifier
    { @"test.identifier", @"CFBundleIdentifier" },
    // things called to get a name
    { nil, @"CFBundleDisplayName" },
    { nil, @"CFBundleName" },
    { nil, @"CFBundleExecutable" },
    { @"testCopyright", @"NSHumanReadableCopyright" },
    { @"testVersion", @"CFBundleVersion" }
  };    
  for (size_t i = 0; 
       i < sizeof(stubValuesAndKeys) / sizeof(stubValuesAndKeys[0]);
       ++i) {
    [[[bundleMock stub] andReturn:stubValuesAndKeys[i].value] 
     objectForInfoDictionaryKey:stubValuesAndKeys[i].key];
    if (!stubValuesAndKeys[i].value) {
      [[[bundleMock stub] andReturn:nil] 
       pathForResource:@"QSBInfo" ofType:@"plist"];
    }
  }
  config = 
    [NSDictionary dictionaryWithObject:bundleMock 
                                forKey:kHGSExtensionBundleKey];
  extension = [[[HGSExtension alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(extension, nil);
  STAssertEqualObjects([extension identifier], @"test.identifier", nil);
  STAssertEqualObjects([extension displayName], @"Unknown Name", nil);
  STAssertEqualObjects([extension bundle], bundleMock, nil);
  STAssertNotNil([extension icon], nil);
  
  STAssertEqualObjects([extension copyright], @"testCopyright", nil);
  STAssertEqualObjects([extension extensionVersion], @"testVersion", nil);
  [bundleMock verify];
}

- (void)testIcon {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  NSDictionary *config = 
    [NSDictionary dictionaryWithObjectsAndKeys:
     bundleMock, kHGSExtensionBundleKey,
     @"test.identifier", kHGSExtensionIdentifierKey,
     @"testName", kHGSExtensionUserVisibleNameKey,
     [[[NSImage alloc] init] autorelease], kHGSExtensionIconImageKey,
     @"testPath", kHGSExtensionIconImagePathKey,
     nil];
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSString *finderPath 
    = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.finder"];
  STAssertNotNil(finderPath, nil);
  NSBundle *bundle = [NSBundle bundleWithPath:finderPath];
  STAssertNotNil(bundle, nil);
  NSString *imagePath = [bundle pathForImageResource:@"Finder.icns"];
  STAssertNotNil(imagePath, nil);
  [[[bundleMock stub] andReturn:imagePath] pathForImageResource:@"testPath"];
  [[[bundleMock stub] andReturn:@"testName"] 
   qsb_localizedInfoPListStringForKey:@"testName"];
  HGSExtension *extension 
    = [[[HGSExtension alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(extension, nil);
  NSImage *icon = [extension icon];
  STAssertNotNil(icon, nil);
  [bundleMock verify];
  
  // Test failure cases
  bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  config = 
    [NSDictionary dictionaryWithObjectsAndKeys:
     bundleMock, kHGSExtensionBundleKey,
     @"test.identifier", kHGSExtensionIdentifierKey,
     @"testName", kHGSExtensionUserVisibleNameKey,
     [[[NSImage alloc] init] autorelease], kHGSExtensionIconImageKey,
     @"testPath", kHGSExtensionIconImagePathKey,
     nil];
  [[[bundleMock stub] andReturn:@"testName"] 
   qsb_localizedInfoPListStringForKey:@"testName"];
  [[[bundleMock stub] andReturn:@"imagePath"] pathForImageResource:@"testPath"];
  extension 
    = [[[HGSExtension alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(extension, nil);
  icon = [extension icon];
  STAssertNotNil(icon, nil);
}

@end

@implementation NSSet_HGSExtensionTest

- (void)test_qsb_setFromId {
  id value = nil;
  NSSet *set = [NSSet qsb_setFromId:value];
  STAssertNil(set, nil);
  
  value = @"Foo";
  set = [NSSet qsb_setFromId:value];
  STAssertTrue([set containsObject:value], nil);

  value = [NSArray arrayWithObjects:@"Foo", @"Bar", nil];
  set = [NSSet qsb_setFromId:value];
  SEL sortSel = @selector(caseInsensitiveCompare:);
  STAssertEqualObjects([[set allObjects] sortedArrayUsingSelector:sortSel], 
                       [value sortedArrayUsingSelector:sortSel], nil);
  
  value = [NSSet setWithObjects:@"Foo", @"Bar", nil];
  set = [NSSet qsb_setFromId:value];
  STAssertEqualObjects(set, value, nil);
  
  value = [NSNumber numberWithInt:0];
  set = [NSSet qsb_setFromId:value];
  STAssertNil(set, nil);
}

@end

@implementation NSBundle_HGSExtensionTest

- (void)test_qsb_localizedInfoPListStringForKey {
  NSBundle *bundle = HGSGetPluginBundle();
  STAssertNotNil(bundle, nil);
  
  NSString *string 
    = [bundle qsb_localizedInfoPListStringForKey:@"^Localize Me Localizable.strings"];
  STAssertEqualObjects(string, @"Localize Me Localizable.strings", nil);
  
  string 
    = [bundle qsb_localizedInfoPListStringForKey:@"^Localize Me InfoPlist.strings"];
  STAssertEqualObjects(string, @"Localize Me InfoPlist.strings", nil);
  
  string = [bundle qsb_localizedInfoPListStringForKey:@"^No localized string"];
  STAssertEqualObjects(string, @"^No localized string", nil);
  
  string = [bundle qsb_localizedInfoPListStringForKey:nil];
  STAssertNil(string, nil);
}

@end

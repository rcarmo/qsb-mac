//
//  HGSProtoExtensionTest.m
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
#import "HGSCoreExtensionPoints.h"
#import "HGSExtensionPoint.h"
#import "HGSPlugin.h"
#import "HGSProtoExtension.h"
#import <OCMock/OCMock.h>

@interface HGSProtoExtensionTest : GTMTestCase 
@end


static NSString *const kAccountType = @"AccountType";

@interface HGSProtoExtension ()

+ (NSSet *)keyPathsForValuesAffectingKeyInstalled;
+ (NSSet *)keyPathsForValuesAffectingCanSetEnabled;

@end


@implementation HGSProtoExtensionTest

- (void)testClassFunctions {
  NSSet *set = [HGSProtoExtension keyPathsForValuesAffectingKeyInstalled];
  STAssertEquals([set count], (NSUInteger)1, nil);
  NSString *oneSetObject = [set anyObject];
  STAssertEqualObjects(oneSetObject, @"extension", nil);
  set = [HGSProtoExtension keyPathsForValuesAffectingCanSetEnabled];
  STAssertEquals([set count], (NSUInteger)1, nil);
  oneSetObject = [set anyObject];
  STAssertEqualObjects(oneSetObject, @"plugin.enabled", nil);
}

- (void)testBadInits {
  HGSProtoExtension *protoExtension
    = [[[HGSProtoExtension alloc] init] autorelease];
  STAssertNil(protoExtension, nil);
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:nil plugin:nil]
       autorelease];
  STAssertNil(protoExtension, nil);

  // Bad configurations.
  id pluginMock = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMock expect] andReturn:@"PLUGIN A"] displayName];
  [[[pluginMock stub] andReturn:[NSBundle mainBundle]] bundle];
  NSDictionary *configurationA
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME A", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER A", kHGSExtensionIdentifierKey,
       @"CLASS NAME A", kHGSExtensionClassKey,
       nil];
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationA
                                                 plugin:pluginMock]
       autorelease];
  STAssertNil(protoExtension, nil);
  
  NSDictionary *configurationB
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME B", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER B", kHGSExtensionIdentifierKey,
       @"EXTENSION POINT B", kHGSExtensionPointKey,
       nil];
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationB
                                                 plugin:pluginMock]
       autorelease];
  STAssertNil(protoExtension, nil);
  
  NSDictionary *configurationC
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME C", kHGSExtensionUserVisibleNameKey,
       @"CLASS NAME C", kHGSExtensionClassKey,
       @"EXTENSION POINT C", kHGSExtensionPointKey,
       nil];
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationC
                                                 plugin:pluginMock]
       autorelease];
  STAssertNil(protoExtension, nil);
  
  // Bad plugins.
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:nil plugin:pluginMock]
       autorelease];
  STAssertNil(protoExtension, nil);

  NSDictionary *configurationD
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME D", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER D", kHGSExtensionIdentifierKey,
       @"CLASS NAME D", kHGSExtensionClassKey,
       @"EXTENSION POINT D", kHGSExtensionPointKey,
       nil];
  id pluginMockD = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockD expect] andReturn:@"PLUGIN D"] displayName];
  [[[pluginMockD expect] andReturn:nil] bundle];
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationD
                                                 plugin:pluginMockD]
       autorelease];
  STAssertNil(protoExtension, nil);
}

- (void)testGoodInits {
  id pluginMockE = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockE expect] andReturn:@"PLUGIN E"] displayName];
  [[[pluginMockE stub] andReturn:[NSBundle mainBundle]] bundle];
  NSDictionary *configurationE
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME E", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER E", kHGSExtensionIdentifierKey,
       @"CLASS NAME E", kHGSExtensionClassKey,
       @"EXTENSION POINT E", kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       nil];
  HGSProtoExtension *protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationE
                                                 plugin:pluginMockE]
       autorelease];
  STAssertNotNil(protoExtension, nil);
  
  NSDictionary *configurationF
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME F", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER F", kHGSExtensionIdentifierKey,
       @"CLASS NAME F", kHGSExtensionClassKey,
       @"EXTENSION POINT F", kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionIsEnabledByDefaultKey,
       nil];
  protoExtension
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationF
                                                 plugin:pluginMockE]
       autorelease];
  STAssertNotNil(protoExtension, nil);
}

- (void)testAttributes {
  NSDictionary *configurationJ
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME J", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER J", kHGSExtensionIdentifierKey,
       @"CLASS NAME J", kHGSExtensionClassKey,
       @"EXTENSION POINT J", kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       kAccountType, kHGSExtensionDesiredAccountTypesKey,
       nil];
  id pluginMockJ = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockJ expect] andReturn:@"PLUGIN J"] displayName];
  [[[pluginMockJ expect] andReturn:[NSBundle mainBundle]] bundle];
  NSAttributedString *extensionDescription
    = [[[NSAttributedString alloc] initWithString:@"EXTENSION DESCRIPTION J"]
       autorelease];
  [[[pluginMockJ expect] andReturn:extensionDescription] extensionDescription];
  [[[pluginMockJ expect] andReturn:@"EXTENSION VERSION J"] extensionVersion];
  HGSProtoExtension *protoExtensionJ
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationJ
                                                 plugin:pluginMockJ]
     autorelease];
  NSString *version = [protoExtensionJ extensionVersion];
  STAssertEqualObjects(version, @"EXTENSION VERSION J", nil);
  NSAttributedString *extDescription = [protoExtensionJ extensionDescription];
  STAssertEqualObjects(extDescription, extensionDescription, nil);
  NSString *description = [protoExtensionJ description];
  STAssertNotNil(description, nil);
  
  BOOL isInstalled = [protoExtensionJ isInstalled];
  STAssertFalse(isInstalled, nil);
  
  [protoExtensionJ setEnabled:NO];
}

- (void)testInstallAccountTypes {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock expect] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  BOOL yes = YES;
  [[[bundleMock expect] andReturnValue:OCMOCK_VALUE(yes)] isLoaded];
  NSDictionary *configurationK
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME K", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER K", kHGSExtensionIdentifierKey,
       @"CLASS NAME K", kHGSExtensionClassKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       kHGSAccountsExtensionPoint, kHGSExtensionPointKey,
       kAccountType, kHGSExtensionDesiredAccountTypesKey,
       bundleMock, kHGSExtensionBundleKey,
       nil];
  id pluginMockK = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockK expect] andReturn:@"PLUGIN K"] displayName];
  [[[pluginMockK expect] andReturn:bundleMock] bundle];
  [[[pluginMockK expect] andReturn:@"EXTENSION VERSION K"] extensionVersion];
  [[[bundleMock expect] andReturn:@"DISPLAY NAME K"] 
   qsb_localizedInfoPListStringForKey:@"DISPLAY NAME K"];  

  HGSProtoExtension *protoExtensionK
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationK
                                                 plugin:pluginMockK]
       autorelease];
  STAssertNotNil(protoExtensionK, nil);
}

- (void)testIsFactorable {
  NSDictionary *configurationG
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME G", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER G", kHGSExtensionIdentifierKey,
       @"CLASS NAME G", kHGSExtensionClassKey,
       @"EXTENSION POINT G", kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       @"ACCOUNT TYPE G", kHGSExtensionDesiredAccountTypesKey,
       nil];
  id pluginMockG = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockG expect] andReturn:@"PLUGIN G"] displayName];
  [[[pluginMockG expect] andReturn:[NSBundle mainBundle]] bundle];
  HGSProtoExtension *protoExtensionG
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationG
                                                 plugin:pluginMockG]
       autorelease];
  STAssertTrue([protoExtensionG isFactorable], nil);
  
  NSDictionary *configurationH
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME H", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER H", kHGSExtensionIdentifierKey,
       @"CLASS NAME H", kHGSExtensionClassKey,
       @"EXTENSION POINT H", kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       nil];
  id pluginMockH = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMockH expect] andReturn:@"PLUGIN H"] displayName];
  [[[pluginMockH expect] andReturn:[NSBundle mainBundle]] bundle];
  HGSProtoExtension *protoExtensionH
    = [[[HGSProtoExtension alloc] initWithConfiguration:configurationH
                                                 plugin:pluginMockH]
       autorelease];
  STAssertFalse([protoExtensionH isFactorable], nil);
}

@end

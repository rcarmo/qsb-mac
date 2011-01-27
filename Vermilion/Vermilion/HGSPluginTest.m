//
//  HGSPluginTest.m
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
#import "HGSPlugin.h"
#import <OCMock/OCMock.h>

@interface HGSPluginTest : GTMTestCase 
@end

@implementation HGSPluginTest

- (void)testInit {
  HGSPlugin *plugin = [[HGSPlugin alloc] init];
  STAssertNil(plugin, nil);
  
  // Test with no extensions
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock expect] andReturn:@"plugin.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock expect] andReturn:@"pluginName"] 
   objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  [[[bundleMock expect] andReturn:nil] 
   objectForInfoDictionaryKey:@"HGSExtensions"];
  [[[bundleMock expect] andReturn:nil] pathForResource:@"QSBInfo" 
                                                ofType:@"plist"];
  [[[bundleMock expect] andReturn:@"bundlePath"] bundlePath];  
  plugin = [[[HGSPlugin alloc] initWithBundle:bundleMock] autorelease];
  STAssertNil(plugin, nil);
  [bundleMock verify];
  
  // Test with extensions
  bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock expect] andReturn:@"plugin.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock expect] andReturn:@"pluginName"] 
   objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  [[[bundleMock expect] andReturn:@"bundle.identifier"] 
   bundleIdentifier];  
  NSDictionary *extensionDict 
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"HGSPluginTestExtensionClass", kHGSExtensionClassKey,
       @"HGSPluginExtensionPoint", kHGSExtensionPointKey,
       @"HGSPluginExtensionID", kHGSExtensionIdentifierKey,
       nil];
  NSArray *array = [NSArray arrayWithObject:extensionDict];
  [[[bundleMock expect] andReturn:array] 
   objectForInfoDictionaryKey:@"HGSExtensions"];
  plugin = [[[HGSPlugin alloc] initWithBundle:bundleMock] autorelease];
  STAssertNotNil(plugin, nil);
  NSString *bundleIdentifier = [plugin bundleIdentifier];
  STAssertEqualObjects(bundleIdentifier, @"bundle.identifier", nil);
  [bundleMock verify];
}

@end

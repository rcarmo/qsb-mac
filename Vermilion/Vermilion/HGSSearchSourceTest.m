//
//  HGSSearchSourceTest.mm
//
//  Copyright (c) 2008-2009 Google Inc. All rights reserved.
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

#import "HGSSearchSource.h"
#import "GTMSenTestCase.h"
#import "HGSBundle.h"
#import "HGSCoreExtensionPoints.h"

static NSString *const kHGSSimpleNamedSearchSourceTestID 
  = @"com.google.hgssearchsourcetest.simplenamedtestid";

@interface HGSSearchSourceTest : GTMTestCase
@end

@implementation HGSSearchSourceTest
- (void)testSimpleNamedSearchSource {
  // Failure tests
  HGSSearchSource *source 
    = [HGSSimpleNamedSearchSource sourceWithName:nil
                                      identifier:kHGSSimpleNamedSearchSourceTestID
                                          bundle:HGSGetPluginBundle()];
  STAssertNil(source, nil);
  source 
    = [HGSSimpleNamedSearchSource sourceWithName:@"testSource"
                                      identifier:nil
                                          bundle:HGSGetPluginBundle()];
  // Gets identifier from bundle identifier.
  STAssertNotNil(source, nil);
  source 
    = [HGSSimpleNamedSearchSource sourceWithName:@"testSource"
                                      identifier:kHGSSimpleNamedSearchSourceTestID
                                          bundle:nil];
  STAssertNil(source, nil);
  source 
    = [HGSSimpleNamedSearchSource sourceWithName:@"testSource"
                                      identifier:kHGSSimpleNamedSearchSourceTestID
                                          bundle:HGSGetPluginBundle()];
  STAssertNotNil(source, nil);
  
  // Success test
  HGSExtensionPoint *sp = [HGSExtensionPoint sourcesPoint];
  HGSExtension *extension 
    = [sp extensionWithIdentifier:kHGSSimpleNamedSearchSourceTestID];
  STAssertEqualObjects(extension, source, nil);
  
}
@end

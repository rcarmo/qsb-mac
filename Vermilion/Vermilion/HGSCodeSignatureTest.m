//
//  HGSCodeSignatureTest.m
//  QSB
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

#import <Foundation/Foundation.h>
#import "GTMSenTestCase.h"
#import "HGSCodeSignature.h"


@interface HGSCodeSignatureTest : GTMTestCase
@end

static NSString *kAppPath = @"/Applications/System Preferences.app";

@implementation HGSCodeSignatureTest

- (void)testKeyedSignature {
  NSBundle *appBundle
    = [NSBundle bundleWithPath:kAppPath];
  STAssertNotNil(appBundle, @"could not find System Preferences.app bundle");
  
  HGSCodeSignature *sig = [HGSCodeSignature codeSignatureForBundle:appBundle];
  STAssertNotNil(sig, @"failed to create code signature object");
  
  HGSSignatureStatus status = [sig verifyDetachedSignature:[NSData data]];
  STAssertEquals(status, eSignatureStatusInvalid, @"invalid signature accepted");
  
  NSData *sigData = [sig generateDetachedSignature];
  STAssertNotNil(sigData, @"failed to create signature");

  status = [sig verifyDetachedSignature:sigData];
  STAssertEquals(status, eSignatureStatusOK, @"failed to validate signature");
}

- (void)testSignatureValid {
  NSBundle *appBundle
    = [NSBundle bundleWithPath:kAppPath];
  STAssertNotNil(appBundle, @"could not find System Preferences.app bundle");
  
  HGSCodeSignature *sig = [HGSCodeSignature codeSignatureForBundle:appBundle];
  STAssertNotNil(sig, @"failed to create code signature object");
  
  HGSSignatureStatus status = [sig verifySignature];
  STAssertEquals(status, eSignatureStatusOK, @"OK signature declared invalid");
}

- (void)testCertificates {
  NSBundle *appBundle
    = [NSBundle bundleWithPath:kAppPath];
  STAssertNotNil(appBundle, @"could not find System Preferences.app bundle");
  
  HGSCodeSignature *sig = [HGSCodeSignature codeSignatureForBundle:appBundle];
  STAssertNotNil(sig, @"failed to create code signature object");
  
  SecCertificateRef cert = [sig copySignerCertificate];
  STAssertTrue(cert != NULL, @"failed to extract certificate");
  
  STAssertTrue([HGSCodeSignature certificate:cert
                                     isEqual:cert], @"certificates incorrect");
  CFRelease(cert);
}

- (void)testCommonName {
  NSBundle *appBundle
    = [NSBundle bundleWithPath:kAppPath];
  STAssertNotNil(appBundle, @"could not find System Preferences.app bundle");
  
  HGSCodeSignature *sig = [HGSCodeSignature codeSignatureForBundle:appBundle];
  STAssertNotNil(sig, @"failed to create code signature object");
  
  SecCertificateRef cert = [sig copySignerCertificate];
  STAssertNotNULL(cert, @"failed to extract certificate");
  
  NSString *commonName = [HGSCodeSignature certificateSubjectCommonName:cert];
  STAssertNotNil(commonName, @"failed to extract common name");
  
  // System Preferences.app is signed using Apple's "Software Signing" cert
  STAssertEqualObjects(commonName, @"Software Signing",
                       @"unrecognized common name");
  
  CFRelease(cert);
}

@end

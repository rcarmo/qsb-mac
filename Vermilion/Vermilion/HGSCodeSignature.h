//
//  HGSCodeSignature.h
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

/*!
 @header
 @discussion HGSCodeSignature
*/

#import <Cocoa/Cocoa.h>

/*! 
  @enum HGSSignatureStatus 
  @constant eSignatureStatusInvalid Code has a signature that did not validate.
  @constant eSignatureStatusOK Code has a valid signature.
  @constant eSignatureStatusUnsigned No signature present.
*/
typedef enum {
  eSignatureStatusInvalid,
  eSignatureStatusOK,
  eSignatureStatusUnsigned
} HGSSignatureStatus;

/*!
  Encapsulates information about the signature (or lack thereof) on a
  bundle. This class is used by HGSPluginLoader to track which plugins
  are trusted by the user. The purpose of this class is to keep all
  usage of the codesigning SPIs relegated to a single file. If Apple
  changes the SPIs or makes them public APIs, there is only one place
  we will need to make our own changes.
*/
@interface HGSCodeSignature : NSObject {
 @private
  NSBundle *bundle_;
}
+ (HGSCodeSignature *)codeSignatureForBundle:(NSBundle *)bundle;

/*! 
  Evaluates two SecCertificateRef objects for equality. Certificates are
  considered equal if they have the same DER encoding.
*/
+ (BOOL)certificate:(SecCertificateRef)cert1
            isEqual:(SecCertificateRef)cert2;

/*! 
  Returns the common name from the specified certificate ref, or nil
  if an error occurs. If there are multiple common name entries, they are
  returned in a comma-separated list.
*/
+ (NSString *)certificateSubjectCommonName:(SecCertificateRef)cert;

- (id)initWithBundle:(NSBundle *)bundle;

/*! 
  Returns a copy of the certificate used to sign the bundle if the bundle
  has a valid embedded signature. Otherwise, returns NULL.
*/
- (SecCertificateRef)copySignerCertificate;

/*! 
  Returns a copy of the certificate chain used to sign the bundle if the bundle
  has a valid embedded signature. Otherwise, returns NULL.
*/
- (CFArrayRef)copySignerCertificateChain;

/*! 
  Embeds a code signature in the bundle. If the bundle contains a Mach
  executable, then standard Mac OS X code signing is used. Otherwise,
  a proprietary signature is generated. Returns whether or not the
  signature was sucessfully generated and embedded. Any existing signature
  will be overwritten.
*/
- (BOOL)generateSignatureUsingIdentity:(SecIdentityRef)identity;

/*! 
  Verifies an embedded code signature. If the bundle contains a Mac executable,
  the bundle must be signed using a standard Mac OS X code signature (which
  may have been generated using generateSignatureUsingIdentity or the
  Mac OS X codesign tool); otherwise, the proprietary signature generated
  by generateSignatureUsingIdentity is checked.
*/
- (HGSSignatureStatus)verifySignature;

/*
  Generates a code signature for the bundle. The resulting signature must
  be stored securely by the caller.
*/
- (NSData *)generateDetachedSignature;

/*! 
  Verifies a detached code signature created be generateDetachedSignature
  using the same rules as verifySignature.
*/
- (HGSSignatureStatus)verifyDetachedSignature:(NSData *)signature;

@end

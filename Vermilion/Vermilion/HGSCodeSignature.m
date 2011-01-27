//
//  HGSCodeSignature.m
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

#import <uuid/uuid.h>
#import <openssl/hmac.h>
#import <openssl/sha.h>
#import <Vermilion/Vermilion.h>
#import "HGSCodeSignature.h"

// Definitions for the code signing framework SPIs
typedef struct __SecRequirementRef *SecRequirementRef;
typedef struct __SecCodeSigner *SecCodeSignerRef;
typedef struct __SecCode const *SecStaticCodeRef;
enum {
  kSecCSSigningInformation = 2,
  errSecCSUnsigned = -67062,
  errSecCSBadObjectFormat = -67049,
  kCodeSignatureDigestLength = 20 // 160 bits
};
extern const NSString *kSecCodeInfoCertificates;
extern const NSString *kSecCodeSignerDetached;
extern const NSString *kSecCodeSignerIdentity;
OSStatus SecStaticCodeCreateWithPath(CFURLRef path, uint32_t flags,
                                     SecStaticCodeRef *staticCodeRef);
OSStatus SecCodeCopySigningInformation(SecStaticCodeRef code, uint32_t flags,
                                       CFDictionaryRef *information);
OSStatus SecStaticCodeCheckValidityWithErrors(SecStaticCodeRef staticCodeRef,
                                              uint32_t flags,
                                              SecRequirementRef requirementRef,
                                              CFErrorRef *errors);
OSStatus SecCodeSignerCreate(CFDictionaryRef parameters, uint32_t flags,
                             SecCodeSignerRef *signer);
OSStatus SecCodeSignerAddSignatureWithErrors(SecCodeSignerRef signer,
                                             SecStaticCodeRef code,
                                             uint32_t flags,
                                             CFErrorRef *errors);
OSStatus SecCodeSetDetachedSignature(SecStaticCodeRef codeRef,
                                     CFDataRef signature, uint32_t flags);

static NSString *kSignatureDataKey = @"SignatureDataKey";
static NSString *kSignatureDateKey = @"SignatureDateKey";
static NSString *kDetachedSignatureTypeKey = @"DetachedSignatureTypeKey";
static const int kSignatureTypeStandard = 1;
static const int kSignatureTypeDigest = 2;

@interface HGSCodeSignature()
- (BOOL)digest:(unsigned char *)digest;
- (BOOL)digestDirectory:(NSString *)path shaContext:(SHA_CTX *)shaCtx;
@end

@implementation HGSCodeSignature

+ (HGSCodeSignature *)codeSignatureForBundle:(NSBundle *)bundle {
  return [[[HGSCodeSignature alloc] initWithBundle:bundle] autorelease];
}

- (id)initWithBundle:(NSBundle *)bundle {
  self = [super init];
  if (self) {
    bundle_ = [bundle retain];
  }
  return self;
}

- (void)dealloc {
  [bundle_ release];
  [super dealloc];
}

- (SecCertificateRef)copySignerCertificate {
  SecCertificateRef result = NULL;
  
  CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:[bundle_ bundlePath]];
  if (url) {
    SecStaticCodeRef codeRef;
    if (SecStaticCodeCreateWithPath(url, 0, &codeRef) == noErr) {
      if (SecStaticCodeCheckValidityWithErrors(codeRef, 0,
                                               NULL, NULL) == noErr) {
        CFDictionaryRef signingInfo;
        if (SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation,
                                          &signingInfo) == noErr) {
          CFArrayRef certs = CFDictionaryGetValue(signingInfo,
                                                  kSecCodeInfoCertificates);
          if (certs && CFArrayGetCount(certs)) {
            SecCertificateRef cert;
            cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, 0);
            if (cert) {
              // Make a deep copy of the certificate so that callers can
              // retain it after releasing us (the code signing framework
              // does not like having its own SecCertificateRef retained
              // after the info dictionary is released);
              CSSM_DATA signerDer;
              if (SecCertificateGetData(cert, &signerDer) == noErr) {
                SecCertificateCreateFromData(&signerDer, CSSM_CERT_X_509v3,
                                             CSSM_CERT_ENCODING_DER,
                                             &result);
              }
            }
          }
        }
        CFRelease(signingInfo);
      }
      CFRelease(codeRef);
    }
  }
  
  return result;
}

- (CFArrayRef)copySignerCertificateChain {
  CFMutableArrayRef result = NULL;
  
  CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:[bundle_ bundlePath]];
  if (url) {
    SecStaticCodeRef codeRef;
    if (SecStaticCodeCreateWithPath(url, 0, &codeRef) == noErr) {
      if (SecStaticCodeCheckValidityWithErrors(codeRef, 0,
                                               NULL, NULL) == noErr) {
        CFDictionaryRef signingInfo;
        if (SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation,
                                          &signingInfo) == noErr) {
          CFArrayRef certs = CFDictionaryGetValue(signingInfo,
                                                  kSecCodeInfoCertificates);
          if (certs) {
            for (int i = 0; i < CFArrayGetCount(certs); ++i) {
              SecCertificateRef cert;
              cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, i);
              if (cert) {
                // Make a deep copy of the certificate so that callers can
                // retain it after releasing us (the code signing framework
                // does not like having its own SecCertificateRef retained
                // after the info dictionary is released);
                CSSM_DATA signerDer;
                if (SecCertificateGetData(cert, &signerDer) == noErr) {
                  SecCertificateRef copiedRef;
                  if (SecCertificateCreateFromData(&signerDer, CSSM_CERT_X_509v3,
                                                   CSSM_CERT_ENCODING_DER,
                                                   &copiedRef) == noErr) {
                    if (!result) {
                      result
                        = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
                    }
                    CFArrayAppendValue(result, copiedRef);
                    CFRelease(copiedRef);
                  }
                }
              }
            }
          }
        }
        CFRelease(signingInfo);
      }
      CFRelease(codeRef);
    }
  }
  
  return result;
}

+ (BOOL)certificate:(SecCertificateRef)cert1
            isEqual:(SecCertificateRef)cert2 {
  BOOL result = NO;
  
  if (cert1 && cert2) {
    if (cert1 == cert2) {
      result = YES;
    } else {
      // Compare by doing a memcmp of the two certificates' DER encoding
      CSSM_DATA certDer, signerDer;
      if (SecCertificateGetData(cert1, &certDer) == noErr &&
          SecCertificateGetData(cert2, &signerDer) == noErr &&
          certDer.Length == signerDer.Length &&
          memcmp(certDer.Data, signerDer.Data, certDer.Length) == 0) {
        result = YES;
      }
    }
  }
  
  return result;
}

+ (NSString *)certificateSubjectCommonName:(SecCertificateRef)cert {
  NSString *result = nil;
  if (cert) {
    const CSSM_X509_NAME *name;
    OSStatus err = SecCertificateGetSubject(cert, &name);
    if (err == noErr) {
      for (uint32 rdn = 0; rdn < name->numberOfRDNs; ++rdn) {
        CSSM_X509_RDN rdnRef = name->RelativeDistinguishedName[rdn];
        for (uint32 pair = 0; pair < rdnRef.numberOfPairs; ++pair) {
          CSSM_DATA type = rdnRef.AttributeTypeAndValue[pair].type;
          if (CSSMOID_CommonName.Length == type.Length &&
              memcmp(CSSMOID_CommonName.Data, type.Data,
                     CSSMOID_CommonName.Length) == 0) {
            CSSM_DATA value = rdnRef.AttributeTypeAndValue[pair].value;
            NSData *certCnData = [NSData dataWithBytes:value.Data
                                                length:value.Length];
            NSString *certCnString
              = [[[NSString alloc] initWithData:certCnData
                                       encoding:NSUTF8StringEncoding]
                 autorelease];
            if (!result) {
              result = certCnString;
            } else {
              result = [result stringByAppendingFormat:@", %@", certCnString];
            }
          }
        }
      }
    }
  }
  return result;
}

- (BOOL)generateSignatureUsingIdentity:(SecIdentityRef)identity {
  BOOL result = NO;
  
  if (!bundle_ || !identity) {
    return NO;
  }
  
  // Start by trying to create a standard Mac OS X code signature on the
  // bundle. This works only with bundles containing a Mac executable.
  OSStatus err = fnfErr;
  CFTypeRef keys[] = { kSecCodeSignerIdentity };
  CFTypeRef values[] = { identity };
  CFDictionaryRef parameters
    = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1,
                         &kCFTypeDictionaryKeyCallBacks,
                         &kCFTypeDictionaryValueCallBacks);
  if (parameters) {
    NSURL *url = [NSURL fileURLWithPath:[bundle_ bundlePath]];
    if (url) {
      SecStaticCodeRef codeRef;
      if ((err = SecStaticCodeCreateWithPath((CFURLRef)url, 0,
                                             &codeRef)) == noErr) {
        SecCodeSignerRef signer;
        if (SecCodeSignerCreate(parameters, 0, &signer) == noErr) {
          CFErrorRef errors = NULL;
          err = SecCodeSignerAddSignatureWithErrors(signer, codeRef, 0,
                                                    &errors);
          CFRelease(signer);
        }
        CFRelease(codeRef);
      }
    }
    CFRelease(parameters);
  }
  
  if (err == noErr) {
    // Standard code signing succeeded
    result = YES;
  }
    
  return result;
}

- (HGSSignatureStatus)verifySignature {
  HGSSignatureStatus result = eSignatureStatusInvalid;

  // Try validating the Mac OS X code signature first
  OSStatus err = fnfErr;
  CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:[bundle_ bundlePath]];
  if (url) {
    SecStaticCodeRef codeRef;
    err = SecStaticCodeCreateWithPath(url, 0, &codeRef);
    if (err == noErr) {
      err = SecStaticCodeCheckValidityWithErrors(codeRef, 0, NULL, NULL);
      CFDictionaryRef signingInfo;
      switch (err) {
        case errSecCSUnsigned:
          result = eSignatureStatusUnsigned;
          break;
        case noErr:
          if (SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation,
                                            &signingInfo) == noErr) {
            CFArrayRef certs = CFDictionaryGetValue(signingInfo,
                                                    kSecCodeInfoCertificates);
            if (certs && CFArrayGetCount(certs)) {
              SecCertificateRef cert;
              cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, 0);
              if (cert) {
                // Require a certificate, since our trust model relies on
                // matching certificates between the app and plugins
                result = eSignatureStatusOK;
              }
            }
            CFRelease(signingInfo);
          }
          break;
      }
      CFRelease(codeRef);
    }
  }
  
  return result;
}

- (NSData *)generateDetachedSignature {
  NSData *sigData = nil;
  NSNumber *sigType = nil;
  
  uuid_t uuid;
  uuid_generate(uuid);
  char uuidString[37];
  uuid_unparse(uuid, uuidString);
  NSString *detachedFilePath
    = [NSTemporaryDirectory() stringByAppendingPathComponent:
       [NSString stringWithUTF8String:uuidString]];
  NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSURL fileURLWithPath:detachedFilePath],
                              kSecCodeSignerDetached,
                              kCFNull, kSecCodeSignerIdentity,
                              nil];
  
  OSStatus err = fnfErr;
  CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:[bundle_ bundlePath]];
  if (url) {
    SecStaticCodeRef codeRef;
    err = SecStaticCodeCreateWithPath(url, 0, &codeRef);
    if (err == noErr) {
      SecCodeSignerRef signer;
      if (SecCodeSignerCreate((CFDictionaryRef)parameters, 0,
                              &signer) == noErr) {
        CFErrorRef errors = NULL;
        if (SecCodeSignerAddSignatureWithErrors(signer, codeRef, 0,
                                                &errors) == noErr) {
          // TODO(hawk): There is a race condition at this point. An attacker
          // could conceivably write a different signature to our temp file
          // before we read it, causing us to trust the signature on their
          // malicious plugin. Figure out something to avoid this.
          sigData = [NSData dataWithContentsOfFile:detachedFilePath];
          sigType = [NSNumber numberWithInt:kSignatureTypeStandard];
        } else {
          if (errors) {
            CFStringRef desc = CFErrorCopyDescription(errors);
            if (desc) {
              HGSLog(@"Failed to generate code signature: %@", desc);
              CFRelease(desc);
            }
            CFRelease(errors);
          }
        }
        CFRelease(signer);
      }
      CFRelease(codeRef);
    } else if (err == errSecCSBadObjectFormat) {
      // Not a Mach-o plugin; generate a digest of the scripts, etc. in the
      // Resources directory instead of a traditional code signature
      unsigned char digest[kCodeSignatureDigestLength];
      if ([self digest:digest]) {
        sigData = [NSData dataWithBytes:digest
                                 length:kCodeSignatureDigestLength];
        sigType = [NSNumber numberWithInt:kSignatureTypeDigest];
      }
    } else {
      HGSLog(@"Failed to generate code signature for %@ (%i)", bundle_, err);
    }
  }
  
  NSData *result = nil;
  if (sigData && sigType) {
    NSDictionary *sigDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             sigData, kSignatureDataKey,
                             sigType, kDetachedSignatureTypeKey,
                             [NSDate date], kSignatureDateKey,
                             nil];
    result = [NSKeyedArchiver archivedDataWithRootObject:sigDict];
  }
  
  return result;
}

- (HGSSignatureStatus)verifyDetachedSignature:(NSData *)signature {
  HGSSignatureStatus result = eSignatureStatusInvalid;
  
  NSDictionary *sigDict;
  @try {
    sigDict = [NSKeyedUnarchiver unarchiveObjectWithData:signature];
  }
  @catch (NSException *e) {
   sigDict = nil;
  }
  
  NSData *sigData = [sigDict objectForKey:kSignatureDataKey];
  if (!sigData) {
    return eSignatureStatusInvalid;
  }
  
  int sigType = [[sigDict objectForKey:kDetachedSignatureTypeKey] intValue];
  if (sigType == kSignatureTypeStandard) {
    CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:[bundle_ bundlePath]];
    if (url) {
      SecStaticCodeRef codeRef;
      if (SecStaticCodeCreateWithPath(url, 0, &codeRef) == noErr) {
        if (SecCodeSetDetachedSignature(codeRef,
                                        (CFDataRef)sigData, 0) == noErr) {
          if (SecStaticCodeCheckValidityWithErrors(codeRef, 0, NULL,
                                                   NULL) == noErr) {
            result = eSignatureStatusOK;
          }
        }
        CFRelease(codeRef);
      }
    }
  } else if (sigType == kSignatureTypeDigest) {
    if ([sigData length] == kCodeSignatureDigestLength) {
      unsigned char digest[kCodeSignatureDigestLength];
      if ([self digest:digest] &&
          memcmp(digest, [sigData bytes], kCodeSignatureDigestLength) == 0) {
        result = eSignatureStatusOK;
      }
    }
  }
  
  return result;
}

- (BOOL)digest:(unsigned char *)digest {
  SHA_CTX ctx;
  if (!SHA1_Init(&ctx)) {
    HGSLogDebug(@"Could not instantiate a SHA1 context for plugin signing");
    return NO;
  }
  
  NSString *plistPath
    = [[[bundle_ bundlePath] stringByAppendingPathComponent:@"Contents"]
       stringByAppendingPathComponent:@"Info.plist"];
  NSData *contents = [NSData dataWithContentsOfFile:plistPath];
  if ([contents length]) {
    SHA1_Update(&ctx, [contents bytes], [contents length]);
  } else {
    HGSLogDebug(@"Could not read Info.plist for plugin signing");
    return NO;
  }
  if (![self digestDirectory:[bundle_ resourcePath] shaContext:&ctx]) {
    HGSLogDebug(@"Could not read Info.plist for plugin signing");
    return NO;
  }

  return (SHA1_Final(digest, &ctx) != 0);
}

- (BOOL)digestDirectory:(NSString *)path shaContext:(SHA_CTX *)shaCtx {
  BOOL result = YES;

  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:path];
  if (!dirEnum) {
    return NO;
  }
  NSString *filePath;
  while (result && (filePath = [dirEnum nextObject])) {
    filePath = [path stringByAppendingPathComponent:filePath];
    BOOL isDirectory, succeeded = NO;
    // Should always return YES
    if ([fm fileExistsAtPath:filePath isDirectory:&isDirectory]) {
      if (!isDirectory) {
        // Must be digestable
        if ([fm isReadableFileAtPath:filePath]) {
          // Must be able to get file attributes
          NSDictionary *attrs = [fm fileAttributesAtPath:path traverseLink:YES];
          if (attrs) {
            NSNumber *size = [attrs objectForKey:NSFileSize];
            if (size && [size unsignedLongLongValue] <= 0xFFFFFFFFLL) {
              // SHA1_Update() takes the length as an unsigned long
              if (result && [size unsignedLongLongValue] > 0) {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                NSData *contents = [NSData dataWithContentsOfFile:filePath];
                if (contents) {
                  if (SHA1_Update(shaCtx, [contents bytes], [contents length])) {
                      succeeded = YES;
                  }
                }
                [pool release];
              }
            }
          }
        }
      } else {
        // Recurse into the directory
        succeeded = [self digestDirectory:filePath shaContext:shaCtx];
      }
    }
    result = succeeded;
  }

  return result;
}

@end

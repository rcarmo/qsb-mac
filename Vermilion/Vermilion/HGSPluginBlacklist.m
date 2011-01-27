//
//  HGSPluginBlacklist.m
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

#import "HGSPluginBlacklist.h"
#import "HGSPluginLoader.h"
#import "HGSDelegate.h"
#import "HGSLog.h"
#import "HGSCodeSignature.h"
#import "GTMObjectSingleton.h"
#import <GData/GDataHTTPFetcher.h>
#import <stdlib.h>

static NSString* const kHGSPluginBlacklistFile = @"PluginBlacklist";
static NSString* const kHGSPluginBlacklistVersionKey = @"HGSPBVersion";
static NSString* const kHGSPluginBlacklistEntriesKey = @"HGSPBEntries";
static NSString* const kHGSPluginBlacklistLastUpdateKey = @"HGSPBLastUpdate";
static NSString* const kHGSPluginBlacklistVersion = @"1";
static NSString* const kHGSPluginBlacklistGuidKey = @"HGSPBGuidKey";
static NSString* const kHGSPluginBlacklistOverridesKey = @"HGSPBOverridesKey";
static NSString* const kHGSPluginBlacklistCommonNameKey = @"HGSPBCNKey";
static NSString* const kHGSPluginBlacklistInfoPlistKey = @"HGSPluginBlacklistURL";
static const NSTimeInterval kHGSPluginBlacklistUpdateInterval = 86400; // 1 day
static const NSTimeInterval kHGSPluginBlacklistJitterRange = 3600; // 1 hour
NSString* kHGSBlacklistUpdatedNotification = @"HGSBlacklistUpdatedNotification";

@interface HGSPluginBlacklist()
- (NSTimeInterval)jitter;
@end

@implementation HGSPluginBlacklist

GTMOBJECT_SINGLETON_BOILERPLATE(HGSPluginBlacklist, sharedPluginBlacklist);

@synthesize blacklistPath = blacklistPath_;

- (id)init {
  self = [super init];
  if (self) {
    arc4random_stir();
    id<HGSDelegate> delegate = [[HGSPluginLoader sharedPluginLoader] delegate];
    NSString *appSupportPath = [delegate userCacheFolderForApp];
    blacklistPath_
      = [[appSupportPath
         stringByAppendingPathComponent:kHGSPluginBlacklistFile] retain];
    NSTimeInterval lastUpdate = 0;
    if (blacklistPath_) {
      @try {
        NSDictionary *blacklist
          = [NSDictionary dictionaryWithContentsOfFile:blacklistPath_];
        if (blacklist) {
          NSString *version
            = [blacklist objectForKey:kHGSPluginBlacklistVersionKey];
          if ([version isEqualToString:kHGSPluginBlacklistVersion]) {
            blacklistedPlugins_
              = [[blacklist objectForKey:kHGSPluginBlacklistEntriesKey] retain];
            lastUpdate
              = [[blacklist objectForKey:kHGSPluginBlacklistLastUpdateKey]
                 doubleValue];
          }
        }
      }
      @catch(NSException *e) {
        HGSLog(@"Unable to load blacklist for %@ (%@)", self, e);
      }
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (lastUpdate < now - (int)kHGSPluginBlacklistUpdateInterval) {
      [self updateBlacklist:self];
    } else {
      NSTimeInterval interval
        = kHGSPluginBlacklistUpdateInterval + [self jitter];
      updateTimer_
        = [NSTimer scheduledTimerWithTimeInterval:interval
                                           target:self
                                         selector:@selector(updateBlacklist:)
                                         userInfo:nil
                                          repeats:NO];
    }
  }
  return self;
}

// COV_NF_START
// Singleton, so this is never called.
- (void)dealloc {
  if ([updateTimer_ isValid]) {
    [updateTimer_ invalidate];
  }
  [blacklistPath_ release];
  [blacklistedPlugins_ release];
  [super dealloc];
}
// COV_NF_END

- (BOOL)bundleIDIsBlacklisted:(NSString *)bundleID {
  BOOL isBlacklisted = NO;
  bundleID = [bundleID lowercaseString];
  @synchronized(self) {
    for (NSDictionary *entry in blacklistedPlugins_) {
      if ([[entry objectForKey:kHGSPluginBlacklistGuidKey] isEqual:bundleID]) {
        isBlacklisted = YES;
      }
    }
  }
  return isBlacklisted;
}

- (BOOL)bundleIsBlacklisted:(NSBundle *)pluginBundle {
  BOOL isBlacklisted = NO;
  NSString *bundleID = [[pluginBundle bundleIdentifier] lowercaseString];
  @synchronized(self) {
    for (NSDictionary *entry in blacklistedPlugins_) {
      if ([[entry objectForKey:kHGSPluginBlacklistGuidKey] isEqual:bundleID]) {
        isBlacklisted = YES;
        if ([[entry objectForKey:kHGSPluginBlacklistOverridesKey] boolValue]) {
          // This blacklist entry can be overriden if the plugin has a code
          // signature from a certificate signed by a CA trusted by the
          // system, such as Verisign
          HGSCodeSignature *sig
            = [HGSCodeSignature codeSignatureForBundle:pluginBundle];
          if ([sig verifySignature] == eSignatureStatusOK) {
            CFArrayRef certArray = [sig copySignerCertificateChain];
            if (certArray) {
              OSStatus err;
              SecPolicySearchRef searchRef = NULL;
              err = SecPolicySearchCreate(CSSM_CERT_X_509v3,
                                          &CSSMOID_APPLE_X509_BASIC, NULL,
                                          &searchRef);
              if (err == noErr) {
                SecPolicyRef policyRef = NULL;
                err = SecPolicySearchCopyNext(searchRef, &policyRef);
                if (err == noErr) {
                  SecTrustRef trustRef = NULL;
                  err = SecTrustCreateWithCertificates(certArray, policyRef,
                                                       &trustRef);
                  if (err == noErr) {
                    SecTrustResultType trustResult;
                    err = SecTrustEvaluate(trustRef, &trustResult);
                    if (err == noErr &&
                        (trustResult == kSecTrustResultProceed ||
                         trustResult == kSecTrustResultUnspecified)) {
                      // Certificate is trusted, match the Common Name
                      NSString *blacklistCommonName
                        = [entry objectForKey:kHGSPluginBlacklistCommonNameKey];
                      if (blacklistCommonName) {
                        SecCertificateRef cert
                          = (SecCertificateRef)CFArrayGetValueAtIndex(certArray,
                                                                      0);
                        NSString *certificateCommonName
                          = [HGSCodeSignature certificateSubjectCommonName:cert];
                        if ([certificateCommonName isEqual:blacklistCommonName]) {
                          isBlacklisted = NO;
                        }
                      }
                    }
                    CFRelease(trustRef);
                  }
                  CFRelease(policyRef);
                }
                CFRelease(searchRef);
              }
              CFRelease(certArray);
            }
          }
        }
      }
    }
  }
  return isBlacklisted;
}

-(void)updateBlacklist:(id)sender {
  NSBundle *bnd = [NSBundle bundleForClass:[self class]];
  NSString *urlString
    = [[bnd infoDictionary] valueForKey:kHGSPluginBlacklistInfoPlistKey];
  if (urlString) {
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    GDataHTTPFetcher *fetcher
      = [GDataHTTPFetcher httpFetcherWithRequest:request];
    [fetcher setIsRetryEnabled:YES];
    [fetcher beginFetchWithDelegate:self
                  didFinishSelector:@selector(blacklistFetcher:
                                              finishedWithData:)
                    didFailSelector:@selector(blacklistFetcher:
                                              failedWithError:)];
    if ([updateTimer_ isValid]) {
      [updateTimer_ invalidate];
    }
    NSTimeInterval interval = kHGSPluginBlacklistUpdateInterval + [self jitter];
    updateTimer_
      = [NSTimer scheduledTimerWithTimeInterval:interval
                                         target:self
                                       selector:@selector(updateBlacklist:)
                                       userInfo:nil
                                        repeats:NO];
  } else {
    HGSLog(@"Unable to get blacklist URL for %@", self);
  }
}

- (NSTimeInterval)jitter {
  return (NSTimeInterval)(arc4random() % (int)kHGSPluginBlacklistJitterRange);
}

- (void)blacklistFetcher:(GDataHTTPFetcher *)fetcher
        finishedWithData:(NSData *)data {
  NSInteger statusCode = [fetcher statusCode];
  if (statusCode == 200) {
    [self updateBlacklistWithData:data];
  } else {
    HGSLog(@"Unable to refresh blacklist for %@ (%i)", self, statusCode);
  }
}

- (void)updateBlacklistWithData:(NSData *)data {
  NSError *error;
  NSXMLDocument *doc
    = [[[NSXMLDocument alloc] initWithData:data
                                    options:0
                                      error:&error] autorelease];
  if (doc) {
    NSMutableArray *newBlacklist = [NSMutableArray array];
    NSArray *plugins = [doc nodesForXPath:@"//plugin" error:nil];
    for (NSXMLNode *plugin in plugins) {
      NSString *guid = nil, *cn = @"";
      NSNumber *overrides = nil;
      for (NSXMLNode *node in [plugin children]) {
        if ([[node name] isEqual:@"guid"]) {
          guid = [[node stringValue] lowercaseString];
        } else if ([[node name] isEqual:@"overrides"]) {
          if ([[[node stringValue] lowercaseString] isEqual:@"true"]) {
            overrides = [NSNumber numberWithBool:YES];
          }
        } else if ([[node name] isEqual:@"cn"]) {
          cn = [node stringValue];
        }
      }
      if (guid) {
        if (!overrides || ![cn length]) {
          // Default to not allowing overrides
          overrides = [NSNumber numberWithBool:NO];
        }
        NSDictionary *entry
          = [NSDictionary dictionaryWithObjectsAndKeys:
             guid, kHGSPluginBlacklistGuidKey,
             overrides, kHGSPluginBlacklistOverridesKey,
             cn, kHGSPluginBlacklistCommonNameKey,
             nil];
        [newBlacklist addObject:entry];
      }
    }
    @synchronized(self) {
      [blacklistedPlugins_ release];
      blacklistedPlugins_ = [newBlacklist retain];
      NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
      NSDictionary *cacheDict =
        [NSDictionary dictionaryWithObjectsAndKeys:
         kHGSPluginBlacklistVersion, kHGSPluginBlacklistVersionKey,
         blacklistedPlugins_, kHGSPluginBlacklistEntriesKey,
         [NSNumber numberWithDouble:now], kHGSPluginBlacklistLastUpdateKey,
         nil];
      if (![cacheDict writeToFile:blacklistPath_ atomically:YES]) {
        HGSLogDebug(@"Unable to save blacklist to %@", blacklistPath_);
      }
    }
  } else {
    HGSLog(@"Unable to refresh blacklist for %@ (%@)", self, error);
  }
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSBlacklistUpdatedNotification object:self];
}

- (void)blacklistFetcher:(GDataHTTPFetcher *)fetcher
         failedWithError:(NSError *)error {
  HGSLog(@"Unable to refresh blacklist for %@ (%@)", self, error);
}

@end

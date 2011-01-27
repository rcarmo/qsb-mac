//
//  GoogleAccount.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
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

#import "GoogleAccount.h"
#import "GoogleAccountSetUpViewController.h"
#import "GTMMethodCheck.h"
#import "GTMNSString+URLArguments.h"
#import "HGSGoogleAccountTypes.h"
#import "HGSLog.h"
#import "GTMGoogleSearch.h"
#import <GData/GData.h>
#import <GData/GDataAuthenticationFetcher.h>

static NSString *const kGoogleDomain = @"@google.com";
static NSString *const kGoogleUKDomain = @"@google.co.uk";
static NSString *const kGoogleAccountType = @"GOOGLE";
static NSString *const kGoogleCorpAccountType = @"HOSTED_OR_GOOGLE";
static NSString *const kHostedAccountType = @"HOSTED";
static NSString *const kCaptchaImageURLPrefix
  = @"http://www.google.com/accounts/";
static NSString *const kGoogleAccountAsynchAuth = @"GoogleAccountAsynchAuth";

static NSString *const kHGSGoogleAccountForceNonhostedKey
  = @"HGSGoogleAccountForceNonhostedKey";

// Authentication timing constants.
static const NSTimeInterval kAuthenticationRetryInterval = 0.1;
static const NSTimeInterval kAuthenticationGiveUpInterval = 30.0;


@interface GoogleAccountSetUpViewController ()

@property (nonatomic, getter=isGoogleAppsCheckboxShowing)
  BOOL googleAppsCheckboxShowing;
@property (nonatomic, getter=isWindowSizesDetermined) BOOL windowSizesDetermined;

// Pre-determine the various window heights.
- (void)determineWindowSizes;

// Determine height of window based on checkbox and captcha presentation.
- (CGFloat)windowHeightWithCheckboxShowing:(BOOL)googleAppsCheckboxShowing
                            captchaShowing:(BOOL)captchaShowing;
@end


@interface GoogleAccount ()

@property (nonatomic, assign) BOOL authCompleted;
@property (nonatomic, assign) BOOL authSucceeded;
@property (nonatomic, assign) BOOL forceNonHosted;

// Common function for preparing an authentication fetcher.
// TODO(mrossetti): 1960732: Rework |accountType| when addressed.
- (GDataHTTPFetcher *)authFetcherForPassword:(NSString *)password
                                  parameters:(NSDictionary *)params
                                 accountType:(NSString *)accountType;

// Determine the default account type based on the class and composition
// of the account name (called |userName|).
- (NSString *)accountType;

// Check the authentication results to see if the account authenticated.
- (BOOL)validateResult:(NSData *)result;

// Fetched delegate methods
- (void)fetcher:(GDataHTTPFetcher *)authFetcher finishedWithData:(NSData *)data;
- (void)fetcher:(GDataHTTPFetcher *)authFetcher failedWithError:(NSError *)error;

@end


@implementation GoogleAccount

GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);

@synthesize captchaImage = captchaImage_;
@synthesize captchaText = captchaText_;
@synthesize captchaToken = captchaToken_;
@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;
@synthesize forceNonHosted = forceNonHosted_;

- (id)initWithConfiguration:(NSDictionary *)prefDict {
  if ((self = [super initWithConfiguration:prefDict])) {
    NSNumber *forcedNonHostedNumber
      = [prefDict objectForKey:kHGSGoogleAccountForceNonhostedKey];
    if (forcedNonHostedNumber) {
      forceNonHosted_ = [forcedNonHostedNumber boolValue];
    }
  }
  return self;
}

- (void)dealloc {
  [captchaImage_ release];
  [captchaText_ release];
  [captchaToken_ release];
  [super dealloc];
}

- (NSDictionary *)configuration {
  NSDictionary *accountDict = [super configuration];
  HGSAssert(accountDict, @"HGSAccount should be providing a configuration.");
  if ([self forceNonHosted]) {
    NSMutableDictionary *newDict
      = [NSMutableDictionary dictionaryWithDictionary:accountDict];
    [newDict setObject:[NSNumber numberWithBool:YES]
                forKey:kHGSGoogleAccountForceNonhostedKey];
    accountDict = newDict;
  }
  return accountDict;
}

- (NSString *)type {
  return kHGSGoogleAccountType;
}

- (NSString *)adjustUserName:(NSString *)userName {
  if ([userName rangeOfString:@"@"].location == NSNotFound) {
    NSString *countryGMailCom
      = HGSLocalizedString(@"@gmail.com", @"The gmail domain extension.");
    userName = [userName stringByAppendingString:countryGMailCom];
  }
  return userName;
}

- (void)authenticate {
  NSDictionary *parameters = nil;
  NSString *captchaText = [self captchaText];
  if ([captchaText length]) {
    NSString *captchaToken = [self captchaToken];
    parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                  captchaToken, @"logintoken",
                  captchaText, @"logincaptcha",
                  nil];
    // Clear for next time.
    [self setCaptchaImage:nil];
    [self setCaptchaText:nil];
    [self setCaptchaToken:nil];
  }
  NSString *password = [self password];
  NSString *accountType = [self accountType];
  if ([self forceNonHosted]) {
    accountType = kGoogleCorpAccountType;
  }
  GDataHTTPFetcher *authFetcher = [self authFetcherForPassword:password
                                                    parameters:parameters
                                                   accountType:accountType];
  if (authFetcher) {
    [authFetcher setProperty:@"YES" forKey:kGoogleAccountAsynchAuth];
    [authFetcher beginFetchWithDelegate:self
                      didFinishSelector:@selector(fetcher:finishedWithData:)
                        didFailSelector:@selector(fetcher:failedWithError:)];
  } else {
    // Failed to authenticate because we could not compose an authRequest.
    [self setAuthenticated:NO];
  }
}

- (BOOL)authenticateWithPassword:(NSString *)password {
  // Test this account to see if we can connect.
  BOOL authenticated = NO;
  BOOL hosted = [self isKindOfClass:[GoogleAppsAccount class]];
  NSString *accountType = [self accountType];
  GDataHTTPFetcher *authFetcher = [self authFetcherForPassword:password
                                                    parameters:nil
                                                   accountType:accountType];
  if (authFetcher) {
    [self setAuthCompleted:NO];
    [self setAuthSucceeded:NO];
    [authFetcher beginFetchWithDelegate:self
                      didFinishSelector:@selector(fetcher:finishedWithData:)
                        didFailSelector:@selector(fetcher:failedWithError:)];
    // Block until this fetch is done to make it appear synchronous.  Just in
    // case, put an upper limit of 30 seconds before we bail.
    [[authFetcher request] setTimeoutInterval:kAuthenticationGiveUpInterval];
    NSRunLoop* loop = [NSRunLoop currentRunLoop];
    while (![self authCompleted]) {
      NSDate *sleepTilDate
        = [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
      [loop runUntilDate:sleepTilDate];
    }
    authenticated = [self authSucceeded];
  }

  if (!authenticated && hosted) {
    // Try again, this time forcing non-hosted.
    authFetcher = [self authFetcherForPassword:password
                                    parameters:nil
                                   accountType:kGoogleCorpAccountType];
    if (authFetcher) {
      [self setAuthCompleted:NO];
      [authFetcher beginFetchWithDelegate:self
                        didFinishSelector:@selector(fetcher:finishedWithData:)
                          didFailSelector:@selector(fetcher:failedWithError:)];
      // Block until this fetch is done to make it appear synchronous.  Just in
      // case, put an upper limit of 30 seconds before we bail.
      [[authFetcher request] setTimeoutInterval:kAuthenticationGiveUpInterval];
      NSRunLoop* loop = [NSRunLoop currentRunLoop];
      while (![self authCompleted]) {
        NSDate *sleepTilDate
          = [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
        [loop runUntilDate:sleepTilDate];
      }
      authenticated = [self authSucceeded];
      // If it succeeded then force this in the future.
      // Note: At some point (i.e. when 1960732 has been fixed) accounts for
      // which |forceNonHosted| has been set will fail to authenticate at
      // QSB startup.  The user will need to remove and re-add such accounts
      // at that time, at least until this temporary work-around code is
      // removed and a new release is sent out.
      [self setForceNonHosted:authenticated];
    }
  }
  return authenticated;
}

- (GDataHTTPFetcher *)authFetcherForPassword:(NSString *)password
                                  parameters:(NSDictionary *)params
                                 accountType:(NSString *)accountType {
  NSString *userName = [self userName];
#ifdef REENABLE_WHEN_1960732_HAS_BEEN_ADDRESSED
  NSString *accountType = kHostedAccountType;
  BOOL hosted = [self isKindOfClass:[GoogleAppsAccount class]];
  if (!hosted) {
    accountType = kGoogleAccountType;
    NSRange atRange = [userName rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
      NSString *domainString = [userName substringFromIndex:atRange.location];
      if ([GoogleAccount isMatchToGoogleDomain:domainString]) {
        accountType = kGoogleCorpAccountType;
      }
    }
  }
#endif  // REENABLE_WHEN_1960732_HAS_BEEN_ADDRESSED

  // Validate the account using the contacts service since a basic account
  // should have at least mail service with contacts.
  NSString *serviceID = [GDataServiceGoogleContact serviceID];
  GDataHTTPFetcher *authFetcher
    = [GDataAuthenticationFetcher authTokenFetcherWithUsername:userName
                                                      password:password
                                                       service:serviceID
                                                        source:@"google-qsb-1.0"
                                                  signInDomain:nil
                                                   accountType:accountType
                                          additionalParameters:params
                                                 customHeaders:nil];
  if (!authFetcher) {
    HGSLog(@"Failed to allocate GDataAuthenticationFetcher.");
  }
  return authFetcher;
}

- (NSString *)accountType {
  NSString *accountType = kHostedAccountType;
  BOOL hosted = [self isKindOfClass:[GoogleAppsAccount class]];
  if (!hosted) {
    accountType = kGoogleAccountType;
    NSString *userName = [self userName];
    NSRange atRange = [userName rangeOfString:@"@"];
    if (atRange.location != NSNotFound) {
      NSString *domainString = [userName substringFromIndex:atRange.location];
      if ([GoogleAccount isMatchToGoogleDomain:domainString]) {
        accountType = kGoogleCorpAccountType;
      }
    }
  }
  return accountType;
}

- (BOOL)validateResult:(NSData *)result {
  BOOL validated = NO;
  NSString *answer = [[[NSString alloc] initWithData:result
                                            encoding:NSUTF8StringEncoding]
                      autorelease];
  // Simple test to see if the string contains 'SID=' and 'LSID='.
  NSDictionary *responseDict
    = [GDataUtilities dictionaryWithResponseString:answer];
  validated = ([responseDict objectForKey:@"SID"]
               && [responseDict objectForKey:@"LSID"]);
  if (!validated) {
    HGSLog(@"Authentication for account '%@' failed with a "
           @"response of '%@'.", [self displayName], answer);
  }
  return validated;
}

+ (BOOL)isMatchToGoogleDomain:(NSString *)domain {
  // TODO(mrossetti): Determine if it is sufficient to test the domain
  // against '@google.~'.
  NSComparisonResult result
    = [kGoogleDomain compare:domain options:NSCaseInsensitiveSearch];
  if (result != NSOrderedSame) {
    result = [kGoogleUKDomain compare:domain
                              options:NSCaseInsensitiveSearch];
  }
  return (result == NSOrderedSame);
}

+ (BOOL)isPartialMatchToGoogleDomain:(NSString *)domain {
  BOOL isPartialMatch = NO;
  NSUInteger domainLength = [domain length];
  NSUInteger googleDomainLength = [kGoogleDomain length];
  NSUInteger googleUKDomainLength = [kGoogleUKDomain length];
  NSRange domainRange = NSMakeRange(0, domainLength);
  if (domainLength <= googleDomainLength) {
    NSComparisonResult googleResult
      = [kGoogleDomain compare:domain
                       options:NSCaseInsensitiveSearch
                         range:domainRange];
    isPartialMatch = (googleResult == NSOrderedSame);
  }
  if (!isPartialMatch && domainLength <= googleUKDomainLength) {
    NSComparisonResult googleResult
      = [kGoogleUKDomain compare:domain
                         options:NSCaseInsensitiveSearch
                           range:domainRange];
    isPartialMatch = (googleResult == NSOrderedSame);
  }
  return isPartialMatch;
}

+ (BOOL)openGoogleHomePage {
  GTMGoogleSearch *gsearch = [GTMGoogleSearch sharedInstance];
  NSString *url = [gsearch searchURLFor:nil ofType:@"webhp" arguments:nil];
  NSURL *googleURL = [NSURL URLWithString:url];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:googleURL];
  if (!success) {
    HGSLogDebug(@"Failed to open %@", googleURL);
    NSBeep();
  }
  return success;
}

#pragma mark GDataAuthenticationFetcher Delegate Methods

- (void)fetcher:(GDataHTTPFetcher *)authFetcher finishedWithData:(NSData *)data {
  // An authentication may be synchronous or asynchronous.  The latter is
  // indicated by the presence of the property key below.
  BOOL authenticated = [self validateResult:data];
  if ([authFetcher propertyForKey:kGoogleAccountAsynchAuth]) {
    [self setAuthenticated:authenticated];
  } else {
    // Signal the runLoop that the fetch has completed.
    [self setAuthCompleted:YES];
    [self setAuthSucceeded:authenticated];
  }
}

- (void)fetcher:(GDataHTTPFetcher *)authFetcher failedWithError:(NSError *)error {
  // An authentication may be synchronous or asynchronous.  The latter is
  // indicated by the presence of the property key below. Extract information
  // from the header for logging purposes as well as to detect a captcha
  // request.
  NSDictionary *userInfo = [error userInfo];
  NSMutableArray *messages = [NSMutableArray array];
  NSString *dataString = nil;  // Keep for detecting the captcha request.
  if (userInfo) {
    // Add a string to the diagnostic message for each item in userInfo.
    for (NSString *key in userInfo) {
      if ([key isEqualToString:kGDataHTTPFetcherStatusDataKey]) {
        NSData *data = [userInfo objectForKey:kGDataHTTPFetcherStatusDataKey];
        if ([data length]) {
          dataString = [[[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding]
                        autorelease];
          if (dataString) {
            [messages addObject:[NSString stringWithFormat:@"data: %@",
                                 dataString]];
          }
        }
      } else {
        NSString *value = [userInfo objectForKey:key];
        NSString *infoString = [NSString stringWithFormat:@"%@: %@",
                                key, value];
        [messages addObject:infoString];
      }
    }
  }
  if ([authFetcher propertyForKey:kGoogleAccountAsynchAuth]) {
    [self setAuthenticated:NO];
  } else {
    // Signal the runLoop that the fetch has completed and check for
    // a captcha request.
    [self setAuthCompleted:YES];
    [self setAuthSucceeded:NO];
    NSString *captchaToken = nil;
    NSString *captchaImageURLString = nil;
    NSString *const captchaTokenKey = @"CaptchaToken";
    NSString *const captchaImageURLKey = @"CaptchaUrl";
    if (dataString) {
      NSDictionary *responseInfo
        = [GDataUtilities dictionaryWithResponseString:dataString];
      captchaToken = [responseInfo objectForKey:captchaTokenKey];
      captchaImageURLString = [responseInfo objectForKey:captchaImageURLKey];
      if ([captchaToken length] && [captchaImageURLString length]) {
        // Retrieve the captcha image.
        NSString *fullURLString
          = [kCaptchaImageURLPrefix
             stringByAppendingString:captchaImageURLString];
        NSURL *captchaImageURL = [NSURL URLWithString:fullURLString];
        NSImage *captchaImage
          = [[[NSImage alloc] initWithContentsOfURL:captchaImageURL]
             autorelease];
        if (captchaImage) {
          [self setCaptchaToken:captchaToken];
          [self setCaptchaImage:captchaImage];
          HGSLog(@"Authentication for account '%@' requires captcha.",
                 [self displayName]);
        } else {
          HGSLog(@"Authentication for account '%@' requires captcha but "
                 @"failed to retrieve the captcha image from URL '%@'.",
                 [self displayName], fullURLString);
        }
      }
    }
  }
  NSString *userInfoString = [messages componentsJoinedByString:@", "];
  HGSLog(@"Authentication of account '%@' failed with error %d. "
         @"Reason: '%@'.  UserInfo: '%@'", [self displayName], [error code],
         [error localizedFailureReason], userInfoString);
}

@end


@implementation GoogleAppsAccount

- (NSString *)type {
  return kHGSGoogleAppsAccountType;
}

@end

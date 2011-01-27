//
//  HGSAppleScriptAction.m
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

#import "HGSAppleScriptAction.h"
#import "HGSLog.h"
#import "HGSBundle.h"
#import "HGSUserMessage.h"
#import "GTMNSAppleScript+Handler.h"
#import "HGSResult.h"
#import "GTMNSWorkspace+Running.h"
#import "GTMMethodCheck.h"
#import "GTMNSAppleEventDescriptor+Foundation.h"

NSString *const kHGSAppleScriptFileNameKey = @"HGSAppleScriptFileName";
NSString *const kHGSAppleScriptHandlerNameKey = @"HGSAppleScriptHandlerName";
NSString *const kHGSAppleScriptApplicationsKey = @"HGSAppleScriptApplications";
NSString *const kHGSAppleScriptBundleIDKey = @"HGSAppleScriptBundleID";
NSString *const kHGSAppleScriptMustBeRunningKey 
  = @"HGSAppleScriptMustBeRunning";
static NSString *const kHGSOpenDocAppleEvent = @"aevtodoc";
static NSString *const kHGSAppleScriptErrorUserMessageName 
  = @"HGSAppleScriptErrorUserMessageName";
@interface HGSAppleScriptAction ()
- (BOOL)requiredAppsRunning:(HGSResultArray *)results;
@end

@implementation HGSAppleScriptAction
GTM_METHOD_CHECK(NSWorkspace, gtm_isAppWithIdentifierRunning:);
GTM_METHOD_CHECK(NSAppleScript, gtm_hasOpenDocumentsHandler);
GTM_METHOD_CHECK(NSAppleScript, gtm_executePositionalHandler:parameters:error:); 
GTM_METHOD_CHECK(NSAppleScript, gtm_executeAppleEvent:error:); 
GTM_METHOD_CHECK(NSAppleScript, gtm_appleEventDescriptor);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSString *fileName = [configuration objectForKey:kHGSAppleScriptFileNameKey];
    if (!fileName) {
      fileName = @"main";
    }
    NSBundle *bundle = [self bundle];
    scriptPath_ = [bundle pathForResource:fileName 
                                   ofType:@"scpt" 
                              inDirectory:@"Scripts"];
    if (!scriptPath_) {
      scriptPath_ = [bundle pathForResource:fileName 
                                     ofType:@"applescript" 
                                inDirectory:@"Scripts"];
    }
    if (!scriptPath_) {
      [self release];
      self = nil;
      HGSLog(@"Unable to locate script %@", fileName);
    } else {
      [scriptPath_ retain];
      handlerName_ = [configuration objectForKey:kHGSAppleScriptHandlerNameKey];
      if (!handlerName_ && [script_ gtm_hasOpenDocumentsHandler]) {
        handlerName_ = kHGSOpenDocAppleEvent;
      }
      [handlerName_ retain];
      requiredApplications_ 
        = [[configuration objectForKey:kHGSAppleScriptApplicationsKey] 
           retain];
    }
  }
  return self;
}

- (void)dealloc {
  [handlerName_ release];
  [requiredApplications_ release];
  [scriptPath_ release];
  [script_ release];
  [super dealloc];
}

- (BOOL)requiredAppsRunning:(HGSResultArray *)results {
  BOOL areRunning = YES;
  NSMutableArray *resultBundleIDs = nil;
  if (results) {
    NSInteger count = [results count];
    resultBundleIDs = [NSMutableArray arrayWithCapacity:count];
    for (HGSResult *result in  results) {
      NSString *bundleID = [result valueForKey:kHGSObjectAttributeBundleIDKey];
      if (bundleID) {
        [resultBundleIDs addObject:bundleID];
      }
    }
  }
  if (areRunning) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    for (NSDictionary *requiredApp in requiredApplications_) {
      NSString *bundleID 
        = [requiredApp objectForKey:kHGSAppleScriptBundleIDKey];
      if (resultBundleIDs) {
        areRunning = [resultBundleIDs containsObject:bundleID];
      }
      if (areRunning) {
        NSNumber *nsRunning 
          = [requiredApp objectForKey:kHGSAppleScriptMustBeRunningKey];
        if (nsRunning) {
          BOOL running = [nsRunning boolValue];
          if (running) {
            areRunning = [ws gtm_isAppWithIdentifierRunning:bundleID];
          }
        }
      }
      if (!areRunning) break;
    }
  }
  return areRunning;
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = NO;
  if (requiredApplications_) {
    doesApply = [self requiredAppsRunning:results];
  } else {
    doesApply = [super appliesToResults:results];
  }
  return doesApply;
}

- (BOOL)showInGlobalSearchResults {
  BOOL showInResults = [super showInGlobalSearchResults];
  if (showInResults) {
    showInResults = [self requiredAppsRunning:nil];
  }
  return showInResults;
}

- (void)loadScript {
  NSDictionary *err = nil;
  NSURL *url = [NSURL fileURLWithPath:scriptPath_];
  script_ = [[NSAppleScript alloc] initWithContentsOfURL:url error:&err];
  if (!script_) {
    HGSLog(@"Unable to load script at %@ (%@)", scriptPath_, err);
  }
}

- (void)handleLocalizedString:(NSAppleEventDescriptor *)event 
               withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
  NSAppleEventDescriptor *stringDesc 
    = [event descriptorForKeyword:keyDirectObject];
  NSString *string = [stringDesc stringValue];
  NSString *localizedString = [[self bundle] localizedStringForKey:string 
                                                             value:string 
                                                             table:nil];
  NSAppleEventDescriptor *localizedStringDesc
    = [NSAppleEventDescriptor descriptorWithString:localizedString];
  [replyEvent setDescriptor:localizedStringDesc
                 forKeyword:keyDirectObject];
}

- (void)installLocalizedStringHandler {
  NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
  [manager setEventHandler:self 
               andSelector:@selector(handleLocalizedString:withReplyEvent:) 
             forEventClass:'appS' 
                andEventID:'locS'];
}

- (void)uninstallLocalizedStringHandler {
  NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
  [manager removeEventHandlerForEventClass:'appS' andEventID:'locS'];
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  // If we have a handler we call it
  // if not and it supports open, we call that
  // otherwise we just run the script.
  
  // TODO(dmaclach): Give applescripts a way to return results.
  BOOL wasGood = NO;
  @synchronized(self) {
    [self installLocalizedStringHandler];
    if (!script_) {
      [self performSelectorOnMainThread:@selector(loadScript) 
                             withObject:nil 
                          waitUntilDone:YES];
    }
    wasGood = script_ != nil;
  }
  if (wasGood) {
    NSDictionary *error = nil;
    if (handlerName_) {
      HGSResultArray *directObjects 
        = [info objectForKey:kHGSActionDirectObjectsKey];
      if ([handlerName_ isEqualToString:kHGSOpenDocAppleEvent]) {
        NSArray *urls = [directObjects urls];
        NSAppleEventDescriptor *target 
          = [[NSProcessInfo processInfo] gtm_appleEventDescriptor];
        NSAppleEventDescriptor *openDoc 
          = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass 
                                                     eventID:kAEOpenDocuments
                                            targetDescriptor:target 
                                                    returnID:kAutoGenerateReturnID 
                                               transactionID:kAnyTransactionID];
        [openDoc setParamDescriptor:[urls gtm_appleEventDescriptor]
                         forKeyword:keyDirectObject];
        [script_ gtm_executeAppleEvent:openDoc error:&error];
      } else {
        NSMutableArray *params 
          = [NSMutableArray arrayWithCapacity:[directObjects count]];
        for (HGSResult *hgsResult in directObjects) {
          NSString *urlString = [hgsResult uri];
          NSString *title = [hgsResult displayName];
          NSAppleEventDescriptor *record 
            = [NSAppleEventDescriptor recordDescriptor];
          NSAppleEventDescriptor *desc = [title gtm_appleEventDescriptor];
          if (desc) {
            [record setDescriptor:[title gtm_appleEventDescriptor]
                       forKeyword:pName];
          } else {
            HGSLogDebug(@"Unable to convert %@ to an appleEventDescriptor",
                        title);
          }
          desc = [urlString gtm_appleEventDescriptor];
          if (desc) {
            [record setDescriptor:desc
                       forKeyword:'pURI'];
          } else {
            HGSLogDebug(@"Unable to convert %@ to an appleEventDescriptor",
                        urlString);
          }
          [params addObject:record];
        }  
        [script_ gtm_executePositionalHandler:handlerName_ 
                                   parameters:[NSArray arrayWithObject:params] 
                                        error:&error];
      }
    } else {
      [script_ executeAndReturnError:&error];
    }
    if (!error) {
      wasGood = YES;
    } else {
      wasGood = NO;
      NSString *summary 
        = HGSLocalizedString(@"AppleScript Error", 
                             @"A dialog title denoting an error caused while "
                             @"attempting to execute an AppleScript");
      NSString *description = [NSString stringWithFormat:@"%@\nError: %@", 
                               [error objectForKey:@"NSAppleScriptErrorMessage"],
                               [error objectForKey:@"NSAppleScriptErrorNumber"]];
      [HGSUserMessenger displayUserMessage:summary 
                               description:description 
                                      name:kHGSAppleScriptErrorUserMessageName 
                                     image:nil 
                                      type:kHGSUserMessageErrorType];
    }
    [self uninstallLocalizedStringHandler];
  }
  return wasGood;
}


@end

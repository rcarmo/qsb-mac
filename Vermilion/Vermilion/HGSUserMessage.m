//
//  HGSUserMessage.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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

#import "HGSUserMessage.h"
#import "NSNotificationCenter+MainThread.h"
#import <GTM/GTMObjectSingleton.h>

// Notifications

NSString *const kHGSUserMessageNotification = @"HGSUserMessageNotification";

// Notification content keys
NSString *const kHGSSummaryMessageKey = @"HGSTextMessageKey";
NSString *const kHGSDescriptionMessageKey = @"HGSDescriptionMessageKey";
NSString *const kHGSImageMessageKey = @"HGSImageMessageKey";
NSString *const kHGSTypeMessageKey = @"HGSTypeMessageKey";
NSString *const kHGSNameMessageKey = @"HGSNameMessageKey";

@implementation HGSUserMessenger
GTMOBJECT_SINGLETON_BOILERPLATE(HGSUserMessenger, sharedUserMessenger);

+ (void)displayUserMessage:(id)message
               description:(id)description
                      name:(NSString *)name
                     image:(NSImage *)image
                      type:(HGSUserMessageType)type {
  [[self sharedUserMessenger] displayUserMessage:message
                                     description:description
                                            name:name
                                           image:image
                                            type:type];
}

- (void)displayUserMessage:(id)message
               description:(id)description
                      name:(NSString *)name
                     image:(NSImage *)image
                      type:(HGSUserMessageType)type {
  NSMutableDictionary *infoDictionary
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithInteger:type], kHGSTypeMessageKey,
       nil];
  if (message) {
    [infoDictionary setObject:message forKey:kHGSSummaryMessageKey];
  }
  if (description) {
    [infoDictionary setObject:description forKey:kHGSDescriptionMessageKey];
  }
  if (name) {
    [infoDictionary setObject:name forKey:kHGSNameMessageKey];
  }
  if (image) {
    [infoDictionary setObject:image forKey:kHGSImageMessageKey];
  }
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc hgs_postOnMainThreadNotificationName:kHGSUserMessageNotification
                                    object:nil
                                  userInfo:infoDictionary];
}

@end



//
//  ContactsActions.m
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

#import <Vermilion/Vermilion.h>
#import <AddressBook/AddressBook.h>

@interface ContactEmailAction : HGSAction
@end

@interface ContactChatAction : HGSAction
@end

@interface ContactTextChatAction : ContactChatAction
@end

@interface ContactAudioChatAction : ContactChatAction
- (NSString *)chatStyle;
@end

@interface ContactVideoChatAction : ContactAudioChatAction
@end

@implementation ContactEmailAction 

- (BOOL)appliesToResult:(HGSResult *)result {
  NSString *emailAddress 
    = [result valueForKey:kHGSObjectAttributeContactEmailKey];
  return emailAddress != nil;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  NSMutableString *emailAddresses = nil;
  for (HGSResult *result in directObjects) {
    NSString *emailAddress 
      = [result valueForKey:kHGSObjectAttributeContactEmailKey];
    HGSAssert(emailAddress, @"Email addresses should exist for %@", result);
    if (!emailAddresses) {
      emailAddresses = [NSMutableString stringWithString:emailAddress];
    } else {
      [emailAddresses appendFormat:@",%@", emailAddress];
    }
  }
  
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSString *urlStr = [NSString stringWithFormat:@"mailto:%@", emailAddresses];
  NSURL *url = [NSURL URLWithString:urlStr];
  return [ws openURL:url];
}

@end

@implementation ContactChatAction

- (BOOL)appliesToResult:(HGSResult *)result {
  // just check for a chat. We only check for Jabber and AIM because that's
  // what iChat handles.
  BOOL doesApply = NO;
  NSString *recordIdentifier 
    = [result valueForKey:kHGSObjectAttributeAddressBookRecordIdentifierKey];
  if (recordIdentifier) {
    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    ABRecord *person = [addressBook recordForUniqueId:recordIdentifier];
    if (person) {
      ABMultiValue *chatAddresses
        = [person valueForProperty:kABAIMInstantProperty];
      if ([chatAddresses count] == 0) {
        chatAddresses = [person valueForProperty:kABJabberInstantProperty];
      }
      doesApply = [chatAddresses count] > 0;
    }
  }
  return doesApply;
}

@end

@implementation ContactTextChatAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL isGood = NO;
  
  //TODO(dmaclach): any way to make this a group chat?
  for (HGSResult *result in directObjects) {
    NSURL *url = nil;
    if ([result conformsToType:kHGSTypeTextInstantMessage]) {
      url = [result url];
    } else {
      struct {
        NSString *property_;
        NSString *urlFormat_;
      } addressBookToURLMap[] = {
        { kABAIMInstantProperty, @"aim:goim?screenname=%@" },
        { kABJabberInstantProperty, @"xmpp:%@" },
        { kABYahooInstantProperty, @"ymsgr:sendim?%@" },
        { kABMSNInstantProperty, @"msn:chat?contact=%@" },
        { kABICQInstantProperty, @"icq:%@" }
      };
      
      NSString *recordIdentifier 
        = [result valueForKey:kHGSObjectAttributeAddressBookRecordIdentifierKey];
      if (recordIdentifier) {
        NSString *urlString = nil;
        ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
        ABRecord *person = [addressBook recordForUniqueId:recordIdentifier];
        if (person) {
          for (size_t i = 0; 
               i < sizeof(addressBookToURLMap) / sizeof(addressBookToURLMap[0]); 
               ++i) {
            ABMultiValue *chatAddresses
              = [person valueForProperty:addressBookToURLMap[i].property_];
            if ([chatAddresses count]) {
              NSString *primID = [chatAddresses primaryIdentifier];
              NSUInteger idx = 0;
              if (primID) {
                idx = [chatAddresses indexForIdentifier:primID];
                if (idx == NSNotFound) idx = 0;
              }
              NSString *chatAddress = [chatAddresses valueAtIndex:idx];
              urlString 
                = [NSString stringWithFormat:addressBookToURLMap[i].urlFormat_, 
                   chatAddress];
              break;
          }
          }
        }
        if (urlString) {
          url = [NSURL URLWithString:urlString];
        }  
      }
    }
    if (url) {
      NSWorkspace *ws = [NSWorkspace sharedWorkspace];
      isGood = [ws openURL:url];
    }
  }
  return isGood;
}

@end

@implementation ContactAudioChatAction

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = [results count] == 1;
  if (doesApply) {
    doesApply = [super appliesToResults:results];
  }
  return doesApply;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL isGood = YES;
  HGSResultArray *directObjects 
    = [info objectForKey:kHGSActionDirectObjectsKey];
  //TODO(dmaclach): any way to make this a group chat?
  NSString *style = [self chatStyle];
  for (HGSResult *result in directObjects) {
    NSString *abID 
      = [result valueForKey:kHGSObjectAttributeAddressBookRecordIdentifierKey];
  
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    // TODO(alcor): add support for ichat:compose?service=AIM&id=Somebody style 
    // urls so they don't have to be in your address book 
    // (google contacts, etc.)
    NSString *urlString 
      = [NSString stringWithFormat:@"iChat:compose?card=%@&style=%@", 
         abID, style];
    NSURL *url = [NSURL URLWithString:urlString];
    isGood |= [ws openURL:url];
  }
  return isGood;
}

- (NSString *)chatStyle {
  return @"audiochat";
}
@end

@implementation ContactVideoChatAction
- (NSString *)chatStyle {
  return @"videochat";
}
@end

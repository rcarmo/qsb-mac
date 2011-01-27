//
//  KeychainItem.mm
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

#import "HGSKeychainItem.h"
#import "HGSLog.h"

@implementation HGSKeychainItem
+ (HGSKeychainItem*)keychainItemForService:(NSString*)serviceName
                                  username:(NSString*)username {
  SecKeychainItemRef itemRef;
  const char* serviceCString = [serviceName UTF8String];
  UInt32 serviceLength = serviceCString ? (UInt32)strlen(serviceCString) : 0;
  const char* accountCString = [username UTF8String];
  UInt32 accountLength = accountCString ? (UInt32)strlen(accountCString) : 0;
  HGSKeychainItem *item = nil;
  OSStatus result = SecKeychainFindGenericPassword(NULL,
                                                   serviceLength, serviceCString,
                                                   accountLength, accountCString,
                                                   0, NULL,
                                                   &itemRef);
  if (![self reportIfKeychainError:result]) {
    item = [[[self alloc] initWithRef:itemRef] autorelease];
    CFRelease(itemRef);
  }

  return item;
}

+ (HGSKeychainItem*)keychainItemForHost:(NSString*)host
                               username:(NSString*)username {
  SecKeychainItemRef itemRef;
  const char* serverCString = [host UTF8String];
  UInt32 serverLength = serverCString ? (UInt32)strlen(serverCString) : 0;
  const char* accountCString = [username UTF8String];
  UInt32 accountLength = accountCString ? (UInt32)strlen(accountCString) : 0;
  HGSKeychainItem *item = nil;
  OSStatus result = SecKeychainFindInternetPassword(NULL, serverLength, serverCString,
                                                    0, NULL, accountLength, accountCString,
                                                    0, NULL, kAnyPort, 0, 0,
                                                    NULL, NULL, &itemRef);
  if (![self reportIfKeychainError:result]) {
    item = [[[self alloc] initWithRef:itemRef] autorelease];
    CFRelease(itemRef);
  }

  return item;
}

+ (NSArray*)allKeychainItemsForService:(NSString*)serviceName {
  SecKeychainAttribute attributes[1];

  const char* serviceCString = [serviceName UTF8String];
  attributes[0].tag = kSecServiceItemAttr;
  attributes[0].data = (void*)(serviceCString);
  attributes[0].length = (UInt32)strlen(serviceCString);

  SecKeychainAttributeList searchCriteria;
  searchCriteria.count = 1;
  searchCriteria.attr = attributes;

  SecKeychainSearchRef searchRef;
  OSStatus result = SecKeychainSearchCreateFromAttributes(NULL,
                                                          kSecGenericPasswordItemClass,
                                                          &searchCriteria,
                                                          &searchRef);
  if ([self reportIfKeychainError:result]) {
    return nil;
  }

  NSMutableArray* matchingItems = [NSMutableArray array];
  SecKeychainItemRef keychainItemRef;
  while (SecKeychainSearchCopyNext(searchRef, &keychainItemRef) == noErr) {
    HGSKeychainItem *item
      = [[[self alloc] initWithRef:keychainItemRef] autorelease];
    CFRelease(keychainItemRef);
    [matchingItems addObject:item];
  }
  CFRelease(searchRef);

  return matchingItems;
}

+ (HGSKeychainItem*)addKeychainItemForService:(NSString*)serviceName
                                 withUsername:(NSString*)username
                                     password:(NSString*)password {
  const char* serviceCString = [serviceName UTF8String];
  UInt32 serviceLength = serviceCString ? (UInt32)strlen(serviceCString) : 0;
  const char* accountCString = [username UTF8String];
  UInt32 accountLength = accountCString ? (UInt32)strlen(accountCString) : 0;
  const char* passwordData = [password UTF8String];
  UInt32 passwordLength = passwordData ? (UInt32)strlen(passwordData) : 0;
  SecKeychainItemRef keychainItemRef;
  OSStatus result = SecKeychainAddGenericPassword(NULL, serviceLength, serviceCString,
                                                  accountLength, accountCString,
                                                  passwordLength, passwordData, &keychainItemRef);
  HGSKeychainItem *item = nil;
  if (![self reportIfKeychainError:result]) {
    item = [[[self alloc] initWithRef:keychainItemRef] autorelease];
    CFRelease(keychainItemRef);
  }

  return item;
}

- (HGSKeychainItem*)initWithRef:(SecKeychainItemRef)ref {
  if ((self = [super init])) {
    if (ref) {
      keychainItemRef_ = ref;
      CFRetain(keychainItemRef_);
    } else {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  if (keychainItemRef_) {
    CFRelease(keychainItemRef_);
  }
  [super dealloc];
}

- (NSString *)keychainStringForAttribute:(UInt32)attribute {
  NSString *string = nil;
  if (keychainItemRef_) {
    SecKeychainAttributeInfo attrInfo;
    UInt32 tags[1];
    tags[0] = attribute;
    attrInfo.count = (UInt32)(sizeof(tags)/sizeof(UInt32));
    attrInfo.tag = tags;
    attrInfo.format = NULL;

    SecKeychainAttributeList *attrList;
    OSStatus result = SecKeychainItemCopyAttributesAndData(keychainItemRef_,
                                                           &attrInfo,
                                                           NULL,
                                                           &attrList,
                                                           NULL,
                                                           NULL);

    if (![[self class] reportIfKeychainError:result]) {
      for (unsigned int i = 0; i < attrList->count; i++) {
        SecKeychainAttribute attr = attrList->attr[i];
        if (attr.tag == attribute) {
          string = [[[NSString alloc] initWithBytes:(char*)(attr.data)
                                             length:attr.length
                                           encoding:NSUTF8StringEncoding]
                    autorelease];
          break;
        }
      }
      OSStatus status = SecKeychainItemFreeAttributesAndData(attrList, NULL);
      [[self class] reportIfKeychainError:status];
    }
  }
  return string;
}

- (NSString *)username {
  return [self keychainStringForAttribute:kSecAccountItemAttr];
}

- (NSString *)label {
  return [self keychainStringForAttribute:kSecLabelItemAttr];
}

- (NSString*)password {
  NSString *password = nil;
  if (keychainItemRef_) {
    UInt32 passwordLength;
    void* passwordData;
    OSStatus result = SecKeychainItemCopyAttributesAndData(keychainItemRef_,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           &passwordLength,
                                                           &passwordData);

    if (![[self class] reportIfKeychainError:result]) {
      password = [[[NSString alloc] initWithBytes:passwordData
                                           length:passwordLength
                                         encoding:NSUTF8StringEncoding]
                  autorelease];
      OSStatus status = SecKeychainItemFreeAttributesAndData(NULL,
                                                             passwordData);
      [[self class] reportIfKeychainError:status];
    }
  }
  return password;
}

- (void)setUsername:(NSString*)username password:(NSString*)password {
  SecKeychainAttribute user;
  user.tag = kSecAccountItemAttr;
  const char* usernameString = [username UTF8String];
  user.data = (void*)usernameString;
  user.length = user.data ? (UInt32)strlen(user.data) : 0;
  SecKeychainAttributeList attrList;
  attrList.count = 1;
  attrList.attr = &user;
  const char* passwordData = [password UTF8String];
  UInt32 passwordLength = passwordData ? (UInt32)strlen(passwordData) : 0;
  OSStatus status = SecKeychainItemModifyAttributesAndData(keychainItemRef_,
                                                           &attrList,
                                                           passwordLength,
                                                           passwordData);
  [[self class] reportIfKeychainError:status];
}

- (void)removeFromKeychain {
  OSStatus status = SecKeychainItemDelete(keychainItemRef_);
  [[self class] reportIfKeychainError:status];
  CFRelease(keychainItemRef_);
  keychainItemRef_ = nil;
}

+ (BOOL)reportIfKeychainError:(OSStatus)status {
  BOOL wasError = NO;
  if (status != noErr) {
    if (status == wrPermErr) {
      HGSLog(@"A problem was detected while accessing the keychain (%d). "
             @"You may need to run Keychain First Aid to repair your "
             @"keychain.", status);
    } else {
      HGSLogDebug(@"An error occurred while accessing the keychain (%d).",
                  status);
    }
    wasError = YES;
  }
  return wasError;
}

@end

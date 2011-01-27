//
//  ApplicationUIAction.m
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
#import "ApplicationUISource.h"
#import "ApplicationUIAction.h"
#import "GTMAXUIElement.h"

static NSString *const kApplicationUIActionFormat 
  = @"com.google.qsb.applicationUI.action.%@";

static NSString *const kApplicationUIAXActionKey = @"ApplicationUIAXAction";

@implementation ApplicationUIAction
+ (HGSAction *)defaultActionForElement:(GTMAXUIElement*)element {
  HGSAction *action = nil;
  
  typedef struct {
    NSString *role;
    NSString *action;
  } RoleActionMap;
  
  RoleActionMap roleActionMap[] = {
    { NSAccessibilityMenuItemRole, NSAccessibilityPressAction },
    { NSAccessibilityWindowRole, NSAccessibilityRaiseAction },
    { NSAccessibilityMenuRole, NSAccessibilityPressAction },
    { (NSString*)kAXMenuBarItemRole, NSAccessibilityPressAction },
    { NSAccessibilityButtonRole, NSAccessibilityPressAction },
    { NSAccessibilityRadioButtonRole, NSAccessibilityPressAction },
    { NSAccessibilityCheckBoxRole, NSAccessibilityPressAction },
  };
  NSString *actionName = nil;
  NSString *role = [element stringValueForAttribute:NSAccessibilityRoleAttribute];
  for (size_t i = 0; i < sizeof(roleActionMap) / sizeof(RoleActionMap); ++i) {
    if ([role isEqualToString:roleActionMap[i].role]) {
      actionName = roleActionMap[i].action;
      break;
    }
  }
  if (actionName) {
    NSString *identifier 
      = [NSString stringWithFormat:kApplicationUIActionFormat, actionName];
    HGSExtensionPoint *actionsPoint = [HGSExtensionPoint actionsPoint];
    action = [actionsPoint extensionWithIdentifier:identifier];
  }
  return action;
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  // Set up some known keys
  NSString *action = [configuration objectForKey:kApplicationUIAXActionKey];
  HGSAssert(action, @"Must have %@ key", kApplicationUIAXActionKey);
  NSString *name = NSAccessibilityActionDescription(action);
  NSMutableDictionary *fullConfiguration 
    = [NSMutableDictionary dictionaryWithDictionary:configuration];
  [fullConfiguration setObject:name forKey:kHGSExtensionUserVisibleNameKey];
  if ((self = [super initWithConfiguration:fullConfiguration])) {
    accessibilityAction_ = [action retain];
  }
  return self;
}

- (void)dealloc {
  [accessibilityAction_ release];
  [super dealloc];
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = YES;
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    GTMAXUIElement *element 
      = [result valueForKey:kAppUISourceAttributeElementKey];
    pid_t processID = [element processIdentifier];
    ProcessSerialNumber psn;
    OSStatus status = GetProcessForPID(processID, &psn);
    if (status == noErr) {
      SetFrontProcessWithOptions(&psn, kSetFrontProcessFrontWindowOnly);
      wasGood &= [element performAccessibilityAction:accessibilityAction_];
    } else {
      HGSLogDebug(@"Unable to get PSN for PID: %d", processID);
      wasGood = NO;
    }
  }
  return wasGood;
}

- (BOOL)appliesToResult:(HGSResult *)result {
  BOOL doesApply = NO;
  GTMAXUIElement *element 
    = [result valueForKey:kAppUISourceAttributeElementKey];
  
  if (element) {
    doesApply = [element supportsAction:accessibilityAction_];
  }
  return doesApply;
}

@end

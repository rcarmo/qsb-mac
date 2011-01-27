//
//  QSBApplication.m
//
//  Copyright (c) 2006-2008 Google Inc. All rights reserved.
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

#import "QSBApplication.h"

#import <GTM/GTMCarbonEvent.h>
#import <GTM/GTMDebugSelectorValidation.h>

#import "QSBApplicationDelegate.h"
#import "QSBSearchWindowController.h"

static const EventTypeSpec kModifierEventTypeSpec[]
  = { { kEventClassKeyboard, kEventRawKeyModifiersChanged } };
static const size_t kModifierEventTypeSpecSize
  = sizeof(kModifierEventTypeSpec) / sizeof(EventTypeSpec);

static const EventTypeSpec kApplicationEventTypeSpec[]
  = { { kEventClassApplication, kEventAppFrontSwitched } };
static const size_t kApplicationEventTypeSpecSize
  = sizeof(kApplicationEventTypeSpec) / sizeof(EventTypeSpec);

@implementation QSBApplication

// Allows me to intercept the "control" double tap to activate QSB. There
// appears to be no way to do this from straight Cocoa.
- (void)awakeFromNib {
  GTMCarbonEventMonitorHandler *monitorHandler
    = [GTMCarbonEventMonitorHandler sharedEventMonitorHandler];
  [monitorHandler registerForEvents:kModifierEventTypeSpec
                              count:kModifierEventTypeSpecSize];
  [monitorHandler setDelegate:self];

  GTMCarbonEventApplicationEventHandler *applicationHandler
    = [GTMCarbonEventApplicationEventHandler sharedApplicationEventHandler];
  [applicationHandler registerForEvents:kApplicationEventTypeSpec
                                  count:kApplicationEventTypeSpecSize];
  [applicationHandler setDelegate:self];
}

- (void) dealloc {
  GTMCarbonEventMonitorHandler *monitorHandler
    = [GTMCarbonEventMonitorHandler sharedEventMonitorHandler];
  [monitorHandler unregisterForEvents:kModifierEventTypeSpec
                                count:kModifierEventTypeSpecSize];
  [monitorHandler setDelegate:nil];

  GTMCarbonEventApplicationEventHandler *applicationHandler
    = [GTMCarbonEventApplicationEventHandler sharedApplicationEventHandler];
  [applicationHandler unregisterForEvents:kApplicationEventTypeSpec
                                    count:kApplicationEventTypeSpecSize];
  [applicationHandler setDelegate:nil];

  [super dealloc];
}

// Verify that our delegate will respond to things it is supposed to.
- (void)setDelegate:(id)anObject {
  if (anObject) {
    GTMAssertSelectorNilOrImplementedWithArguments(anObject,
                                                   @selector(modifiersChangedWhileActive:),
                                                   @encode(NSEvent *), nil);
    GTMAssertSelectorNilOrImplementedWithArguments(anObject,
                                                   @selector(modifiersChangedWhileInactive:),
                                                   @encode(NSEvent *), nil);
    GTMAssertSelectorNilOrImplementedWithArguments(anObject,
                                                   @selector(keysChangedWhileActive:),
                                                   @encode(NSEvent *), nil);
  }
  [super setDelegate:anObject];
}

- (void)sendEvent:(NSEvent *)theEvent {
  QSBApplicationDelegate *delegate = (QSBApplicationDelegate *)[self delegate];
  NSEventType type = [theEvent type];
  if (type == NSFlagsChanged) {
    [delegate modifiersChangedWhileActive:theEvent];
  } else if (type == NSKeyDown || type == NSKeyUp) {
    [delegate keysChangedWhileActive:theEvent];
  }
  [super sendEvent:theEvent];
}

- (OSStatus)gtm_eventHandler:(GTMCarbonEventHandler *)sender
               receivedEvent:(GTMCarbonEvent *)event
                     handler:(EventHandlerCallRef)handler {
  OSStatus status = eventNotHandledErr;
  EventClass theClass = [event eventClass];
  EventKind theKind = [event eventKind];
  if (theClass == kEventClassKeyboard &&
      theKind == kEventRawKeyModifiersChanged) {
    UInt32 modifiers;
    if ([event getUInt32ParameterNamed:kEventParamKeyModifiers
                                  data:&modifiers]) {
      NSUInteger cocoaMods = GTMCarbonToCocoaKeyModifiers(modifiers);
      NSEvent *nsEvent = [NSEvent keyEventWithType:NSFlagsChanged
                                          location:[NSEvent mouseLocation]
                                     modifierFlags:cocoaMods
                                         timestamp:[event time]
                                      windowNumber:0
                                           context:nil
                                        characters:nil
                       charactersIgnoringModifiers:nil
                                         isARepeat:NO
                                           keyCode:0];
      QSBApplicationDelegate *delegate
        = (QSBApplicationDelegate *)[self delegate];
      [delegate modifiersChangedWhileInactive:nsEvent];
    }
  } else if (theClass == kEventClassApplication &&
             theKind == kEventAppFrontSwitched) {
    ProcessSerialNumber psn;
    if ([event getParameterNamed:kEventParamProcessID
                            type:typeProcessSerialNumber
                            size:sizeof(psn)
                            data:&psn]) {
      ProcessSerialNumber myPSN;
      MacGetCurrentProcess(&myPSN);
      Boolean equal;
      if (SameProcess(&psn, &myPSN, &equal) == noErr && !equal) {
        QSBApplicationDelegate *delegate
          = (QSBApplicationDelegate *)[self delegate];
        [[delegate searchWindowController] hideSearchWindow:self];
      }
    }
  }
  return status;
}

@end

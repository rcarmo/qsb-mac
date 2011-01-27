//
//  QSBResultIconView.m
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


#import "QSBResultIconView.h"
#import <Vermilion/Vermilion.h>
#import "QSBTableResult.h"
#import "QSBResultRowViewController.h"
#import "GTMNSObject+KeyValueObserving.h"
#import "GTMMethodCheck.h"

static NSString *const kQSBDisplayIconKVOKey = @"representedObject.displayIcon";

@interface QSBResultIconView ()
- (void)displayIconValueChanged:(GTMKeyValueChangeNotification *)notification;
@end

@implementation QSBResultIconView
GTM_METHOD_CHECK(NSObject, gtm_addObserver:forKeyPath:selector:userInfo:options:);
GTM_METHOD_CHECK(NSObject, gtm_stopObservingAllKeyPaths);

- (void)awakeFromNib {
  [controller_ gtm_addObserver:self 
                    forKeyPath:kQSBDisplayIconKVOKey
                      selector:@selector(displayIconValueChanged:)
                      userInfo:nil
                       options:NSKeyValueObservingOptionNew];
  [controller_ retain];
}

- (void)dealloc {
  [self gtm_stopObservingAllKeyPaths];
  [controller_ release];
  [super dealloc];
}

- (void)displayIconValueChanged:(GTMKeyValueChangeNotification *)notification {
  NSImage *icon = [[notification change] objectForKey:NSKeyValueChangeNewKey];
  HGSAssert(icon == nil || [icon isKindOfClass:[NSImage class]], nil);
  [self setImage:icon];
}

@end

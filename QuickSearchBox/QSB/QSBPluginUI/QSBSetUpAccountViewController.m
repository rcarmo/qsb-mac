//
//  QSBSetUpAccountViewController.m
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

#import "QSBSetUpAccountViewController.h"
#import "HGSAccount.h"

@implementation QSBSetUpAccountViewController

@synthesize account = account_;
@synthesize accountTypeClass = accountTypeClass_;
@synthesize parentWindow = parentWindow_;

- (id)init {
  self = [self initWithNibName:nil
                        bundle:nil
              accountTypeClass:nil];
  return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
     accountTypeClass:(Class)accountTypeClass {
  if ((self = [super initWithNibName:nibNameOrNil
                              bundle:nibBundleOrNil])) {
    if (accountTypeClass) {
      accountTypeClass_ = accountTypeClass;
    } else {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [account_ release];
  [super dealloc];
}

- (IBAction)cancelSetupAccountSheet:(id)sender {
  NSWindow *sheet = [sender window];
  [NSApp endSheet:sheet];
}

- (void)presentMessageOffWindow:(NSWindow *)parentWindow
                    withSummary:(NSString *)summary
                    explanation:(NSString *)explanation
                     alertStyle:(NSAlertStyle)style {
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setAlertStyle:style];
  [alert setMessageText:summary];
  [alert setInformativeText:explanation];
  [alert beginSheetModalForWindow:parentWindow
                    modalDelegate:self
                   didEndSelector:nil
                      contextInfo:nil];
}

@end


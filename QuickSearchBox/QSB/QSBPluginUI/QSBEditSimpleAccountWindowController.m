//
//  QSBSimpleAccountEditController.m
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

#import "QSBEditSimpleAccountWindowController.h"
#import <Vermilion/Vermilion.h>

@implementation QSBEditSimpleAccountWindowController

@synthesize password = password_;

- (void)dealloc {
  [password_ release];
  [super dealloc];
}

- (void)awakeFromNib {
  HGSSimpleAccount *account = (HGSSimpleAccount *)[self account];
  NSString *password = [account password];
  [self setPassword:password];
}

- (IBAction)acceptEditAccountSheet:(id)sender {
  NSWindow *sheet = [self window];
  NSString *password = [self password];
  HGSSimpleAccount *account = (HGSSimpleAccount *)[self account];
  if ([account authenticateWithPassword:password]) {
    [account setPassword:password];
    [NSApp endSheet:sheet];
    [account setAuthenticated:YES];
  } else if (![self canGiveUserAnotherTry]) {
    NSString *summaryFormat = NSLocalizedString(@"Could not set up that %@ "
                                                @"account.", 
                                                @"A dialog title denoting that "
                                                @"we were unable to set up the "
                                                @"%@ account");
    NSString *summary = [NSString stringWithFormat:summaryFormat,
                         [account type]];
    NSString *explanationFormat
      = NSLocalizedString(@"The %1$@ account '%2$@' could not be set up for "
                          @"use.  Please check your password and try "
                          @"again.", 
                          @"A dialog label explaining in detail that we could "
                          @"not set up an account of type 1 with username 2.");
    NSString *explanation = [NSString stringWithFormat:explanationFormat,
                             [account type],
                             [account userName]];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:summary];
    [alert setInformativeText:explanation];
    [alert beginSheetModalForWindow:sheet
                      modalDelegate:self
                     didEndSelector:nil
                        contextInfo:nil];
  }
}

- (BOOL)canGiveUserAnotherTry {
  return NO;
}

@end


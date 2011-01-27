//
//  QSBSetUpAccountWindowController.m
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

#import "QSBSetUpAccountWindowController.h"
#import <Vermilion/Vermilion.h>
#import "QSBApplicationDelegate.h"
#import "QSBSetUpAccountViewController.h"

NSString *const kQSBSetUpAccountViewNibName = @"QSBSetUpAccountViewNibName";
NSString *const kQSBSetUpAccountViewControllerClassName
  = @"QSBSetUpAccountViewControllerClassName";


@interface QSBSetUpAccountWindowController ()

@property (nonatomic, retain, readwrite) NSArray *visibleAccountTypes;
@property (nonatomic, retain, readwrite) HGSAccountType *selectedAccountType;

- (void)setInstalledSetupViewController:(NSViewController *)setupViewController;

@end


@implementation QSBSetUpAccountWindowController

@synthesize visibleAccountTypes = visibleAccountTypes_;
@synthesize selectedAccountType = selectedAccountType_;

- (id)initWithParentWindow:(NSWindow *)parentWindow {
  parentWindow_ = parentWindow;
  self = [self init];
  return self;
}

- (id)init {
  if ((self = [super initWithWindowNibName:@"SetUpAccount"])) {
    HGSExtensionPoint *accountTypesPoint 
      = [HGSExtensionPoint accountTypesPoint];
    NSArray *visibleAccountTypes = [accountTypesPoint extensions];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"userVisible == YES"];
    visibleAccountTypes_
      = [[visibleAccountTypes filteredArrayUsingPredicate:pred] retain];
  }
  return self;
}

- (void) dealloc {
  [visibleAccountTypes_ release];
  [selectedAccountType_ release];
  [installedSetupViewController_ release];
  [super dealloc];
}

- (void)awakeFromNib {
  NSSortDescriptor *newSort 
    = [[[NSSortDescriptor alloc] initWithKey:@"self.displayName" 
                                   ascending:YES] autorelease];
  [accountTypeController_ setSortDescriptors:[NSArray arrayWithObject:newSort]];
  NSArray *arrangedTypes = [accountTypeController_ arrangedObjects];
  HGSAccountType *accountType = [arrangedTypes objectAtIndex:0];
  if (accountType) {
    [self setSelectedAccountType:accountType];
  }
}

- (void)setSelectedAccountType:(HGSAccountType *)accountType {
  if (selectedAccountType_ != accountType) {
    HGSProtoExtension *accountProto = [accountType protoExtension];
    NSString *setUpAccountControllerClassName
      = [accountProto objectForKey:kQSBSetUpAccountViewControllerClassName];
    Class setUpAccountControllerClass
      = NSClassFromString(setUpAccountControllerClassName);
    NSBundle *accountTypeBundle
      = [NSBundle bundleForClass:setUpAccountControllerClass];
    NSString *setUpAccountNibName
      = [accountProto objectForKey:kQSBSetUpAccountViewNibName];
    QSBSetUpAccountViewController *loadedViewController
      = [[[setUpAccountControllerClass alloc]
          initWithNibName:setUpAccountNibName bundle:accountTypeBundle]
         autorelease];
    if (loadedViewController) {
      [loadedViewController loadView];
      [loadedViewController setParentWindow:parentWindow_];
      [self setInstalledSetupViewController:loadedViewController];

      [selectedAccountType_ release];
      selectedAccountType_ = [accountType retain];
    } else {
      HGSLog(@"Failed to load set up account nib '%@'.", setUpAccountNibName);
    }
  }
}

- (void)setInstalledSetupViewController:(NSViewController *)setupViewController {
  if (setupViewController) {
    if (installedSetupViewController_ != setupViewController) {
      // Remove any previously installed setup view.
      NSView *oldSetupView = [installedSetupViewController_ view];
      [oldSetupView removeFromSuperview];
      [installedSetupViewController_ autorelease];
      installedSetupViewController_ = [setupViewController retain];
      
      NSView *setupView = [installedSetupViewController_ view];
      
      // 1) Adjust the window height to accommodate the new view, 2) adjust
      // the width of the new view to fit the container, then 3) install the
      // new view.
      // Assumption: The container view is set to resize with the window.
      NSRect containerFrame = [setupContainerView_ frame];
      NSRect setupViewFrame = [setupView frame];
      CGFloat deltaHeight = NSHeight(setupViewFrame) - NSHeight(containerFrame);
      NSWindow *setupWindow = [setupContainerView_ window];
      NSRect setupWindowFrame = [setupWindow frame];
      setupWindowFrame.origin.y -= deltaHeight;
      setupWindowFrame.size.height += deltaHeight;
      [setupWindow setFrame:setupWindowFrame display:YES];
      
      containerFrame = [setupContainerView_ frame];  // Refresh
      CGFloat deltaWidth = NSWidth(containerFrame) - NSWidth(setupViewFrame);
      setupViewFrame.size.width += deltaWidth;
      [setupView setFrame:setupViewFrame];
      
      [setupContainerView_ addSubview:setupView];
      
      // Set the focused field.
      NSView *wannabeKeyView = [setupView nextKeyView];
      [setupWindow makeFirstResponder:wannabeKeyView];
    }
  } else {
    HGSLogDebug(@"Attempt to set a nil setupViewController.");
  }
}

@end

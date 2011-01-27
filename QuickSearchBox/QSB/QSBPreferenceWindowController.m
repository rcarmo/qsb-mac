//
//  QSBPreferenceWindowController.m
//
//  Copyright (c) 2008-2009 Google Inc. All rights reserved.
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

#import <SecurityInterface/SFCertificatePanel.h>
#import "QSBPreferenceWindowController.h"
#import "GTMGarbageCollection.h"
#import "GTMHotKeyTextField.h"
#import "GTMMethodCheck.h"
#import "HGSAccount.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSLog.h"
#import "NSColor+Naming.h"
#import "QSBPreferences.h"
#import "QSBSearchWindowController.h"
#import "QSBSetUpAccountWindowController.h"
#import "QSBEditAccountWindowController.h"

NSString *const kQSBEditAccountWindowNibName = @"QSBEditAccountWindowNibName";
NSString *const kQSBEditAccountWindowControllerClassName
  = @"QSBEditAccountWindowControllerClassName";

// This is equivalent to kLSSharedFileListLoginItemHidden which is supported on
// 10.5 and higher, but somehow missing from Apple's 10.5 headers.
// http://openradar.appspot.com/6482251
NSString *const kQSBSharedFileListLoginItemHidden
  = @"com.apple.loginitem.HideOnLaunch";

static void OpenAtLoginItemsChanged(LSSharedFileListRef inList, void *context);

@interface QSBPreferenceWindowController ()

// Adjust color popup to the corect color
- (void)updateColorPopup;

// Get/set the sources sort descriptor.
- (NSArray *)sourceSortDescriptor;
- (void)setSourceSortDescriptor:(NSArray *)value;

// Make each account authenticate.
- (void)authenticateAccounts;

- (void)setGlossy:(id)sender;
- (void)changeColor:(id)sender;
- (void)chooseOtherColor:(id)sender;


// Notifications
- (void)didAddAccount:(NSNotification *)notification;

// Callbacks
- (void)setUpAccountSheetDidEnd:(NSWindow *)sheet
                     returnCode:(NSInteger)returnCode
                    contextInfo:(void *)contextInfo;
- (void)editAccountSheetDidEnd:(NSWindow *)sheet
                    returnCode:(NSInteger)returnCode
                   contextInfo:(void *)contextInfo;
- (void)removeAccountAlertDidEnd:(NSWindow *)sheet
                      returnCode:(int)returnCode
                     contextInfo:(void *)contextInfo;
@end


static NSString *const kQSBBackgroundPref = @"backgroundColor";
static NSString *const kQSBBackgroundGlossyPref = @"backgroundIsGlossy";
static const NSInteger kCustomColorTag = -1;

// Some internal functions that we weakly link against and check before using
typedef NSInteger CGSConnection;
typedef NSInteger CGSWindow;
typedef NSInteger CGSWorkspace;

extern CGSConnection _CGSDefaultConnection(void) WEAK_IMPORT_ATTRIBUTE;
extern OSStatus CGSGetWorkspace(const CGSConnection cid,
                                CGSWorkspace *workspace) WEAK_IMPORT_ATTRIBUTE;
extern OSStatus CGSGetWindowWorkspace(const CGSConnection cid,
                                      const CGSWindow wid,
                                      CGSWorkspace *workspace) WEAK_IMPORT_ATTRIBUTE;
extern OSStatus CGSMoveWorkspaceWindowList(const CGSConnection connection,
                                           CGSWindow *wids,
                                           NSInteger count,
                                           CGSWorkspace toWorkspace) WEAK_IMPORT_ATTRIBUTE;

@interface NSColor (QSBColorRendering)

- (NSImage *)menuImage;

@end


@implementation NSColor (QSBColorRendering)
- (NSImage *)menuImage {
  NSRect rect = NSMakeRect(0.0, 0.0, 24.0, 12.0);
  NSImage *image = [[[NSImage alloc] initWithSize:rect.size] autorelease];
  [image lockFocus];
  [self set];
  NSRectFill(rect);
  [[NSColor colorWithDeviceWhite:0.0 alpha:0.2] set];
  NSFrameRectWithWidthUsingOperation(rect, 1.0, NSCompositeSourceOver);
  [image unlockFocus];
  return image;
}
@end


@implementation QSBPreferenceWindowController

@synthesize selectedColor = selectedColor_;

GTM_METHOD_CHECK(NSColor, crayonName);

- (id)init {
  if ((self = [super initWithWindowNibName:@"PreferencesWindow"])) {
    NSSortDescriptor *sortDesc
      = [[[NSSortDescriptor alloc] initWithKey:@"displayName"
                                     ascending:YES
                                      selector:@selector(caseInsensitiveCompare:)]
                              autorelease];
    [self setSourceSortDescriptor:[NSArray arrayWithObject:sortDesc]];
    openAtLoginItemsList_
      = LSSharedFileListCreate(NULL,
                               kLSSharedFileListSessionLoginItems,
                               NULL);
    if (!openAtLoginItemsList_) {
      HGSLog(@"Unable to create kLSSharedFileListSessionLoginItems");
    } else {
      LSSharedFileListAddObserver(openAtLoginItemsList_,
                                  CFRunLoopGetMain(),
                                  kCFRunLoopDefaultMode,
                                  OpenAtLoginItemsChanged,
                                  self);
      openAtLoginItemsSeedValue_
        = LSSharedFileListGetSeedValue(openAtLoginItemsList_);
    }

    // Notify us when an account is added so we can highlight it.
    HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(didAddAccount:)
               name:kHGSExtensionPointDidAddExtensionNotification
             object:accountsPoint];
  }
  return self;
}

- (void) dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [colors_ release];
  [sourceSortDescriptor_ release];
  if (openAtLoginItemsList_) {
    LSSharedFileListRemoveObserver(openAtLoginItemsList_,
                                   CFRunLoopGetMain(),
                                   kCFRunLoopDefaultMode,
                                   OpenAtLoginItemsChanged,
                                   self);
    CFRelease(openAtLoginItemsList_);
  }
  [super dealloc];
}

- (void)windowDidLoad {
  [super windowDidLoad];

  [[colorPopUp_ menu] setDelegate:self];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSData *colorData = [ud objectForKey:kQSBBackgroundPref];
  NSColor *color = colorData ? [NSUnarchiver unarchiveObjectWithData:colorData]
                             : [NSColor whiteColor];
  [self setSelectedColor:color];

  // Add the Google color palette
  colors_ = [[NSColorList alloc] initWithName:@"Google"];

  [colors_ setColor:[NSColor whiteColor]
             forKey:NSLocalizedString(@"White", @"")];

  [colors_ setColor:[NSColor colorWithCalibratedRed:0
                                              green:102.0/255.0
                                               blue:204.0/255.0
                                              alpha:1.0]
             forKey:NSLocalizedString(@"Blue", @"")];

  [colors_ setColor:[NSColor redColor]
             forKey:NSLocalizedString(@"Red", @"")];
  [colors_ setColor:[NSColor colorWithCalibratedRed:255.0/255.0
                                              green:204.0/255.0
                                               blue:0.0
                                              alpha:1.0]
             forKey:NSLocalizedString(@"Yellow", @"")];
  [colors_ setColor:[NSColor colorWithCalibratedRed:0
                                              green:153.0/255.0
                                               blue:57.0/255.0
                                              alpha:1.0]
             forKey:NSLocalizedString(@"Green", @"")];

  [colors_ setColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0]
             forKey:NSLocalizedString(@"Silver", @"")];
  [colors_ setColor:[NSColor blackColor]
             forKey:NSLocalizedString(@"Black", @"")];

  [self menuNeedsUpdate:[colorPopUp_ menu]];
  [colorPopUp_ selectItemAtIndex:0];
  [self updateColorPopup];

  // Ensure that the "Under the Hood" view is scrolled to the top
  NSPoint leftTop = [[advancedScrollView_ contentView]
                     constrainScrollPoint:NSMakePoint(0, CGFLOAT_MAX)];
  [[advancedScrollView_ contentView] scrollToPoint:leftTop];
  [[advancedScrollView_ verticalScroller] setFloatValue:0.0f];

  [[self window] setHidesOnDeactivate:YES];

  [tabView_ selectTabViewItemAtIndex:0];
  [sourcesTable_ setIntercellSpacing:NSMakeSize(3.0, 6.0)];
  [accountsTable_ setIntercellSpacing:NSMakeSize(3.0, 6.0)];

  [toolbar_ setDelegate:self];
  NSString *firstIdentifier
    = [[[toolbar_ items] objectAtIndex:0] itemIdentifier];
  [toolbar_ setSelectedItemIdentifier:firstIdentifier];
}


#pragma mark Color Menu

- (void)menuNeedsUpdate:(NSMenu *)menu {

  if (![[menu itemArray] count]) {
    NSArray *colorNames = [colors_ allKeys];
    for (NSUInteger i = 0; i < [colorNames count]; i++) {
      NSString *name = [colorNames objectAtIndex:i];
      NSMenuItem *item = [menu addItemWithTitle:name
                                         action:nil
                                  keyEquivalent:@""];
      [item setTag:i];
      [item setRepresentedObject:[colors_ colorWithKey:name]];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSString *otherString = NSLocalizedString(@"Other...", @"") ;
    NSMenuItem *item = [menu addItemWithTitle:otherString
                                       action:@selector(chooseOtherColor:)
                                keyEquivalent:@""];
    [item setTarget:self];
    [item setTag:kCustomColorTag];

    [menu addItem:[NSMenuItem separatorItem]];
    [[menu addItemWithTitle:NSLocalizedString(@"Glossy", @"")
                     action:@selector(setGlossy:)
              keyEquivalent:@""] setTarget:self];
  }
}

- (NSInteger)indexOfColor:(NSColor *)color {
  for (NSString *key in [colors_ allKeys]) {
    NSColor *thisColor = [colors_ colorWithKey:key];
    if ([color isEqual:thisColor]) {
      return [[colors_ allKeys] indexOfObject:key];
    }
  }
  return NSNotFound;
}

- (void)setColor:(NSColor *)color {
  [self setSelectedColor:color];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSData *colorData = [NSArchiver archivedDataWithRootObject:color];
  [ud setObject:colorData forKey:kQSBBackgroundPref];
  [self updateColorPopup];
}

- (IBAction)setColorFromMenu:(id)sender {
  NSColor *color = [[sender selectedItem] representedObject];
  [self setColor:color];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
  if ([item action] == @selector(setGlossy:)) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL value = YES;
    NSNumber *valueNumber = [ud objectForKey:kQSBBackgroundGlossyPref];
    if (valueNumber) {
      value = [valueNumber boolValue];
    }
    [item setState:value];
  } else if ([item action] == @selector(chooseOtherColor:))  {
    NSColor *color = [self selectedColor];
    [item setImage:[color menuImage]];
    [item setTitle:NSLocalizedString(@"Other...", @"")];
    [item menu];
  } else {
    if (![item image]) {
      NSColor *color = [colors_ colorWithKey:[item title]];
      [item setImage:[color menuImage]];
    }
  }
  return YES;
}

- (void)setGlossy:(id)sender {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  BOOL glossy = [ud boolForKey:kQSBBackgroundGlossyPref];
  [ud setBool:!glossy forKey:kQSBBackgroundGlossyPref];

  [self updateColorPopup];
}

- (void)changeColor:(id)sender {
  [self setColor:[sender color]];
}

- (void)chooseOtherColor:(id)sender {
  // If the user should decide to change colors on us
  // we want the following settings available.
  NSColorPanel *sharedColorPanel = [NSColorPanel sharedColorPanel];
  [sharedColorPanel setShowsAlpha:YES];
  [sharedColorPanel setMode:NSCrayonModeColorPanel];
  [sharedColorPanel setAction:@selector(changeColor:)];
  [sharedColorPanel setTarget:self];
  [sharedColorPanel makeKeyAndOrderFront:sender];

}

- (IBAction)showPreferences:(id)sender {
  NSWindow *prefWindow = [self window];
  // This is a little sketchy as we are using private APIs from Apple, but
  // AFAIK there is no other way to do this. This makes sure that the
  // preferences open up in the current space, and doesn't jump us around
  // while using QSB. This is a privilege, not a right, so if anything
  // looks skanky we abort and fall back to the old space switching.
  if (_CGSDefaultConnection && CGSGetWorkspace
      && CGSGetWindowWorkspace && CGSMoveWorkspaceWindowList) {
    NSInteger windowNumber = [prefWindow windowNumber];
    if (windowNumber != -1) {
      CGSConnection connection = _CGSDefaultConnection();
      CGSWorkspace currentWorkspace, windowWorkspace;
      OSStatus status = CGSGetWorkspace(connection, &currentWorkspace);
      if (status == noErr) {
        status = CGSGetWindowWorkspace(connection, windowNumber,
                                       &windowWorkspace);
        if (status == noErr && currentWorkspace != windowWorkspace) {
          status = CGSMoveWorkspaceWindowList(connection, &windowNumber,
                                              1, currentWorkspace);
        }
      }
      if (status != noErr) {
        HGSLogDebug(@"A private CoreGraphics function returrned an error in"
                    @"[QSBPreferenceWindowController -showPreferences:]");
      }
    }
  } else {
    HGSLogDebug(@"Unable to access weak symbols _CGSDefaultConnection:%p "
                @"CGSGetWorkspace:%p CGSGetWindowWorkspace:%p "
                @"CGSMoveWorkspaceWindowList:%p",
                _CGSDefaultConnection, CGSGetWorkspace,
                CGSGetWindowWorkspace, CGSMoveWorkspaceWindowList);
  }
  [NSApp activateIgnoringOtherApps:YES];
  [prefWindow center];
  [prefWindow makeKeyAndOrderFront:nil];
  if (prefsColorWellWasShowing_) {
    [[NSColorPanel sharedColorPanel] setIsVisible:YES];
  }
}

- (void)hidePreferences {
  if ([self preferencesWindowIsShowing]) {
    [[self window] setIsVisible:NO];
  }
}

- (BOOL)preferencesWindowIsShowing {
  return ([[self window] isVisible]);
}

#pragma mark Account Management

- (IBAction)setupAccount:(id)sender {
  NSWindow *preferenceWindow = [self window];
  QSBSetUpAccountWindowController *controller
    = [[[QSBSetUpAccountWindowController alloc]
        initWithParentWindow:preferenceWindow] autorelease];
  NSWindow *setUpWindow = [controller window];
  [NSApp beginSheet:setUpWindow
     modalForWindow:preferenceWindow
      modalDelegate:self
     didEndSelector:@selector(setUpAccountSheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (IBAction)editAccount:(id)sender {
  NSArray *selections = [accountsListController_ selectedObjects];
  HGSAccount *account = [selections objectAtIndex:0];
  if ([account isEditable]) {
    NSString *accountTypeName = [account type];
    HGSExtensionPoint *accountTypesEP = [HGSExtensionPoint accountTypesPoint];
    HGSAccountType *accountType
      = [accountTypesEP extensionWithIdentifier:accountTypeName];
    HGSProtoExtension *accountProto = [accountType protoExtension];
    NSString *editAccountControllerClassName
      = [accountProto objectForKey:kQSBEditAccountWindowControllerClassName];
    Class editAccountControllerClass
      = NSClassFromString(editAccountControllerClassName);
    NSString *editAccountNibName
      = [accountProto objectForKey:kQSBEditAccountWindowNibName];
    QSBEditAccountWindowController *editWindowController
      = [[editAccountControllerClass alloc]
         initWithWindowNibName:editAccountNibName account:account];
    if (editWindowController) {
      NSWindow *preferenceWindow = [self window];
      NSWindow *editWindow = [editWindowController window];
      [NSApp beginSheet:editWindow
         modalForWindow:preferenceWindow
          modalDelegate:self
         didEndSelector:@selector(editAccountSheetDidEnd:returnCode:contextInfo:)
            contextInfo:editWindowController];
    } else {
      HGSLog(@"Failed to load edit account nib '%@' for account '%@'.",
             editAccountNibName, account);
    }
  }
}

- (IBAction)removeAccount:(id)sender {
  NSArray *selections = [accountsListController_ selectedObjects];
  if ([selections count]) {
    HGSAccount *accountToRemove = [selections objectAtIndex:0];
    NSString *summary = NSLocalizedString(@"About to remove an account.",
                                          nil);
    NSString *format
      = NSLocalizedString(@"Removing the account '%@' will disable and remove "
                          @"all search sources associated with this account.",
                          nil);
    NSString *userName = [accountToRemove userName];
    NSString *explanation = [NSString stringWithFormat:format, userName];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:summary];
    [alert setInformativeText:explanation];
    [alert addButtonWithTitle:NSLocalizedString(@"Remove", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(removeAccountAlertDidEnd:
                                              returnCode:contextInfo:)
                        contextInfo:accountToRemove];
  }
}

- (void)authenticateAccounts {
  // Validate the accounts so that the user will have up-to-date
  // knowledge of account status.
  NSArray *accounts = [accountsListController_ arrangedObjects];
  [accounts makeObjectsPerformSelector:@selector(authenticate)];
}

- (IBAction)selectTabForSender:(id)sender {
  [tabView_ selectTabViewItemAtIndex:[sender tag]];
}

#pragma mark Delegate Methods

- (void)windowDidBecomeKey:(NSNotification *)notification {
  NSWindow *window = [notification object];
  if (window == [self window]) {
    [self authenticateAccounts];
  }
}

- (void)windowDidResignKey:(NSNotification *)notification {
  NSWindow *window = [notification object];
  if (window == [self window]) {
    prefsColorWellWasShowing_ = [[NSColorPanel sharedColorPanel] isVisible];
    [[NSColorPanel sharedColorPanel] setIsVisible:NO];
  }
}

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client {
  if ([client isKindOfClass:[GTMHotKeyTextField class]]) {
    return [GTMHotKeyFieldEditor sharedHotKeyFieldEditor];
  } else {
    return nil;
  }
}

- (void)setUpAccountSheetDidEnd:(NSWindow *)sheet
                     returnCode:(NSInteger)returnCode
                    contextInfo:(void *)contextInfo {
  [sheet close];
}

- (void)editAccountSheetDidEnd:(NSWindow *)sheet
                    returnCode:(NSInteger)returnCode
                   contextInfo:(void *)contextInfo {
  QSBEditAccountWindowController *editWindowController = contextInfo;
  [sheet close];
  [editWindowController release];
}

- (void)updateColorPopup {
  NSInteger idx = [self indexOfColor:[self selectedColor]];
  if (idx == NSNotFound) {
    [colorPopUp_ selectItemWithTag:kCustomColorTag];
    NSMenuItem *item = [colorPopUp_ selectedItem];
    [item setTitle:[[self selectedColor] crayonName]];
  } else {
    [colorPopUp_ selectItemAtIndex:idx];
  }
  [self validateMenuItem:[colorPopUp_ selectedItem]];
}

- (NSArray *)sourceSortDescriptor {
  return sourceSortDescriptor_;
}

- (void)setSourceSortDescriptor:(NSArray *)value {
  [sourceSortDescriptor_ autorelease];
  sourceSortDescriptor_ = [value retain];
}

- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar; {
  NSArray *identifiers = [[toolbar items] valueForKey:@"itemIdentifier"];
  return identifiers;
}

#pragma mark Account Management

- (void)removeAccountAlertDidEnd:(NSWindow *)sheet
                      returnCode:(int)returnCode
                     contextInfo:(void *)contextInfo {
  if (returnCode == NSAlertFirstButtonReturn) {
    HGSAccount *accountToRemove = (HGSAccount *)contextInfo;
    NSUInteger selection = [accountsListController_ selectionIndex];
    if (selection > 0) {
      [accountsListController_ setSelectionIndex:(selection - 1)];
    }
    [accountToRemove remove];
  }
}

- (void)didAddAccount:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  HGSAccount *newAccount = [userInfo objectForKey:kHGSExtensionKey];
  if (newAccount) {
    NSArray *accounts = [NSArray arrayWithObject:newAccount];
    [accountsListController_ setSelectedObjects:accounts];
  } else {
    HGSLogDebug(@"Could not highlight newly added account '%@' because "
                @"it seems to be missing.", [newAccount userName]);
  }
}

#pragma mark Bindings

// Tied to the Open QSB At Login checkbox
- (UInt32)openedAtLoginSeedValue {
  return openAtLoginItemsSeedValue_;
}

- (BOOL)openedAtLogin {
  BOOL opened = NO;
  if (openAtLoginItemsList_) {
    NSBundle *ourBundle = [NSBundle mainBundle];
    NSString *bundlePath = [ourBundle bundlePath];
    NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
    CFArrayRef cfItems
      = LSSharedFileListCopySnapshot(openAtLoginItemsList_,
                                     &openAtLoginItemsSeedValue_);
    NSArray *items = GTMCFAutorelease(cfItems);
    for (id item in items) {
      CFURLRef itemURL;
      if (LSSharedFileListItemResolve((LSSharedFileListItemRef)item,
                                      0, &itemURL, NULL) == 0) {
        if ([bundleURL isEqual:(NSURL *)itemURL]) {
          opened = YES;
          break;
        }
        CFRelease(itemURL);
      }
    }
  }
  return opened;
}

- (void)setOpenedAtLogin:(BOOL)opened {
  if (!openAtLoginItemsList_) return;
  NSBundle *ourBundle = [NSBundle mainBundle];
  NSString *bundlePath = [ourBundle bundlePath];
  NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
  if (opened) {
    NSNumber *nsTrue = [NSNumber numberWithBool:YES];
    NSDictionary *propertiesToSet
      = [NSDictionary dictionaryWithObject:nsTrue
                                    forKey:kQSBSharedFileListLoginItemHidden];
    LSSharedFileListItemRef item
      = LSSharedFileListInsertItemURL(openAtLoginItemsList_,
                                      kLSSharedFileListItemLast,
                                      NULL,
                                      NULL,
                                      (CFURLRef)bundleURL,
                                      (CFDictionaryRef)propertiesToSet,
                                      NULL);
    CFRelease(item);
    openAtLoginItemsSeedValue_
      = LSSharedFileListGetSeedValue(openAtLoginItemsList_);
  } else {
    CFArrayRef cfItems
      = LSSharedFileListCopySnapshot(openAtLoginItemsList_,
                                     &openAtLoginItemsSeedValue_);
    NSArray *items = GTMCFAutorelease(cfItems);
    for (id item in items) {
      CFURLRef itemURL;
      if (LSSharedFileListItemResolve( (LSSharedFileListItemRef)item,
                                      0, &itemURL, NULL) == 0) {
        if ([bundleURL isEqual:(NSURL *)itemURL]) {
          OSStatus status
            = LSSharedFileListItemRemove(openAtLoginItemsList_,
                                         (LSSharedFileListItemRef)item);
          if (status) {
            HGSLog(@"Unable to remove %@ from open at login (%d)",
                   itemURL, status);
          }
        }
        CFRelease(itemURL);
      }
    }
  }
}

void OpenAtLoginItemsChanged(LSSharedFileListRef inList, void *context) {
  UInt32 seedValue = LSSharedFileListGetSeedValue(inList);
  QSBPreferenceWindowController *controller
    = (QSBPreferenceWindowController *)context;
  UInt32 contextSeedValue = [controller openedAtLoginSeedValue];
  if (contextSeedValue != seedValue) {
    [controller willChangeValueForKey:@"openedAtLogin"];
    [controller didChangeValueForKey:@"openedAtLogin"];
  }
}

@end

//
//  QSBApplicationDelegate.m
//
//  Copyright (c) 2006-2009 Google Inc. All rights reserved.
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
//

#import "QSBApplicationDelegate.h"

#import <unistd.h>
#import <Vermilion/Vermilion.h>
#import <Sparkle/Sparkle.h>
#import <Quartz/Quartz.h>

#import <GTM/GTMCarbonEvent.h>
#import <GTM/GTMGarbageCollection.h>
#import <GTM/GTMGeometryUtils.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMSystemVersion.h>
#import <GTM/GTMFoundationUnitTestingUtilities.h>
#import <GTM/GTMHotKeyTextField.h>
#import <GTM/GTMNSWorkspace+Running.h>
#import <GTM/GTMNSObject+KeyValueObserving.h>

#import "QSBHGSObjectSpecifiers.h"
#import "QSBKeyMap.h"
#import "QSBPreferences.h"
#import "QSBPreferenceWindowController.h"
#import "QSBHGSResult+NSPasteboard.h"
#import "QSBUserMessenger.h"
#import "QSBSearchWindowController.h"
#import "QSBHGSDelegate.h"
#import "QSBResultsWindowController.h"
#import "PFMoveApplication.h"
#import "QSBDebugWindowController.h"
#import "QSBActionPresenter.h"

// Adds a weak reference to QLPreviewPanel so that we work on Leopard.
__asm__(".weak_reference _OBJC_CLASS_$_QLPreviewPanel");

// Local pref set once we've been launched. Used to control whether or not we
// show the help window at startup.
NSString *const kQSBBeenLaunchedPrefKey = @"QSBBeenLaunchedPrefKey";

// The preference containing the configuration for each plugin.
// It is a dictionary with two keys:
// kQSBPluginConfigurationPrefVersionKey
// and kQSBPluginConfigurationPrefPluginsKey.
static NSString *const kQSBPluginConfigurationPrefKey
  = @"QSBPluginConfigurationPrefKey";
// The version of the preferences data stored in the dictionary (NSNumber).
static NSString *const kQSBPluginConfigurationPrefVersionKey
  = @"QSBPluginConfigurationPrefVersionKey";
// The key for an NSArray of plugin configuration information.
static NSString *const kQSBPluginConfigurationPrefPluginsKey
  = @"QSBPluginConfigurationPrefPluginsKey";
static const NSInteger kQSBPluginConfigurationPrefCurrentVersion = 1;

// The preference containing the information about our known
// accounts. It is a dictionary with one key (kQSBAccountsPrefKey) that
// contains an array of accounts.  Older versions of preferences have an
// outer dictionary container with this key (kQSBAccountsPrefKey) which
// contained the array of accounts with the kQSBAccountsPrefAccountsKey.
static NSString *const kQSBAccountsPrefKey = @"QSBAccountsPrefKey";
// The old key for an NSArray of account information.
static NSString *const kQSBAccountsPrefAccountsKey
  = @"QSBAccountsPrefAccountsKey";

static NSString *const kQSBHomepageKey = @"QSBHomepageURL";
static NSString *const kQSBFeedbackKey = @"QSBFeedbackURL";

// Human-readable growl notification name.
static NSString *const kGrowlNotificationName = @"QSB User Message";

@interface QSBApplicationDelegate ()

@property (retain, nonatomic) NSAppleEventDescriptor *applicationASDictionary;

// sets us up so we're looking for the right hotkey
- (void)updateHotKeyRegistration;

// our hotkey has been hit, let's do something about it
- (void)hitHotKey:(id)sender;

// Called when we should update how our status icon appears
- (void)updateIconInMenubar;

- (void)hotKeyValueChanged:(GTMKeyValueChangeNotification *)note;
- (void)iconInMenubarValueChanged:(GTMKeyValueChangeNotification *)note;

// Identify all sdef files and compose the application AE dictionary.
- (void)composeApplicationAEDictionary;

// Reconcile what we previously knew about accounts and saved in our
// preferences with what we now know about accounts.
- (void)inventoryAccounts;

// Update our preferences with the current account information.
- (void)updateAccountsPreferences;

// Reconcile what we previously knew about plugins and extensions
// and had saved in our preferences with a new inventory
// of plugins and extensions, then enable each as appropriate.
- (void)inventoryPlugins;

// Record all current plugin configuration information.
- (void)updatePluginsPreferences;

// Check if the screen saver is running.
- (BOOL)isScreenSaverActive;

// Check if front row is active.
- (BOOL)frontRowActive;

// Called when we want to update menus with a proper app name
- (void)updateMenuWithAppName:(NSMenu* )menu;

// Each plugin's protoExtensions must be monitored in order for the app
// delegate's list of sourceExtensions to be properly updated.
- (void)observeProtoExtensions;
- (void)stopObservingProtoExtensions;
- (void)protoExtensionsValueChanged:(GTMKeyValueChangeNotification *)note;

// Present a user message using QSBUserMessenger.
- (void)presentUserMessageViaMessenger:(NSDictionary *)messageDict;

// Present a user message using Growl.
- (void)presentUserMessageViaGrowl:(NSDictionary *)messageDict;

// Return the time required to count as a double click.
- (NSTimeInterval)doubleClickTime;

- (BOOL)suppressStartupDialogs;

- (void)actionWillPerformNotification:(NSNotification *)notification;
- (void)actionDidPerformNotification:(NSNotification *)notification;
- (void)pluginOrExtensionDidChangeEnabled:(NSNotification*)notification;
- (void)pluginsDidInstall:(NSNotification *)notification;
- (void)pluginsValueChanged:(GTMKeyValueChangeNotification *)notification;
- (void)protoExtensionsValueChanged:(GTMKeyValueChangeNotification *)note;
- (void)didAddOrRemoveAccount:(NSNotification *)notification;
- (void)didLaunchApplication:(NSNotification *)notification;
- (void)didTerminateApplication:(NSNotification *)notification;
- (void)presentMessageToUser:(NSNotification *)notification;

- (void)handleGetSDEFEvent:(NSAppleEventDescriptor *)event
            withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
@end


@interface NSEvent (QSBApplicationEventAdditions)

- (NSUInteger)qsbModifierFlags;

@end

@implementation QSBApplicationDelegate

GTM_METHOD_CHECK(NSWorkspace, gtm_processInfoDictionaryForActiveApp);
GTM_METHOD_CHECK(GTMHotKeyTextFieldCell, stringForKeycode:useGlyph:resourceBundle:);
GTM_METHOD_CHECK(NSObject, gtm_addObserver:forKeyPath:selector:userInfo:options:);
GTM_METHOD_CHECK(NSObject, gtm_stopObservingAllKeyPaths);

@synthesize applicationASDictionary = applicationASDictionary_;
@synthesize searchWindowController = searchWindowController_;
@synthesize hotKey = hotKey_;

+ (NSSet *)keyPathsForValuesAffectingSourceExtensions {
  NSSet *affectingKeys = [NSSet setWithObject:kQSBPluginsScriptingKVOKey];
  return affectingKeys;
}

- (id)init {
  if ((self = [super init])) {
    hgsDelegate_ = [[QSBHGSDelegate alloc] init];
    [[HGSPluginLoader sharedPluginLoader] setDelegate:hgsDelegate_];

    NSNotificationCenter *wsNotificationCenter
      = [[NSWorkspace sharedWorkspace] notificationCenter];
    [wsNotificationCenter addObserver:self
                             selector:@selector(didLaunchApplication:)
                                 name:NSWorkspaceDidLaunchApplicationNotification
                               object:nil];
    [wsNotificationCenter addObserver:self
                             selector:@selector(didTerminateApplication:)
                                 name:NSWorkspaceDidTerminateApplicationNotification
                               object:nil];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(presentMessageToUser:)
               name:kHGSUserMessageNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(pluginsDidInstall:)
               name:kHGSPluginLoaderDidInstallPluginsNotification
             object:[HGSPluginLoader sharedPluginLoader]];
    [QSBPreferences registerDefaults];

    BOOL iconInDock
      = [[NSUserDefaults standardUserDefaults] boolForKey:kQSBIconInDockKey];
    if (iconInDock) {
      ProcessSerialNumber psn = { 0, kCurrentProcess };
      TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    }
    searchWindowController_ = [[QSBSearchWindowController alloc] init];

    NSArray *supportedTypes
      = [NSArray arrayWithObjects:NSStringPboardType, NSRTFPboardType, nil];
    [NSApp registerServicesMenuSendTypes:supportedTypes
                             returnTypes:supportedTypes];

    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
  }
  return self;
}

- (void)dealloc {
  [self stopObservingProtoExtensions];
  [self gtm_stopObservingAllKeyPaths];
  [userMessenger_ release];
  [statusItem_ release];
  NSNotificationCenter *workspaceNC
    = [[NSWorkspace sharedWorkspace] notificationCenter];
  [workspaceNC removeObserver:self];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [prefsWindowController_ release];
  [hgsDelegate_ release];
  [searchWindowController_ release];
  [applicationASDictionary_ release];
  [super dealloc];
}

- (void)awakeFromNib {
  // set up all our menu bar UI
  [self updateIconInMenubar];

  // watch for prefs changing
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults gtm_addObserver:self
             forKeyPath:kQSBHotKeyKey
                   selector:@selector(hotKeyValueChanged:)
                   userInfo:nil
                    options:0];
  [defaults gtm_addObserver:self
                 forKeyPath:kQSBHotKeyKeyEnabled
                   selector:@selector(hotKeyValueChanged:)
                   userInfo:nil
                    options:0];
  [defaults gtm_addObserver:self
                 forKeyPath:kQSBHotKeyKey2
                   selector:@selector(hotKeyValueChanged:)
                   userInfo:nil
                    options:0];
  [defaults gtm_addObserver:self
                 forKeyPath:kQSBHotKeyKey2Enabled
                   selector:@selector(hotKeyValueChanged:)
                   userInfo:nil
                    options:0];
  [defaults gtm_addObserver:self
             forKeyPath:kQSBIconInMenubarKey
                   selector:@selector(iconInMenubarValueChanged:)
                   userInfo:nil
                    options:0];
  [statusShowSearchBoxItem_ setTarget:searchWindowController_];
  [statusShowSearchBoxItem_ setAction:@selector(showSearchWindow:)];
  [dockShowSearchBoxItem_ setTarget:searchWindowController_];
  [dockShowSearchBoxItem_ setAction:@selector(showSearchWindow:)];
#if DEBUG
  [statusItemMenu_ addItem:[NSMenuItem separatorItem]];
  [statusItemMenu_ addItemWithTitle:@"Show Debug Window"
                             action:@selector(showDebugWindow:)
                      keyEquivalent:@""];
  [dockMenu_ addItem:[NSMenuItem separatorItem]];
  [dockMenu_ addItemWithTitle:@"Show Debug Window"
                       action:@selector(showDebugWindow:)
                keyEquivalent:@""];
#endif
}

- (void)hotKeyValueChanged:(GTMKeyValueChangeNotification *)note {
  [self updateHotKeyRegistration];
}

- (void)iconInMenubarValueChanged:(GTMKeyValueChangeNotification *)note {
  [self updateIconInMenubar];
}

// method that is called when the modifier keys are hit and we are inactive
- (void)modifiersChangedWhileInactive:(NSEvent*)event {
  // If we aren't activated by hotmodifiers, we don't want to be here
  // and if we are in the process of activating, we want to ignore the hotkey
  // so we don't try to process it twice.
  if (!hotModifiers_ || [NSApp keyWindow]) return;

  // There is no way of knowing what the previous state of the modifiers was
  // without saving it off. We only want to start this sequence if the
  // previous state was no modifiers, so we track the modifier state at all
  // times and keep it stored in oldHotModifiers_.
  NSUInteger oldHotModifiers = oldHotModifiers_;
  oldHotModifiers_ = [event qsbModifierFlags];
  if (oldHotModifiers || oldHotModifiers_ != hotModifiers_) return;

  const useconds_t oneMilliSecond = 10000;
  UInt16 modifierKeys[] = {
    0,
    kVK_Shift,
    kVK_CapsLock,
    kVK_RightShift,
  };
  if (hotModifiers_ == NSControlKeyMask) {
    modifierKeys[0] = kVK_Control;
  } else if (hotModifiers_ == NSAlternateKeyMask) {
    modifierKeys[0]  = kVK_Option;
  } else if (hotModifiers_ == NSCommandKeyMask) {
    modifierKeys[0]  = kVK_Command;
  }
  QSBKeyMap *hotMap = [[[QSBKeyMap alloc] initWithKeys:modifierKeys
                                               count:1] autorelease];
  QSBKeyMap *invertedHotMap
    = [[[QSBKeyMap alloc] initWithKeys:modifierKeys
                                count:sizeof(modifierKeys) / sizeof(UInt16)]
       autorelease];
  invertedHotMap = [invertedHotMap keyMapByInverting];
  NSTimeInterval startDate = [NSDate timeIntervalSinceReferenceDate];
  BOOL isGood = NO;
  while(([NSDate timeIntervalSinceReferenceDate] - startDate)
        < [self doubleClickTime]) {
    QSBKeyMap *currentKeyMap = [QSBKeyMap currentKeyMap];
    if ([currentKeyMap containsAnyKeyIn:invertedHotMap]
        || GetCurrentButtonState()) {
      return;
    }
    if (![currentKeyMap containsAnyKeyIn:hotMap]) {
      // Key released;
      isGood = YES;
      break;
    }
    usleep(oneMilliSecond);
  }
  if (!isGood) return;
  isGood = NO;
  startDate = [NSDate timeIntervalSinceReferenceDate];
  while(([NSDate timeIntervalSinceReferenceDate] - startDate)
        < [self doubleClickTime]) {
    QSBKeyMap *currentKeyMap = [QSBKeyMap currentKeyMap];
    if ([currentKeyMap containsAnyKeyIn:invertedHotMap]
        || GetCurrentButtonState()) {
      return;
    }
    if ([currentKeyMap containsAnyKeyIn:hotMap]) {
      // Key down
      isGood = YES;
      break;
    }
    usleep(oneMilliSecond);
  }
  if (!isGood) return;
  startDate = [NSDate timeIntervalSinceReferenceDate];
  while(([NSDate timeIntervalSinceReferenceDate] - startDate)
        < [self doubleClickTime]) {
    QSBKeyMap *currentKeyMap = [QSBKeyMap currentKeyMap];
    if ([currentKeyMap containsAnyKeyIn:invertedHotMap]
        || GetCurrentButtonState()) {
      return;
    }
    if (![currentKeyMap containsAnyKeyIn:hotMap]) {
      // Key Released
      isGood = YES;
      break;
    }
    usleep(oneMilliSecond);
  }
  if (isGood) {
    // Once we are "active" we no longer will receive modifier notifications
    // through this channel, so reset it to the "clean" state.
    oldHotModifiers_ = 0;
    [self hitHotKey:self];
  }
}

- (void)modifiersChangedWhileActive:(NSEvent*)event {
  // A statemachine that tracks our state via hotModifiersState_.
  // Simple incrementing state.
  if (!hotModifiers_) {
    return;
  }
  NSTimeInterval timeWindowToRespond
    = lastHotModifiersEventCheckedTime_ + [self doubleClickTime];
  lastHotModifiersEventCheckedTime_ = [event timestamp];
  if (hotModifiersState_
      && lastHotModifiersEventCheckedTime_ > timeWindowToRespond) {
    // Timed out. Reset.
    hotModifiersState_ = 0;
    return;
  }
  NSUInteger flags = [event qsbModifierFlags];
  BOOL isGood = NO;
  if (!(hotModifiersState_ % 2)) {
    // This is key down cases
    isGood = flags == hotModifiers_;
  } else {
    // This is key up cases
    isGood = flags == 0;
  }
  if (!isGood) {
    // reset
    hotModifiersState_ = 0;
    return;
  } else {
    hotModifiersState_ += 1;
  }
  if (hotModifiersState_ == 3) {
    // We've worked our way through the state machine to success!
    [self hitHotKey:self];
  }
}

// method that is called when a key changes state and we are active
- (void)keysChangedWhileActive:(NSEvent*)event {
  if (!hotModifiers_) return;
  hotModifiersState_ = 0;
}

- (NSMenu*)statusItemMenu {
  return statusItemMenu_;
}

- (void)updateIconInMenubar {
  BOOL iconInMenubar
    = [[NSUserDefaults standardUserDefaults] boolForKey:kQSBIconInMenubarKey];
  NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
  if (iconInMenubar) {
    NSImage *defaultImg = [NSImage imageNamed:@"QSBStatusMenuIconGray"];
    NSImage *altImg = [NSImage imageNamed:@"QSBStatusMenuIconGrayInverted"];
    HGSAssert(defaultImg, @"Can't find QSBStatusMenuIconGray");
    HGSAssert(altImg,  @"Can't find QSBStatusMenuIconGrayInverted");
    CGFloat itemWidth = [defaultImg size].width + 8.0;
    statusItem_ = [[statusBar statusItemWithLength:itemWidth] retain];
    [statusItem_ setMenu:statusItemMenu_];
    [statusItem_ setHighlightMode:YES];
    [statusItem_ setImage:defaultImg];
    [statusItem_ setAlternateImage:altImg];
  } else if (statusItem_) {
    [statusBar removeStatusItem:statusItem_];
    [statusItem_ autorelease];
    statusItem_ = nil;
  }
}

- (void)setHotKey:(GTMHotKey *)hotKey {

}
- (void)updateHotKeyRegistration {
  GTMCarbonEventDispatcherHandler *dispatcher
    = [GTMCarbonEventDispatcherHandler sharedEventDispatcherHandler];

  // Remove any hotkey we currently have.
  if (carbonHotKey_) {
    [dispatcher unregisterHotKey:carbonHotKey_];
    [carbonHotKey_ release];
    carbonHotKey_ = nil;
  }

  NSMenuItem *statusMenuItem = [statusItemMenu_ itemAtIndex:0];
  NSString *statusMenuItemKey = @"";
  uint statusMenuItemModifiers = 0;
  [statusMenuItem setKeyEquivalent:statusMenuItemKey];
  [statusMenuItem setKeyEquivalentModifierMask:statusMenuItemModifiers];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSDictionary *newKey = [ud valueForKeyPath:kQSBHotKeyKey];
  NSNumber *value = [newKey objectForKey:kQSBHotKeyDoubledModifierKey];
  BOOL hotKey1UseDoubleModifier = [value boolValue];
  BOOL hotkey1Enabled = [ud boolForKey:kQSBHotKeyKeyEnabled];
  BOOL hotkey2Enabled = [ud boolForKey:kQSBHotKeyKey2Enabled];
  if (!newKey || hotKey1UseDoubleModifier || hotkey2Enabled) {
    // set up double tap if appropriate
    hotModifiers_ = NSCommandKeyMask;
    statusMenuItemKey = [NSString stringWithUTF8String:"⌘"];
    statusMenuItemModifiers = NSCommandKeyMask;
  } else {
    hotModifiers_ = 0;
  }
  if (hotkey1Enabled && !hotKey1UseDoubleModifier) {
    // setting hotModifiers_ means we're not looking for a double tap
    value = [newKey objectForKey:kQSBHotKeyModifierFlagsKey];
    uint modifiers = [value unsignedIntValue];
    value = [newKey objectForKey:kQSBHotKeyKeyCodeKey];
    uint keycode = [value unsignedIntValue];
    carbonHotKey_ = [[dispatcher registerHotKey:keycode
                                      modifiers:modifiers
                                         target:self
                                         action:@selector(hitHotKey:)
                                       userInfo:nil
                                    whenPressed:YES] retain];

    NSBundle *bundle = [NSBundle bundleForClass:[GTMHotKeyTextField class]];
    statusMenuItemKey = [GTMHotKeyTextFieldCell stringForKeycode:keycode
                                                        useGlyph:YES
                                                  resourceBundle:bundle];
    statusMenuItemModifiers = modifiers;
  }
  [statusMenuItem setKeyEquivalent:statusMenuItemKey];
  [statusMenuItem setKeyEquivalentModifierMask:statusMenuItemModifiers];
}

- (void)hitHotKey:(id)sender {
  hotModifiersState_ = 0;
  if (otherQSBPSN_.highLongOfPSN || otherQSBPSN_.lowLongOfPSN) {
    // We bow down before the other QSB
    return;
  }

  // Try to (partially) address radar 5856746. On Leopard we can steal focus
  // from the screensaver password dialog (SecurityAgent.app) on hotkey.
  // This is an Apple bug, and potential lets an attacker open Terminal and
  // type commands.
  // We can't fix this (there is a race condition around detecting whether
  // the screensaver is frontmost), but we can at least try to make it
  // less likely.
  // Also check to see if frontRow is running, and if so beep and don't
  // activate.
  // For http://buganizer/issue?id=652067
  if ([self isScreenSaverActive] || [self frontRowActive]) {
    NSBeep();
    return;
  }

  [searchWindowController_ hitHotKey:sender];
}

- (BOOL)isScreenSaverActive {
  NSDictionary *processInfo
  = [[NSWorkspace sharedWorkspace] gtm_processInfoDictionaryForActiveApp];
  NSString *bundlePath
  = [processInfo objectForKey:kGTMWorkspaceRunningBundlePath];
  // ScreenSaverEngine is the frontmost app if the screen saver is actually
  // running Security Agent is the frontmost app if the "enter password"
  // dialog is showing
  return ([bundlePath hasSuffix:@"ScreenSaverEngine.app"]
          || [bundlePath hasSuffix:@"SecurityAgent.app"]);
}

- (BOOL)frontRowActive {
  // Can't use NSWorkspace here because of
  // rdar://5049713 When FrontRow is frontmost app,
  // [NSWorkspace -activeApplication] returns nil
  NSDictionary *processDict
  = [[NSWorkspace sharedWorkspace] gtm_processInfoDictionaryForActiveApp];
  NSString *bundleID
  = [processDict objectForKey:kGTMWorkspaceRunningBundleIdentifier];
  return [bundleID isEqualToString:@"com.apple.frontrow"];
}

- (void)updateMenuWithAppName:(NSMenu* )menu {
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *newName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
  NSArray *items = [menu itemArray];
  for (NSMenuItem *item in items) {
    NSString *appName = @"$APPNAME$";
    NSString *title = [item title];

    if ([title rangeOfString:appName].length != 0) {
      NSString *newTitle = [title stringByReplacingOccurrencesOfString:appName
                                                            withString:newName];
      [item setTitle:newTitle];
    }
    NSMenu *subMenu = [item submenu];
    if (subMenu) {
      [self updateMenuWithAppName:subMenu];
    }
  }
}

// Returns the amount of time between two clicks to be considered a double click
- (NSTimeInterval)doubleClickTime {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSTimeInterval doubleClickThreshold
    = [defaults doubleForKey:@"com.apple.mouse.doubleClickThreshold"];

  // if we couldn't find the value in the user defaults, take a
  // conservative estimate
  if (doubleClickThreshold <= 0.0) {
    doubleClickThreshold = 1.0;
  }
  return doubleClickThreshold;
}

-(BOOL)suppressStartupDialogs {
  NSDictionary *envVars = [[NSProcessInfo processInfo] environment];
  NSString *value = [envVars objectForKey:@"QSBSuppressStartupDialogs"];
  return ([value boolValue]
          || [GTMFoundationUnitTestingUtilities areWeBeingUnitTested]);
}

#pragma mark Actions

- (IBAction)showDebugWindow:(id)sender {
  [[QSBDebugWindowController sharedWindowController] showWindow:sender];
}

- (IBAction)orderFrontStandardAboutPanel:(id)sender {
  [NSApp activateIgnoringOtherApps:YES];
  [NSApp orderFrontStandardAboutPanelWithOptions:nil];
}

- (IBAction)showPreferences:(id)sender {
  if (!prefsWindowController_) {
    prefsWindowController_ = [[QSBPreferenceWindowController alloc] init];
  }
  [prefsWindowController_ showPreferences:sender];
  [NSApp activateIgnoringOtherApps:YES];
}

// Open a browser window with the QSB homepage
- (IBAction)showProductHomepage:(id)sender {
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *homepageStr = [bundle objectForInfoDictionaryKey:kQSBHomepageKey];
  NSURL *homepageURL = [NSURL URLWithString:homepageStr];
  [[NSWorkspace sharedWorkspace] openURL:homepageURL];
}

- (IBAction)sendFeedbackToGoogle:(id)sender {
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *feedbackStr = [bundle objectForInfoDictionaryKey:kQSBFeedbackKey];
  NSURL *feedbackURL = [NSURL URLWithString:feedbackStr];
  [[NSWorkspace sharedWorkspace] openURL:feedbackURL];
}

#pragma mark Plugins & Extensions Management

- (NSArray *)plugins {
  return [[HGSPluginLoader sharedPluginLoader] plugins];
}

- (void)inventoryPlugins {
  // Load up plugins
  NSArray *errors;
  HGSPluginLoader *pluginLoader = [HGSPluginLoader sharedPluginLoader];
  [pluginLoader loadPluginsWithErrors:&errors];
  for (NSDictionary *error in errors) {
    NSString *type = [error objectForKey:kHGSPluginLoaderPluginFailureKey];
    if (![type isEqualToString:kHGSPluginLoaderPluginFailedUnknownPluginType]) {
      //TODO(dmaclach): Change this over to an alert.
      HGSLogDebug(@"Unable to load %@ (%@)",
                  [error objectForKey:kHGSPluginLoaderPluginPathKey], type);
    }
  }
  // Load up and install accounts
  [self inventoryAccounts];
  // Retrieve list of configuration information for previously
  // inventoried plug-ins
  NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
  NSArray *pluginsFromPrefs = nil;
  NSDictionary *pluginPrefs
    = [standardDefaults objectForKey:kQSBPluginConfigurationPrefKey];
  // Check to make sure our plugin data is valid.
  if ([pluginPrefs isKindOfClass:[NSDictionary class]]) {
    NSNumber *version
      = [pluginPrefs objectForKey:kQSBPluginConfigurationPrefVersionKey];
    if ([version integerValue] == kQSBPluginConfigurationPrefCurrentVersion) {
      pluginsFromPrefs
        = [pluginPrefs objectForKey:kQSBPluginConfigurationPrefPluginsKey];
    }
  }
  // Install our plugins and enable them based on our previously stored
  // configuration.
  [pluginLoader installAndEnablePluginsBasedOnPluginsState:pluginsFromPrefs];
}

- (void)updatePluginsPreferences {
  NSArray *pluginState = [[HGSPluginLoader sharedPluginLoader] pluginsState];
  NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
  NSNumber *version
    = [NSNumber numberWithInteger:kQSBPluginConfigurationPrefCurrentVersion];
  NSDictionary *pluginsDict
    = [NSDictionary dictionaryWithObjectsAndKeys:
       pluginState, kQSBPluginConfigurationPrefPluginsKey,
       version, kQSBPluginConfigurationPrefVersionKey,
       nil];
  [standardDefaults setObject:pluginsDict
                       forKey:kQSBPluginConfigurationPrefKey];
  [standardDefaults synchronize];
}

- (NSArray *)sourceExtensions {
  // Iterate through all plugins and gather all source extensions.
  NSMutableArray *sourceExtensions = [NSMutableArray array];
  for (HGSPlugin *plugin in [self plugins]) {
    for (HGSProtoExtension *protoExtension in [plugin protoExtensions]) {
      if ([protoExtension
            isUserVisibleAndExtendsExtensionPoint:kHGSSourcesExtensionPoint]) {
        [sourceExtensions addObject:protoExtension];
      }
    }
  }
  return sourceExtensions;
}

- (void)observeProtoExtensions {
  NSArray *plugins = [self plugins];
  for (HGSPlugin *plugin in plugins) {
    [plugin gtm_addObserver:self
                 forKeyPath:kQSBProtoExtensionsKVOKey
                   selector:@selector(protoExtensionsValueChanged:)
                   userInfo:nil
                    options:0];
  }
}

- (void)stopObservingProtoExtensions {
  NSArray *plugins = [self plugins];
  for (HGSPlugin *plugin in plugins) {
    [plugin gtm_removeObserver:self
                    forKeyPath:kQSBProtoExtensionsKVOKey
                      selector:@selector(protoExtensionsValueChanged:)];
  }
}

#pragma mark Account Management

- (NSArray *)accounts {
  HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  return [accountsPoint extensions];
}

- (void)inventoryAccounts {
  // Retrieve list of known accounts.
  NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
  NSArray *accounts = [standardDefaults arrayForKey:kQSBAccountsPrefKey];
  if (!accounts) {
    // We may have an older version of account information.
    NSDictionary *dict = [standardDefaults dictionaryForKey:kQSBAccountsPrefKey];
    accounts = [dict objectForKey:kQSBAccountsPrefAccountsKey];
  }
  HGSAccountsExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  [accountsPoint addAccountsFromArray:accounts];
  [self updateAccountsPreferences];  // In case any accounts have been updated.
}

- (void)updateAccountsPreferences {
  // Update preferences to current account knowledge.
  NSArray *archivableAccounts
    = [[HGSExtensionPoint accountsPoint] accountsAsArray];
  NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
  [standardDefaults setObject:archivableAccounts
                       forKey:kQSBAccountsPrefKey];
  [standardDefaults synchronize];
}

#pragma mark Application Delegate Methods

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  if ([GTMSystemVersion isLeopard]) {
    // Force load the private framework that has the QuickLook APIs
    // On Leopard.
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
  #error Clean up this mess now that we don't support Leopard
#endif //  MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
    NSBundle *qlUI = [NSBundle bundleWithPath:@"/System/Library/"
                      @"PrivateFrameworks/QuickLookUI.framework"];
    _GTMDevAssert(qlUI, @"Unable to load qlUI");
    NSError *error = nil;
    BOOL didLoad = [qlUI loadAndReturnError:&error];
    if (!didLoad) {
      NSLog(@"Unable to load QuickLookUI.framework (%@)", error);
    }
    Class cls = NSClassFromString(@"QLPreviewPanel");
    if (!cls) {
      NSLog(@"Unable to load QLPreviewPanel class");
    }
  }
  // If the user launches us hidden we don't want to activate.
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSDictionary *processDict
    = [ws gtm_processInfoDictionary];
  NSNumber *nsDoNotActivateOnStartup
    = [processDict valueForKey:kGTMWorkspaceRunningIsHidden];
  activateOnStartup_ = ![nsDoNotActivateOnStartup boolValue];
  if (activateOnStartup_) {
    activateOnStartup_ = ![ws gtm_wasLaunchedAsLoginItem];
  }
  if (activateOnStartup_) {
    // During startup we may inadvertently be made inactive, most likely due
    // to keychain access requests, so let's just force ourself to be
    // active.
    [NSApp activateIgnoringOtherApps:YES];
    if (![self suppressStartupDialogs]) {
      PFMoveToApplicationsFolderIfNecessary();
    }
  }
  [self updateHotKeyRegistration];
  [self updateMenuWithAppName:[NSApp mainMenu]];
  [self updateMenuWithAppName:dockMenu_];
  [self updateMenuWithAppName:statusItemMenu_];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // Load the search window
  [searchWindowController_ window];

  if (activateOnStartup_) {
    [searchWindowController_ showSearchWindow:self];
  }

  // Inventory and process all plugins and extensions.
  [self inventoryPlugins];

  // Now that all the plugins are loaded, start listening to them. We didn't
  // want to do it earlier as there is a lot of enabled/disabled messages
  // flying around that we don't actually care about.
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(actionWillPerformNotification:)
             name:kQSBActionPresenterWillPerformActionNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(actionDidPerformNotification:)
             name:kHGSActionDidPerformNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(pluginOrExtensionDidChangeEnabled:)
             name:kHGSPluginDidChangeEnabledNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(pluginOrExtensionDidChangeEnabled:)
             name:kHGSExtensionDidChangeEnabledNotification
           object:nil];
  HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  [nc addObserver:self
         selector:@selector(didAddOrRemoveAccount:)
             name:kHGSExtensionPointDidAddExtensionNotification
           object:accountsPoint];
  [nc addObserver:self
         selector:@selector(didAddOrRemoveAccount:)
             name:kHGSExtensionPointDidRemoveExtensionNotification
           object:accountsPoint];
  // Inventory the application and plugin Apple Script sdef files.
  [self composeApplicationAEDictionary];

  // Install a custom scripting dictionary event handler.
  NSAppleEventManager *aeManager = [NSAppleEventManager sharedAppleEventManager];
  [aeManager setEventHandler:self
                 andSelector:@selector(handleGetSDEFEvent:withReplyEvent:)
               forEventClass:kASAppleScriptSuite
                  andEventID:'gsdf'];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication
                    hasVisibleWindows:(BOOL)flag {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kQSBApplicationDidReopenNotification
                    object:NSApp];
  return NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  hotModifiersState_ = 0;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
  #error Clean up this mess now that we don't support Leopard
#endif //  MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
  QLPreviewPanel *panel
    = [NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel];
  if ([panel isVisible]) {
    [panel close];
  }
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  if (carbonHotKey_) {
    GTMCarbonEventDispatcherHandler *dispatcher
      = [GTMCarbonEventDispatcherHandler sharedEventDispatcherHandler];
    [dispatcher unregisterHotKey:carbonHotKey_];
    [carbonHotKey_ release];
    carbonHotKey_ = nil;
  }

  // Clean up our dock tile in case it got modified when
  // another qsb was launched.
  NSDockTile *tile = [NSApp dockTile];
  [tile setContentView:nil];
  [tile display];

  // Set it so we don't think this is first launch anymore
  [[NSUserDefaults standardUserDefaults] setBool:YES
                                          forKey:kQSBBeenLaunchedPrefKey];

  // Uninstall all extensions.
  [[self plugins] makeObjectsPerformSelector:@selector(uninstall)];
}

// Reroute certain properties off to our delegate for scripting purposes.
- (BOOL)application:(NSApplication *)sender
 delegateHandlesKey:(NSString *)key {
  if ([key isEqual:kQSBPluginsScriptingKVOKey]
      || [key isEqual:kQSBSourceExtensionsKVOKey]
      || [key isEqual:kQSBAccountsScriptingKVOKey]) {
    return YES;
  } else {
    return NO;
  }
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
  return dockMenu_;
}

- (void)application:(NSApplication *)app openFiles:(NSArray *)fileList {
  NSArray *plugIns
     = [fileList pathsMatchingExtensions:[NSArray arrayWithObject:@"hgs"]];
  NSMutableArray *otherFiles = [[fileList mutableCopy] autorelease];
  [otherFiles removeObjectsInArray:plugIns];
  BOOL wasGood = YES;
  NSError *error = nil;
  if ([plugIns count]) {
    // TODO(dmaclach): give user option to install globally or locally.
    // TODO(dmaclach): handle case where user launches plugin while qsb is
    // running. We will want to install it asap.
    // TODO(dmaclach): Add case for plugin that already is here.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *pluginsDir
      = [[hgsDelegate_ userApplicationSupportFolderForApp]
         stringByAppendingPathComponent:@"PlugIns"];
    if (![fm fileExistsAtPath:pluginsDir]) {
      wasGood = [fm createDirectoryAtPath:pluginsDir
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:&error];
    }
    if (wasGood) {
      for (NSString *plugIn in plugIns) {
        NSString *name = [plugIn lastPathComponent];
        NSString *newPath = [pluginsDir stringByAppendingPathComponent:name];
        wasGood = [fm copyItemAtPath:plugIn toPath:newPath error:&error];
        if (!wasGood) {
          break;
        }
      }
      BOOL isRunning = [NSApp currentEvent] != nil;
      if (wasGood && isRunning) {
        // TODO(dmaclach): Fix up so that we can load the plugins dynamically.
        HGSLog(@"Need to restart QSB for Plugins to take effect");
      }
    }
  }
  if ([otherFiles count]) {
    HGSResultArray *results = [HGSResultArray arrayWithFilePaths:otherFiles];
    [searchWindowController_ selectResults:results saveText:NO];
    [searchWindowController_ showSearchWindow:self];

  }
  NSApplicationDelegateReply reply = NSApplicationDelegateReplySuccess;
  if (!wasGood) {
    NSAlert *alert = [NSAlert alertWithError:error];
    // TODO(dmaclach): Better error alerts. The default ones are pathetic.
    [alert runModal];
    reply = NSApplicationDelegateReplyFailure;
  }
  [app replyToOpenOrPrint:reply];
}

- (void)getSelectionFromService:(NSPasteboard *)pasteboard
                       userData:(NSString *)userData
                          error:(NSString **)error {
  HGSResultArray *results = [HGSResultArray resultsWithPasteboard:pasteboard];
  if (results) {
    [searchWindowController_ selectResults:results saveText:NO];
  } else {
    NSString *userText = [pasteboard stringForType:NSStringPboardType];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    userText = [userText stringByTrimmingCharactersInSet:ws];
    [searchWindowController_ searchForString:userText];
  }
  [searchWindowController_ showSearchWindow:self];
}

#pragma mark Notifications

- (void)actionWillPerformNotification:(NSNotification *)notification {
  QSBActionPresenter *presenter = [notification object];
  HGSActionOperation *operation = [presenter actionOperation];
  HGSAction * action = [operation action];
  if ([action causesUIContextChange]) {
    [NSApp sendAction:@selector(hideSearchWindow:) to:nil from:self];
  }
}

- (void)actionDidPerformNotification:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSNumber *success = [userInfo objectForKey:kHGSActionCompletedSuccessfullyKey];
  if (success && ![success boolValue]) {
    // TODO(dmaclach): Once we are able to add localized strings again
    // maybe put a growl notification up about the action failing.
    NSBeep();
  }
}

- (void)pluginOrExtensionDidChangeEnabled:(NSNotification*)notification {
  // A plugin or extension has been enabled or disabled.  Update our prefs.
  [self updatePluginsPreferences];
}

- (void)pluginsDidInstall:(NSNotification *)notification {
  HGSPluginLoader *loader = [notification object];
  [loader gtm_addObserver:self
               forKeyPath:kQSBPluginsScriptingKVOKey
                 selector:@selector(pluginsValueChanged:)
                 userInfo:nil
                  options:(NSKeyValueObservingOptionPrior
                           | NSKeyValueObservingOptionInitial)];
  [GrowlApplicationBridge setGrowlDelegate:self];
}

- (void)pluginsValueChanged:(GTMKeyValueChangeNotification *)notification {
  NSNumber *prior = [[notification change]
                     objectForKey:NSKeyValueChangeNotificationIsPriorKey];

  if ([prior boolValue]) {
    [self stopObservingProtoExtensions];
  } else {
    [self observeProtoExtensions];
    [self updatePluginsPreferences];
  }
}

- (void)protoExtensionsValueChanged:(GTMKeyValueChangeNotification *)note {
  [self willChangeValueForKey:kQSBSourceExtensionsKVOKey];
  [self didChangeValueForKey:kQSBSourceExtensionsKVOKey];
}

- (void)didAddOrRemoveAccount:(NSNotification *)notification {
  [self willChangeValueForKey:@"accounts"];
  [self updateAccountsPreferences];
  [self didChangeValueForKey:@"accounts"];
}

// If we launch up another QSB we will let it handle all the activations until
// it dies. This is to make working with QSB easier for us as we can have a
// version running all the time, even when we are debugging the newer version.
// See "hitHotKey:" to see where otherQSBPSN_ is actually used.
- (void)didLaunchApplication:(NSNotification *)notification {
  if (otherQSBPSN_.highLongOfPSN == 0 && otherQSBPSN_.lowLongOfPSN == 0) {
    NSDictionary *userInfo = [notification userInfo];
    ProcessSerialNumber psn;
    psn.highLongOfPSN
      = [[userInfo objectForKey:@"NSApplicationProcessSerialNumberHigh"] unsignedIntValue];
    psn.lowLongOfPSN
      = [[userInfo objectForKey:@"NSApplicationProcessSerialNumberLow"] unsignedIntValue];
    NSDictionary *info
      = GTMCFAutorelease(ProcessInformationCopyDictionary(&psn,
                                                          kProcessDictionaryIncludeAllInformationMask));
    // bundleID is "optional"
    NSString *bundleID = [info objectForKey:(NSString*)kCFBundleIdentifierKey];
    if (!bundleID) return;
    ProcessSerialNumber myPSN;
    MacGetCurrentProcess(&myPSN);
    NSString *myBundleID = [[NSBundle mainBundle] bundleIdentifier];
    Boolean sameProcess;
    OSErr err = SameProcess(&myPSN, &psn, &sameProcess);
    if (!err
        && !sameProcess
        && [bundleID isEqualToString:myBundleID]) {
      otherQSBPSN_ = psn;

      // Fade out our dock tile
      NSDockTile *tile = [NSApp dockTile];
      NSRect tileRect = GTMNSRectOfSize([tile size]);
      NSImage *appImage = [NSImage imageNamed:@"NSApplicationIcon"];
      NSImage *newImage
        = [[[NSImage alloc] initWithSize:tileRect.size] autorelease];
      [newImage lockFocus];
      [appImage drawInRect:tileRect
                  fromRect:GTMNSRectOfSize([appImage size])
                 operation:NSCompositeCopy
                  fraction:0.3];
      [newImage unlockFocus];
      NSImageView *imageView
        = [[[NSImageView alloc] initWithFrame:tileRect] autorelease];
      [imageView setImageFrameStyle:NSImageFrameNone];
      [imageView setImageScaling:NSImageScaleProportionallyDown];
      [imageView setImage:newImage];
      [tile setContentView:imageView];
      [tile display];
    }
  }
}

- (void)didTerminateApplication:(NSNotification *)notification {
  if (otherQSBPSN_.highLongOfPSN != 0 || otherQSBPSN_.lowLongOfPSN != 0) {
    NSDictionary *userInfo = [notification userInfo];
    ProcessSerialNumber psn;
    psn.highLongOfPSN
      = [[userInfo objectForKey:@"NSApplicationProcessSerialNumberHigh"] unsignedIntValue];
    psn.lowLongOfPSN
      = [[userInfo objectForKey:@"NSApplicationProcessSerialNumberLow"] unsignedIntValue];

    Boolean sameProcess;
    if (SameProcess(&otherQSBPSN_, &psn, &sameProcess) == noErr
        && sameProcess) {
      otherQSBPSN_.highLongOfPSN = 0;
      otherQSBPSN_.lowLongOfPSN = 0;
      NSDockTile *tile = [NSApp dockTile];
      [tile setContentView:nil];
      [tile display];
    }
  }
}

#pragma mark AppleScript Support

- (void)composeApplicationAEDictionary {
  // Inventory all .sdef files, including the app's and all plugins.
  NSArray *bundleSDEFPaths
    = [[NSBundle mainBundle] pathsForResourcesOfType:@"sdef" inDirectory:nil];
  HGSAssert([bundleSDEFPaths count] > 0, nil);
  NSArray *pluginsSDEFPaths
    = [[HGSPluginLoader sharedPluginLoader] pluginsSDEFPaths];
  NSArray *sdefPaths
    = [bundleSDEFPaths arrayByAddingObjectsFromArray:pluginsSDEFPaths];

  if ([sdefPaths count]) {
    // load the first .sdef file's xml data.  All of the scripting definitions
    // from the app and the plugins will be combined into one NSXMLDocument and
    // then copied into the response Apple event descriptor as UTF-8 XML text.
    NSString *sdefPath = [sdefPaths objectAtIndex:0];
    sdefPaths
      = [sdefPaths subarrayWithRange:NSMakeRange(1, [sdefPaths count] - 1)];
    NSURL *sdefURL = [NSURL fileURLWithPath:sdefPath];
    NSError *xmlError = nil;
    NSXMLDocument *sdefXML
      = [[[NSXMLDocument alloc] initWithContentsOfURL:sdefURL
                                              options:NSXMLNodePreserveWhitespace
                                                error:&xmlError] autorelease];
    if (sdefXML) {
      // Retrieve the root element which will be the root of the final
      // combined dictionary.
      NSXMLElement *rootElement = [sdefXML rootElement];
      for (sdefPath in sdefPaths) {
        NSError *pluginXMLError = nil;
        sdefURL = [NSURL fileURLWithPath:sdefPath];
        NSXMLDocument *pluginXML
          = [[[NSXMLDocument alloc] initWithContentsOfURL:sdefURL
                                                  options:NSXMLNodePreserveWhitespace
                                                    error:&pluginXMLError]
             autorelease];
        if (pluginXML) {
          // Copy the plugin definitions over into the collective.
          NSXMLElement *pluginRoot = [pluginXML rootElement];
          for (NSXMLNode *childElement in [pluginRoot children]) {
            [childElement detach];
            [rootElement addChild:childElement];
          }
        } else {
          HGSLog(@"Error loading plugin .sdef file '%@': %@",
                 sdefPath, xmlError);
        }
      }
      [sdefXML setCharacterEncoding:
       (NSString *)CFStringConvertEncodingToIANACharSetName(kCFStringEncodingUTF8)];
      // The newer version of libxml in Mac OS X 10.6.1 has a couple more
      // fields in the sax parser struct, one of which isn't getting
      // initialized properly.  As a workaround, these fields are never
      // accessed if -[NSXMLDocument setStandAlone:NO] is called.
      // See Radar 7242013.
      [sdefXML setStandalone:NO];
      NSData *combinedXML = [sdefXML XMLDataWithOptions:NSXMLDocumentValidate];
      NSAppleEventDescriptor *xmlDictionaryDescriptor
        = [NSAppleEventDescriptor descriptorWithDescriptorType:typeUTF8Text
                                                          data:combinedXML];
      [self setApplicationASDictionary:xmlDictionaryDescriptor];
    } else {
      HGSLog(@"Error loading application .sdef file '%@': %@",
             sdefPath, xmlError);
    }
  } else {
    HGSLogDebug(@"Strange!  No .sdef's found in QSB or its plugins.");
  }
}

- (void)handleGetSDEFEvent:(NSAppleEventDescriptor *)event
            withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
  if (applicationASDictionary_) {
    [replyEvent setDescriptor:applicationASDictionary_
                   forKeyword:keyDirectObject];
  }
}

#pragma mark User Messages

- (void)presentMessageToUser:(NSNotification *)notification {
  NSDictionary *messageDict = [notification userInfo];
  if (messageDict) {
    SEL selector = [self useGrowl] ? @selector(presentUserMessageViaGrowl:)
                                   : @selector(presentUserMessageViaMessenger:);
    [self performSelectorOnMainThread:selector
                           withObject:messageDict
                        waitUntilDone:NO];
  }
}

- (void)presentUserMessageViaMessenger:(NSDictionary *)messageDict {
  if (!userMessenger_) {
    // First use.  Create message window.
    NSWindow *searchBox = [searchWindowController_ window];
    userMessenger_
      = [[QSBUserMessenger alloc] initWithAnchorWindow:searchBox];
  }
  id summaryMessage = [messageDict objectForKey:kHGSSummaryMessageKey];
  id descriptionMessage = [messageDict objectForKey:kHGSDescriptionMessageKey];
  NSImage *image = [messageDict objectForKey:kHGSImageMessageKey];
  if ([summaryMessage isKindOfClass:[NSString class]]) {
    NSString *summary = summaryMessage;
    NSString *description = descriptionMessage;
    if ([descriptionMessage isKindOfClass:[NSAttributedString class]]) {
      description = [descriptionMessage string];
    }
    [userMessenger_ showPlainMessage:summary
                         description:description
                               image:image];
  } else if ([summaryMessage isKindOfClass:[NSAttributedString class]]) {
    NSAttributedString *attributedMessage = summaryMessage;
    [userMessenger_ showAttributedMessage:attributedMessage image:image];
  } else if (image) {
    [userMessenger_ showImage:image];
  } else {
    HGSLogDebug(@"User message request did not contain any of an "
                @"NSString, NSAttributedString or NSImage.");
  }
}

- (void)presentUserMessageViaGrowl:(NSDictionary *)messageDict {
  id summaryMessage = [messageDict objectForKey:kHGSSummaryMessageKey];
  NSImage *image = [messageDict objectForKey:kHGSImageMessageKey];
  if ([summaryMessage isKindOfClass:[NSAttributedString class]]) {
    NSAttributedString *attributedMessage = summaryMessage;
    summaryMessage = [attributedMessage string];
  }
  id descriptiveMessage = [messageDict objectForKey:kHGSDescriptionMessageKey];
  if ([descriptiveMessage isKindOfClass:[NSAttributedString class]]) {
    NSAttributedString *attributedDescription = descriptiveMessage;
    descriptiveMessage = [attributedDescription string];
  }
#if USE_PLUGIN_PROVIDED_NOTIFICATION_NAME_WHEN_THEY_ARE_REGISTERED
  // TODO(itsmikro): Re-enable the following once registrationDictionaryForGrowl
  // has been changed to pull in notification names from plugins.
  NSString *name = [messageDict objectForKey:kHGSNameMessageKey];
  if (!name) {
    name = kGrowlNotificationName;
  }
#else
  NSString *name = kGrowlNotificationName;
#endif  // USE_PLUGIN_PROVIDED_NOTIFICATION_NAME_WHEN_THEY_ARE_REGISTERED
  NSData *imageData = [image TIFFRepresentation];
  NSNumber *successCode = [messageDict objectForKey:kHGSTypeMessageKey];
  signed int priority;
  switch ([successCode intValue]) {
    case kHGSUserMessageErrorType:
      priority = 1;
      break;

    case kHGSUserMessageWarningType:
      priority = 0;
      break;

    case kHGSUserMessageNoteType:
      priority = -1;
      break;

    default:
      HGSLogDebug(@"Unknown priority %d", [successCode intValue]);
      priority = 0;
      break;
  }
  [GrowlApplicationBridge notifyWithTitle:summaryMessage
                              description:descriptiveMessage
                         notificationName:name
                                 iconData:imageData
                                 priority:priority
                                 isSticky:NO
                             clickContext:nil];
}

#pragma mark Growl Support

- (BOOL)growlIsInstalledAndRunning {
  BOOL installed = [GrowlApplicationBridge isGrowlInstalled];
  BOOL running = [GrowlApplicationBridge isGrowlRunning];
  return installed && running;
}

- (BOOL)useGrowl {
  BOOL growlRunning = [self growlIsInstalledAndRunning];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL userWantsGrowl = [defaults boolForKey:kQSBUseGrowlKey];
  return growlRunning && userWantsGrowl;
}

- (void)setUseGrowl:(BOOL)value {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool:value forKey:kQSBUseGrowlKey];
}

#pragma mark GrowlApplicationBridgeDelegate Methods

- (void)growlIsReady {
  [self willChangeValueForKey:@"growlIsInstalledAndRunning"];
  [self didChangeValueForKey:@"growlIsInstalledAndRunning"];
}

- (NSDictionary *)registrationDictionaryForGrowl {
  // TODO(dmaclach): pick up notification names from plugins
  NSArray *array = [NSArray arrayWithObjects:kGrowlNotificationName, nil];
  return [NSDictionary dictionaryWithObjectsAndKeys:
          array, GROWL_NOTIFICATIONS_ALL,
          array, GROWL_NOTIFICATIONS_DEFAULT,
          nil];
}

#pragma mark Sparkle Support
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)bundle {
  BOOL suppress = [self suppressStartupDialogs];
  return !suppress;
}

@end


@implementation NSEvent (QSBApplicationEventAdditions)

- (NSUInteger)qsbModifierFlags {
  NSUInteger flags
    = ([self modifierFlags] & NSDeviceIndependentModifierFlagsMask);
  // Ignore caps lock if it's set http://b/issue?id=637380
  if (flags & NSAlphaShiftKeyMask) flags -= NSAlphaShiftKeyMask;
  // Ignore numeric lock if it's set http://b/issue?id=637380
  if (flags & NSNumericPadKeyMask) flags -= NSNumericPadKeyMask;
  return flags;
}

@end


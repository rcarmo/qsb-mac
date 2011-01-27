//
//  QSBSearchWindowController.m
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
//

#import "QSBSearchWindowController.h"

#import <objc/runtime.h>
#import <Quartz/Quartz.h>
#import <GTM/GTMTypeCasting.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSImage+Scaling.h>
#import <GTM/GTMNSObject+KeyValueObserving.h>
#import <GTM/GTMNSAppleEventDescriptor+Foundation.h>
#import <Vermilion/Vermilion.h>

#import "QSBApplicationDelegate.h"
#import "QSBTextField.h"
#import "QSBActionPresenter.h"
#import "QSBPreferences.h"
#import "QSBSearchController.h"
#import "QSBResultsViewBaseController.h"
#import "NSString+CaseInsensitive.h"
#import "QSBTableResult.h"
#import "QSBWelcomeController.h"
#import "QSBResultsWindowController.h"
#import "QSBResultTableView.h"

// Adds a weak reference to QLPreviewPanel so that we work on Leopard.
__asm__(".weak_reference _OBJC_CLASS_$_QLPreviewPanel");

const NSTimeInterval kQSBShowDuration = 0.1;
const NSTimeInterval kQSBHideDuration = 0.3;
static const NSTimeInterval kQSBShortHideDuration = 0.15;
static const NSTimeInterval kQSBResizeDuration = 0.1;
static const NSTimeInterval kQSBPushPopDuration = 0.2;
const NSTimeInterval kQSBAppearDelay = 0.2;
static const NSTimeInterval kQSBLongerAppearDelay = 0.667;
const NSTimeInterval kQSBUpdateSizeDelay = 0.333;
static const NSTimeInterval kQSBReshowResultsDelay = 4.0;
static const CGFloat kTextFieldPadding = 2.0;

// Should we fade the background. User default. Bool value.
static NSString * const kQSBSearchWindowDimBackground
  = @"QSBSearchWindowDimBackground";
// How long should the fade animation be. User default. Float value.
static NSString * const kQSBSearchWindowDimBackgroundDuration
  = @"QSBSearchWindowDimBackgroundDuration";
// How dark should the fade be. User default. Float value.
static NSString * const kQSBSearchWindowDimBackgroundAlpha
  = @"QSBSearchWindowDimBackgroundAlpha";

static NSString * const kQSBHideQSBWhenInactivePrefKey = @"hideQSBWhenInactive";
static NSString * const kQSBSearchWindowFrameTopPrefKey
  = @"QSBSearchWindow Top QSBSearchResultsWindow";
static NSString * const kQSBSearchWindowFrameLeftPrefKey
  = @"QSBSearchWindow Left QSBSearchResultsWindow";
static NSString * const kQSBUserPrefBackgroundColorKey = @"backgroundColor";
static NSString * const kQSBMainInterfaceNibName = @"MainInterfaceNibName";


// NSNumber value in seconds that controls how fast the QSB clears out
// an old query once it's put in the background.
static NSString *const kQSBResetQueryTimeoutPrefKey
  = @"QSBResetQueryTimeoutPrefKey";

// This is a tag value for corpora in the corpora menu.
static const NSInteger kBaseCorporaTagValue = 10000;

@interface QSBSearchWindowController ()

- (void)updateLogoView;
- (BOOL)firstLaunch;

// Reposition our window on screen as appropriate
- (void)centerWindowOnScreen;

- (void)resetActionModel;

// Resets the query to blank after a given time interval
- (void)resetQuery:(NSTimer *)timer;

// Checks the find pasteboard to see if it's changed
- (void)checkFindPasteboard:(NSTimer *)timer;

- (IBAction)displayResults:(id)sender;

// Returns YES if the screen that our search window is on is captured.
// NOTE: Frontrow in Tiger DOES NOT capture the screen, so this is not a valid
// way of checking for Frontrow. The only way we know of to check for Frontrow
// is the method used by GoogleDesktop to do it. Search for "5049713"
- (BOOL)isOurScreenCaptured;

// Given a proposed frame, returns a frame that fully exposes
// the proposed frame on |screen| as close to it's original position as
// possible.
// Args:
//    proposedFrame - the frame to be adjusted to fit on the screen
//    respectingDock - if YES, we won't cover the dock.
//    screen - the screen the rect is on
// Returns:
//   The frame rect offset such that if used to position the window
//   will fully exposes the window on the screen. If the proposed
//   frame is bigger than the screen, it is anchored to the upper
//   left.  The size of the proposed frame is never adjusted.
- (NSRect)fullyExposedFrameForFrame:(NSRect)proposedFrame
                     respectingDock:(BOOL)respectingDock
                           onScreen:(NSScreen *)screen;

// Notifications
- (void)aWindowDidBecomeKey:(NSNotification *)notification;
- (void)backgroundColorChanged:(GTMKeyValueChangeNotification *)notification;
- (void)pluginWillLoad:(NSNotification *)notification;
- (void)pluginWillInstall:(NSNotification *)notification;
- (void)pluginsDidInstall:(NSNotification *)notification;
- (void)selectedTableResultDidChange:(NSNotification *)notification;
- (void)actionPresenterDidPivot:(NSNotification *)notification;
- (void)actionPresenterDidUnpivot:(NSNotification *)notification;
- (void)welcomeWindowWillClose:(NSNotification *)notification;
- (void)applicationDidReopen:(NSNotification *)notification;
@end


@implementation QSBSearchWindowController

GTM_METHOD_CHECK(NSObject,
                 gtm_addObserver:forKeyPath:selector:userInfo:options:);
GTM_METHOD_CHECK(NSObject, gtm_stopObservingAllKeyPaths);
GTM_METHOD_CHECK(NSAppleEventDescriptor, gtm_arrayValue);
GTM_METHOD_CHECK(NSImage, gtm_duplicateOfSize:);

- (id)init {
  // Read the nib name from user defaults to allow for ui switching
  // Defaults to ResultsWindow.xib
  NSString *nibName = [[NSUserDefaults standardUserDefaults]
                        stringForKey:kQSBMainInterfaceNibName];
  if (!nibName) nibName = @"QSBSearchWindow";
  self = [self initWithWindowNibName:nibName];
  return self;
}

- (void)awakeFromNib {
  NSUserDefaults *userPrefs = [NSUserDefaults standardUserDefaults];

  [userPrefs gtm_addObserver:self
                  forKeyPath:kQSBUserPrefBackgroundColorKey
                    selector:@selector(backgroundColorChanged:)
                    userInfo:nil
                     options:0];

  [self updateLogoView];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(applicationDidBecomeActive:)
             name:NSApplicationDidBecomeActiveNotification
           object:NSApp];

  [nc addObserver:self
         selector:@selector(applicationWillResignActive:)
             name:NSApplicationWillResignActiveNotification
           object:NSApp];

  [nc addObserver:self
         selector:@selector(applicationDidChangeScreenParameters:)
             name:NSApplicationDidChangeScreenParametersNotification
           object:NSApp];

  [nc addObserver:self
         selector:@selector(applicationDidReopen:)
             name:kQSBApplicationDidReopenNotification
           object:NSApp];

  // named aWindowDidBecomeKey instead of windowDidBecomeKey because if we
  // used windowDidBecomeKey we would be called twice for our window (once
  // for the notification, and once because we are the search window's delegate)
  [nc addObserver:self
         selector:@selector(aWindowDidBecomeKey:)
             name:NSWindowDidBecomeKeyNotification
           object:nil];

  HGSPluginLoader *sharedLoader = [HGSPluginLoader sharedPluginLoader];
  [nc addObserver:self
         selector:@selector(pluginWillLoad:)
             name:kHGSPluginLoaderWillLoadPluginNotification
           object:sharedLoader];
  [nc addObserver:self
         selector:@selector(pluginWillInstall:)
             name:kHGSPluginLoaderWillInstallPluginNotification
           object:sharedLoader];
  [nc addObserver:self
         selector:@selector(pluginsDidInstall:)
             name:kHGSPluginLoaderDidInstallPluginsNotification
           object:sharedLoader];

  [nc addObserver:self
         selector:@selector(actionPresenterDidPivot:)
             name:kQSBActionPresenterDidPivotNotification
           object:actionPresenter_];

  [nc addObserver:self
         selector:@selector(actionPresenterDidUnpivot:)
             name:kQSBActionPresenterDidUnpivotNotification
           object:actionPresenter_];


  // get the pasteboard count and make sure we change it to something different
  // so that when the user first brings up the QSB its query is correct.
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSTimeInterval resetInterval;
  resetInterval = [userDefaults floatForKey:kQSBResetQueryTimeoutPrefKey];
  if (resetInterval < 1) {
    resetInterval = 60; // One minute
    [userDefaults setDouble:resetInterval forKey:kQSBResetQueryTimeoutPrefKey];
    // No need to worry about synchronize here as somebody else will sync us
  }

  // subtracting one just makes sure that we are initialized to something other
  // than what |changeCount| is going to be. |Changecount| always increments.
  NSPasteboard *findPasteBoard = [NSPasteboard pasteboardWithName:NSFindPboard];
  findPasteBoardChangeCount_ = [findPasteBoard changeCount] - 1;
  [self checkFindPasteboard:nil];
  findPasteBoardChangedTimer_
    = [NSTimer scheduledTimerWithTimeInterval:resetInterval
                                       target:self
                                     selector:@selector(checkFindPasteboard:)
                                     userInfo:nil
                                      repeats:YES];
  [nc addObserver:self
         selector:@selector(selectedTableResultDidChange:)
             name:kQSBSelectedTableResultDidChangeNotification
           object:nil];
  if ([self firstLaunch]) {
    welcomeController_ = [[QSBWelcomeController alloc] init];
  }
}

- (void)dealloc {
  [self gtm_stopObservingAllKeyPaths];
  [queryResetTimer_ invalidate];
  queryResetTimer_ = nil;
  [displayResultsTimer_ invalidate];
  displayResultsTimer_ = nil;
  [findPasteBoardChangedTimer_ invalidate];
  findPasteBoardChangedTimer_ = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)windowDidLoad {
  // If we have a remembered position for the search window then restore it.
  // Note: See note in |windowDidMove:|.
  NSWindow *searchWindow = [self window];
  if ([self firstLaunch]) {
    [searchWindow center];
  } else {
    NSPoint topLeft = NSMakePoint(
                                  [[NSUserDefaults standardUserDefaults]
                                   floatForKey:kQSBSearchWindowFrameLeftPrefKey],
                                  [[NSUserDefaults standardUserDefaults]
                                   floatForKey:kQSBSearchWindowFrameTopPrefKey]);
    [searchWindow setFrameTopLeftPoint:topLeft];

    // Now insure that the window's frame is fully visible.
    NSRect searchFrame = [searchWindow frame];
    NSRect actualFrame = [self fullyExposedFrameForFrame:searchFrame
                                          respectingDock:YES
                                                onScreen:[searchWindow screen]];
    [searchWindow setFrame:actualFrame display:NO];
  }

  // get us so that the IME windows appear above us as necessary.
  // http://b/issue?id=602250

  [searchWindow setLevel:kCGStatusWindowLevel + 2];
  // Support spaces on Leopard.
  // http://b/issue?id=648841
  [searchWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

  [searchWindow setMovableByWindowBackground:YES];
  [searchWindow invalidateShadow];
  [searchWindow setAlphaValue:0.0];

  NSString *startupString = HGSLocalizedString(@"Starting up…",
                                               @"A string shown "
                                               @"at launchtime to denote that "
                                               @"QSB is starting up.");

  [searchTextField_ setString:startupString];
  [searchTextField_ setEditable:NO];

  [thumbnailView_ setHidden:YES];

  if (welcomeController_) {
    NSWindow *welcomeWindow = [welcomeController_ window];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(welcomeWindowWillClose:)
               name:NSWindowWillCloseNotification
             object:welcomeWindow];

    [searchWindow addChildWindow:welcomeWindow
                         ordered:NSWindowBelow];
  }
}

- (BOOL)firstLaunch {
  NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
  BOOL beenLaunched = [standardUserDefaults boolForKey:kQSBBeenLaunchedPrefKey];
  return !beenLaunched;
}

- (void)updateLogoView {
  NSImage *menuImage = nil;
  NSImage *logoImage = nil;
  NSData *data = [[NSUserDefaults standardUserDefaults]
                  dataForKey:kQSBUserPrefBackgroundColorKey];
  NSColor *color = data ? [NSUnarchiver unarchiveObjectWithData:data]
                        : [NSColor whiteColor];
  color = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];

  CGFloat brightness = [color brightnessComponent];
  CGFloat hue = [color hueComponent];
  CGFloat saturation = [color saturationComponent];

  // Only pastels show color logo
  if (saturation < 0.25 && brightness > 0.9) {
    logoImage = [NSImage imageNamed:@"ColorLargeGoogle"];
    menuImage = [NSImage imageNamed:@"MenuArrowBlack"];
  } else {
    // If is a bright, saturated color, use the black logo
    const CGFloat kYellowHue = 1.0 / 6.0;
    const CGFloat kMinDistance = 1.0 / 12.0;
    CGFloat yellowDistance = fabs(kYellowHue - hue);
    if (yellowDistance < kMinDistance && brightness > 0.8) {
      logoImage = [NSImage imageNamed:@"BlackLargeGoogle"];
      menuImage = [NSImage imageNamed:@"MenuArrowBlack"];
    } else {
      logoImage = [NSImage imageNamed:@"WhiteLargeGoogle"];
      menuImage = [NSImage imageNamed:@"MenuArrowWhite"];
    }
  }
  [logoView_ setImage:logoImage];
  if (menuImage) [windowMenuButton_ setImage:menuImage];
}

- (NSArray *)corpora {
  NSMutableArray *allCorpora = [NSMutableArray array];
  HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
  for (HGSExtension *extension in [sourcesPoint extensions]) {
    if ([extension isKindOfClass:[HGSCorporaSource class]]) {
      NSArray *corpora = [(HGSCorporaSource *)extension searchableCorpora];
      if (corpora) {
        [allCorpora addObjectsFromArray:corpora];
      }
    }
  }
  return allCorpora;
}

- (void)searchForString:(NSString *)string {
  // Selecting destroys the stack
  [self resetActionModel];
  [searchTextField_ setString:string];
  [searchTextField_ didChangeText];
}

- (void)selectResults:(HGSResultArray *)results saveText:(BOOL)saveText {
  // If there's not a current pivot then add one.  Then change the pivot object
  // for the pivot (either the existing one or the newly created one) to the
  // chosen corpus.  Don't alter the search text.
  NSString *text = saveText ? [searchTextField_ stringWithoutPivots] : nil;
  // Selecting destroys the stack
  [self resetActionModel];

  // Create a pivot with the current text, and set the base query to the
  // indicated corpus.
  [actionPresenter_ pivotOnObjects:results];
  if (text) {
    [actionPresenter_ searchFor:text];
  }
  NSAttributedString *attrString = [actionPresenter_ pivotAttributedString];
  [searchTextField_ setAttributedStringValue:attrString];
  [searchTextField_ didChangeText];
}

- (void)hitHotKey:(id)sender {
  if (![[self window] ignoresMouseEvents]) {
    [self hideSearchWindow:self];
  } else {
    // Check to see if the display is captured, and if so beep and don't
    // activate.
    // For http://buganizer/issue?id=652067
    if ([self isOurScreenCaptured]) {
      NSBeep();
      return;
    }
    [self showSearchWindow:self];
  }
}

// Add our results window into the responder chain.
- (NSResponder *)nextResponder {
  NSWindow *resultsWindow = [resultsWindowController_ window];
  NSResponder *resultsWindowResponder = [resultsWindow firstResponder];
  [actionPresenter_ setNextResponder:resultsWindowResponder];
  return actionPresenter_;
}

- (NSWindow *)shieldWindow {
  if (!shieldWindow_) {
    NSRect windowRect = [[NSScreen mainScreen] frame];
    shieldWindow_ = [[NSWindow alloc] initWithContentRect:windowRect
                                                styleMask:NSBorderlessWindowMask
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [shieldWindow_ setIgnoresMouseEvents:YES];
    [shieldWindow_
       setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [shieldWindow_ setBackgroundColor: [NSColor blackColor]];
    [shieldWindow_ setLevel:kCGStatusWindowLevel];
    [shieldWindow_ setOpaque:YES];
    [shieldWindow_ setHasShadow:NO];
    [shieldWindow_ setReleasedWhenClosed:YES];
    [shieldWindow_ setAlphaValue:0.0];
    [shieldWindow_ display];
  }
  return shieldWindow_;

}

- (NSRect)setResultsWindowFrameWithHeight:(CGFloat)newHeight {
  NSWindow *queryWindow = [self window];
  NSWindow *resultsWindow = [resultsWindowController_ window];
  BOOL resultsVisible = [resultsWindow isVisible];
  NSRect baseFrame = [resultsOffsetterView_ frame];
  baseFrame.origin = [queryWindow convertBaseToScreen:baseFrame.origin];
  // Always start with the baseFrame and enlarge it to fit the height
  NSRect proposedFrame = baseFrame;
  proposedFrame.origin.y -= newHeight; // one more for borders
  proposedFrame.size.height = newHeight;
  NSRect actualFrame = proposedFrame;
  if (resultsVisible) {
    // If the results panel is visible then we first size and position it
    // and then reposition the search box.

    // second, determine a frame that actually fits within the screen.
    actualFrame = [self fullyExposedFrameForFrame:proposedFrame
                                   respectingDock:YES
                                         onScreen:[queryWindow screen]];
    if (!NSEqualRects(actualFrame, proposedFrame)) {
      // We need to move the query window as well as the results window.
      NSPoint deltaPoint
        = NSMakePoint(actualFrame.origin.x - proposedFrame.origin.x,
                      actualFrame.origin.y - proposedFrame.origin.y);

      NSRect queryFrame = NSOffsetRect([queryWindow frame],
                                deltaPoint.x, deltaPoint.y);
      [[queryWindow animator] setFrame:queryFrame display:YES];
    }
    NSPoint upperLeft = NSMakePoint(NSMinX(actualFrame), NSMaxY(actualFrame));
    [resultsWindow setFrameTopLeftPoint:upperLeft];
    [[resultsWindow animator] setFrame:actualFrame display:YES];
  }
  return actualFrame;
}

- (void)updateWindowVisibilityBasedOnQueryString {
  if ([[searchTextField_ string] length]) {
    [resultsWindowController_ showResultsWindow:self];
    [welcomeController_ close];
  } else {
    [resultsWindowController_ hideResultsWindow:self];
  }
}

- (void)resetActionModel {
  [actionPresenter_ reset];
  [searchTextField_ setAttributedStringValue:[actionPresenter_ pivotAttributedString]];
}

- (void)centerWindowOnScreen {
  NSWindow *window = [self window];
  [window center];
}

#pragma mark Actions

- (IBAction)grabSelection:(id)sender {
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *path = [bundle pathForResource:@"GrabFinderSelectionAsPosixPaths"
                                    ofType:@"scpt"
                               inDirectory:@"Scripts"];
  HGSAssert(path, @"Can't find GrabFinderSelectionAsPosixPaths.scpt");
  NSURL *url = [NSURL fileURLWithPath:path];
  NSDictionary *error = nil;

  NSAppleScript *grabScript
    = [[[NSAppleScript alloc] initWithContentsOfURL:url
                                              error:&error] autorelease];
  if (!error) {
    NSAppleEventDescriptor *desc = [grabScript executeAndReturnError:&error];
    if (!error) {
      NSArray *paths = [desc gtm_arrayValue];
      if (paths) {
        HGSResultArray *results
          = [HGSResultArray arrayWithFilePaths:paths];
        [self selectResults:results saveText:NO];
      }
    }
  }
}

- (IBAction)dropSelection:(id)sender {
  //TODO(dmaclach): implement
  [self selectResults:nil saveText:NO];
  NSBeep();
}

- (IBAction)resetSearchString:(id)sender {
  [self resetActionModel];
  [searchTextField_ didChangeText];
}

- (IBAction)qsb_clearSearchString:(id)sender {
  BOOL hadText = [[searchTextField_ string] length];
  [self resetSearchString:self];
  // Hide the results window if it's showing.
  if (![[resultsWindowController_ window] ignoresMouseEvents]) {
    [resultsWindowController_ hideResultsWindow:self];
  } else if (!hadText) {
    [self hideSearchWindow:self];
  }
}

- (IBAction)selectCorpus:(id)sender {

  NSInteger tag = [sender tag] - kBaseCorporaTagValue;
  HGSScoredResult *corpus = [[self corpora] objectAtIndex:tag];
  HGSResultArray *results = [HGSResultArray arrayWithResult:corpus];
  [self selectResults:results saveText:YES];
}

- (IBAction)showSearchWindow:(id)sender {
  NSWindow *modalWindow = [NSApp modalWindow];
  if (!modalWindow) {
    // a window must be "visible" for it to be key. This makes it "visible"
    // but invisible to the user so we can accept keystrokes while we are
    // busy opening the window. We order it front as a invisible window, and
    // then slowly fade it in.
    NSWindow *searchWindow = [self window];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud boolForKey:kQSBSearchWindowDimBackground]) {
      NSWindow *shieldWindow = [self shieldWindow];
      [shieldWindow setFrame:[[NSScreen mainScreen] frame] display:NO];
      if (![shieldWindow isVisible]) {
        [shieldWindow setAlphaValue:0.0];
        [shieldWindow makeKeyAndOrderFront:nil];
      }
      CGFloat fadeDuration
        = [ud floatForKey:kQSBSearchWindowDimBackgroundDuration];
      CGFloat fadeAlpha = [ud floatForKey:kQSBSearchWindowDimBackgroundAlpha];
      // If fadeDuration (or fadeAlpha) < FLT_EPSILON then the user is using
      // a bogus value, so we ignore it and use the default value.
      if (fadeDuration < FLT_EPSILON) {
        fadeDuration = 0.5;
      }
      if (fadeAlpha < FLT_EPSILON) {
        fadeAlpha = 0.1;
      }
      fadeAlpha = MIN(fadeAlpha, 1.0);
      [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:fadeDuration];
      [[shieldWindow animator] setAlphaValue:fadeAlpha];
      [NSAnimationContext endGrouping];
    }

    [(QSBCustomPanel *)searchWindow setCanBecomeKeyWindow:YES];
    [searchWindow setIgnoresMouseEvents:NO];
    [searchWindow makeKeyAndOrderFront:self];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [[searchWindow animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
    [searchWindow setAlphaValue:1.0];
    [welcomeController_ setHidden:NO];

    if ([[searchTextField_ string] length]) {
      displayResultsTimer_
        = [NSTimer scheduledTimerWithTimeInterval:kQSBReshowResultsDelay
                                           target:self
                                         selector:@selector(displayResults:)
                                         userInfo:nil
                                          repeats:NO];
    }
  } else {
    // Bring whatever modal up front.
    [NSApp activateIgnoringOtherApps:YES];
    [modalWindow makeKeyAndOrderFront:self];
  }
}

- (IBAction)hideSearchWindow:(id)sender {
  QSBCustomPanel *searchWindow = (QSBCustomPanel *)[self window];
  if ([searchWindow ignoresMouseEvents]) {
    return;
  }

  // Must be called BEFORE resignAsKeyWindow otherwise we call hide again
  [searchWindow setIgnoresMouseEvents:YES];
  [searchWindow setCanBecomeKeyWindow:NO];
  [searchWindow resignAsKeyWindow];
  [[actionPresenter_ activeSearchController] stopQuery];
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if ([ud boolForKey:kQSBSearchWindowDimBackground]) {
    CGFloat fadeDuration
      = [ud floatForKey:kQSBSearchWindowDimBackgroundDuration];
    if (fadeDuration < FLT_EPSILON) {
      // If fadeDuration < FLT_EPSILON then the user has set the duration
      // to a bogus value, so we ignore it and use the default value.
      fadeDuration = 0.5;
    }
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:fadeDuration];
    [[[self shieldWindow] animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
  }
  [displayResultsTimer_ invalidate];
  displayResultsTimer_ = nil;
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] setDuration:kQSBHideDuration];
  [[searchWindow animator] setAlphaValue:0.0];
  [welcomeController_ setHidden:YES];
  [resultsWindowController_ hideResultsWindow:self];
  [NSAnimationContext endGrouping];
}

- (IBAction)displayResults:(id)sender {
  displayResultsTimer_ = nil;
  NSWindow *searchWindow = [self window];
  if (![searchWindow ignoresMouseEvents]) {
    // Force the results view to show
    if ([resultsWindowController_ selectedTableResult]) {
      [welcomeController_ close];
      [resultsWindowController_ showResultsWindow:self];
    }
  }
}

#pragma mark User Interface Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  BOOL valid = YES;
  SEL action = [menuItem action];
  SEL showSearchWindowSel = @selector(showSearchWindow:);
  SEL hideSearchWindowSel = @selector(hideSearchWindow:);
  BOOL searchWindowActive = ![[self window] ignoresMouseEvents];
  if (action == showSearchWindowSel && searchWindowActive) {
    [menuItem setAction:hideSearchWindowSel];
    [menuItem setTitle:NSLocalizedString(@"Hide Quick Search Box", nil)];
  } else if (action == hideSearchWindowSel && !searchWindowActive) {
    [menuItem setAction:showSearchWindowSel];
    [menuItem setTitle:NSLocalizedString(@"Show Quick Search Box", nil)];
  } else if (action == @selector(selectCorpus:)) {
    NSArray *corpora = [self corpora];
    NSUInteger idx = [menuItem tag] - kBaseCorporaTagValue;
    if (idx < [corpora  count]) {
      HGSScoredResult *corpus = [corpora objectAtIndex:idx];
      QSBSearchController *activeSearchController
        = [actionPresenter_ activeSearchController];
      HGSResultArray *pivotObjects
        = [activeSearchController pivotObjects];
      if ([pivotObjects count] == 1) {
        HGSScoredResult *result = [pivotObjects objectAtIndex:0];
        [menuItem setState:([corpus isEqual:result])];
      }
    } else {
      valid = NO;
    }
  }

  return valid;
}

#pragma mark NSWindow Notification Methods

- (void)windowDidMove:(NSNotification *)notification {
  // The search window position on the screen has changed so record
  // this in our preferences so that we can later restore the window
  // to its new position.
  //
  // NOTE: We do this because it is far simpler than trying to use the autosave
  // approach and intercepting a number of window moves and resizes during
  // initial nib loading.
  NSRect windowFrame = [[self window] frame];
  NSPoint topLeft = windowFrame.origin;
  topLeft.y += windowFrame.size.height;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  [ud setDouble:topLeft.x forKey:kQSBSearchWindowFrameLeftPrefKey];
  [ud setDouble:topLeft.y forKey:kQSBSearchWindowFrameTopPrefKey];
}

- (void)aWindowDidBecomeKey:(NSNotification *)notification {
  NSWindow *window = [notification object];
  NSWindow *searchWindow = [self window];

  if ([window isEqual:searchWindow]) {
    if (needToUpdatePositionOnActivation_) {
      [self centerWindowOnScreen];
      needToUpdatePositionOnActivation_ = NO;
    }
    [queryResetTimer_ invalidate];
    queryResetTimer_ = nil;

    [self checkFindPasteboard:nil];
    if (insertFindPasteBoardString_) {
      insertFindPasteBoardString_ = NO;
      NSPasteboard *findPBoard = [NSPasteboard pasteboardWithName:NSFindPboard];
      NSArray *types = [findPBoard types];
      if ([types count]) {
        NSString *text = [findPBoard stringForType:[types objectAtIndex:0]];
        if ([text length] > 0) {
          [searchTextField_ selectAll:self];
          [searchTextField_ insertText:text];
          [searchTextField_ selectAll:self];
        }
      }
    }
  } else if (![window isKindOfClass:[QLPreviewPanel class]]
             && [searchWindow isVisible]) {
    // We check for QLPreviewPanel because we don't want to hide for quicklook
    [self hideSearchWindow:self];
  }

}

- (void)windowDidResignKey:(NSNotification *)notification {
  // If we resigned key because of a quick look panel, then we don't want
  // to hide ourselves.
  if ([[NSApp keyWindow] isKindOfClass:[QLPreviewPanel class]]) return;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSTimeInterval resetInterval = [ud floatForKey:kQSBResetQueryTimeoutPrefKey];
  // preset previously in awakeFromNib:
  queryResetTimer_ = [NSTimer scheduledTimerWithTimeInterval:resetInterval
                                                      target:self
                                                    selector:@selector(resetQuery:)
                                                    userInfo:nil
                                                     repeats:NO];
  BOOL hideWhenInactive = YES;
  NSNumber *hideNumber = [[NSUserDefaults standardUserDefaults]
                          objectForKey:kQSBHideQSBWhenInactivePrefKey];
  if (hideNumber) {
    hideWhenInactive = [hideNumber boolValue];
  }
  if (hideWhenInactive) {

    // If we've pivoted and have a token in the search text box we will just
    // blow everything away (http://b/issue?id=1567906), otherwise we will
    // select all of the text, so the next time the user brings us up we will
    // immediately replace their selection with what they type.
    if ([actionPresenter_ canUnpivot]) {
      [self resetSearchString:self];
    } else {
      [searchTextField_ selectAll:self];
    }
    if (![[self window] ignoresMouseEvents]) {
      [self hideSearchWindow:self];
    }
  }
}

- (void)welcomeWindowWillClose:(NSNotification *)notification {
  NSWindow *window = [self window];
  NSWindow *childWindow = [notification object];
  HGSCheckDebug(childWindow == [welcomeController_ window], @"");
  [window removeChildWindow:childWindow];
  welcomeController_ = nil;
}

#pragma mark NSMenu Delegate Methods

// Delegate callback for the window menu, this propogates the dropdown of
// search sites
- (void)menuNeedsUpdate:(NSMenu *)menu {
  // We have some items at the top and bottom of the menu that we don't want
  // to delete when we refresh it.
  const NSInteger kNumberOfItemsAtStartOfMenu = 2;
  const NSInteger kNumberOfItemsAtEndOfMenu = 3;

  // If this isn't the expected menu return
  if ([windowMenuButton_ menu] != menu) return;
  NSUInteger menuItemCount = [menu numberOfItems] - kNumberOfItemsAtEndOfMenu;
  for (NSUInteger i = kNumberOfItemsAtStartOfMenu; i < menuItemCount; ++i) {
    [menu removeItemAtIndex:2];
  }
  // Add our items.
  NSArray *corpora = [self corpora];
  for (unsigned int i = 0; i < [corpora count]; i++) {
    HGSScoredResult *corpus = [corpora objectAtIndex:i];
    NSString *key = [[NSNumber numberWithUnsignedInt:i] stringValue];
    NSMenuItem *item
      = [[[NSMenuItem alloc] initWithTitle:[corpus displayName]
                                    action:@selector(selectCorpus:)
                             keyEquivalent:key]
         autorelease];

    // Insert after the everything item
    [menu insertItem:item atIndex:i + 2];
    [item setTag:i + kBaseCorporaTagValue];
    NSImage *image = [corpus valueForKey:kHGSObjectAttributeIconKey];
    image = [image gtm_duplicateOfSize:NSMakeSize(16,16)];
    [item setImage: image];
  }
}

#pragma mark NSApplication Notification Methods

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  if ([NSApp keyWindow] == nil) {
    [self showSearchWindow:self];
  }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
  if ([[self window] isVisible]) {
    BOOL hideWhenInactive = YES;
    NSNumber *hideNumber = [[NSUserDefaults standardUserDefaults]
                            objectForKey:kQSBHideQSBWhenInactivePrefKey];
    if (hideNumber) {
      hideWhenInactive = [hideNumber boolValue];
    }
    if (hideWhenInactive) {
      [self hideSearchWindow:self];
    }
  }
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)notification {
  if ([[self window] isVisible]) {
    // if we are active, do our change immediately.
    [self centerWindowOnScreen];
  } else {
    // We don't want to update immediately if we are in the background because
    // we don't want to move unnecessarily if the user doesn't invoke us in
    // the different mode change.
    needToUpdatePositionOnActivation_ = YES;
  }
}

- (void)applicationDidReopen:(NSNotification *)notification {
  if (![NSApp keyWindow]) {
    [self showSearchWindow:self];
  }
}

#pragma mark NSTextView Delegate Methods (for QSBTextField)

- (void)textDidChange:(NSNotification *)notification {
  QSBTextField *editor = GTM_STATIC_CAST(QSBTextField,
                                               [notification object]);
  NSString *queryString = [editor stringWithoutPivots];
  if (![queryString length]) {
    queryString = nil;
  }
  [actionPresenter_ searchFor:queryString];
  [self updateWindowVisibilityBasedOnQueryString];
}

- (BOOL)textView:(NSTextView *)textView
    doCommandBySelector:(SEL)commandSelector {
  BOOL handled = NO;

  // If our results aren't visible, make them so.
  if (sel_isEqual(commandSelector, @selector(moveDown:))) {
    if ([[resultsWindowController_ window] ignoresMouseEvents]) {
      [resultsWindowController_ showResultsWindow:self];
      handled = YES;
    }
  }

  if (!handled) {
    NSTableView *tableView = [resultsWindowController_ activeTableView];
    if ([tableView respondsToSelector:commandSelector]) {
      [tableView doCommandBySelector:commandSelector];
      handled = YES;
    }
  }
  return handled;
}

- (NSArray *)textView:(NSTextView *)textView
          completions:(NSArray *)words
  forPartialWordRange:(NSRange)charRange
  indexOfSelectedItem:(int *)idx {
  *idx = 0;
  NSString *completion = nil;
  // We grab the string from the textStorage instead of from the
  // activeSearchController_ because the string from textStorage includes marked
  // text.
  NSString *queryString = [[textView textStorage] string];
  if ([queryString length]) {
    id result = [resultsWindowController_ selectedTableResult];
    if (result && [result respondsToSelector:@selector(displayName)]) {
      completion = [result displayName];
      // If the query string is not a prefix of the completion then
      // ignore the completion.
      if (![completion qsb_hasPrefix:queryString
                             options:(NSWidthInsensitiveSearch
                                      | NSCaseInsensitiveSearch
                                      | NSDiacriticInsensitiveSearch)]) {
        completion = nil;
      }
    }
  }
  return completion ? [NSArray arrayWithObject:completion] : nil;
}

#pragma mark Plugin Notifications

- (void)pluginWillLoad:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSString *pluginName = [userInfo objectForKey:kHGSPluginLoaderPluginNameKey];
  NSString *startupString = nil;
  if (pluginName) {
    NSString *format = HGSLocalizedString(@"Starting up… Loading %@",
                                          @"A string shown "
                                          @"at launchtime to denote that QSB "
                                          @"is starting up and is loading a "
                                          @"plugin.");
    startupString = [NSString stringWithFormat:format, pluginName];
  } else {
    startupString = HGSLocalizedString(@"Starting up…",
                                       @"A string shown "
                                       @"at launchtime to denote that QSB "
                                       @"is starting up.");

  }
  [searchTextField_ setString:startupString];
  [searchTextField_ display];
}

- (void)pluginWillInstall:(NSNotification *)notification {
  NSString *initializing = HGSLocalizedString(@"Initializing %@",
                                              @"A string shown at launchtime "
                                              @"to denote that we are "
                                              @"initializing a plugin.");
  NSDictionary *userInfo = [notification userInfo];
  HGSPlugin *plugin = [userInfo objectForKey:kHGSPluginLoaderPluginKey];
  NSString *name = [plugin displayName];
  initializing = [NSString stringWithFormat:initializing, name];
  [searchTextField_ setString:initializing];
  [searchTextField_ displayIfNeeded];
}

- (void)pluginsDidInstall:(NSNotification *)notification {
  [searchTextField_ setString:@""];
  [searchTextField_ displayIfNeeded];
  [searchTextField_ setEditable:YES];
  [[searchTextField_ window] makeFirstResponder:searchTextField_];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  HGSPluginLoader *sharedLoader = [HGSPluginLoader sharedPluginLoader];
  [nc removeObserver:self
                name:kHGSPluginLoaderWillLoadPluginNotification
              object:sharedLoader];
  [nc removeObserver:self
                name:kHGSPluginLoaderWillInstallPluginNotification
              object:sharedLoader];
  [nc removeObserver:self
                name:kHGSPluginLoaderDidInstallPluginsNotification
              object:sharedLoader];
}

#pragma mark QSB Notifications

- (void)selectedTableResultDidChange:(NSNotification *)notification {
  [thumbnailView_ unbind:NSValueBinding];
  QSBTableResult *tableResult
    = [[notification userInfo] objectForKey:kQSBSelectedTableResultKey];
  if (tableResult) {
    [thumbnailView_ bind:NSValueBinding
                toObject:tableResult
             withKeyPath:@"displayThumbnail"
                 options:nil];
    [thumbnailView_ setHidden:NO];
  } else {
    [thumbnailView_ setHidden:YES];
  }
  [searchTextField_ complete:self];
  NSImage* thumbnail = [tableResult displayThumbnail];
  [logoView_ setHidden:(thumbnail != nil)];
}

- (void)actionPresenterDidPivot:(NSNotification *)notification {
  QSBActionPresenter *actionPresenter
    = GTM_STATIC_CAST(QSBActionPresenter, [notification object]);
  NSAttributedString *pivotString = [actionPresenter pivotAttributedString];
  [searchTextField_ setAttributedStringValue:pivotString];
  [searchTextField_ didChangeText];
}

- (void)actionPresenterDidUnpivot:(NSNotification *)notification {
  QSBActionPresenter *actionPresenter
    = GTM_STATIC_CAST(QSBActionPresenter, [notification object]);
  NSAttributedString *pivotString = [actionPresenter pivotAttributedString];
  [searchTextField_ setAttributedStringValue:pivotString];
  [searchTextField_ didChangeText];
}

#pragma mark KVC Notifications

- (void)backgroundColorChanged:(GTMKeyValueChangeNotification *)notification {
  [self updateLogoView];
}

#pragma mark NSTimer Callbacks

- (void)resetQuery:(NSTimer *)timer {
  queryResetTimer_ = nil;
  [self resetSearchString:self];
}

- (void)checkFindPasteboard:(NSTimer *)timer {
  NSInteger newCount
    = [[NSPasteboard pasteboardWithName:NSFindPboard] changeCount];
  insertFindPasteBoardString_ = newCount != findPasteBoardChangeCount_;
  findPasteBoardChangeCount_ = newCount;
}

- (BOOL)isOurScreenCaptured {
  BOOL captured = NO;
  NSScreen *screen = [[self window] screen];
  NSDictionary *deviceDescription = [screen deviceDescription];
  NSNumber *displayIDValue = [deviceDescription objectForKey:@"NSScreenNumber"];
  if (displayIDValue) {
    CGDirectDisplayID displayID = [displayIDValue unsignedIntValue];
    if (displayID) {
      captured = CGDisplayIsCaptured(displayID) ? YES : NO;
    }
  }
  return captured;
}

- (NSRect)fullyExposedFrameForFrame:(NSRect)proposedFrame
                     respectingDock:(BOOL)respectingDock
                           onScreen:(NSScreen *)screen {
  // If we can't find a screen for this window, use the main one.
  if (!screen) {
    screen = [NSScreen mainScreen];
  }
  NSRect screenFrame = respectingDock ? [screen visibleFrame] : [screen frame];
  if (!NSContainsRect(screenFrame, proposedFrame)) {
    if (proposedFrame.origin.y < screenFrame.origin.y) {
      proposedFrame.origin.y = screenFrame.origin.y;
    }
    if (NSMaxX(proposedFrame) > NSMaxX(screenFrame)) {
      proposedFrame.origin.x = NSMaxX(screenFrame) - NSWidth(proposedFrame);
    }
    if (proposedFrame.origin.x < screenFrame.origin.x) {
      proposedFrame.origin.x = screenFrame.origin.x;
    }
    if (NSMaxY(proposedFrame) > NSMaxY(screenFrame)) {
      proposedFrame.origin.y = NSMaxY(screenFrame) - NSHeight(proposedFrame);
    }
  }
  return proposedFrame;
}

@end

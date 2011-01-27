//
//  QSBPluginVerifyWindowController.m
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

#import "QSBPluginVerifyWindowController.h"

@interface QSBPluginVerifyWindowController ()
- (void)showDetails;
- (void)hideDetails;

@property (nonatomic, retain, readwrite) HGSPlugin *plugin;

@end

@implementation QSBPluginVerifyWindowController

@synthesize plugin = plugin_;

- (id)init {
  self = [super initWithWindowNibName:@"PluginVerifyWindow"];
  if (self) {
    [detailsView_ retain];
  }
  return self;
}

- (void)dealloc {
  [plugin_ release];
  [detailsView_ release];
  [super dealloc];
}

- (HGSPluginLoadResult)runForPluginAtPath:(NSString *)path
                            withSignature:(HGSCodeSignature *)signature {
  NSBundle *bundle = [NSBundle bundleWithPath:path];
  if (!bundle) {
    HGSLog(@"Unable to load plugin %@", path);
    return eHGSDisallow;
  }
  [self setPlugin:[[HGSPlugin alloc] initWithBundle:bundle]];
  if (!plugin_) {
    HGSLog(@"Unable to verify plugin %@", path);
    return eHGSDisallow;
  }
  [plugin_ factorProtoExtensions];
  
  [NSApp activateIgnoringOtherApps:YES];
  NSWindow *window = [self window];
  [window makeFirstResponder:denyButton_];
  
  NSString *pluginName = [plugin_ displayName];
  if (!pluginName) {
    pluginName = [[path stringByDeletingPathExtension] lastPathComponent];
  }
  NSString *appName = [[NSBundle mainBundle]
                       objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  NSString *format = NSLocalizedString(@"The %@ plugin \"%@\" is untrusted.",
                                       nil);
  NSString *header = [NSString stringWithFormat:format, appName, pluginName];
  [headerTextField_ setStringValue:header];
  
  [self hideDetails];
  [window center];
   
  [window makeKeyAndOrderFront:nil];
  NSInteger resultCode = [NSApp runModalForWindow:window];
  [window orderOut:self];
  return (HGSPluginLoadResult)resultCode;
}

- (IBAction)disclosureTriangleToggled:(id)sender {
  if ([disclosureTriangle_ state] == NSOnState) {
    [self showDetails];
  } else {
    [self hideDetails];
  }
}

- (IBAction)allow:(id)sender {
  [NSApp stopModalWithCode:(NSInteger)eHGSAllowOnce];
}

- (IBAction)alwaysAllow:(id)sender {
  [NSApp stopModalWithCode:(NSInteger)eHGSAllowAlways];
}

- (IBAction)deny:(id)sender {
  [NSApp stopModalWithCode:(NSInteger)eHGSDisallow];
}

- (void)showDetails {
  NSWindow *window = [self window];
  
  [disclosureTriangle_ setState:NSOnState];
  
  if ([detailsView_ superview]) {
    // Already showing
    return;
  }
  
  // Size up the window
  NSRect frame = [window frame];
  frame.size.height += detailsViewFrame_.size.height;
  frame.origin.y -= detailsViewFrame_.size.height;
  [window setFrame:frame display:YES animate:YES];
  
  [[window contentView] addSubview:detailsView_];
  [detailsView_ setFrame:detailsViewFrame_];
}

- (void)hideDetails {
  NSWindow *window = [self window];
  
  [disclosureTriangle_ setState:NSOffState];
  
  if ([detailsView_ superview]) {
    // Save the original size and position
    detailsViewFrame_ = [detailsView_ frame];
    [detailsView_ removeFromSuperview];
  } else {
    // Already hidden
    return;
  }
  
  // Size down the window
  NSRect frame = [window frame];
  frame.size.height -= detailsViewFrame_.size.height;
  frame.origin.y += detailsViewFrame_.size.height;
  [window setFrame:frame display:YES animate:YES];
}

@end

@interface QSBProtoExtensionImageTransformer : NSValueTransformer
@end

@implementation QSBProtoExtensionImageTransformer

+ (Class)transformedValueClass {
  return [NSImage class];
}

- (id)transformedValue:(id)value {
  // TODO(alcor): create some real icons that differentiate between
  // the different kinds of extensions
  NSImage *result = nil;
  if ([value isEqual:kHGSActionsExtensionPoint]) {
    result = [NSImage imageNamed:@"QSBPlugin"];
  } else if ([value isEqual:kHGSSourcesExtensionPoint]) {
    result = [NSImage imageNamed:@"QSBPlugin"];
  } else if ([value isEqual:kHGSServicesExtensionPoint]) {
    result = [NSImage imageNamed:@"QSBPlugin"];
  }  
  return result;
}

@end

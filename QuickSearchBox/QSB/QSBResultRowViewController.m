//
//  QSBResultRowViewController.m
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

#import "QSBResultRowViewController.h"
#import <QSBPluginUI/QSBPluginUI.h>
#import <GTM/GTMMethodCheck.h>
#import <Vermilion/Vermilion.h>

#import "QSBTableResult.h"

// An extension wishing to present a result in a custom view will provide
// a dictionary in its plist with the following key.  This dictionary
// will contain one or more dictionaries identified with a key equal to
// the type of the result for which a custom result view should be used
// to render the result.
//
// Here is an example of what might be found within an extension specification:
//
//    <key>QSBCustomResultViewTypes</key>
//    <dict>
//      <key>webpage</key>
//      <dict>
//        <key>QSBResultViewNibName</key>
//        <string>FunkyWebPageNib</string>
//        <key>QSBResultViewControllerClassName</key>
//        <string>FunkyWebPageNibViewController</string>
//      </dict>
//    </dict>
//
// The associated extension, when presented with a webpage result, would
// provide the FunkyWebPageNib nib file, containing a custom view, while
// identifying the view controller class for that nib file's owner being
// FunkyWebPageNibViewController.
static NSString *const kQSBCustomResultViewTypes = @"QSBCustomResultViewTypes";

// Each custom result view dictionary contains two strings: one identifies
// the nib by name and the other specifies the class of the view controller
// constituting the nibs owner.
static NSString *const kQSBResultViewNibName = @"QSBResultViewNibName";
static NSString *const kQSBResultViewControllerClassName
  = @"QSBResultViewControllerClassName";


@implementation QSBResultRowViewController

@synthesize customResultViewInstalled = customResultViewInstalled_;

- (id)initWithNib:(NSNib *)nib {
  // Instead of passing a name and bundle into NSViewController, we actually
  // cache the nib ourselves.
  if ((self = [super initWithNibName:nil
                              bundle:nil])) {
    nib_ = [nib retain];
  }
  return self;
}

- (void)dealloc {
  [topLevelObjects_ release];
  [nib_ release];
  [super dealloc];
}

-(void)loadView {
  // Instead of loading the view by name and bundle, we use the nib we already
  // have cached.
  BOOL loaded = [nib_ instantiateNibWithOwner:self
                              topLevelObjects:&topLevelObjects_];
  if (!loaded) {
    HGSLogDebug(@"Unable to instantiate %@ for %@", nib_, [self class]);
  } else {
    [[topLevelObjects_ retain] makeObjectsPerformSelector:@selector(release)];
  }
}

- (void)setRepresentedObject:(id)object {
  [super setRepresentedObject:object];

  if (customResultView_) {
    // Remove any old custom view.
    if ([self isCustomResultViewInstalled]) {
      customResultViewInstalled_ = NO;
      NSArray *subViews = [customResultView_ subviews];
      if ([subViews count]) {
        NSView *subView = [subViews objectAtIndex:0];
        [subView removeFromSuperview];
      }
    }
    [customResultView_ setHidden:YES]; // Assume it won't be shown.

    // For now, we only support custom views for HGSResults, but this could
    // be expanded to support any type of represented object.
    if ([object isKindOfClass:[QSBSourceTableResult class]]) {
      QSBSourceTableResult *tableResult = object;
      HGSScoredResult *result = [tableResult representedResult];
      HGSSearchSource *source = [result source];
      NSBundle *sourceBundle = [source bundle];
      if (sourceBundle) {
        // Force the bundle to load.  It may not be loaded, for instance, in the
        // case of a Python-based source.
        BOOL bundleLoaded = [sourceBundle load];
        if (!bundleLoaded) {
          HGSLogDebug(@"Failed to load bundle '%@'.", sourceBundle);
        }
        NSString *resultType = [result type];
        HGSProtoExtension *protoExtension = [source protoExtension];
        NSDictionary *customResultViewTypes
          = [protoExtension objectForKey:kQSBCustomResultViewTypes];
        NSDictionary *customResultViewInfo
          = [customResultViewTypes objectForKey:resultType];
        if (customResultViewInfo) {
          NSString *resultViewNibName
            = [customResultViewInfo objectForKey:kQSBResultViewNibName];
          NSString *resultViewControllerClassName
            = [customResultViewInfo objectForKey:kQSBResultViewControllerClassName];
          Class resultViewControllerClass
            = NSClassFromString(resultViewControllerClassName);
          if ([resultViewNibName length] && resultViewControllerClass) {
            NSViewController<QSBCustomResultView> *resultViewController
              = [[[resultViewControllerClass alloc]
                  initWithNibName:resultViewNibName bundle:sourceBundle]
                 autorelease];
            if (resultViewController) {
              // The custom view doesn't _have_ to do anything special
              // with the result, but it normally should.  There are cases,
              // however, where the result might not be necessary in order
              // to properly render the custom view -- a clock, for example.
              // If the source determines that it cannot or does not want to
              // use its custom view then it should return NO
              // from the call to -[qsb_setResult:].
              if ([resultViewController qsb_setResult:result]) {
                NSView *resultView = [resultViewController view];

                // Re-width the custom view and re-height the container view.
                NSRect customFrame = [customResultView_ frame];
                NSRect resultFrame = [resultView frame];
                resultFrame.origin = NSZeroPoint;
                resultFrame.size.width = NSWidth(customFrame);
                [resultView setFrame:resultFrame];
                CGFloat deltaHeight
                  = NSHeight(resultFrame) - NSHeight(customFrame);
                NSView *containerView = [self view];
                NSSize containerSize = [containerView frame].size;
                containerSize.height += deltaHeight;
                [containerView setFrameSize:containerSize];
                [customResultView_ addSubview:resultView];
                [customResultView_ setHidden:NO];
                customResultViewInstalled_ = YES;
              }
            } else {
              HGSLogDebug(@"Failed to load custom result view nib '%@' "
                          @"for extension '%@'.", resultViewNibName,
                          [source displayName]);
            }

          } else {
            HGSLogDebug(@"Extension '%@' has custom result view entry for '%@' "
                        @"but fails to provide a nib name and/or a "
                        @"view controller class.", [source displayName],
                        resultType);
          }
        }
      }
    }
  } else {
    customResultViewInstalled_ = NO;
  }
}

@end

//
//  QSBTopResultsRowViewControllers.m
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

#import "QSBTopResultsRowViewControllers.h"
#import "QSBTableResult.h"
#import <Vermilion/Vermilion.h>

#define QSBVIEWCONTROLLER_INIT(name) \
  static NSNib *nib = nil; \
  if (!nib) { \
    nib = [[NSNib alloc] initWithNibNamed:name \
                                   bundle:nil];\
  } \
  return [super initWithNib:nib];

@implementation QSBTopDetailedRowViewController

- (void)awakeFromNib {
  // Remember our standard view height and text view y offset.
  defaultViewHeight_ = NSHeight([[self view] frame]);
}

- (void)setRepresentedObject:(id)object {
  [super setRepresentedObject:object];
  if (![self isCustomResultViewInstalled]) {
    BOOL isTableResult = [object isKindOfClass:[QSBTableResult class]];
    if (isTableResult) {
      // Reset the defaults.
      NSView *mainView = [self view];
      CGFloat mainWidth = NSWidth([mainView frame]);
      NSSize newViewSize = NSMakeSize(mainWidth, defaultViewHeight_);
      [mainView setFrameSize:newViewSize];
    } else {
      HGSLogDebug(@"The represented object must be a QSBTableResult.");
    }
  }
}

@end

@implementation QSBTopStandardRowViewController

- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopStandardResultView")
}

@end

@implementation QSBTopSeparatorRowViewController
- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopSeparatorResultView")
}
@end

@implementation QSBTopSearchForRowViewController
- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopSearchForResultView")
}
@end

@implementation QSBTopSearchIconViewController
- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopSearchIconResultView")
}
@end

@implementation QSBTopFoldRowViewController
- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopFoldResultView")
}
@end

@implementation QSBTopMessageRowViewController
- (id)init {
  QSBVIEWCONTROLLER_INIT(@"TopMessageResultView")
}
@end

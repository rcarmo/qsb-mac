//
//  QSBSearchResult.m
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

#import "QSBTableResult.h"
#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>
#import <GTM/GTMNSString+HTML.h>
#import <GTM/GTMNSObject+KeyValueObserving.h>
#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMGoogleSearch.h>

#import "NSAttributedString+Attributes.h"
#import "NSString+ReadableURL.h"
#import "QSBTopResultsRowViewControllers.h"
#import "ClipboardSearchSource.h"
#import "QSBSearchController.h"
#import "QSBActionPresenter.h"
#import "QSBResultsWindowController.h"
#import "QSBMoreResultsViewController.h"

typedef enum {
  kQSBResultDescriptionTitle = 0,
  kQSBResultDescriptionSnippet,
  kQSBResultDescriptionSourceURL,
  kQSBResultDescriptionShowAll,
  kQSBResultDescriptionFold,
} QSBResultDescriptionItemType;

static NSString *const kClipboardCopyActionIdentifier
  = @"com.google.qsb.clipboard.action.copy";

@interface QSBTableResult ()

- (void)addAttributes:(NSMutableAttributedString*)string
          elementType:(QSBResultDescriptionItemType)itemType;

- (NSMutableAttributedString *)mutableAttributedStringWithString:(NSString*)string;

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLString:(NSString*)item
                                                     prettyPrintPath:(BOOL)prettyPrintPath;

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLString:(NSString*)item;

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLPath:(NSString*)item;

// TODO(mrossetti): Some of the mocks show the partial match string as being
// bolded or otherwise highlighted.  Investigate and implement as appropriate.

// Return a mutable string containin the title to be presented for a result.
- (NSMutableAttributedString*)genericTitleLine;

// Return a string containing the snippet, if any, to be presented for a result,
// otherwise return nil.
- (NSAttributedString*)snippetString;

// Return a string containing the sourceURL/URL, if any, to be presented for a
// result, otherwise return nil.
- (NSAttributedString*)sourceURLString;

@end

@interface QSBSourceTableResult ()
- (void)objectIconChanged:(GTMKeyValueChangeNotification *)notification;
@end

@interface NSString(QSBDisplayPathAdditions)
// Converts a path to a pretty, localized, arrow separated version
// Returns autoreleased string with beautified path
- (NSString*)qsb_displayPath;
@end


@implementation QSBTableResult

GTM_METHOD_CHECK(NSMutableAttributedString, addAttribute:value:);
GTM_METHOD_CHECK(NSMutableAttributedString, addAttributes:);
GTM_METHOD_CHECK(NSMutableAttributedString,
                 addAttributes:fontTraits:toTextDelimitedBy:postDelimiter:);
GTM_METHOD_CHECK(NSString, qsb_displayPath);
GTM_METHOD_CHECK(NSString, gtm_stringByUnescapingFromHTML);

static NSDictionary *gBaseStringAttributes_ = nil;

+ (void)initialize {
  if (self == [QSBTableResult class]) {
    NSMutableParagraphStyle *style
    = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setLineBreakMode:NSLineBreakByTruncatingTail];
    [style setParagraphSpacing:0];
    [style setParagraphSpacingBefore:0];
    [style setLineSpacing:0];
    [style setMaximumLineHeight:14.0];

    gBaseStringAttributes_
    = [NSDictionary dictionaryWithObject:style
                                  forKey:NSParagraphStyleAttributeName];
    [gBaseStringAttributes_ retain];
  }
}

+ (NSColor *)secondaryTitleColor {
  return [NSColor colorWithCalibratedRed:165.0/255.0
                                   green:180.0/255.0
                                    blue:204.0/255.0 alpha:1.0];
}

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

- (BOOL)isPivotable {
  return NO;
}

- (void)willPivot {
  HGSLogDebug(@"Tried to pivot on result %@ that doesn't pivot", self);
}

- (NSAttributedString *)titleString {
  NSMutableAttributedString *resultString = [self genericTitleLine];
  [self addAttributes:resultString elementType:kQSBResultDescriptionTitle];
  return resultString;
}

- (NSAttributedString *)titleSnippetSourceURLString {
  NSMutableAttributedString *fullString
    = [[[self titleSnippetString] mutableCopy] autorelease];
  NSAttributedString *sourceURLString = [self sourceURLString];
  if (sourceURLString) {
    [fullString appendAttributedString:[[[NSAttributedString alloc]
                                         initWithString:@"\n"] autorelease]];
    [fullString appendAttributedString:sourceURLString];
  }
  return fullString;
}

- (NSAttributedString *)titleSnippetString {
  NSMutableAttributedString *resultString
    = [[[self titleString] mutableCopy] autorelease];
  NSAttributedString *resultSnippet = [self snippetString];
  if (resultSnippet) {
    [resultString appendAttributedString:[[[NSAttributedString alloc]
                                           initWithString:@"\n"] autorelease]];
    [resultString appendAttributedString:resultSnippet];
  }
  return resultString;
}

- (NSAttributedString *)titleSourceURLString {
  NSMutableAttributedString *resultString
    = [[[self titleString] mutableCopy] autorelease];
  NSAttributedString *resultSourceURL = [self sourceURLString];
  if (resultSourceURL) {
    [resultString appendAttributedString:[[[NSAttributedString alloc]
                                           initWithString:@"\n"] autorelease]];
    [resultString appendAttributedString:resultSourceURL];
  }
  return resultString;
}

- (CGFloat)score {
  return -1.0;
}

- (Class)topResultsRowViewControllerClass {
  HGSLogDebug(@"Need to handle [%@ %s] result %@.", [self class], _cmd, self);
  return nil;
}

- (void)performAction:(id)sender {
  // Do nothing
}

- (NSString *)displayName {
  return nil;
}

- (NSArray *)displayPath {
  return nil;
}

- (void)addAttributes:(NSMutableAttributedString*)string
          elementType:(QSBResultDescriptionItemType)itemType {
  // Note: nothing should be done here that changes the string metrics,
  // since computations may already have been done based on string sizes.
  [string addAttributes:gBaseStringAttributes_];
  switch (itemType) {
    case kQSBResultDescriptionSnippet:
    [string addAttribute:NSForegroundColorAttributeName
                   value:[NSColor grayColor]];
      break;
    case kQSBResultDescriptionSourceURL:
      [string addAttribute:NSForegroundColorAttributeName
                     value:[NSColor colorWithCalibratedRed:(float)0x00/0xFF
                                                     green:(float)0x4c/0xFF
                                                      blue:(float)0x00/0xFF
                                                     alpha:0.5]];
      break;
    case kQSBResultDescriptionTitle:
      [string addAttribute:NSForegroundColorAttributeName
                     value:[NSColor blackColor]];
      break;
    case kQSBResultDescriptionShowAll:
      [string addAttribute:NSForegroundColorAttributeName
                     value:[[self class] secondaryTitleColor]];
      break;
    case kQSBResultDescriptionFold:
      [string addAttribute:NSFontAttributeName
                     value:[NSFont systemFontOfSize:12]];
      break;
    default:
      HGSLogDebug(@"Unknown itemType: %d", itemType);
      break;
  }
}

- (NSMutableAttributedString*)mutableAttributedStringWithString:(NSString*)string {
  CGFloat startingSize = 13.0;
  const CGFloat maxLineHeight = 200;
  NSDictionary *attributes = nil;
  NSMutableAttributedString *attrString = nil;
  NSRect bounds;
  NSStringDrawingOptions options = (NSStringDrawingUsesLineFragmentOrigin
                                    | NSStringDrawingUsesFontLeading);
  do {
    // For some fonts (like Devangari) we have to shrink down a bit. We try to
    // do the minimum shrinkage needed to fit under 14 points. The smallest we
    // will shrink to is 8 points. It may look ugly but at least it still should
    // be readable at 8 points. Anything smaller than that is unreadable.
    // http://b/issue?id=661705
    NSFont *font = [NSFont menuFontOfSize:startingSize];
    attributes = [NSDictionary dictionaryWithObject:font
                                             forKey:NSFontAttributeName];
    attrString = [NSMutableAttributedString attrStringWithString:string
                                                      attributes:attributes];
    bounds = [attrString boundingRectWithSize:[attrString size]
                                      options:options];
    startingSize -= 1.0;
  } while (bounds.size.height > maxLineHeight && startingSize >= 8.0);
  return attrString;
}

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLString:(NSString*)item
                                                     prettyPrintPath:(BOOL)prettyPrintPath {
  NSMutableString *mutableItem = [NSMutableString stringWithString:item];

  NSString* boldPrefix = @"%QSB_MAC_BOLD_PREFIX%";
  NSString* boldSuffix = @"%QSB_MAC_BOLD_SUFFIX%";
  [mutableItem replaceOccurrencesOfString:@"<b>"
                               withString:boldPrefix
                                  options:NSCaseInsensitiveSearch
                                    range:NSMakeRange(0, [mutableItem length])];
  [mutableItem replaceOccurrencesOfString:@"</b>"
                               withString:boldSuffix
                                  options:NSCaseInsensitiveSearch
                                    range:NSMakeRange(0, [mutableItem length])];
  if (prettyPrintPath) {
    NSString *displayString = [mutableItem qsb_displayPath];
    mutableItem = [NSMutableString stringWithString:displayString];
  }
  NSString *unescapedItem = [mutableItem gtm_stringByUnescapingFromHTML];
  NSMutableAttributedString* mutableAttributedItem =
  [self mutableAttributedStringWithString:unescapedItem];
  [mutableAttributedItem addAttributes:nil
                            fontTraits:NSBoldFontMask
                     toTextDelimitedBy:boldPrefix
                         postDelimiter:boldSuffix];
  return mutableAttributedItem;
}

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLString:(NSString*)item {
  return [self mutableAttributedStringFromHTMLString:item prettyPrintPath:NO];
}

- (NSMutableAttributedString *)mutableAttributedStringFromHTMLPath:(NSString*)item {
  return [self mutableAttributedStringFromHTMLString:item prettyPrintPath:YES];
}

- (NSMutableAttributedString*)genericTitleLine {
  return nil;
}

- (NSAttributedString*)snippetString {
  return nil;
}

- (NSAttributedString*)sourceURLString {
  return nil;
}

- (NSImage *)displayIcon {
  return nil;
}

- (NSString*)displayToolTip {
  return @"";
}

- (NSImage *)flagIcon {
  return nil;
}

- (NSImage *)displayThumbnail {
  return nil;
}

- (BOOL)copyToPasteboard:(NSPasteboard *)pb {
  return NO;
}

@end


@implementation QSBSourceTableResult : QSBTableResult

GTM_METHOD_CHECK(NSObject, gtm_addObserver:forKeyPath:selector:userInfo:options:);
GTM_METHOD_CHECK(NSObject, gtm_stopObservingAllKeyPaths);

@synthesize representedResult = representedResult_;
@synthesize categoryName = categoryName_;

+ (id)tableResultWithResult:(HGSScoredResult *)result {
  return [[[[self class] alloc] initWithResult:result] autorelease];
}

- (id)initWithResult:(HGSScoredResult *)result {
  if ((self = [super init])) {
    representedResult_ = [result retain];
    [representedResult_ gtm_addObserver:self
                             forKeyPath:kHGSObjectAttributeIconKey
                               selector:@selector(objectIconChanged:)
                               userInfo:nil
                                options:NSKeyValueObservingOptionNew];
  }
  return self;
}

- (void)dealloc {
  [self gtm_stopObservingAllKeyPaths];
  [representedResult_ release];
  [thumbnailImage_ release];
  [icon_ release];
  [super dealloc];
}

- (BOOL)isEqual:(id)val {
  BOOL equal = NO;
  if ([val isKindOfClass:[self class]]) {
    equal = [[self representedResult] isEqual:[val representedResult]];
  }
  return equal;
}

- (NSUInteger)hash {
  return [[self representedResult] hash];
}

- (void)objectIconChanged:(GTMKeyValueChangeNotification *)notification {
  [self willChangeValueForKey:@"displayIcon"];
  [self willChangeValueForKey:@"displayThumbnail"];
  NSDictionary *change = [notification change];
  NSImage *newIcon = [change objectForKey:NSKeyValueChangeNewKey];
  if (newIcon) {
    [icon_ release];
    [thumbnailImage_ release];
    icon_ = [newIcon retain];
    thumbnailImage_ = [newIcon retain];
  }
  [self didChangeValueForKey:@"displayThumbnail"];
  [self didChangeValueForKey:@"displayIcon"];
}

- (BOOL)isPivotable {
  // We want to pivot on non-suggestions, non-qsb stuff, and non-actions.
  HGSScoredResult *result = [self representedResult];
  BOOL pivotable = YES;
  if ([result conformsToType:kHGSTypeAction]) {
    HGSAction *action = [result valueForKey:kHGSObjectAttributeDefaultActionKey];
    pivotable = [[action arguments] count] > 0;
  }

  return pivotable;
}

- (void)willPivot {
  // Let the result know that we were interested in it.
  HGSScoredResult *result = [self representedResult];
  [result promote];
}

- (void)addAttributes:(NSMutableAttributedString*)string
          elementType:(QSBResultDescriptionItemType)itemType {
  [super addAttributes:string elementType:itemType];
  if (itemType == kQSBResultDescriptionTitle) {
    HGSScoredResult *result = [self representedResult];
    if ([result conformsToType:kHGSTypeAction]) {
      [string addAttribute:NSForegroundColorAttributeName
                     value:[NSColor colorWithCalibratedRed:(float)0x33/0xFF
                                                     green:(float)0x77/0xFF
                                                      blue:(float)0xAA/0xFF
                                                     alpha:1.0]];
    }
  }
}

- (CGFloat)score {
  return [[self representedResult] score];
}

- (Class)topResultsRowViewControllerClass {
  Class rowViewClass = Nil;
  HGSScoredResult *result = [self representedResult];
  if ([result conformsToType:kHGSTypeSuggest]) {
    rowViewClass = [QSBTopSearchForRowViewController class];
  } else if ([result isKindOfClass:[HGSScoredResult class]]) {
    rowViewClass = [QSBTopStandardRowViewController class];
  }
  return rowViewClass;
}

- (void)performAction:(id)sender {
  [NSApp sendAction:@selector(qsb_pickCurrentSourceTableResult:) to:nil from:self];
}

- (NSArray *)displayPath {
  HGSScoredResult *result = [self representedResult];
  return [result valueForKey:kQSBObjectAttributePathCellsKey];
}

- (NSString *)displayName {
  HGSScoredResult *result = [self representedResult];
  return [result displayName];
}

- (NSImage *)flagIcon {
  HGSScoredResult *result = [self representedResult];
  NSString *iconName = [result valueForKey:kHGSObjectAttributeFlagIconNameKey];
  NSImage *image = nil;
  if (iconName) image = [NSImage imageNamed:iconName];
  return image;
}

- (NSImage *)displayIcon {
  if (!icon_) {
    HGSScoredResult *result = [self representedResult];
    icon_ = [[result valueForKey:kHGSObjectAttributeIconKey] retain];
  }
  return icon_;
}

- (NSString*)displayToolTip {
  NSString *displayString = [self displayName];
  HGSScoredResult *result = [self representedResult];
  NSString *snippetString
    = [result valueForKey:kHGSObjectAttributeSnippetKey];
  if ([snippetString length]) {
    displayString = [displayString stringByAppendingFormat:@" — %@",
                     snippetString];
  }
  NSString *resultSourceURL = [[self sourceURLString] string];
  if ([resultSourceURL length]) {
    displayString = [displayString stringByAppendingFormat:@" — %@",
                     resultSourceURL];
  }
#if DEBUG
  NSString *sourceName = [[[self representedResult] source] displayName];
  displayString = [NSString stringWithFormat:@"%@ (Score: %.2f, Source: %@)",
                   displayString, [self score], sourceName];
#endif
  return displayString;
}

- (NSImage *)displayThumbnail {
  if (!thumbnailImage_) {
    HGSScoredResult *result = [self representedResult];
    thumbnailImage_
      = [[result valueForKey:kHGSObjectAttributeImmediateIconKey] retain];
  }
  return thumbnailImage_;
}

- (NSMutableAttributedString*)genericTitleLine {
  // Title is rendered as 12 pt black.
  HGSScoredResult *result = [self representedResult];
  NSString *html = [result valueForKey:kHGSObjectAttributeNameKey];
  NSMutableAttributedString *title
    = [self mutableAttributedStringWithString:html];
  if ([title length] == 0) {
    // If we don't have a title, we'll just use a canned string
    NSString *titleString = NSLocalizedString(@"<No Title>", @"");
    title =  [self mutableAttributedStringWithString:titleString];
  }

  return title;
}

- (NSAttributedString*)snippetString {
  // Snippet is rendered as 12 pt gray (50% black).
  NSMutableAttributedString *snippetString = nil;
  HGSScoredResult *result = [self representedResult];
  NSString *snippet = [result valueForKey:kHGSObjectAttributeSnippetKey];
  if (snippet) {
    snippetString = [self mutableAttributedStringFromHTMLString:snippet];
    [self addAttributes:snippetString elementType:kQSBResultDescriptionSnippet];
  }
  return snippetString;
}

- (NSAttributedString*)sourceURLString {
  // SourceURL is rendered as 12 pt green.
  NSMutableAttributedString *sourceURLString = nil;
  HGSScoredResult *result = [self representedResult];
  NSString *sourceURL = [result valueForKey:kHGSObjectAttributeSourceURLKey];

  sourceURL = [sourceURL readableURLString];
  if (sourceURL) {
    sourceURLString = [self mutableAttributedStringFromHTMLString:sourceURL];
    [self addAttributes:sourceURLString elementType:kQSBResultDescriptionSourceURL];
  }
  return sourceURLString;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %p - %@",
          [self class], self, representedResult_];
}

- (BOOL)copyToPasteboard:(NSPasteboard *)pb {
  BOOL didCopy = NO;
  HGSScoredResult *result = [self representedResult];
  HGSAction *action = [[HGSExtensionPoint actionsPoint]
                       extensionWithIdentifier:kClipboardCopyActionIdentifier];
  if (result && action) {
    HGSResultArray *resultArray = [HGSResultArray arrayWithResult:result];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          resultArray, kHGSActionDirectObjectsKey,
                          pb, kClipboardAttributePasteboardKey,
                          nil];
    didCopy = [action performWithInfo:info];
  }
  return didCopy;
}

@end


@implementation QSBGoogleTableResult

- (id)init {
  [NSException raise:NSIllegalSelectorException format:@"Call initWithQuery"];
  return nil;
}

- (Class)topResultsRowViewControllerClass {
  return [QSBTopSearchForRowViewController class];
}

// We want to inherit the google logo, so don't return an icon
- (NSImage *)displayIcon {
  return [NSImage imageNamed:@"blue-google-white"];
}

- (NSImage *)displayThumbnail {
  return nil;
}

- (NSArray *)displayPath {
  NSString *string = NSLocalizedString(@"Search Google for '%@'",
                                       @"A table result label for an item that "
                                       @"allows you to search google for the "
                                       @"token represented by %@.");
  string = [NSString stringWithFormat:string, [self displayName]];
  NSURL *url = [[self representedResult] url];

  return [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                   string, kQSBPathCellDisplayTitleKey,
                                   url, kQSBPathCellURLKey,
                                   nil]];
}

- (NSAttributedString*)sourceURLString {
  NSMutableAttributedString *sourceURLString = nil;
  NSString *sourceURL = NSLocalizedString(@"Google Search", @""); ;
  if (sourceURL) {
    sourceURLString = [self mutableAttributedStringFromHTMLString:sourceURL];
    [self addAttributes:sourceURLString elementType:kQSBResultDescriptionSnippet];
  }
  return sourceURLString;
}

@end

@implementation QSBSeparatorTableResult

+ (id)tableResult {
  return [[[[self class] alloc] init] autorelease];
}

- (Class)topResultsRowViewControllerClass {
  return [QSBTopSeparatorRowViewController class];
}

@end


@implementation QSBFoldTableResult

+ (id)tableResultWithSearchController:(QSBSearchController *)controller {
  return [[[[self class] alloc] initWithSearchController:controller] autorelease];
}

- (id)initWithSearchController:(QSBSearchController *)controller {
  if ((self = [super init])) {
    controller_ = [controller retain];
  }
  return self;
}

- (void)dealloc {
  [controller_ release];
  [super dealloc];
}

- (Class)topResultsRowViewControllerClass {
  return [QSBTopFoldRowViewController class];
}

- (void)performAction:(id)sender {
  [NSApp sendAction:@selector(qsb_showMoreResults:) to:nil from:self];
}

- (NSMutableAttributedString *)genericTitleLine {
  NSString *title = [controller_ categorySummaryString];
  return [self mutableAttributedStringWithString:title];
}

- (NSAttributedString *)titleString {
  NSMutableAttributedString *resultString = [self genericTitleLine];
  [self addAttributes:resultString elementType:kQSBResultDescriptionFold];
  return resultString;
}

@end

@implementation QSBShowAllTableResult

+ (id)tableResultWithCategory:(QSBCategory *)category
                        count:(NSUInteger)categoryCount {
  return [[[[self class] alloc] initWithCategory:category
                                           count:categoryCount] autorelease];
}

- (id)initWithCategory:(QSBCategory *)category
                 count:(NSUInteger)categoryCount {
  if ((self = [super init])) {
    categoryCount_ = categoryCount;
    category_ = [category retain];
  }
  return self;
}

- (void)dealloc {
  [category_ release];
  [super dealloc];
}

- (NSString *)categoryName {
  return [category_ localizedName];
}

- (NSMutableAttributedString *)genericTitleLine {
  NSString *format = NSLocalizedString(@"Show all %u %@…",
                                       @"A table result label for an item that "
                                       @"will show the user all x things where "
                                       @"x is %u and the things are %@.");
  NSString *title
    = [NSString stringWithFormat:format, categoryCount_, [self categoryName]];
  return [self mutableAttributedStringWithString:title];
}

- (NSAttributedString *)titleString {
  NSMutableAttributedString *resultString = [self genericTitleLine];
  [self addAttributes:resultString elementType:kQSBResultDescriptionShowAll];
  return resultString;
}

- (void)performAction:(id)sender {
  [NSApp sendAction:@selector(qsb_showAllForSelectedCategory:) to:nil from:self];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %p - %@",
          [self class], self, [[self genericTitleLine] string]];
}
@end


@implementation QSBMessageTableResult

+ (id)tableResultWithString:(NSString *)message {
  return [[[[self class] alloc] initWithString:message] autorelease];
}

- (id)initWithString:(NSString *)message {
  if ((self = [super init])) {
    message_ = [message copy];
  }
  return self;
}

- (void)dealloc {
  [message_ release];
  [super dealloc];
}

- (NSAttributedString *)titleSnippetString {
  NSMutableAttributedString *titleSnippet
    = [self mutableAttributedStringWithString:message_];
  [self addAttributes:titleSnippet elementType:kQSBResultDescriptionSnippet];
  return titleSnippet;
}

- (Class)topResultsRowViewControllerClass {
  return [QSBTopMessageRowViewController class];
}

- (void)addAttributes:(NSMutableAttributedString*)string
          elementType:(QSBResultDescriptionItemType)itemType {
  [super addAttributes:string elementType:itemType];
  [string setAlignment:NSCenterTextAlignment
                 range:NSMakeRange(0, [string length])];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: %p - %@",
          [self class], self, message_];
}

@end

@implementation NSString(QSBDisplayPathAdditions)

- (NSString*)qsb_displayPath {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *displayName = [self stringByStandardizingPath];
  displayName = [fm displayNameAtPath:displayName];
  NSString *container = [self stringByDeletingLastPathComponent];
  if (!([container isEqualToString:@"/"] // Root
        || [container isEqualToString:@""] // Relative path
        || [container isEqualToString:@"/Volumes"])) {
    container = [container qsb_displayPath];
    displayName = [container stringByAppendingFormat:@" ▸ %@", displayName];
  }
  return displayName;
}

@end

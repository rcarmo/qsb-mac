//
//  DictionarySearchSource.m
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

#import <Vermilion/Vermilion.h>
#import <CoreServices/CoreServices.h>
#import "GTMNSNumber+64Bit.h"
#import "GTMMethodCheck.h"

static NSString *kDictionaryUrlFormat = @"qsbdict://%@";
static NSString *kDictionaryResultType
  = HGS_SUBTYPE(@"onebox", @"dictionary_definition");
NSString *kDictionaryRangeKey = @"DictionaryRange";
NSString *kDictionaryTermKey = @"DictionaryTerm";
static NSString *kShowInDictionaryAction
  = @"com.google.qsb.dictionary.action.open";
static NSString *kDictionaryAppBundleId = @"com.apple.Dictionary";
static const int kMinQueryLength = 3;

@interface DictionarySearchSource : HGSCallbackSearchSource {
 @private
  NSImage *dictionaryIcon_;
}
@end

@implementation DictionarySearchSource
GTM_METHOD_CHECK(NSNumber, gtm_numberWithCGFloat:);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    dictionaryIcon_
      = [ws iconForFile:
         [ws absolutePathForAppBundleWithIdentifier:@"com.apple.Dictionary"]];
    [dictionaryIcon_ retain];
  }
  return self;
}

- (void) dealloc {
  [dictionaryIcon_ release];
  [super dealloc];
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    HGSResult *pivotObject = [query pivotObject];
    if (pivotObject) {
      isValid = NO;
      if ([[pivotObject type] isEqual:kHGSTypeFileApplication]) {
        NSString *path = [pivotObject filePath];
        NSBundle *bnd = [NSBundle bundleWithPath:path];
        if ([[bnd bundleIdentifier] isEqual:kDictionaryAppBundleId]) {
          isValid = ([[query tokenizedQueryString] originalLength] > 0);
        }
      }
    } 
  }
  return isValid;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  NSMutableSet *results = [NSMutableSet set];
  HGSQuery *hgsQuery = [operation query];
  HGSTokenizedString *tokenizedQueryString = [hgsQuery tokenizedQueryString];
  NSString *rawQuery = [tokenizedQueryString originalString];
  
  BOOL highRelevance = NO;
  NSString *dictionaryPrefix = HGSLocalizedString(@"define ",
                                                  @"prefix for explicit "
                                                  @"dictionary searches of the "
                                                  @"form define foo");
  NSString *dictionarySuffix = HGSLocalizedString(@" define",
                                                  @"suffix for explicit "
                                                  @"dictionary searches of the "
                                                  @"form 'foo define'");
  NSString *lowerQuery = [rawQuery lowercaseString];
  if ([lowerQuery hasPrefix:dictionaryPrefix]) {
    rawQuery = [rawQuery substringFromIndex:[dictionaryPrefix length]];
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    rawQuery = [rawQuery stringByTrimmingCharactersInSet:set];
    highRelevance = YES;
  } else if ([lowerQuery hasSuffix:dictionarySuffix]) {
    rawQuery = [rawQuery substringToIndex:[rawQuery length] - [dictionarySuffix length]];
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    rawQuery = [rawQuery stringByTrimmingCharactersInSet:set];
    highRelevance = YES;
  } else if ([hgsQuery pivotObject]) {
    highRelevance = YES;
  }
  CFRange range = DCSGetTermRangeInString(NULL, (CFStringRef)rawQuery, 0);
  if (range.location != kCFNotFound 
      && range.length != kCFNotFound 
      && range.length == [rawQuery length]) {
    CFStringRef def = DCSCopyTextDefinition(NULL, (CFStringRef)rawQuery, range);
    if (def) {
      NSString *urlString 
        = [NSString stringWithFormat:kDictionaryUrlFormat,
           [rawQuery stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
      NSRange nsRange = NSMakeRange(range.location, range.length);
      NSMutableDictionary *attributes
        = [NSMutableDictionary dictionaryWithObjectsAndKeys:
           (NSString *)def, kHGSObjectAttributeSnippetKey,
           dictionaryIcon_, kHGSObjectAttributeIconKey,
           [NSNumber numberWithUnsignedInteger:eHGSSpecialUIRankFlag], 
             kHGSObjectAttributeRankFlagsKey,
           [NSValue valueWithRange:nsRange], kDictionaryRangeKey,
           [rawQuery substringWithRange:nsRange], kDictionaryTermKey,
           nil];
      
      HGSCalibratedScoreType scoreType 
        = highRelevance ? kHGSCalibratedStrongScore 
                        : kHGSCalibratedInsignificantScore;
      CGFloat score = HGSCalibratedScore(scoreType);
      
      HGSAction *action 
        = [[HGSExtensionPoint actionsPoint]
           extensionWithIdentifier:kShowInDictionaryAction];
      if (action) {
        [attributes setObject:action forKey:kHGSObjectAttributeDefaultActionKey];
      }
      NSString *definitionFormat 
        = HGSLocalizedString(@"Definition of %@", 
                             @"A label for a result denoting the dictionary "
                             @"definition of the term represented by %@.");
      NSString *name
        = [NSString stringWithFormat:definitionFormat,
           [rawQuery substringWithRange:NSMakeRange(range.location, range.length)]];
      HGSScoredResult *scoredResult 
        = [HGSScoredResult resultWithURI:urlString
                                    name:name
                                    type:kDictionaryResultType
                                  source:self
                              attributes:attributes
                                   score:score 
                                   flags:eHGSSpecialUIRankFlag
                             matchedTerm:tokenizedQueryString 
                          matchedIndexes:nil];
      [results addObject:scoredResult];
      CFRelease(def);
    }
  }
  [operation setRankedResults:[results allObjects]];
  
  // Since we are concurent, finish the query ourselves.
  // TODO(hawk): if we go back to being non-concurrent, remove this
  [operation finishQuery];
}

- (BOOL)isSearchConcurrent {
  return YES;
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributePasteboardValueKey]) {
    NSString *snippet = [result valueForKey:kHGSObjectAttributeSnippetKey];
    value = [NSDictionary dictionaryWithObject:snippet
                                        forKey:NSStringPboardType];
  }
  return value;
}

@end

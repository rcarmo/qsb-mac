//
//  HGSTokenizer.mm
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

#import "HGSTokenizer.h"    
#import <vector>
#import "GTMGarbageCollection.h"
#import "HGSLog.h"
#import "HGSBundle.h"

typedef struct HGSRangeMapping {
  NSRange domain_;
  NSRange codomain_;
} HGSRangeMapping;

@interface HGSTokenizedString ()
// The mapping from the original string to the tokenized string
@property (readonly, assign) HGSRangeMapping *mappings;
@property (readwrite, retain) NSString *tokenizedString;
- (id)initWithString:(NSString *)string 
            capacity:(NSUInteger)capacity;
@end

@interface HGSTokenizerInternal : NSObject {
@private
  CFStringTokenizerRef tokenizer_;
  CFCharacterSetRef numberSet_;
}

- (HGSTokenizedString *)tokenizeString:(NSString *)string;
@end

static NSDictionary *gHGSTokenizerExceptions = nil;

@implementation HGSTokenizerInternal
+ (void)initialize {
  if (!gHGSTokenizerExceptions) {
    NSBundle *hgsBundle = HGSGetPluginBundle();
    NSString *path = [hgsBundle pathForResource:@"HGSTokenizerExceptions" 
                                         ofType:@"plist"];
    gHGSTokenizerExceptions = [NSDictionary dictionaryWithContentsOfFile:path];
    HGSAssert(gHGSTokenizerExceptions, nil);
    [gHGSTokenizerExceptions retain];
  }
}

- (id)init {
  if ((self = [super init])) {
    // The header comments for CFStringTokenizerCreate and
    // kCFStringTokenizerUnitWord indicate the locale is unused for UnitWord;
    // so we just pass NULL here to avoid creating one.
    // Radar 6195821 has been filed to get the docs updated to match.    
    tokenizer_ = CFStringTokenizerCreate(NULL, 
                                         CFSTR(""), 
                                         CFRangeMake(0,0), 
                                         kCFStringTokenizerUnitWord, 
                                         NULL);
    numberSet_ 
      = CFCharacterSetCreateWithCharactersInString(NULL, 
                                                   CFSTR("0123456789,."));
    HGSAssert(tokenizer_, nil);
  }
  return self;
}

- (void)dealloc {
  if (tokenizer_) {
    CFRelease(tokenizer_);
    tokenizer_ = NULL;
  }
  if (numberSet_) {
    CFRelease(numberSet_);
    numberSet_ = NULL;
  }
  [super dealloc];
}
  
- (HGSTokenizedString *)tokenizeString:(NSString *)string {
  CFLocaleRef currentLocale = (CFLocaleRef)[NSLocale currentLocale];
  CFOptionFlags options = (kCFCompareDiacriticInsensitive 
                           | kCFCompareWidthInsensitive);
  CFMutableStringRef normalizedString 
    = CFStringCreateMutableCopy(NULL, 0, (CFStringRef)string);
  if (!normalizedString) return nil;
  CFStringFold(normalizedString, options, currentLocale);
  
  std::vector<CFRange> tokensRanges;
  
  CFRange tokenRange = CFRangeMake(0, CFStringGetLength(normalizedString));
  CFStringTokenizerSetString(tokenizer_, normalizedString, tokenRange);
  while (TRUE) {
    CFStringTokenizerTokenType tokenType
      = CFStringTokenizerAdvanceToNextToken(tokenizer_);
    if (tokenType == kCFStringTokenizerTokenNone) {
      break;
    }
    CFRange subTokenRanges[100];
    CFIndex rangeCount 
      = CFStringTokenizerGetCurrentSubTokens(tokenizer_, 
                                             subTokenRanges, 
                                             sizeof(subTokenRanges) / sizeof(subTokenRanges[0]), 
                                             NULL);
    if (rangeCount == 0) {
      subTokenRanges[0] = CFStringTokenizerGetCurrentTokenRange(tokenizer_);
      rangeCount = 1;
    }
    // If our subtokens contain numbers we want to rejoin the numbers back
    // up. 
    if (tokenType & kCFStringTokenizerTokenHasHasNumbersMask) {
      BOOL makingNumber = NO;
      CFRange newRange = CFRangeMake(subTokenRanges[0].location, 0);
      for (CFIndex i = 0; i < rangeCount; ++i) {
        UniChar theChar 
          = CFStringGetCharacterAtIndex(normalizedString, 
                                        subTokenRanges[i].location);
        BOOL isNumber 
          = CFCharacterSetIsCharacterMember(numberSet_, theChar) ? YES : NO;
        if (isNumber == YES) {
          if (!makingNumber) {
            if (newRange.length > 0) {
              tokensRanges.push_back(newRange);
            }
            newRange = CFRangeMake(subTokenRanges[i].location, 0);
            makingNumber = YES;
          } 
          newRange.length += subTokenRanges[i].length;
        } else {
          makingNumber = NO;
          if (newRange.length > 0) {
            tokensRanges.push_back(newRange);
            newRange = CFRangeMake(subTokenRanges[i].location, 0);
          }
          tokensRanges.push_back(subTokenRanges[i]);
        }
      }
      if (newRange.length > 0) {
        tokensRanges.push_back(newRange);
      }
    } else {
      tokensRanges.insert(tokensRanges.end(), 
                          subTokenRanges, subTokenRanges + rangeCount);
    }
  }
  
  CFStringFold(normalizedString, 
               kCFCompareCaseInsensitive, 
               currentLocale);
  
  size_t tokenRangeCount = tokensRanges.size();
  NSMutableArray *subStrings = [NSMutableArray arrayWithCapacity:tokenRangeCount];
  for (CFIndex i = 0; i < tokenRangeCount; ++i) {
    CFRange range = tokensRanges[i];
    NSString *subString 
      = (NSString *)CFStringCreateWithSubstring(NULL,
                                                (CFStringRef)normalizedString, 
                                                range);
    NSArray *exceptionArray = [gHGSTokenizerExceptions objectForKey:subString];
    if (exceptionArray) {
      tokensRanges.erase(tokensRanges.begin() + i);
      for (NSString *exceptionSubstring in exceptionArray) {
        [subStrings addObject:exceptionSubstring];
        CFRange subRange = range;
        subRange.length = [exceptionSubstring length];
        tokensRanges.insert(tokensRanges.begin() + i, &subRange, &subRange + 1);
        range.location += subRange.length;
        range.length -= subRange.length;
        ++tokenRangeCount;
        ++i;
      }
      // Subtract one to account for the one term erased above.
      --tokenRangeCount;
      --i;

    } else {
      [subStrings addObject:subString];
    }
    [subString release];
  }
  
  tokenRangeCount = tokensRanges.size();
  NSInteger length = [string length] + tokenRangeCount;
  NSMutableString *finalString = [NSMutableString stringWithCapacity:length];
  // Now that we have all of our ranges, check for exceptions.

      
  NSUInteger codomainStart = 0;
  HGSTokenizedString *tokenizedString 
    = [[[HGSTokenizedString alloc] initWithString:string
                                         capacity:tokenRangeCount] autorelease];
  HGSRangeMapping *mappings = [tokenizedString mappings];
  CFIndex i = 0;
  NSString *tokenizerSeparator = [HGSTokenizer tokenizerSeparatorString];
  for (NSString *subString in subStrings) {
    if (i != 0) {
      [finalString appendString:tokenizerSeparator];
      codomainStart++;
    }
    HGSRangeMapping mapping;
    mapping.codomain_ = *((NSRange*)(&tokensRanges[i]));
    mapping.domain_ = NSMakeRange(codomainStart, 
                                  tokensRanges[i].length);
    mappings[i] = mapping;
    codomainStart += tokensRanges[i].length;
    [finalString appendString:subString];
    ++i;
  }
  CFRelease(normalizedString);
  [tokenizedString setTokenizedString:finalString];
  return tokenizedString;
}

@end

@implementation HGSTokenizer
#if DEBUG
// Verify that our separator string and our separator character are the same.
+ (void)load {
  unichar stringChar = [[self tokenizerSeparatorString] characterAtIndex:0];
  HGSAssert(stringChar == [self tokenizerSeparator], nil);
}
#endif

+ (HGSTokenizedString *)tokenizeString:(NSString *)string {
  HGSTokenizedString *tokenizedString = nil;
  if (string) {
    NSThread *currentThread = [NSThread currentThread];
    NSMutableDictionary *threadDictionary = [currentThread threadDictionary];
    NSString *kHGSTokenizerThreadTokenizer = @"HGSTokenizerThreadTokenizer";
    HGSTokenizerInternal *internalTokenizer 
      = [threadDictionary objectForKey:kHGSTokenizerThreadTokenizer];
    if (!internalTokenizer) {
      internalTokenizer = [[[HGSTokenizerInternal alloc] init] autorelease];
      [threadDictionary setObject:internalTokenizer 
                           forKey:kHGSTokenizerThreadTokenizer];
    }
    tokenizedString = [internalTokenizer tokenizeString:string];
  }
  return tokenizedString;
}

+ (NSArray *)tokenizeStrings:(NSArray *)strings {
  NSUInteger count = [strings count];
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
  for (NSString *string in strings) {
    HGSTokenizedString *tokenizedString = [HGSTokenizer tokenizeString:string];
    [array addObject:tokenizedString];
  }
  return array;
}

+ (NSString *)tokenizerSeparatorString {
  return @"˽";
}

+ (unichar)tokenizerSeparator {
  return 0x02FD;
}

@end

@implementation HGSTokenizedString
@synthesize originalString = originalString_;
@synthesize tokenizedString = tokenizedString_;
@synthesize mappings = mappings_; 

- (id)initWithString:(NSString *)string 
            capacity:(NSUInteger)capacity {
  if ((self = [super init])) {
    mappings_ = (HGSRangeMapping *)malloc(sizeof(HGSRangeMapping) * capacity);
    if (!mappings_) {
      [self release];
      self = nil;
    }
    count_ = capacity;
    originalString_ = [string copy];
  }
  return self;
}

- (void)dealloc {
  [originalString_ release];
  [tokenizedString_ release];
  free(mappings_);
  [super dealloc];
}

- (NSUInteger)mapIndexFromTokenizedToOriginal:(NSUInteger)indx {
  NSUInteger mappedIndex = NSNotFound;
  for (NSUInteger i = 0; i < count_; i++) {
    if (NSLocationInRange(indx, mappings_[i].domain_)) {
      mappedIndex = (indx - mappings_[i].domain_.location 
                     + mappings_[i].codomain_.location);
      break;
    }
  }
  return mappedIndex;
}

- (NSUInteger)hash {
  return [originalString_ hash];
}

- (BOOL)isEqual:(id)object {
  BOOL isGood = NO;
  if ([[object class] isEqual:[self class]]) {
    NSString *objectString = [(HGSTokenizedString*)object originalString];
    NSString *originalString = [self originalString];
    isGood = [objectString isEqualToString:originalString];
  }
  return isGood;
}

- (NSUInteger)tokenizedLength {
  return [tokenizedString_ length];
}

- (NSUInteger)originalLength {
  return [originalString_ length];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p raw='%@', tokenized='%@'>",
          [self class], self, [self originalString], [self tokenizedString]];
}

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

@end


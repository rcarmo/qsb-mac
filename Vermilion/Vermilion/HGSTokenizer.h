//
//  HGSTokenizer.h
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

#import <Foundation/Foundation.h>

/*!
 @header 
 HGSTokenizer is our standard tokenizer for breaking up strings that we index.
 As implemented currently it breaks according to the Unicode standard 
 ( http://www.unicode.org/reports/tr29/#Word_Boundaries ). It then strips out
 all punctuation, and breaks the tokens again at camelcaps boundaries and
 alpha/number boundaries.
 
 Therefore, according to the unicode spec, "MacPython2.4" should not break,
 but we break it as "Mac" "Python" "2.4". Numbers are defined as [0-9\.,]+.
 
 This tokenizer breaks all Roman languages and CZJK.
*/ 

@interface HGSTokenizedString : NSObject <NSCopying> {
 @private
  NSString *originalString_;
  NSString *tokenizedString_;
  NSUInteger count_;
  struct HGSRangeMapping *mappings_;
}

// The original string that was tokenized.
@property (readonly, copy) NSString *originalString;
// The tokenized string (intentionally retained vs copied to cut down on
// unnecessary copying).
@property (readonly, retain) NSString *tokenizedString;

@property (readonly, assign) NSUInteger tokenizedLength;
@property (readonly, assign) NSUInteger originalLength;

- (NSUInteger)mapIndexFromTokenizedToOriginal:(NSUInteger)indx;

@end

/*!
 HGSTokenizer is thread safe.
*/
@interface HGSTokenizer : NSObject
/*!
 Tokenize a string.
 @param string String to be tokenized
 @result A tokenized string.
*/
+ (HGSTokenizedString *)tokenizeString:(NSString *)string;
+ (NSArray *)tokenizeStrings:(NSArray *)strings;
+ (NSString *)tokenizerSeparatorString;
+ (unichar)tokenizerSeparator;
@end

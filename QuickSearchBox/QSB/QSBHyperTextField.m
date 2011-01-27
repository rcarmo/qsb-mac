//
//  GDHyperTextField.m
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

#import "GDHyperTextField.h"
#import "GTMMethodCheck.h"
#import "NSString+CaseInsensitive.h"

@implementation GDHyperTextFieldEditor
GTM_METHOD_CHECK(NSString, hasCaseInsensitivePrefix:)

- (void)awakeFromNib {
  [self setEditable:YES];
  [self setFieldEditor:NO];
  [self setSelectable:YES];
}

- (void)deleteCompletion {
  if (lastCompletionRange_.length > 0) {
    NSRange intersection = NSIntersectionRange(lastCompletionRange_, NSMakeRange(0, [[self textStorage] length]));
    if (intersection.length) {
      [[self textStorage] deleteCharactersInRange:intersection];
    }
    lastCompletionRange_ = NSMakeRange(0,0);
  }
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
  [self deleteCompletion];
  return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
}

- (void)didChangeText {
  [super didChangeText];
  [self complete:self];
}

- (void)complete:(id)sender {
  [self deleteCompletion];
  NSTextStorage *storage = [self textStorage];
  NSRange range = NSMakeRange(0, [storage length]);
  NSInteger idx = 0;
  NSArray *completions = [self completionsForPartialWordRange:range 
                                          indexOfSelectedItem:&idx];
  if ([completions count]) {
    [self insertCompletion:[completions objectAtIndex:0]
       forPartialWordRange:range movement:0 isFinal:YES];
  }
}

- (void)insertCompletion:(NSString *)completion 
     forPartialWordRange:(NSRange)charRange 
                movement:(int)movement
                 isFinal:(BOOL)flag {
  if ([completion length]) {
    NSTextStorage *storage = [self textStorage];
    NSArray *selection = [self selectedRanges];
    NSRange stringRange = NSMakeRange(0, [storage length]);
    [storage beginEditing];
    
    NSString *typedString = [[self string] substringWithRange:charRange];
    NSRange substringRange = [completion rangeOfString:typedString
                                            options:NSCaseInsensitiveSearch];
    
    // If this string isn't found at the beginning or with a space prefix,
    // find the range of the last word and proceed with that.
    if (substringRange.location == NSNotFound || (substringRange.location &&
            [completion characterAtIndex:substringRange.location - 1] != ' ')) {
      NSString *lastWord =
      [[typedString componentsSeparatedByString:@" "] lastObject];
      substringRange = [completion rangeOfString:lastWord
                                         options:NSCaseInsensitiveSearch];
    }
    
    NSString *wordCompletion = @"";
    
    // Make sure we don't capitalize what the user typed
    if (substringRange.location == 0) {
      completion = [typedString stringByAppendingString:
                     [completion substringFromIndex:stringRange.length]];
      
    // if our search string appears at the beginning of a word later in the
    // string, pull the remainder of the word out as a completion
    } else if (substringRange.location != NSNotFound 
          && [completion characterAtIndex:substringRange.location - 1] == ' ') {
      NSRange wordRange = NSMakeRange(NSMaxRange(substringRange), 
                              [completion length] - NSMaxRange(substringRange));
      // Complete the current word
      NSRange nextSpaceRange = [completion rangeOfString:@" "
                                                 options:0
                                                   range:wordRange];
      
      if (nextSpaceRange.location != NSNotFound) 
        wordRange.length = nextSpaceRange.location - wordRange.location;
      
      wordCompletion = [completion substringWithRange:wordRange];
    }
  
    if ([completion hasCaseInsensitivePrefix:[storage string]]) {
      [storage replaceCharactersInRange:charRange withString:completion];
      lastCompletionRange_ = NSMakeRange(NSMaxRange(stringRange), 
                                         [completion length] - charRange.length);
    } else {
      NSString *appendString = [NSString stringWithFormat:@"%@ (%@)",
                                                          wordCompletion, 
                                                          completion];
      int length = [storage length];
      [storage replaceCharactersInRange:NSMakeRange([storage length], 0) 
                             withString:appendString];
      lastCompletionRange_ = NSMakeRange(length, [appendString length]);
    }
    
    [storage addAttribute:NSForegroundColorAttributeName 
                    value:[NSColor lightGrayColor] 
                    range:lastCompletionRange_];
    [storage endEditing];
    [self setSelectedRanges:selection];
  }
}

- (BOOL)isAtBeginning {
  NSRange range = [self selectedRange];
  return (range.length == 0 && range.location == 0);
}

- (BOOL)isAtEnd {
  NSRange range = [self selectedRange];
  if (range.length == 0) {
    if (lastCompletionRange_.location > 0) {
      
      return range.location == lastCompletionRange_.location; 
    } else {
      return range.location == [[self string] length]; 
    }
  }
  return NO;
}

- (NSRange)removeCompletionIfNecessaryFromSelection:(NSRange)selection {
  if (lastCompletionRange_.length > 0 && 
      NSMaxRange(selection) > lastCompletionRange_.location) {
    selection.length -= lastCompletionRange_.location - selection.location;
    [self deleteCompletion];
  }
  return selection;
}

- (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
  NSArray *outRanges = ranges;
  if (lastCompletionRange_.length != 0) {
    NSMutableArray *newRanges =[NSMutableArray arrayWithCapacity:[ranges count]];
    NSEnumerator *rangeEnum = [ranges objectEnumerator];
    NSValue *value;
    while ((value = [rangeEnum nextObject])) {
      NSRange range = [value rangeValue];
      if (lastCompletionRange_.location < NSMaxRange(range)) {
        if (range.location < lastCompletionRange_.location) {
          range = NSMakeRange(range.location, lastCompletionRange_.location - range.location);
        } else {
          range = NSMakeRange(lastCompletionRange_.location, 0);
        }
        range = NSMakeRange(range.location, lastCompletionRange_.location - range.location);
      }
      [newRanges addObject:[NSValue valueWithRange:range]];
    }
    outRanges = newRanges;
  }
  [super setSelectedRanges:outRanges affinity:affinity stillSelecting:stillSelectingFlag];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
  [self deleteCompletion];
  return [super draggingEntered:sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
  [self complete:self];
  [super draggingExited:sender];
}

@end

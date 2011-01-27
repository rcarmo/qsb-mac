//
//  main.m
//  UndocumentedGoodness
//
//  Created by Nicholas Jitkoff on 3/19/08.
//  Copyright Google Inc 2008. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "QLUIPrivate.h"
#import "CPSPrivate.h"
#import "CGSPrivate.h"
#import "CoreDockPrivate.h"
#import "DCSPrivate.h"
#import "CalculatePrivate.h"

int main(int argc, char *argv[])
{
  [NSAutoreleasePool new];

  NSLog(@"CALCULATE");
  char result[1024];
  OSStatus success =  CalculatePerformExpression("pi * 2000", 100, 1, result);
  NSLog(@"pi*2000 = %d %s", success, result);
  
  NSLog(@"DEFINE");
  NSString *word = @"onomatopoeia";
  NSLog(@"%@", (NSString *)DCSCopyTextDefinition (NULL, (CFStringRef)word, CFRangeMake(0, [word length])));
  
  NSURL *url = [NSURL fileURLWithPath:@"/Library/Dictionaries/New Oxford American Dictionary.dictionary"];
  
  CFTypeRef dictionary = DCSDictionaryCreate((CFURLRef) url);
  CFArrayRef records =  DCSCopyRecordsForSearchString(dictionary, (CFStringRef)word, 0, 0);
  
  for (id record in (NSArray *)records) {
    NSLog(@"dict %@",  DCSRecordCopyData(record) );
  }
  return 0;//NSApplicationMain(argc,  (const char **) argv);
}

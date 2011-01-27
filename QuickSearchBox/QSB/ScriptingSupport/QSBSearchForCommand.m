//
//  QSBSearchForCommand.m
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

#import <Vermilion/Vermilion.h>
#import "GTMNSAppleEventDescriptor+Foundation.h"
#import "GTMNSAppleScript+Handler.h"
#import <Carbon/Carbon.h>

// Handles the QSBSearchForCommand. Allows you to implement searches with and
// without handlers. Here's a simple example of a applescript qsb interface
// working with an AppleScript callback.

// using terms from application "Google Quick Search"
//   on results received results for query
//     set resultText to ""
//     repeat with a in results
//       set resultText to resultText & name of a & " : " & URL of a & return
//     end repeat
//     tell me
//       activate
//       display dialog "Query: " & query & return & "Results: " & return
//            & resultText buttons {"OK"} default button "OK"
//       doQuery()
//     end tell
//   end results received
// end using terms from
//
// on doQuery()
//   set query to display dialog "Search For:" default answer ""
//    buttons {"Quit", "Search"} default button "Search"
//   if (button returned of query) is "Quit" then
//     tell me to quit
//   else
//     tell application "Google Quick Search"
//       search for (text returned of query) handler me
//     end tell
//   end if
// end doQuery
//
// on run
//   doQuery()
// end run

@interface QSBSearchForCommand : NSScriptCommand {
 @private
  NSAppleEventDescriptor *returnAddress_;
  HGSQueryController *queryController_;
  NSAppleScript *handler_;
  NSArray *results_;
  NSRange resultRange_;
  BOOL queryHasFinished_;
}

@property BOOL queryHasFinished;

- (void)queryControllerDidFinish:(NSNotification *)notification;

@end

// Converts a script wrapped up in an AEDesc to an NSAppleScript object for us.
// It's unfortunate that Apple didn't implement this one.
@interface NSAppleScript (GTMNSAppleScriptConversion)
+ (NSAppleScript *)scriptingScriptWithDescriptor:(NSAppleEventDescriptor *)desc;
@end

@implementation QSBSearchForCommand

@synthesize queryHasFinished = queryHasFinished_;

- (id)performDefaultImplementation {
  // Store off our return address so we can call back below in finished.
  NSAppleEventDescriptor *appleEvent = [self appleEvent];
  returnAddress_
    = [[appleEvent attributeDescriptorForKeyword:keyAddressAttr] retain];

  // get the query
  NSString *text = [self directParameter];

  // set up our internals
  HGSQuery *query = [[[HGSQuery alloc] initWithString:text
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:nil
                                           queryFlags:0] autorelease];

  HGSAssert(!queryController_, @"QueryController should be nil");
  queryController_ = [[HGSQueryController alloc] initWithQuery:query];

  // store off the handler if there is one. Optional arg.
  NSDictionary *args = [self evaluatedArguments];
  handler_ = [[args objectForKey:@"handler"] retain];

  // Set up the range of results to find.
  NSInteger maxResults = [[args objectForKey:@"maxResults"] integerValue];
  if (maxResults <= 0) maxResults = 100;
  resultRange_ = NSMakeRange(0, maxResults);

  // Set up notifications and start the query
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
          selector:@selector(queryControllerDidFinish:)
              name:kHGSQueryControllerDidFinishNotification
            object:queryController_];
  [self setQueryHasFinished:NO];
  [queryController_ startQuery];

  // if we don't have a handler, we'll just spin until the search
  // is done. This could take a while and may time out
  if (!handler_) {
    NSRunLoop *rl = [NSRunLoop currentRunLoop];
    while (![self queryHasFinished]) {
      [rl runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
  } else {
    // Set up handler so that the chain is correct for applescript
    // evaluation. This is a bit tricky. So what happens is that we get
    // a script passed to us as a handler. It will have a inheritence hierarchy
    // that looks something like this...
    // parent process
    //   script
    //     script
    //       ...
    //       ourHandler
    //
    // Problem is that parent process is set to "QSB" which we don't want. We
    // want the script run in the context of it's original parent process.
    // We walk up the inheritence chain looking for a parent that is not a
    // script (the parent process is usually of type psn, but could be any
    // of the standard AppleScript addressing types) and once we find one
    // that is not a script, we will set it to the returnAddress_ that we
    // stored out of the incoming event above.
    // If this should fail we will continue, because in many cases it WILL
    // work.
    NSAppleScript *parent = handler_;
    NSAppleScript *child = nil;
    GTMFourCharCode *propertyCode
      = [GTMFourCharCode fourCharCodeWithFourCharCode:pASParent];
    do {
      child = parent;
      parent = [parent gtm_valueForProperty:propertyCode];
    } while ([parent isKindOfClass:[NSAppleScript class]]);
    [child gtm_setValue:returnAddress_
            forProperty:propertyCode
       addingDefinition:YES];

    // Retain ourselves so we don't get released while the runloop spins
    // and our query is being evaluated.
    [self retain];
    results_ = [NSArray array];
  }
  return results_;
}

- (void)queryControllerDidFinish:(NSNotification *)notification {
  HGSQueryController *controller = [notification object];
  HGSAssert(controller == queryController_, nil);
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:kHGSQueryControllerDidFinishNotification
              object:queryController_];
  // Our query is finished.
  [self setQueryHasFinished:YES];

  NSArray *results
    = [controller rankedResultsInRange:resultRange_
                            typeFilter:[HGSTypeFilter filterAllowingAllTypes]
                      removeDuplicates:NO];
  NSUInteger count = [results count];
  NSMutableArray *appleScriptResults = [NSMutableArray arrayWithCapacity:count];
  for (HGSScoredResult *hgsResult in results) {
    NSURL *url = [hgsResult url];
    NSString *urlString = [url absoluteString];
    NSString *title = [hgsResult displayName];
    if (handler_ ) {
      // If we have a handler, we store them as AERecords
      NSAppleEventDescriptor *urlDesc = [urlString gtm_appleEventDescriptor];
      NSAppleEventDescriptor *titleDesc = [title gtm_appleEventDescriptor];
      NSAppleEventDescriptor *record
        = [NSAppleEventDescriptor recordDescriptor];
      [record setDescriptor:titleDesc forKeyword:pName];
      [record setDescriptor:urlDesc forKeyword:pURL];
      [appleScriptResults addObject:record];
    } else {
      // If we are just returning, we can use AppleScript's internal handling
      // to convert them.
      NSDictionary *asResult
        = [NSDictionary dictionaryWithObjectsAndKeys:
           urlString, @"link",
           title, @"title",
           nil];
      [appleScriptResults addObject:asResult];
    }
  }
  results_ = [appleScriptResults retain];
  if (handler_) {
    // Call back into our script to tell them we are done.
    // Our inheritence chain should all be set up correctly above.
    // QSBS and ReRe are the codes from our sdef for the
    // received results command.
    NSAppleEventDescriptor *event =
      [[[NSAppleEventDescriptor alloc] initWithEventClass:'QSBS'
                                                  eventID:'ReRe'
                                         targetDescriptor:returnAddress_
                                                 returnID:kAutoGenerateReturnID
                                            transactionID:kAnyTransactionID]
       autorelease];
    NSAppleEventDescriptor *aeResults = [results_ gtm_appleEventDescriptor];
    [event setDescriptor:aeResults forKeyword:keyDirectObject];
    HGSTokenizedString *tokenString
      = [[queryController_ query] tokenizedQueryString];
    NSString *query = [tokenString originalString];
    NSAppleEventDescriptor *aeQuery = [query gtm_appleEventDescriptor];
    [event setDescriptor:aeQuery forKeyword:'Fore'];
    NSDictionary *error = nil;
    [handler_ gtm_executeAppleEvent:event error:&error];
    if (error) {
      HGSLog(@"Unable to execute script handler \"results received for '%@'\"."
             @"\n%@", query, error);
    }
    [self release];
  }
}

- (void)dealloc {
  [queryController_ release];
  [handler_ release];
  [results_ release];
  [returnAddress_ release];
  [super dealloc];
}

@end

@implementation NSAppleScript (GTMNSAppleScriptConversion)

+ (NSAppleScript *)scriptingScriptWithDescriptor:(NSAppleEventDescriptor *)desc {
  return [desc gtm_objectValue];
}

@end

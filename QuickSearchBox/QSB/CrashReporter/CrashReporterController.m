//  Copyright (c) 2010 Google Inc. All rights reserved.
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
//  Portions Copyright (c) 2004 Claus Broch, Infinite Loop. All rights reserved.


#import <asl.h>
#import <fcntl.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>
#import "CrashReporterController.h"

@interface CrashReporterController()
- (void)setupLocalizedFields;
- (NSString*)gatherConsoleLogForApplication:(NSString*)appName
                              withProcessID:(NSInteger)processID;
- (NSString*)pathToCrashLogForApplication:(NSString*)appName;
- (NSString*)rawCrashLog:(NSString*)appName;
@end

@implementation CrashReporterController

- (void)prepareReportForApplication:(NSString*)appName
                            process:(NSInteger)processID
                        companyName:(NSString*)companyName {
  //Make sure window is loaded from nib
  NSWindow *win = [self window];

  [self setupLocalizedFields];

  [[reportsTabView_ tabViewItemAtIndex:
    [reportsTabView_ indexOfTabViewItemWithIdentifier:@"crashreport"]]
    setLabel:NSLocalizedString(@"Crash Report", @"Crash log header")];
  NSString *crashLog = [self rawCrashLog:appName];
  [crashLogTextView_ setString:(crashLog ? crashLog : @"")];

  [[reportsTabView_ tabViewItemAtIndex:
    [reportsTabView_ indexOfTabViewItemWithIdentifier:@"consolelog"]]
    setLabel:NSLocalizedString(@"Console Log", @"Console log header")];
  NSString *consoleLog = [self gatherConsoleLogForApplication:appName
                                                withProcessID:processID];
  [consoleLogTextView_ setString:(consoleLog ? consoleLog : @"")];

  NSString *buttonText = [NSString stringWithFormat:
    NSLocalizedString(@"Send to %@",
                      @"Send to #COMPANY# button text"), companyName];
  [submitButton_ setTitle:buttonText];
  NSRect originalframe = [submitButton_ frame];
  CGFloat x = NSMaxX(originalframe);
  [submitButton_ sizeToFit];
  NSRect newFrame = [submitButton_ frame];
  CGFloat xOffset = x - NSMaxX(newFrame);
  newFrame.origin.x += xOffset;
  [submitButton_ setFrameOrigin:newFrame.origin];

  buttonText = NSLocalizedString(@"Cancel", @"Button Title");
  [cancelButton_ setTitle:buttonText];
  originalframe = [cancelButton_ frame];
  x = NSMaxX(originalframe);
  [cancelButton_ sizeToFit];
  newFrame = [cancelButton_ frame];
  newFrame.origin.x += xOffset + x - NSMaxX(newFrame);
  [cancelButton_ setFrameOrigin:newFrame.origin];

  NSString *windowTitle
    = [NSString stringWithFormat:NSLocalizedString(@"Crash report for \"%@\"",
                                                   @"Crash report window title"),
       appName];
  [win setTitle:windowTitle];

  [win setLevel:NSModalPanelWindowLevel];
  [win center];
  [win makeKeyAndOrderFront:self];
}

- (IBAction)submitReport:(id)sender {
  if ([delegate_ respondsToSelector:@selector(userDidSubmitCrashReport:)]) {
    NSLog(@"Submitted to %@", delegate_);
    NSString *userNotes = [descriptionTextView_ string];
    NSString *crashLog = [crashLogTextView_ string];
    NSString *consoleLog = [consoleLogTextView_ string];
    NSDictionary *report = [NSDictionary dictionaryWithObjectsAndKeys:
                            userNotes, @"notes",
                            crashLog, @"crashlog",
                            consoleLog, @"consolelog",
                            nil];

    [delegate_ userDidSubmitCrashReport:report];
    hasSubmittedReport_ = YES;
  }

  [[self window] performClose:self];
}

- (void)windowWillClose:(NSNotification *)notification {
  if (!hasSubmittedReport_) {
    if ([delegate_ respondsToSelector:@selector(userDidCancelCrashReport)]) {
      [delegate_ userDidCancelCrashReport];
    }
  }
}

- (NSString*)versionStringForApplication:(NSString*)appName {
  NSString* crashLog = [self rawCrashLog:appName];
  if (crashLog == nil) return nil;

  NSRange rangeForVersionField = [crashLog rangeOfString:@"\nVersion: "];
  if (rangeForVersionField.location == NSNotFound) return nil;

  NSUInteger indexOfVersionFieldValueStart = NSMaxRange(rangeForVersionField);

  NSRange endOfLineSearchRange
    = NSMakeRange(indexOfVersionFieldValueStart,
                  [crashLog length] - indexOfVersionFieldValueStart);
  if (NSMaxRange(endOfLineSearchRange) > [crashLog length]) return nil;

  NSUInteger indexOfVersionFieldValueEndOfLine
    = [crashLog rangeOfString:@"\n"
                      options:0
                        range:endOfLineSearchRange].location;
  if (indexOfVersionFieldValueEndOfLine == NSNotFound) return nil;

  NSRange versionFieldValueRange
    = NSMakeRange(indexOfVersionFieldValueStart,
                  indexOfVersionFieldValueEndOfLine - indexOfVersionFieldValueStart);

  return [crashLog substringWithRange:versionFieldValueRange];
}

- (void)setupLocalizedFields {
  [descriptionHeader_ setStringValue:
    NSLocalizedString(@"Problem Description:", @"Description header")];
  [descriptionTextView_ setString:
    NSLocalizedString(@"Please describe the circumstances leading to the crash "
                      @"and any other relevant information:\n\n",
                      @"Description text")];
  [descriptionTextView_ selectAll:nil];
}

- (NSString*)pathToCrashLogForApplication:(NSString*)appName {
  NSFileManager* fileManager = [NSFileManager defaultManager];

  NSArray* libraryArray
    = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                          NSUserDomainMask | NSLocalDomainMask,
                                          YES);
  NSString* appNameWithUnderscoreSuffix = [appName stringByAppendingString:@"_"];

  NSString* leopardCrashLogLocation = nil;
  NSDate* latestCrashLogModificationDate = [NSDate distantPast];

  for (NSString *libraryPath in libraryArray) {
    NSString *directoryToSearchForCrashLog
      = [libraryPath stringByAppendingPathComponent:@"Logs/CrashReporter"];

    NSError *error = nil;
    NSArray *files
      = [fileManager contentsOfDirectoryAtPath:directoryToSearchForCrashLog
                                         error:&error];
    for (NSString *filename in files) {
      if (![filename hasPrefix:appNameWithUnderscoreSuffix]) continue;

      NSString* fullPathFilename
        = [directoryToSearchForCrashLog stringByAppendingPathComponent:filename];
      NSDictionary *attributes
        = [fileManager attributesOfItemAtPath:fullPathFilename
                                        error:&error];
      NSDate* fileModificationDate
        = [attributes objectForKey:NSFileModificationDate];
      if ([latestCrashLogModificationDate compare:fileModificationDate]
          == NSOrderedAscending) {
        leopardCrashLogLocation = fullPathFilename;
        latestCrashLogModificationDate = fileModificationDate;
      }
    }
  }
  return leopardCrashLogLocation;
}

- (NSString*)gatherConsoleLogViaAppleSystemLogger:(NSString*)applicationName
                                         fromDate:(NSDate*)date {
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  if (query == NULL) return nil;

  uint32_t senderQueryOptions
    = ASL_QUERY_OP_EQUAL | ASL_QUERY_OP_CASEFOLD|ASL_QUERY_OP_SUBSTRING;
  int aslSetSenderQueryReturnCode = asl_set_query(query,
                                                  ASL_KEY_SENDER,
                                                  [applicationName UTF8String],
                                                  senderQueryOptions);
  if (aslSetSenderQueryReturnCode != 0) return nil;

  char oneHourAgo[64];
  size_t timeBufferLength = sizeof(oneHourAgo)/sizeof(oneHourAgo[0]);
  snprintf(oneHourAgo, timeBufferLength, "%0lf", [date timeIntervalSince1970]);
  int aslSetTimeQueryReturnCode = asl_set_query(query,
                                                ASL_KEY_TIME,
                                                oneHourAgo,
                                                ASL_QUERY_OP_GREATER_EQUAL);
  if (aslSetTimeQueryReturnCode != 0) return nil;

  aslresponse response = asl_search(NULL, query);

  NSMutableString* searchResults = [NSMutableString string];
  for (;;) {
    aslmsg message = aslresponse_next(response);
    if (message == NULL) break;

    const char* aslTime = asl_get(message, ASL_KEY_TIME);
    if (time == NULL) continue;

    const char* level = asl_get(message, ASL_KEY_LEVEL);
    if (level == NULL) continue;

    const char* messageText = asl_get(message, ASL_KEY_MSG);
    if (messageText == NULL) continue;

    NSCalendarDate* aslDate
      = [NSCalendarDate dateWithTimeIntervalSince1970:atof(aslTime)];

    [searchResults appendFormat:@"%@[%s]: %s\n", aslDate, level, messageText];
  }

  aslresponse_free(response);

  return searchResults;
}

- (NSString*)gatherConsoleLogForApplication:(NSString*)appName
                              withProcessID:(NSInteger)processID {
  NSDate *oneHourAgo = [[NSCalendarDate calendarDate] dateByAddingYears:0
                                                                 months:0
                                                                   days:0
                                                                  hours:(-1)
                                                                minutes:0
                                                                seconds:0];
  NSString *consoleLog = [self gatherConsoleLogViaAppleSystemLogger:appName
                                                           fromDate:oneHourAgo];
  return consoleLog;
}

- (NSString*)rawCrashLog:(NSString*)appName {
  NSString* crashLogPath = [self pathToCrashLogForApplication:appName];
  if (!crashLogPath) {
    NSLog(@"Could not find crashlog for %@", appName);
    return NSLocalizedString(@"Could not locate crash report.", @"Missing crash report");
  }

  NSError *error = nil;
  NSString* crashLog = [NSString stringWithContentsOfFile:crashLogPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&error];
  if (!crashLog)
  {
    NSLog(@"Could not load crashlog: %@", crashLogPath);
  }
  return crashLog;
}

@end


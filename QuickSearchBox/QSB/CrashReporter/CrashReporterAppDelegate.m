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


#import "CrashReporterAppDelegate.h"
#import "GTMDefines.h"

#include "asl.h"

#include <unistd.h>
#include <sys/sysctl.h>

@interface CrashReporterAppDelegate()
- (void)watchForAppleCrashNotification;
- (void)appTerminated:(NSNotification *)notification;
- (void)displayCrashNotificationForProcess:(NSString*)processName;
- (void)serviceCrashAlert;
- (NSData *)formDataForString:(NSString *)string
                         name:(NSString *)name
                     boundary:(NSString *)boundary;
@end

@implementation CrashReporterAppDelegate

- (void)dealloc {
  [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
  [processName_ release];
  [companyName_ release];
  [postURL_ release];
  [userInfo_ release];
  [super dealloc];
}

- (NSData *)formDataForString:(NSString *)string
                         name:(NSString *)name
                     boundary:(NSString *)boundary {
  if (!string || !name || !boundary) return nil;
  NSMutableString *mutable = [[string mutableCopy] autorelease];
  [mutable replaceOccurrencesOfString:boundary
                           withString:@"USED_TO_BE_BOUNDARY"
                              options:0
                                range:NSMakeRange(0, [string length])];
  NSString *fullString
    = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; "
       @"name=\"%@\"\r\n\r\n%@\r\n", boundary, name, string];
  return [fullString dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)userDidSubmitCrashReport:(NSDictionary*)report {
  NSString *boundary = @"0xKhTmLbOuNdArY";
  NSMutableURLRequest *postRequest
    = [NSMutableURLRequest requestWithURL:postURL_];
  [postRequest setHTTPMethod: @"POST"];
  NSString *contentType
    = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
  [postRequest setValue:contentType forHTTPHeaderField: @"Content-Type"];
  NSString *agent = [[NSBundle mainBundle] bundleIdentifier];
  [postRequest setValue: agent forHTTPHeaderField: @"User-Agent"];

  NSMutableData *crashReportData = [NSMutableData data];

  for (NSString *key in [report allKeys]) {
    NSData *data = [self formDataForString:[report objectForKey:key]
                                      name:key
                                  boundary:boundary];
    if (data) {
      [crashReportData appendData:data];
    }
  }
  NSData *terminator = [[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary]
                        dataUsingEncoding:NSUTF8StringEncoding];
  [crashReportData appendData:terminator];

  NSString *contentLength
    = [NSString stringWithFormat:@"%lu", [crashReportData length]];
  [postRequest setValue:contentLength forHTTPHeaderField:@"Content-Length"];
  [postRequest setHTTPBody:crashReportData];
  [NSURLConnection connectionWithRequest:postRequest delegate:self];
}

-(void)showFinishedMessage:(NSError*)error {
  if (error) {
    [[NSAlert alertWithError:error] runModal];
  }
  [NSApp terminate:nil];
}

-(void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error {
  [self performSelectorOnMainThread:@selector(showFinishedMessage:)
                         withObject:error
                      waitUntilDone:NO];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)conn {
  [self connection:conn didFailWithError:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];

  processToWatch_ = [defaults integerForKey:@"pidToWatch"];
  companyName_ = [[defaults stringForKey:@"company"] copy];

  NSString *url = [defaults stringForKey:@"url"];
  if ((processToWatch_ == 0) || (!url)) {
    [NSApp terminate:nil];
  }
  postURL_ = [[NSURL alloc] initWithString:url];
  userInfo_ = [[defaults stringForKey:@"userInfo"] copy];

  NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
  [nc addObserver:self
         selector:@selector(appTerminated:)
             name:NSWorkspaceDidTerminateApplicationNotification
           object:nil];
}

- (void)displayCrashNotificationForProcess:(NSString*)processName {
  NSString  *title;
  NSString  *message;
  NSString  *button1;
  NSString  *button2;

  title
    = [NSString stringWithFormat:NSLocalizedString(@"The application %@ has "
                                                   @"unexpectedly quit.",
                                                   @"App crash title"),
       processName];
  message
    = [NSString stringWithFormat:NSLocalizedString(@"The system and other "
                                                   @"applications have not "
                                                   @"been affected.\n\nWould "
                                                   @"you like to submit a bug "
                                                   @"report to %@?",
                                                   @"App crash message"),
       companyName_];
  button1 = NSLocalizedString(@"Cancel", @"Button title");
  button2 = NSLocalizedString(@"Submit Report...", @"Button title");
  alertPanel_ = NSGetInformationalAlertPanel(title,
                                             message,
                                             button1,
                                             nil,
                                             button2);
  if (alertPanel_) {
    alertSession_ = [NSApp beginModalSessionForWindow:alertPanel_];
    [alertPanel_ setLevel:NSStatusWindowLevel];
    [alertPanel_ makeKeyAndOrderFront:self];

    [self serviceCrashAlert];
  }
}

- (void)serviceCrashAlert {
  NSInteger response = [NSApp runModalSession:alertSession_];
  if (response == NSRunContinuesResponse) {
    [self performSelector:@selector(serviceCrashAlert)
               withObject:nil
               afterDelay:0.05];
  } else {
    [NSApp endModalSession:alertSession_];
    NSReleaseAlertPanel(alertPanel_);
    alertPanel_ = nil;

    if (response == NSAlertOtherReturn) {
      [reportController_ prepareReportForApplication:processName_
                                             process:processToWatch_
                                         companyName:companyName_];
    } else {
      [NSApp terminate:nil];
    }
  }
}

- (void)watchForAppleCrashNotification {
  static int noOfRuns = 0;
  static BOOL displayedOurCrashNotification = NO;

  if (!displayedOurCrashNotification) {
    aslmsg query = asl_new(ASL_TYPE_QUERY);
    if (!query) {
      _GTMDevLog(@"asl_new failed");
      return;
    }

    int err
      = asl_set_query(query, ASL_KEY_SENDER,"ReportCrash", ASL_QUERY_OP_EQUAL);
    if (err) {
      _GTMDevLog(@"asl_set_query failed (%d)", err);
      return;
    }

    NSTimeInterval currTime = [[NSDate date ]timeIntervalSince1970] - 10;
    const char *timeString = [[NSString stringWithFormat:@"%lf", currTime]
                              UTF8String];
    err = asl_set_query(query,
                        ASL_KEY_TIME,
                        timeString,
                        ASL_QUERY_OP_GREATER_EQUAL);
    if (err) {
      _GTMDevLog(@"asl_set_query failed (%d)", err);
      return;
    }

    aslresponse response = asl_search(NULL, query);

    aslmsg lastMessage = NULL;
    for (;;) {
      aslmsg nextMessage = aslresponse_next(response);

      if (!nextMessage) {
        break;
      } else {
        lastMessage = nextMessage;
      }
    }

    const char *messageText = asl_get(lastMessage, ASL_KEY_MSG);
    const char *kSavedCrashReportTo = "Saved crashreport to";
    const char *kSavedCrashReportFor = "Saved crash report for";
    if (messageText &&
       ((strncmp(messageText,
                 kSavedCrashReportTo,
                 strlen(kSavedCrashReportTo)) == 0)
        || (strncmp(messageText,
                    kSavedCrashReportFor,
                    strlen(kSavedCrashReportFor)) == 0))) {
      [self displayCrashNotificationForProcess:processName_];

      displayedOurCrashNotification = YES;
    }
    aslresponse_free(response);
  }

  if (!displayedOurCrashNotification && (noOfRuns++ < 10)) {
    [self performSelector:@selector(watchForAppleCrashNotification)
               withObject:nil
               afterDelay:((NSTimeInterval)noOfRuns / 5.0) - 0.2];
  } else {
    if (!displayedOurCrashNotification) {
      [NSApp terminate:self];
    }
  }
}

- (void)appTerminated:(NSNotification *)notification {
  NSDictionary *info = [notification userInfo];
  NSNumber *pid = [info objectForKey:@"NSApplicationProcessIdentifier"];
  if (pid && ([pid intValue] == processToWatch_)) {
    NSString *path = [info objectForKey:@"NSApplicationPath"];
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    processName_ = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!processName_) {
      processName_ = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    }
    [processName_ retain];

    [self watchForAppleCrashNotification];
  }
}

@end

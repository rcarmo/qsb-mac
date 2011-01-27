//
//  HGSGDataAction.m
//
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

#import "HGSGDataUploadAction.h"

#import <GData/GData.h>

#import "HGSBundle.h"
#import "HGSKeychainItem.h"
#import "HGSLog.h"
#import "HGSResult.h"
#import "HGSSimpleAccount.h"
#import "HGSType.h"

static NSString *const kHGSGDataUploadActionAttemptNumberKey
  = @"kHGSGDataUploadActionAttemptNumberKey";

// User Message Names
static NSString *const kGDataUploadUserMessageName
  = @"kGDataUploadUserMessageName";

// The maximum number of times an upload will be attempted.
static NSUInteger const kMaxUploadAttempts = 3;

// Upload timing constants.
static const NSTimeInterval kUploadRetryInterval = 0.1;
static const NSTimeInterval kUploadGiveUpInterval = 30.0;
static const NSTimeInterval kMaxUploadRetryDelay = 120;


@interface HGSGDataUploadAction ()

// Bottleneck function for retrying the upload a single doc.
- (void)retryUploadGDataEntry:(GDataEntryBase *)dataEntry;
- (void)loginCredentialsChanged:(NSNotification *)notification;
- (void)uploadFileTicket:(GDataServiceTicket *)ticket
       finishedWithEntry:(GDataEntryDocBase *)dataEntry
                   error:(NSError *)error;
@end


@implementation HGSGDataUploadAction

@synthesize account = account_;
@synthesize uploadService = uploadService_;
@synthesize userWasNoticed = userWasNoticed_;
@synthesize bytesSent = bytesSent_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    if (account_) {
      // Watch for credential changes.
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver:self
             selector:@selector(loginCredentialsChanged:)
                 name:kHGSAccountDidChangeNotification
               object:account_];
      // Keep track of active tickets so we can cancel them if necessary.
      activeTickets_ = [[NSMutableSet set] retain];
    } else {
      HGSLogDebug(@"Missing account identifier for %@ '%@'",
                  [self class], [self identifier]);
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self cancelAllTickets];
  [activeTickets_ release];
  [uploadService_ release];
  [account_ release];
  [super dealloc];
}

- (void)uploadGDataEntry:(GDataEntryBase *)dataEntry
              entryTitle:(NSString *)entryTitle
                    item:(NSUInteger)item
                      of:(NSUInteger)count {
  GDataServiceGoogle *uploadService = [self uploadService];
  NSURL *uploadURL = [self uploadURL];
  HGSAssert(uploadURL, nil);

  // Run the upload on our thread. Sleep for a second and then check
  // to see if an upload has completed or if we've recorded some progress
  // in an upload byte-wise.  Give up if there has been no progress for
  // a while.
  NSTimeInterval endTime
    = [NSDate timeIntervalSinceReferenceDate] + kUploadGiveUpInterval;
  NSRunLoop* loop = [NSRunLoop currentRunLoop];
  GDataServiceTicket *uploadTicket
    = [uploadService fetchEntryByInsertingEntry:dataEntry
                                     forFeedURL:uploadURL
                                       delegate:self
                              didFinishSelector:@selector(uploadFileTicket:
                                                          finishedWithEntry:
                                                          error:)];
  [uploadTicket setUserData:entryTitle];
  [uploadTicket retain];
  @synchronized (activeTickets_) {
    [activeTickets_ addObject:uploadTicket];
  }

  // Let the user know that the upload has started, but only for the first item.
  if (item == 0) {
    NSString *formattedString = nil;
    if (count == 1) {
      NSString *format
        = HGSLocalizedString(@"Uploading '%@'.",
                             @"A message explaining to the user that a "
                             @"file is being uploaded. %@ is the display "
                             @"name of the file that is being uploaded.");
      formattedString
        = [NSString stringWithFormat:format, entryTitle];
    } else {
      NSString *format
        = HGSLocalizedString(@"Uploading '%1$@' (the first of %2$d).",
                             @"A message explaining to the user that a "
                             @"file is being uploaded. %1$@ is the display "
                             @"name of the file that is being uploaded. "
                             @"%2$d us the total number of files to be "
                             @"uploaded.");
      formattedString = [NSString stringWithFormat:format, entryTitle, count];
    }
    [self informUserWithDescription:formattedString
                               type:kHGSUserMessageNoteType];
  }

  unsigned long long lastBytesSent = 0;
  do {
    // Reset endTime if some progress occurred.  While |bytesSent| may be
    // shared between threads we don't care because we just care that it
    // has changed.
    unsigned long long bytesSent = [self bytesSent];
    if (lastBytesSent != bytesSent) {
      endTime
        = [NSDate timeIntervalSinceReferenceDate] + kUploadGiveUpInterval;
      lastBytesSent = bytesSent;
    }
    NSDate *sleepTilDate
      = [NSDate dateWithTimeIntervalSinceNow:kUploadRetryInterval];
    [loop runUntilDate:sleepTilDate];
    if ([NSDate timeIntervalSinceReferenceDate] > endTime) {
      [uploadTicket cancelTicket];
      @synchronized (activeTickets_) {
        [activeTickets_ removeObject:uploadTicket];
      }
      NSString *errorString
        = HGSLocalizedString(@"Upload of '%@' timed out. Please "
                             @"check your connection to the Internet.",
                             @"A message explaining that the file, identified "
                             @"by %@, could not be uploaded because it was "
                             @"taking too long.");
      errorString = [NSString stringWithFormat:errorString, entryTitle];
      [self informUserWithDescription:errorString
                                 type:kHGSUserMessageErrorType];
      HGSLog(@"HGSGDataUploadAction timed out uploading '%@' to "
             @"account '%@'.", entryTitle, [account_ displayName]);
    }
  } while ([activeTickets_ containsObject:uploadTicket]);
  [uploadTicket release];
}

- (void)retryUploadGDataEntry:(GDataEntryBase *)dataEntry {
  NSURL *uploadURL = [self uploadURL];
  HGSAssert(uploadURL, nil);
  GDataServiceGoogle *uploadService = [self uploadService];
  GDataServiceTicket *uploadTicket
    = [uploadService fetchEntryByInsertingEntry:dataEntry
                                     forFeedURL:uploadURL
                                       delegate:self
                              didFinishSelector:@selector(uploadFileTicket:
                                                          finishedWithEntry:
                                                          error:)];
  @synchronized (activeTickets_) {
    [activeTickets_ addObject:uploadTicket];
  }
}

- (void)uploadFileTicket:(GDataServiceTicket *)ticket
       finishedWithEntry:(GDataEntryDocBase *)dataEntry
                   error:(NSError *)error {
  @synchronized (activeTickets_) {
    [activeTickets_ removeObject:ticket];
  }

  // Can't use title from dataEntry because if we have an error, dataEntry
  // is nil.
  NSString *title = [ticket userData];
  if (!error) {
    // Only notify the user for the first success.
    if (![self userWasNoticed]) {
      [self setUserWasNoticed:YES];
      NSString *format
        = HGSLocalizedString(@"'%@' has been uploaded.",
                             @"A message explaining to the user that a "
                             @"file was successfully uploaded to the user's "
                             @"Google Docs. %@ is the display name of the "
                             @"file that was uploaded.");
      NSString *successString
        = [NSString stringWithFormat:format, title, [self serviceName]];
      [self informUserWithDescription:successString
                                 type:kHGSUserMessageNoteType];
    }
  } else {
    // Except in the case of a serious error, we will retry a limited number
    // of times before giving up. For serious errors we give up immediately.
    NSNumber *attemptNumber
      = [dataEntry propertyForKey:kHGSGDataUploadActionAttemptNumberKey];
    NSUInteger attempt = [attemptNumber unsignedIntValue];
    NSInteger errorCode = [error code];
    // A 400 (HTTP_BAD_REQUEST) is considered serious. It could be because
    // the item being uploaded is too large.
    if (errorCode != 400 && attempt < kMaxUploadAttempts) {
      attemptNumber = [NSNumber numberWithUnsignedInteger:++attempt];
      [dataEntry setProperty:attemptNumber
                      forKey:kHGSGDataUploadActionAttemptNumberKey];

      // Get retry time in seconds from the response header.
      NSDictionary *responseHeaders = [[ticket currentFetcher] responseHeaders];
      NSString *retryStr = [responseHeaders objectForKey:@"Retry-After"];
      NSTimeInterval delay = [retryStr intValue];
      // If the retry time wasn't in the headers or was unreasonable, use
      // a default delay.
      if (delay <= 0 || delay >= kMaxUploadRetryDelay) {
        delay = (NSTimeInterval)(2 << attempt);
      }

      GDataServiceGoogle *uploadService = [self uploadService];
      NSArray *modes = [uploadService runLoopModes];
      if (modes) {
        [self performSelector:@selector(retryUploadGDataEntry:)
                   withObject:dataEntry
                   afterDelay:delay
                      inModes:modes];
      }
      else {
        [self performSelector:@selector(retryUploadGDataEntry:)
                   withObject:dataEntry
                   afterDelay:delay];
      }
    } else {
      NSString *errorFormat
        = HGSLocalizedString(@"Could not upload '%1$@'. \"%2$@\" (%3$d)",
                             @"A message explaining to the user that we "
                             @"could not upload a file. %1$@ is the name "
                             @"of the file to be uploaded.  %2$@ is the error "
                             @"description. %3$d is the error code.");
      NSString *errorString = [NSString stringWithFormat:errorFormat,
                               title, [error localizedDescription], errorCode];
      [self informUserWithDescription:errorString
                                 type:kHGSUserMessageErrorType];
      HGSLog(@"GoogleDocsUploadAction upload of image '%@' to account '%@' "
             @"failed: error=%d '%@'.", title, [account_ displayName],
             errorCode, [error localizedDescription]);
    }
  }
}

- (void)inputStream:(GDataProgressMonitorInputStream *)stream
          bytesSent:(unsigned long long)bytesSent
         totalBytes:(unsigned long long)totalBytes {
  [self setBytesSent:bytesSent];
}

#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount *)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  [self reset];
  return YES;
}

#pragma mark Utility Methods

- (GDataServiceGoogle *)uploadService {
  HGSSimpleAccount *account = [self account];
  if (!uploadService_) {
    HGSKeychainItem* keychainItem
      = [HGSKeychainItem keychainItemForService:[account identifier]
                                       username:nil];
    NSString *username = [keychainItem username];
    NSString *password = [keychainItem password];
    if ([username length]) {
      GDataServiceGoogle *uploadService
        = [[[[self serviceClass] alloc] init] autorelease];
      [uploadService setUserCredentialsWithUsername:username
                                           password:password];
      [uploadService setUserAgent:@"google-qsb-1.0"];
      [uploadService setShouldCacheDatedData:YES];
      [uploadService setServiceShouldFollowNextLinks:YES];
      [uploadService setIsServiceRetryEnabled:YES];
      SEL progressSel = @selector(inputStream:bytesSent:totalBytes:);
      [uploadService setServiceUploadProgressSelector:progressSel];
      uploadService_ = [uploadService retain];
    }
  }
  if (!uploadService_) {
    NSString *errorString
      = HGSLocalizedString(@"Could not perform upload. Please check the "
                           @"password for account '%@'.",
                           @"A message explaining that the user could "
                           @"not upload Picasa Web images due to a bad "
                           @"password for account %@.");
    errorString = [NSString stringWithFormat:errorString,
                   [account identifier]];
    [self informUserWithDescription:errorString
                               type:kHGSUserMessageErrorType];
    HGSLog(@"PicasaWebUploadAction upload to account '%@' failed due "
           @"to missing keychain item.", [account displayName]);
  }
  return uploadService_;
}

- (NSURL *)uploadURL {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (Class)serviceClass {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSString *)serviceName {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSImage *)serviceIcon {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)reset {
  // Halt any outstanding uploads and reset the service.
  [self cancelAllTickets];
  [uploadService_ release];
  uploadService_ = nil;
}

- (void)cancelAllTickets {
  @synchronized (activeTickets_) {
    for (GDataServiceTicket *ticket in activeTickets_) {
      [ticket cancelTicket];
    }
    [activeTickets_ removeAllObjects];
  }
}

- (void)loginCredentialsChanged:(NSNotification *)notification {
  HGSAssert([notification object] == account_,
            @"Notification from bad account!");
  [self reset];
}

- (void)informUserWithDescription:(NSString *)description
                             type:(HGSUserMessageType)type {
  NSImage *docIcon = [self serviceIcon];
  NSString *summary
    = HGSLocalizedString(@"Upload to %@",
                         @"A dialog title. %@ is replaced by a product name.");
  summary = [NSString stringWithFormat:summary, [self serviceName]];
  [HGSUserMessenger displayUserMessage:summary
                           description:description
                                  name:kGDataUploadUserMessageName
                                 image:docIcon
                                  type:type];
}

+ (NSString *)mimeTypeForResult:(HGSResult *)result {
  NSString *mimeType = nil;
  if (result) {
    // See if we can get the MIME type for one of the standard extensions.
    NSString *resultPath = [result filePath];
    NSString *extension = [resultPath pathExtension];
    if ([extension length]) {
      NSDictionary *extensionMap
        = [NSDictionary dictionaryWithObjectsAndKeys:
           @"application/msword", @"doc",
           @"application/pdf", @"pdf",
           @"application/rtf", @"rtf",
           @"application/vnd.ms-excel", @"xls",
           @"application/vnd.ms-powerpoint", @"pps",
           @"application/vnd.ms-powerpoint", @"ppt",
           @"application/vnd.oasis.opendocument.spreadsheet", @"ods",
           @"application/vnd.oasis.opendocument.text", @"odt",
           @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @"xlsx",
           @"application/vnd.openxmlformats-officedocument.wordprocessingml.document", @"docx",
           @"application/vnd.sun.xml.writer", @"sxw",
           @"image/bmp", @"bmp",
           @"image/gif", @"gif",
           @"image/jpeg", @"jpe",
           @"image/jpeg", @"jpeg",
           @"image/jpeg", @"jpg",
           @"image/png", @"png",
           @"text/csv", @"csv",
           @"text/html", @"htm",
           @"text/html", @"html",
           @"text/plain", @"txt",
           @"text/tab-separated-values", @"tab",
           @"text/tab-separated-values", @"tsv",
           @"video/3gpp", @"3g2",
           @"video/3gpp", @"3gp",
           @"video/3gpp", @"3gpp",
           @"video/avi", @"avi",
           @"video/mp4", @"mp4",
           @"video/mpeg", @"m4v",
           @"video/mpeg", @"mpeg",
           @"video/mpeg", @"mpg",
           @"video/quicktime", @"mov",
           @"video/quicktime", @"qt",
           @"video/x-ms-asf", @"asf",
           @"video/x-ms-wmv", @"wmv",
           nil];
      mimeType = [extensionMap objectForKey:extension];
    }
    // See if we can get a MIME type using the GData utility.
    if (!mimeType) {
      mimeType = [GDataUtilities MIMETypeForFileAtPath:resultPath
                                       defaultMIMEType:nil];
    }
    // Finally, translate using the result type.
    // NOTE: This lookup only useful for text document types at this time.
    // Feel free to extend this dictionary if you desire.
    if (!mimeType) {
      NSString *resultType = [result type];
      NSDictionary *resultTypeMap
        = [NSDictionary dictionaryWithObjectsAndKeys:
           @"text/plain", kHGSTypeTextFile,
           @"application/pdf", kHGSTypeFilePDF,
           nil];
      mimeType = [resultTypeMap objectForKey:resultType];
    }
  }
  return mimeType;
}

+ (Class)dataEntryClassForMIMEType:(NSString *)mimeType {
  Class gDataEntryClass = nil;
  if (mimeType) {
    NSDictionary *mimeTypeMap
      = [NSDictionary dictionaryWithObjectsAndKeys:
         @"GDataEntryPDFDoc", @"application/pdf",
         @"GDataEntryPresentationDoc", @"application/vnd.ms-powerpoint",
         @"GDataEntrySpreadsheetDoc", @"application/vnd.ms-excel",
         @"GDataEntrySpreadsheetDoc", @"application/vnd.oasis.opendocument.spreadsheet",
         @"GDataEntrySpreadsheetDoc", @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         @"GDataEntryStandardDoc", @"application/msword",
         @"GDataEntryStandardDoc", @"application/rtf",
         @"GDataEntryStandardDoc", @"application/vnd.oasis.opendocument.text",
         @"GDataEntryStandardDoc", @"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         @"GDataEntryStandardDoc", @"application/vnd.sun.xml.writer",
         @"GDataEntryStandardDoc", @"image/bmp",
         @"GDataEntryStandardDoc", @"image/gif",
         @"GDataEntryStandardDoc", @"image/jpeg",
         @"GDataEntryStandardDoc", @"image/png",
         @"GDataEntryStandardDoc", @"text/csv",
         @"GDataEntryStandardDoc", @"text/html",
         @"GDataEntryStandardDoc", @"text/plain",
         @"GDataEntryStandardDoc", @"text/tab-separated-values",
         nil];
    NSString *className = [mimeTypeMap objectForKey:mimeType];
    gDataEntryClass = NSClassFromString(className);
  }
  return gDataEntryClass;
}

@end

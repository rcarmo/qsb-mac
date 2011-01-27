//
//  HGSUserMessage.h
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

#import <Foundation/Foundation.h>

/*!
 @header
 @discussion HGSUserMessage
*/

/*!
 @enum HGSUserMessageType
 @constant kHGSUserMessageErrorType Display as error
 @constant kHGSUserMessageWarningType Display as warning
 @constant kHGSUserMessageNoteType Display as notification
 */
enum  {
  kHGSUserMessageErrorType = 1,
  kHGSUserMessageWarningType = 0,
  kHGSUserMessageNoteType = -1,
};
typedef NSInteger HGSUserMessageType;

/*!
 Display a simple message to the user. The UI level decides how the message
 will actually be displayed.
*/
@interface HGSUserMessenger : NSObject
+ (void)displayUserMessage:(id)message 
               description:(id)description 
                      name:(NSString *)name
                     image:(NSImage *)image
                      type:(HGSUserMessageType)type;
+ (HGSUserMessenger *)sharedUserMessenger;

/*
 Display a simple message.
 @param message The main message to show
 @param description Optional description
 @param name The name allows external packages (eg Growl) to control how the
             message is actually displayed. Optional.
 @param image The icon displayed in the message
 @param type Whether this is a an error message, a notification etc.
*/
- (void)displayUserMessage:(id)message 
               description:(id)description 
                      name:(NSString *)name
                     image:(NSImage *)image
                      type:(HGSUserMessageType)type;
@end

/*!
 Posted by an extension for presenting a short informational message to the
 user about the success of failure of an operation that may not otherwise
 manifest itself to the user.  |userInfo| should be a dictionary containing at
 least one of kHGSPlainTextMessageKey or kHGSAttributedTextMessageKey.  Other
 items may also be specified, including those given in the next section.
 |object| should be the reporting extension.
 */
extern NSString *const kHGSUserMessageNotification;

// Extension message notification userinfo keys

/*!
 An NSString or NSAttributedString giving a very short message to be presented
 to the user. Required.
 */
extern NSString *const kHGSSummaryMessageKey;

/*!
 An NSString or NSAttributedString giving a longer, descriptive message to be
 presented to the user.  This is most valuable for suggesting remedial actions
 that the user can take or for giving additional information about the
 message. Optional.
 */
extern NSString *const kHGSDescriptionMessageKey;

/*!
 An NSString that is the name of the notification displayed to the user.
 Optional. Does not need to be localized.
*/
extern NSString *const kHGSNameMessageKey;

/*!
 An NSImage that can be used to give additional context to the message
 presentation.  This is typically an icon representing the service associated
 with the reporting extension. Optional.
 */
extern NSString *const kHGSImageMessageKey;

/*!
 An NSNumber containing a whole number giving a type for the message. Optional.
 */
extern NSString *const kHGSTypeMessageKey;





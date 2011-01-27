//
//  HGSGDataAction.h
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

/*!
 @header
 @discussion HGSGDataUploadAction
*/

#import <Vermilion/HGSAction.h>
#import <Vermilion/HGSAccount.h>
#import <Vermilion/HGSUserMessage.h>

@class HGSSimpleAccount;
@class GDataServiceGoogle;
@class GDataEntryBase;

/*!
 An action which supports uploading a local file to a Google site (Docs 
 and Picasaweb, for example) which requires a Google Account.
*/
@interface HGSGDataUploadAction : HGSAction <HGSAccountClientProtocol> {
 @private
  HGSSimpleAccount *account_;
  GDataServiceGoogle *uploadService_;
  NSMutableSet *activeTickets_;
  BOOL userWasNoticed_;
  UInt64 bytesSent_;
}

@property (readonly, retain) HGSSimpleAccount *account;
@property (readonly, retain) GDataServiceGoogle *uploadService;
@property (nonatomic) BOOL userWasNoticed;
@property (assign) unsigned long long bytesSent;

/*!
 Bottleneck function which performs the uploading of a single item. The
 derived class calls this function in their upload loop.
 
 @param dataEntry A concrete instantiation of a GData entry to be uploaded
        to the uploadService.
 @param entryTitle The display name of this entry; used in user messages.
 @param item The number of this item out of |count|.
 @param count The total number of items which are to be uploaded.
*/
- (void)uploadGDataEntry:(GDataEntryBase *)dataEntry
              entryTitle:(NSString *)entryTitle
                    item:(NSUInteger)item
                      of:(NSUInteger)count;

/*!
 Child class implementations must provide this method which gives the URL
 for uploading an entry to the service associated with the GData class.

 @result An URL to be used in the GData upload operation.
*/
- (NSURL *)uploadURL;

/*!
 Child class implementations must provide this method which gives the
 GDataServiceGoogle class used for creating the service by which the upload
 is performed.
 
 @result A Class which is derived from GDataServiceGoogle.
 */
- (Class)serviceClass;

/*!
 Child class implementations must provide this method which gives the localized
 user-visible name of the service to which the upload is being performed.
 
 @result A NSString.
 */
- (NSString *)serviceName;

/*!
 Child class implementations must provide this method which gives the icon
 presented in any user messages.
 
 @result A NSImage.
 */
- (NSImage *)serviceIcon;

/*! Cancel all outstanding upload operations and reset credentials. */
- (void)reset;

/*! Force all outstanding upload operations to shut down. */
- (void)cancelAllTickets;

/*!
 Utility function to send notification so user can be notified of
 success or failure of the upload attempt.
 
 @param description A brief localized string comprising the message to
        be presented to the user.
 @param type The nature of the message as described in HGSUserMessageType.
*/
- (void)informUserWithDescription:(NSString *)description
                             type:(HGSUserMessageType)type;

/*!
 Utility function for determining the MIME type for a result.
 
 @param result The HGSResult for which the MIME type is to be determined.

 @result A string giving the MIME type for the result or nil if the type
         could not be ascertained.
 */
+ (NSString *)mimeTypeForResult:(HGSResult *)result;

/*!
 Utility function for determining the specific GDataEntryClass associated
 with a MIME type.
 
 @param mimeType A string giving the MIME type for which the concrete
        GDataEntryClass is to be determined.
 
 @result A Class object that is a concrete subclass of GDataEntryClass or nil
         if the class cannot be determined.
 */
+ (Class)dataEntryClassForMIMEType:(NSString *)mimeType;

@end

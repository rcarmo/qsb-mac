//
//  HGSGDataServiceSource.h
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

/*!
 @header
 @discussion HGSGDataServiceSource
*/

#import <Vermilion/HGSMemorySearchSource.h>
#import <Vermilion/HGSAccount.h>

@class GDataServiceGoogle;
@class GDataServiceTicket;
@class HGSGDataServiceIndexContext;
@class HGSInvocationOperation;

extern NSString *const kHGSGDataServiceSourceRefreshIntervalKey;
extern NSString *const kHGSGDataServiceSourceRefreshJitterKey;
extern NSString *const kHGSGDataServiceSourceErrorReportingIntervalKey;

/*!
 A wrapper for a GDataServiceSource.
*/
@interface HGSGDataServiceSource : HGSMemorySearchSource <HGSAccountClientProtocol> {
 @private
  NSTimeInterval refreshInterval_;
  NSTimeInterval refreshJitter_;
  NSTimeInterval errorReportingInterval_;
  GDataServiceGoogle *service_;
  HGSInvocationOperation *indexOp_;
  NSTimer *updateTimer_;
  HGSAccount *account_;
  NSTimeInterval previousErrorReportingTime_;
}

@property (readonly, retain) HGSAccount *account;
@property (readonly, retain) GDataServiceGoogle *service;

- (void)setUpPeriodicRefresh;

/*!
 Utility function for reporting fetch errors.
*/
- (void)handleErrorForFetchType:(NSString *)fetchType
                          error:(NSError *)error;

- (void)ticketHandled:(GDataServiceTicket *)ticket
           forContext:(HGSGDataServiceIndexContext *)context;

// Methods to override
- (GDataServiceTicket *)fetchTicketForService:(GDataServiceGoogle *)service;
- (Class)serviceClass;

@end

/*!
 Keeps track of a GDataService indexing operation and all of its tickets.
 As long as there are tickets, the operation is valid.
*/
@interface HGSGDataServiceIndexContext : NSObject {
 @private
  NSOperation *operation_;
  NSMutableArray *tickets_;
  GDataServiceGoogle *service_;
  HGSMemorySearchSourceDB *database_;
}

@property (readonly, retain) GDataServiceGoogle *service;
@property (readonly, retain) HGSMemorySearchSourceDB *database;
/*!
 Is the operation done (either finished or cancelled).
*/
@property (readonly, assign, getter=isFinished) BOOL finished;

/*!
 Is the operation cancelled.
*/
@property (readonly, assign, getter=isCancelled) BOOL cancelled;

- (id)initWithOperation:(NSOperation *)operation
                service:(GDataServiceGoogle *)service
               database:(HGSMemorySearchSourceDB *)database;
- (void)addTicket:(GDataServiceTicket *)ticket;
- (void)removeTicket:(GDataServiceTicket *)ticket;

/*!
 Cancel outstanding tickets
*/
- (void)cancelTickets;

@end

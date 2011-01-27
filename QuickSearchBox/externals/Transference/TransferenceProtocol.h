//
//  TransferenceProtocol.h
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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

#import "TransferenceServerProtocol.h"
#import "TransferenceConstants.h"

// Constants used in the client and server
extern const unsigned short kTransferencePort;
extern const NSTimeInterval kMaxTimeout;
extern const int kProtocolVersion;

// Keys for the primary NSDictionary that will be shipped between the beacon
// and client.

// Keys for the generalStatus return dictionary
extern NSString *const kQSBVersionKey;
extern NSString *const kMacOSXVersionKey;
extern NSString *const kArchitectureTypeKey;

// Note: the unitialized value is the NSDate reference date 1 January 2001
extern NSString *const kStartupTimeKey;

// Keys for the lastSearchStats_ dictionary
extern NSString *const kSearchTimeKey;
extern NSString *const kSearchModuleTimesKey;
extern NSString *const kSearchTimeAfterRankingKey;

// Keys for the dictionaries returned by lastSearchResultsRanked
extern NSString *const kResultDisplayNameKey;
extern NSString *const kResultDisplayPathKey;
extern NSString *const kResultAvailableActionsKey;
extern NSString *const kResultActionDisplayNameKey;

// Keys for the action dictionary sent between the client and the server
extern NSString *const kActionQueryStringKey;

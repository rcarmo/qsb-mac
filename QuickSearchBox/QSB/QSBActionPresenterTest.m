//
//  QSBActionPresenterTest.m
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

#import "GTMSenTestCase.h"

#import <OCMock/OCMock.h>

#import "QSBActionPresenter.h"
#import "QSBActionModel.h"

@interface QSBActionPresenterTest : GTMTestCase {
 @private
  id actionModel_;
  QSBActionPresenter *presenter_;
}
@end

@implementation QSBActionPresenterTest

- (void)setUp {
  [super setUp];
  
  // actionModel_ gets retained by presenter_
  actionModel_ = [OCMockObject mockForClass:[QSBActionModel class]];
  STAssertNotNil(actionModel_, nil);
  [[actionModel_ expect] pushSearchController:OCMOCK_ANY];
  presenter_ = [[QSBActionPresenter alloc] initWithActionModel:actionModel_];
  STAssertNotNil(presenter_, nil);
}

- (void)tearDown {
  [presenter_ release];
  [super tearDown];
}

- (void)testCreationAndDestruction {
  // Calls init directly which calls through to our designated initializer.
  QSBActionPresenter *presenter = [[QSBActionPresenter alloc] init];
  STAssertNotNil(presenter, nil);

  // Calling release directly instead of autorelease to force destruction at 
  // this point as part of the test.
  [presenter release];
  
  // Test nil model case.
  presenter = [[[QSBActionPresenter alloc] initWithActionModel:nil] autorelease];
  STAssertNil(presenter, nil);
}

// TODO(dmaclach):Add more tests here.

@end

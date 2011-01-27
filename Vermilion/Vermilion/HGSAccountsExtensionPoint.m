//
//  HGSAccountsExtensionPoint.m
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

#import "HGSAccountsExtensionPoint.h"
#import "GTMMethodCheck.h"
#import "GTMNSEnumerator+Filter.h"
#import "HGSAccount.h"
#import "HGSAccountType.h"
#import "HGSExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSLog.h"


@implementation HGSAccountsExtensionPoint

GTM_METHOD_CHECK(NSEnumerator,
                 gtm_enumeratorByMakingEachObjectPerformSelector:withObject:);

- (void)addAccountsFromArray:(NSArray *)accountsArray {
  for (NSDictionary *accountDict in accountsArray) {
    // Upgrade the account configuration if necessary.
    accountDict = [HGSAccount upgradeConfiguration:accountDict];
    NSString *accountTypeID = [accountDict objectForKey:kHGSAccountTypeKey];
    if (accountTypeID) {
      HGSExtensionPoint *accountTypesPoint
        = [HGSExtensionPoint accountTypesPoint];
      HGSAccountType *accountType
        = [accountTypesPoint extensionWithIdentifier:accountTypeID];
      HGSProtoExtension *protoAccountType = [accountType protoExtension];
      if (protoAccountType) {
        NSString *accountClassName
          = [protoAccountType objectForKey:kHGSExtensionOfferedAccountClassKey];
        Class accountClass = NSClassFromString(accountClassName);
        HGSAccount *account = [[[accountClass alloc]
                                initWithConfiguration:accountDict]
                               autorelease];
        if (account) {
          BOOL accountAdded = [self extendWithObject:account];
          if (!accountAdded) {
            HGSLogDebug(@"Failed to add account '%@'.",  // COV_NF_LINE
                        [account displayName]);
          }
        } else {
          HGSLogDebug(@"Failed to create account of type '%@' "  // COV_NF_LINE
                      @"and class '%@'",
                      accountTypeID, accountClassName);
        }
      } else {
        HGSLogDebug(@"Proto extension not found for "  // COV_NF_LINE
                    @"accountType: %@", accountType);
      }
    } else {
      HGSLogDebug(@"Did not find account type for account "  // COV_NF_LINE
                  @"dictionary :%@", accountDict);
    }
  }
}

- (NSArray *)accountsAsArray {
  NSEnumerator *archiveAccountEnum
    = [[[self extensions] objectEnumerator]
       gtm_enumeratorByMakingEachObjectPerformSelector:@selector(configuration)
                                            withObject:nil];
  NSArray *archivableAccounts = [archiveAccountEnum allObjects];
  return archivableAccounts;
}

- (NSArray *)accountsForType:(NSString *)type {
  NSArray *array = [self extensions];
  NSPredicate *pred = [NSPredicate predicateWithFormat:@"type == %@", type];
  array = [array filteredArrayUsingPredicate:pred];
  return array;
}

@end

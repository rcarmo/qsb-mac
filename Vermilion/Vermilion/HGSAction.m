//
//  HGSAction.m
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

#import "HGSAction.h"
#import "HGSResult.h"
#import "HGSLog.h"
#import "HGSTypeFilter.h"
#import "HGSActionArgument.h"
#import "HGSActionOperation.h"

NSString *const kHGSActionDirectObjectsKey = @"HGSActionDirectObjects";
NSString *const kHGSActionDirectObjectTypesKey = @"HGSActionDirectObjectTypes";
NSString *const kHGSActionExcludedDirectObjectTypesKey
  = @"HGSActionExcludedDirectObjectTypesKey";
NSString *const kHGSActionDoesActionCauseUIContextChangeKey
  = @"HGSActionDoesActionCauseUIContextChange";
NSString *const kHGSActionMustRunOnMainThreadKey
  = @"HGSActionMustRunOnMainThread";
NSString* const kHGSActionOtherTermsKey= @"HGSActionOtherTerms";
NSString* const kHGSActionArgumentsKey = @"HGSActionArguments";
NSString *const kHGSActionWillPerformNotification 
  = @"HSGActionWillPerformNotification";
NSString *const kHGSActionDidPerformNotification 
  = @"HSGActionDidPerformNotification";
NSString *const kHGSActionCompletedSuccessfullyKey
  = @"HGSActionCompletedSuccessfully";
NSString *const kHGSActionResultsKey = @"HGSActionResults";
NSString* const kHGSActionReturnedResultsTypesKey 
  = @"HGSActionReturnedResultsTypes";
NSString* const kHGSActionExcludedReturnedResultsTypesKey
  = @"HGSActionExcludedReturnedResultsTypes";

@implementation HGSAction

@synthesize directObjectTypeFilter = directObjectTypeFilter_;
@synthesize returnedResultsTypeFilter = returnedResultsTypeFilter_;
@synthesize causesUIContextChange = causesUIContextChange_;
@synthesize mustRunOnMainThread = mustRunOnMainThread_;
@synthesize otherTerms = otherTerms_;
@synthesize arguments = arguments_;

+ (void)initialize {
  if (self == [HGSAction class]) {
#if DEBUG
    NSNumber *validateBehaviors = [NSNumber numberWithBool:YES];
#else
    NSNumber *validateBehaviors = [NSNumber numberWithBool:NO];
#endif
    NSDictionary *dict
      = [NSDictionary dictionaryWithObject:validateBehaviors
                                    forKey:kHGSValidateActionBehaviorsPrefKey];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:dict];
  }
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    
    id value = [configuration objectForKey:kHGSActionDirectObjectTypesKey];
    NSSet *directObjectTypes = [NSSet qsb_setFromId:value];
    
    value = [configuration objectForKey:kHGSActionExcludedDirectObjectTypesKey];
    NSSet *excludedDirectObjectTypes = [NSSet qsb_setFromId:value];
    if (directObjectTypes) {
      directObjectTypeFilter_ 
        = [[HGSTypeFilter alloc] initWithConformTypes:directObjectTypes 
                                  doesNotConformTypes:excludedDirectObjectTypes];
    }
 
    value = [configuration objectForKey:kHGSActionReturnedResultsTypesKey];
    NSSet *returnedResultsTypes = [NSSet qsb_setFromId:value];
    
    value = [configuration objectForKey:kHGSActionExcludedReturnedResultsTypesKey];
    NSSet *excludedReturnedResultsTypes = [NSSet qsb_setFromId:value];
    if (returnedResultsTypes) {
      returnedResultsTypeFilter_ 
        = [[HGSTypeFilter alloc] initWithConformTypes:returnedResultsTypes 
                                  doesNotConformTypes:excludedReturnedResultsTypes];
    }

    value = [configuration objectForKey:kHGSActionOtherTermsKey];
    NSSet *otherTerms = [NSSet qsb_setFromId:value];
    NSUInteger count = [otherTerms count];
    if (count) {
      NSMutableSet *mutableTerms 
        = [[NSMutableSet alloc] initWithCapacity:count];
      NSBundle *bundle = [self bundle];
      for (NSString *term in otherTerms) {
        NSString *localized = [bundle qsb_localizedInfoPListStringForKey:term]; 
        [mutableTerms addObject:localized];
      }
      otherTerms_ = mutableTerms;
    }
    
    value 
      = [configuration objectForKey:kHGSActionDoesActionCauseUIContextChangeKey];
    // Default is YES, so only call boolValue if it's non nil.
    if (value) {
      causesUIContextChange_ = [value boolValue];
    } else {
      causesUIContextChange_ = YES;
    }
    
    value = [configuration objectForKey:kHGSActionMustRunOnMainThreadKey];
    if (value) {
      mustRunOnMainThread_ = [value boolValue];
    } else {
      mustRunOnMainThread_ = NO;
    }
    
    BOOL goodArgs = YES;
    value = [configuration objectForKey:kHGSActionArgumentsKey];
    if (value) {
      // Arguments can come to us as a single dictionary, or an array of
      // dictionaries. If it's a single dictionary, make an array out of it.
      if ([value isKindOfClass:[NSDictionary class]]) {
        value = [NSArray arrayWithObject:value];
      }
      NSMutableArray *arguments 
        = [NSMutableArray arrayWithCapacity:[value count]];
      for (NSDictionary *config in value) {
        // Add our bundle to the argument dictionary so it can find its own
        // localized values.
        NSMutableDictionary *bundledConfig 
          = [NSMutableDictionary dictionaryWithDictionary:config];
        [bundledConfig setObject:[self bundle] 
                          forKey:kHGSActionArgumentBundleKey];
        // We allow arguments to specify their own subclasses of action
        // argument.
        NSString *className 
          = [bundledConfig objectForKey:kHGSActionArgumentClassKey];
        Class argClass = Nil;
        if (className) {
          argClass = NSClassFromString(className);
        } else {
          argClass = [HGSActionArgument class];
        }
        if (!argClass) {
          HGSLogDebug(@"Unable to find class %@ for %@", argClass, 
                      bundledConfig);
          goodArgs = NO;
          break;
        }
        if ([argClass conformsToProtocol:@protocol(HGSActionArgument)]) {
          HGSActionArgument *actionArgument 
            = [[[argClass alloc] 
                initWithConfiguration:bundledConfig] autorelease];
          if (actionArgument) {
            [arguments addObject:actionArgument];
          } else {
            HGSLogDebug(@"Unable to instantiate action argument for %@", 
                        bundledConfig);
            goodArgs = NO;
            break;
          }
        } else  {
          HGSLogDebug(@"Action argument from %@ does not conform to "
                      @"HGSActionArgument protocol", bundledConfig);
          goodArgs = NO;
          break;
        }
      }
      if (goodArgs) {
        arguments_ = [arguments retain];
      }
    }
    if (!goodArgs) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [directObjectTypeFilter_ release];
  [returnedResultsTypeFilter_ release];
  [otherTerms_ release];
  [arguments_ release];
  
  [super dealloc];
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = NO;
  if (![self showInGlobalSearchResults]) {
    HGSTypeFilter *directObjectTypeFilter = [self directObjectTypeFilter];
    // Not a global-only action.
    // All results must apply to the action for the action to show.
    for (HGSResult *result in results) {
      doesApply = [directObjectTypeFilter isValidType:[result type]] 
        && [self appliesToResult:result];
      if (!doesApply) break;
    }
  }
  return doesApply;
}

- (BOOL)appliesToResult:(HGSResult *)result {
  return YES;
}

- (NSString*)displayNameForResults:(HGSResultArray *)result {
  // defaults to just our name
  return [self displayName];
}

- (NSString *)defaultIconName {
  return @"red-gear";
}

- (NSImage *)displayIconForResults:(HGSResultArray *)result {
  // default to our init icon
  return [self icon];
}

- (BOOL)showInGlobalSearchResults {
  return [self directObjectTypeFilter] == nil;
}

- (HGSActionArgument *)nextArgumentToFillIn:(HGSActionOperation *)operation {
  HGSActionArgument *reqdArgument = nil;
  HGSActionArgument *optArgument = nil;
  NSArray *arguments = [self arguments];
  // Return the first required argument, or failing that, the first optional
  // argument.
  for (HGSActionArgument *arg in arguments) {
    if ([arg isOptional]) {
      if (!optArgument) {
        id value = [operation argumentForKey:[arg identifier]];
        if (!value) {
          optArgument = arg;
        }
      }
    } else {
      id value = [operation argumentForKey:[arg identifier]];
      if (!value) {
        reqdArgument = arg;
        break;
      }
    }
  }
  return reqdArgument ? reqdArgument : optArgument;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHGSValidateActionBehaviorsPrefKey]) {
    HGSLog(@"ERROR: Action %@ forgot to override performWithInfo:.",
           [self class]);
  }
  [self doesNotRecognizeSelector:_cmd];
  return NO;  // COV_NF_LINE
}

- (HGSResultArray *)performReturningResultsWithInfo:(NSDictionary *)info {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHGSValidateActionBehaviorsPrefKey]) {
    HGSLog(@"ERROR: Action %@ forgot to override "
           @"performReturningResultsWithInfo:.",
           [self class]);
  }
  [self doesNotRecognizeSelector:_cmd];
  return nil;  // COV_NF_LINE
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%@<%p> name:%@", 
          [self class], self, [self displayName]];
}

@end

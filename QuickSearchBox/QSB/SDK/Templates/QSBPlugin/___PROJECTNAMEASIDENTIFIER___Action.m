//
//  ___PROJECTNAMEASIDENTIFIER___Action.m
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
//

#import <Vermilion/Vermilion.h>

@interface ___PROJECTNAMEASIDENTIFIER___Action : HGSAction
@end

@implementation  ___PROJECTNAMEASIDENTIFIER___Action

// Perform an action given a dictionary of info.
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    NSString *name = [directObjects displayName];
    NSString *localizedOK = HGSLocalizedString(@"OK", nil);
    NSString *localizedFormat = HGSLocalizedString(@"Action performed on %@",
                                                   nil);
    [NSAlert alertWithMessageText:NSStringFromClass([self class])
                    defaultButton:localizedOK
                   alternateButton:nil
                       otherButton:nil
         informativeTextWithFormat:localizedFormat, name];
    success = YES;
  }
  return success;
}
@end

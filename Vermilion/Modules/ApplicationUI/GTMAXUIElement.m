//
//  GTMAXUIElement.m
//  AccessibilityFS
//
//  Created by Dave MacLachlan on 2008/01/11.
// ================================================================
// Copyright (C) 2008 Google Inc.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// ================================================================

#import "GTMAXUIElement.h"
#import <unistd.h>
#import <AppKit/AppKit.h>
#import "GTMGarbageCollection.h"

@interface GTMAXUIElement (GTMAXUIElementTypeConversion)
- (NSString*)stringValueForCFType:(CFTypeRef)cfValue;
- (NSString*)stringValueForCFArray:(CFArrayRef)cfArray;
- (NSString*)stringValueForAXValue:(AXValueRef)axValueRef;
- (id)valueOfSameTypeAs:(CFTypeRef)previousValue withString:(NSString*)string;
- (AXValueRef)axValueOfType:(AXValueType)type withString:(NSString*)string;
- (BOOL)stringToBool:(NSString*)string;
@end

@implementation GTMAXUIElement
+ (BOOL)isAccessibilityEnabled {
  return AXAPIEnabled() | AXIsProcessTrusted();
}

+ (id)systemWideElement {
  AXUIElementRef elementRef = AXUIElementCreateSystemWide();
  GTMAXUIElement *element 
    = [[[[self class] alloc] initWithElement:elementRef] autorelease];
  CFRelease(elementRef);
  return element;
}

+ (id)elementWithElement:(AXUIElementRef)element {
  return [[[[self class] alloc] initWithElement:element] autorelease];
}

+ (id)elementWithProcessIdentifier:(pid_t)pid {
  return [[[[self class] alloc] initWithProcessIdentifier:pid] autorelease];
}

- (id)init {
  return [self initWithProcessIdentifier:getpid()];
}

- (id)initWithElement:(AXUIElementRef)element {
  if ((self = [super init])) {
    if (!element) {
      [self release];
      return nil;
    }
    element_ = CFRetain(element);
  }
  return self;
}

- (id)initWithProcessIdentifier:(pid_t)pid {
  if ((self = [super init])) {
    if (pid) {
      element_ = AXUIElementCreateApplication(pid);
    }
    if (!element_) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  if (element_) {
    CFRelease(element_);
  }
  [cachedAttributeNames_ release];
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] alloc] initWithElement:element_];
}

- (AXUIElementRef)element {
  return element_;
}

- (NSUInteger)hash {
  return CFHash(element_);
}

- (BOOL)isEqual:(id)object {
  BOOL equal = NO;
  if ([object isKindOfClass:[self class]]) {
    equal = CFEqual([self element], [object element]);
  }
  return equal;
}

- (NSString*)debugDescription {
  CFTypeRef cfDescription = CFCopyDescription(element_);
  NSString *description = [NSString stringWithFormat:@"%@ (%@)",
                           cfDescription, 
                           [self description]];
  CFRelease(cfDescription);
  return description;
}

- (NSString*)description {
  NSString *name = nil;
  NSString *role 
    = [self accessibilityAttributeValue:NSAccessibilityRoleDescriptionAttribute];
  NSString *subname 
    = [self accessibilityAttributeValue:NSAccessibilityTitleAttribute];
  NSNumber *idx 
    = [self accessibilityAttributeValue:NSAccessibilityIndexAttribute];
  if (!subname) {
    subname 
      = [self accessibilityAttributeValue:NSAccessibilityDescriptionAttribute];
  }  
  if (!subname) {
    GTMAXUIElement *titleElement 
      = [self accessibilityAttributeValue:NSAccessibilityTitleUIElementAttribute];
    if (titleElement) {
      subname 
        = [titleElement accessibilityAttributeValue:NSAccessibilityTitleAttribute];
    }
  }
  if (subname) {
    name = [NSString stringWithFormat:@"%@ : %@", role, subname];
  } else {
    name = role;
  }
  if (idx) {
    name = [NSString stringWithFormat:@"%@ %@", name, idx];
  }
  return name;  
}

- (NSInteger)accessibilityAttributeValueCount:(NSString*)attribute {
  CFIndex count;
  AXError error = AXUIElementGetAttributeValueCount(element_, 
                                                    (CFStringRef)attribute,
                                                    &count);
  if (error) {
    count = -1;
  }
  return count;
}
  
- (CFTypeRef)accessibilityCopyAttributeCFValue:(NSString*)attribute {
  CFTypeRef value = NULL;
  NSArray *names = [self accessibilityAttributeNames];
  if ([names containsObject:attribute]) {
    AXError error = AXUIElementCopyAttributeValue(element_, 
                                                  (CFStringRef)attribute, 
                                                  &value);
    if (error) {
      value = NULL;
    }
  }
  return value;
}

- (id)accessibilityAttributeValue:(NSString*)attribute {
  CFTypeRef value = [self accessibilityCopyAttributeCFValue:attribute];
  if (!value) return nil;
  id nsValue = nil;
  CFTypeID axTypeID = AXUIElementGetTypeID();
  if (CFGetTypeID(value) == axTypeID) {
    nsValue = [GTMAXUIElement elementWithElement:(AXUIElementRef)value];
  } else if (CFGetTypeID(value) == CFArrayGetTypeID()) {
    nsValue = [NSMutableArray array];
    NSEnumerator *enumerator = [(NSArray*)value objectEnumerator];
    id object;
    while ((object = [enumerator nextObject])) {
      if (CFGetTypeID((CFTypeRef)object) == axTypeID) {
        GTMAXUIElement *element 
          = [GTMAXUIElement elementWithElement:(AXUIElementRef)object];
        [nsValue addObject:element];
      } else {
        [nsValue addObject:object];
      }
    }
  } else {
    nsValue = [GTMCFAutorelease(value) retain];
  }
  CFRelease(value);
  return nsValue;
}

- (BOOL)accessibilityIsAttributeSettable:(NSString*)attribute {
  Boolean settable;
  AXError error = AXUIElementIsAttributeSettable(element_, 
                                                 (CFStringRef)attribute, 
                                                 &settable);
  if (error) {
    settable = FALSE;
  }
  return settable;
}

- (BOOL)setAccessibilityValue:(id)value 
                 forAttribute:(NSString*)attribute {
  AXError axerror = AXUIElementSetAttributeValue(element_, 
                                                 (CFStringRef)attribute, 
                                                 (CFTypeRef)value);
  return axerror == kAXErrorSuccess;
}

- (NSArray*)accessibilityAttributeNames {
  @synchronized(self) {
    if (!cachedAttributeNames_) {
      CFArrayRef array = NULL;
      AXError axerror = AXUIElementCopyAttributeNames(element_, &array);
      if (!axerror) {
        cachedAttributeNames_ = GTMNSMakeCollectable(array);
      }
    }
  }
  return cachedAttributeNames_;
}

- (pid_t)processIdentifier {
  pid_t pid;
  AXError error = AXUIElementGetPid(element_, &pid);
  if (error) {
    pid = 0;
  }
  return pid;
}

- (GTMAXUIElement*)processElement {
  GTMAXUIElement *processElement = nil;
  pid_t pid = [self processIdentifier];
  if (pid) {
    processElement = [GTMAXUIElement elementWithProcessIdentifier:pid];
  }
  return processElement;
}

- (BOOL)performAccessibilityAction:(NSString*)action {
  return AXUIElementPerformAction(element_, 
                                  (CFStringRef)action) == kAXErrorSuccess;
}

- (NSArray *)accessibilityActionNames {
  CFArrayRef array;
  NSArray *nsArray = nil;
  AXError error = AXUIElementCopyActionNames(element_, &array);
  if (!error) {
    nsArray = GTMCFAutorelease(array);
  }
  return nsArray;
}

- (BOOL)supportsAction:(NSString*)action {
  return [[self accessibilityActionNames] containsObject:action];
}

- (NSString *)accessibilityActionDescription:(NSString *)action {
  CFStringRef description;
  NSString *nsDescription = nil;
  AXError error = AXUIElementCopyActionDescription(element_, 
                                                   (CFStringRef)action,
                                                   &description);
  if (!error) {
    nsDescription = GTMCFAutorelease(description);
  }
  return nsDescription;
}

- (NSArray *)accessibilityParameterizedAttributeNames {
  CFArrayRef names;
  NSArray *nsNames = nil;
  AXError error = AXUIElementCopyParameterizedAttributeNames(element_,
                                                             &names);
  if (!error) {
    nsNames = GTMCFAutorelease(names);
  }
  return nsNames;
}

- (id)accessibilityAttributeValue:(NSString *)attribute 
                     forParameter:(id)parameter {
  CFTypeRef value;
  id nsValue = nil;
  AXError error 
    = AXUIElementCopyParameterizedAttributeValue(element_,
                                                 (CFStringRef)attribute,
                                                 (CFTypeRef)parameter,
                                                 &value);
  if (!error) {
    nsValue = GTMCFAutorelease(value);
  }
  return nsValue;
}

- (NSString*)stringValueForAttribute:(NSString*)attribute {
  CFTypeRef cfValue = [self accessibilityCopyAttributeCFValue:attribute];
  NSString *stringValue = [self stringValueForCFType:cfValue];
  if (cfValue) {
    CFRelease(cfValue);
  }
  return stringValue;
}

- (BOOL)setStringValue:(NSString*)string forAttribute:(NSString*)attribute {
  CFTypeRef cfPreviousValue = [self accessibilityCopyAttributeCFValue:attribute];
  if (!cfPreviousValue || cfPreviousValue == kCFNull) return NO;
  id value = [self valueOfSameTypeAs:cfPreviousValue withString:string];
  CFRelease(cfPreviousValue);
  BOOL isGood = [self setAccessibilityValue:value forAttribute:attribute];
  return isGood;
}

@end

@implementation GTMAXUIElement (GTMAXUIElementTypeConversion)

- (BOOL)stringToBool:(NSString*)string {
  BOOL value = NO;
  if (string && [string length] > 0) {
    unichar uchar = [string characterAtIndex:0];
    if ((uchar == 'T') || (uchar == 't') 
        || (uchar == 'Y') || (uchar == 'y')) {
      value = YES;
    } else {
      value = [string intValue] != 0 ? YES : NO;
    }
  }
  return value;
}

- (AXValueRef)axValueOfType:(AXValueType)type withString:(NSString*)string {
  union {
    CGPoint point;
    CGSize size;
    CGRect rect;
    CFRange range;
    AXError error;
  } axValue;
  
  switch (type) {
    case kAXValueCGPointType: {
      NSPoint nsValue = NSPointFromString(string);
      axValue.point = *(CGPoint*)&nsValue;
      break;
    }
      
    case kAXValueCGSizeType: {
      NSSize nsValue = NSSizeFromString(string);
      axValue.size = *(CGSize*)&nsValue;
      break;
    }
      
    case kAXValueCGRectType: {
      NSRect nsValue = NSRectFromString(string);
      axValue.rect = *(CGRect*)&nsValue;
      break;
    }
      
    case kAXValueCFRangeType: {
      NSRange nsValue = NSRangeFromString(string);
      axValue.range = *(CFRange*)&nsValue;
      break;
    }
      
    case kAXValueAXErrorType:
      axValue.error = [string intValue];
      break;
      
    default:
      NSLog(@"Unknown AXValueType: %d", type);
      return NULL;
      break;
  }

  return (AXValueRef)GTMCFAutorelease(AXValueCreate(type, &axValue));
}

- (NSString*)stringValueForAXValue:(AXValueRef)axValueRef {
  NSString *stringValue = nil;
  AXValueType axValueType = AXValueGetType(axValueRef);
  union {
    CGPoint point;
    CGSize size;
    CGRect rect;
    CFRange range;
    AXError error;
  } axValue;
  Boolean valueConvert = AXValueGetValue(axValueRef, axValueType, &axValue);
  if (!valueConvert) {
    NSLog(@"Unable to AXValueGetValue");
    return nil;
  }
  switch (axValueType) {
    case kAXValueCGPointType:
      stringValue = NSStringFromPoint(*(NSPoint*)&axValue);
      break;
      
    case kAXValueCGSizeType:
      stringValue = NSStringFromSize(*(NSSize*)&axValue);
      break;
      
    case kAXValueCGRectType:
      stringValue = NSStringFromRect(*(NSRect*)&axValue);
      break;
      
    case kAXValueCFRangeType:
      stringValue = NSStringFromRange(*(NSRange*)&axValue);
      break;
      
    case kAXValueAXErrorType:
      stringValue = [NSString stringWithFormat:@"%d", (*(AXError*)&axValue)];
      break;
      
    default:
      NSLog(@"Unknown AXValueType: %d", axValueType);
      break;
  }
  return stringValue;
}


- (NSString*)stringValueForCFArray:(CFArrayRef)cfArray {
  NSArray *array = (NSArray*)cfArray;
  NSEnumerator *arrayEnumerator = [array objectEnumerator];
  id value;
  NSMutableString *string = [NSMutableString stringWithString:@"{ "];
  value = [arrayEnumerator nextObject];
  if (value) {
    [string appendString:[self stringValueForCFType:(CFTypeRef)value]];
  }
  while ((value = [arrayEnumerator nextObject])) {
    [string appendFormat:@", %@", [self stringValueForCFType:(CFTypeRef)value]];
  }
  [string appendString:@" }"];
  return string;
}

- (NSString*)stringValueForCFType:(CFTypeRef)cfValue {
  NSString *stringValue = nil;
  if (!cfValue) return nil;
  CFTypeID cfType = CFGetTypeID(cfValue);
  if (cfType == CFStringGetTypeID()) {
    stringValue = [GTMCFAutorelease(cfValue) retain];
  } else if (cfType == CFURLGetTypeID()) {
    stringValue = [(NSURL*)cfValue absoluteString];
  } else if (cfType == CFNumberGetTypeID()) {
    stringValue = [(NSNumber*)cfValue stringValue];
  } else if (cfType == CFNullGetTypeID()) {
    stringValue = [NSString string];
  } else if (cfType == AXUIElementGetTypeID()) {
    stringValue = [[GTMAXUIElement elementWithElement:cfValue] description];
  } else if (cfType == AXValueGetTypeID()) {
    stringValue = [self stringValueForAXValue:cfValue];
  } else if (cfType == CFArrayGetTypeID()) {
    stringValue = [self stringValueForCFArray:cfValue];
  } else if (cfType == CFBooleanGetTypeID()) {
    stringValue = CFBooleanGetValue(cfValue) ? @"YES" : @"NO";
  } else {
    CFStringRef description = CFCopyDescription(cfValue);
    stringValue = GTMCFAutorelease(description);
  }
  return stringValue;       
}

  
- (id)valueOfSameTypeAs:(CFTypeRef)previousValue withString:(NSString*)string {
  id value = nil;
  CFTypeID valueType = CFGetTypeID(previousValue);
  if (valueType == CFStringGetTypeID()) {
    value = [NSString stringWithString:string];
  } else if (valueType == CFURLGetTypeID()) {
    value = [NSURL URLWithString:string];
  } else if (valueType == CFNumberGetTypeID()) {
    double dValue = [string doubleValue];
    value = [NSNumber numberWithDouble:dValue];
  } else if (valueType == CFNullGetTypeID()) {
    value = [NSNull null];
  } else if (valueType == AXValueGetTypeID()) {
    value = (id)[self axValueOfType:AXValueGetType(previousValue) 
                         withString:string];
  } else if (valueType == CFBooleanGetTypeID()) {
    BOOL bValue = [self stringToBool:string];
    value = [NSNumber numberWithBool:bValue];
  } 
  return value;
}

@end

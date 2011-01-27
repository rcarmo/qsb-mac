//
//  NSEvent+Gestures.h
//  MultiTouchEvents
//
//  Created by Nicholas Jitkoff on 2/7/08.


#import <Cocoa/Cocoa.h>


enum {        /* various types of events */
  NSRotateGesture  = 18, // rotation
  NSBeginGesture   = 19,
  NSEndGesture     = 20,
  NSMagnifyGesture = 30, // deltaZ, magnification
  NSSwipeGesture   = 31, // deltaX, deltaY  
};

enum {                    /* masks for the types of events */
  NSRotateGestureMask  = 1 << NSRotateGesture,
  NSBeginGestureMask   = 1 << NSBeginGesture,
  NSEndGestureMask     = 1 << NSEndGesture,
  NSMagnifyGestureMask = 1 << NSMagnifyGesture,
  NSSwipeGestureMask   = 1 << NSSwipeGesture,
};

@interface NSEvent (GesturesPrivate)
- (BOOL)isGesture;
- (float)magnification;
@end

@interface NSResponder (GesturesPrivate)
- (void)magnifyWithEvent:(NSEvent *)event;
- (void)rotateWithEvent:(NSEvent *)event;
- (void)swipeWithEvent:(NSEvent *)event;
- (void)beginGestureWithEvent:(NSEvent *)event;
- (void)endGestureWithEvent:(NSEvent *)event;
- (unsigned long long)gestureEventMask;
- (void)setGestureEventMask:(unsigned long long)mask;
@end
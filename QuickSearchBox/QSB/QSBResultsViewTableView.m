//
//  QSBResultsViewTableView.m
//
//  Copyright (c) 2006-2008 Google Inc. All rights reserved.
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

#import "QSBResultsViewTableView.h"
#import "QSBViewTableViewDataSourceProtocol.h"
#import "QSBViewTableViewCell.h"

@class QSBViewTableViewColumn;

// Private class for intercepting methods that the tableview would normally send
// directly to it's delegate. The only one we care about right now is
// tableView:willDisplayCell:forTableColumn:row:. Seems like a lot of work to
// just intercept the one method, but you can't use standard forwardInvocation
// because forwardInvocation is never called on to a delegate. We basically
// "wrap" all of the delegate functionality, and aside from the one method, pass
// it on through to the standard delegate.
@interface QSBViewTableViewDelegateProxy : NSObject <NSTableViewDelegate> {
 @private
  QSBResultsViewTableView *tableView_; // The table that we are a delegate for. (WEAK)
  id delegate_; // The delegate that we pass messages through to. (WEAK)
}

// Set up our proxy with it's view and delegate
//  Args:
//    view - the table this proxy applies to
//    delegate - the client supplied delegate to pass methods onto
//  Returns:
//    a QSBViewTableViewDelegateProxy
- (id)initWithViewTableView:(QSBResultsViewTableView *)view delegate:(id)delegate;

// Get the client supplied delegate
//  Returns:
//    the client supplied delegate
- (id)delegate;

// Set the delegate
//  Args:
//    delegate - client supplied delegate
- (void)setDelegate:(id)delegate;

// Utility function for determining if we should pass methods
// on to our delegate.
//
//  Args:
//    command: the selector
//  Returns:
//    YES if the delegate responds to command
- (BOOL)doesDelegateRespondToSelector:(SEL)command;
@end

@implementation QSBViewTableViewDelegateProxy

- (id)initWithViewTableView:(QSBResultsViewTableView *)view delegate:(id)delegate {
  self = [super init];
  if (self != nil) {
    tableView_ = view;
    [self setDelegate:delegate];
  }
  return self;
}

- (void)setDelegate:(id)delegate {
  delegate_ = delegate;  // Intentional weak reference
}


- (id)delegate {
  return delegate_;
}

// We have to special case tableView:heightOfRow: because of radar 4490518.
// Here's the description from the bug.
// -----------------
// -[NSTableView tableView:heightOfRow:] works differently than other delegated
// methods in the NSTableView class. As far as I can tell it is using
// introspection to see if _delegate supports the [NSTableView
// tableView:heightOfRow] method when setDelegate is called and then caching the
// return value to decide if it should be calling [NSTableView
// tableView:heightOfRow] in the future. This causes serious problems for
// subclasses of NSTableView that want to put a proxy delegate in between the
// tableview and the clients delegate. This is often done to support NSViews
// inside of table cells. What appears to be happening in my scenario:
// a) client creates an instance of my subclass of NSTableView (FooTable)
// b) client calls [FooTable setDelegate:clientDelegate]; and behind the scenes
// I create a proxy delegate and call [NSTableView setDelegate:proxyDelegate].
// Proxydelegate intercepts or reroutes certain messages enroute out to
// clientDelegate.
// c) NSTableView does introspection on the delegate I passed in, and sees that
// yes it does support [NSTableView tableView:heightOfRow:]. I have to, as my
// subdelegate may support it. NSTableView caches this response.
// d) time comes around for the table to calculate it's heights and NSTableView
// checks it's internal caches, sees that I "support" tableView:heightOfRow and
// calls [[self delegate] tableView:blah heightOfRow:blah] which asks my
// proxydelegate for it's delegate whom as it turns out DOES not support
// tableView:heightOfRow and I crash. So in effect what's happening is that
// NSTableView is asking proxydelegate if it supports tableView:heightOfRow, but
// due to the indirection done by proxy is calling through to clientDelegate at
// table height calculation time.
// I wouldn't call this a bug except that all of the other delegate functions
// work the other way, and this is a common pattern for working with
// NSTableView. NSTableView shouldn't cache the value, and instead should check
// before calculating rowheights whether the delegate supports
// tableView:heightOfRow like all the other delegate methods in NSTableView.
// -----------------
// So what we do to work around this is implement a respondsToSelector so
// that when we are asked whether or not we support tableView:heightOfRow: we
// ask our delegate that we are proxying if it supports it.
// To bypass the caching issue we always reset our [super delegate] and
// [super dataSource] whenever the client calls setDelegate or setDataSource
// on our table. See [QSBViewTableView -setDelegate/-setDataSource]
- (BOOL)respondsToSelector:(SEL)aSelector {
  BOOL doesRespond = NO;
  if (aSelector == @selector(tableView:heightOfRow:)) {
    doesRespond = [self doesDelegateRespondToSelector:aSelector];
  } else {
    doesRespond = [super respondsToSelector:aSelector];
  }
  return doesRespond;
}

- (BOOL)doesDelegateRespondToSelector:(SEL)command {
  id<NSObject> delegate = [self delegate];
  return [delegate respondsToSelector:command];
}

#pragma mark NSTableDelegate protocol wrappers
// The one method that we want to intercept. If our cell class is of type
// QSBViewTableViewCell we want to ask our dataSource to supply a view for us to
// show. This allows us to lazily instantiate views as necessary.
- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
  if ([[cell class] isSubclassOfClass:[QSBViewTableViewCell class]]) {
    id dataSource = [tableView_ dataSource];
    if ([dataSource respondsToSelector:@selector(tableView:viewForColumn:row:)]) {
      QSBViewTableViewCell *viewCell = (QSBViewTableViewCell *)cell;
      NSView *view = [dataSource tableView:tableView
                             viewForColumn:tableColumn
                                       row:row];
      [viewCell setContentView:view];
      id object = [dataSource tableView:tableView
              objectValueForTableColumn:tableColumn
                                    row:row];
      [viewCell setRepresentedObject:object];
    }
  } else {
    if ([self doesDelegateRespondToSelector:_cmd]) {
      [[self delegate] tableView:tableView
                 willDisplayCell:cell
                  forTableColumn:tableColumn
                             row:row];
    }
  }
}

// All the rest of these implementations just call through to the client's
// delegate's method if it was kind enough to provide one for us.
- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:tableView
                          withObject:tableColumn];
  }
}

- (void)tableView:(NSTableView *)tableView didDragTableColumn:(NSTableColumn *)tableColumn
{
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:tableView withObject:tableColumn];
  }
}

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:tableView withObject:tableColumn];
  }
}

- (BOOL)tableView:(NSTableView *)tableView
shouldEditTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
  BOOL shouldEdit = YES;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    shouldEdit = [[self delegate] tableView:tableView
                      shouldEditTableColumn:tableColumn row:row];
  }
  return shouldEdit;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
  BOOL shouldSelect = YES;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    shouldSelect = [[self delegate] tableView:tableView shouldSelectRow:row];
  }
  return shouldSelect;
}

- (BOOL)tableView:(NSTableView *)tableView
shouldSelectTableColumn:(NSTableColumn *)tableColumn
{
  BOOL shouldSelect = YES;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    shouldSelect = [[self delegate] tableView:tableView
                      shouldSelectTableColumn:tableColumn];
  }
  return shouldSelect;
}

- (void)tableViewColumnDidMove:(NSNotification *)notification {
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:notification];
  }
}

- (void)tableViewColumnDidResize:(NSNotification *)notification {
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:notification];
  }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:notification];
  }
}

- (void)tableViewSelectionIsChanging:(NSNotification *)notification {
  if ([self doesDelegateRespondToSelector:_cmd]) {
    [[self delegate] performSelector:_cmd withObject:notification];
  }
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell
                   rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc
                    row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
  NSString *toolTip = nil;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    toolTip = [[self delegate] tableView:tableView toolTipForCell:cell
                                    rect:rect tableColumn:tc row:row
                           mouseLocation:mouseLocation];
  }
  return toolTip;
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView {
  BOOL shouldChange = YES;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    shouldChange = [[self delegate] selectionShouldChangeInTableView:tableView];
  }
  return shouldChange;
}

// See - (BOOL)respondsToSelector:(SEL)aSelector for info on special handling
// for this method.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
  CGFloat outHeight = 0;
  if ([self doesDelegateRespondToSelector:_cmd]) {
    outHeight = [[self delegate] tableView:tableView heightOfRow:row];
  } else {
    outHeight = [tableView rowHeight];
  }
  return outHeight;
}

@end

// Private class for intercepting methods that the tableview would normally send
// directly to it's dataSource. We care about two of these,
// tableView:objectValueForTableColumn:row: and
// tableView:setObjectValue:forTableColumn:row: Seems like a lot of work to just
// intercept the two methods, but you can't use standard forwardInvocation
// because forwardInvocation is never called on to a dataSource. We basically
// "wrap" all of the dataSource functionality, and aside from the two methods,
// pass it on through to the standard dataSource.
@interface QSBViewTableViewDataSourceProxy : NSObject <NSTableViewDataSource> {
  @private
  QSBResultsViewTableView *tableView_; // The table that we are a datasource for. (WEAK)
  id dataSource_; // The dataSource that we pass messages through too. (WEAK)
}

// Set up our proxy with it's view and dataSource
//  Args:
//    view - the table this proxy applies to
//    dataSource - the client supplied dataSource to pass methods onto
//  Returns:
//    a QSBViewTableViewDataSourceProxy
- (id)initWithViewTableView:(QSBResultsViewTableView *)view
                 dataSource:(id)dataSource;

// Get the client supplied dataSource
//  Returns:
//    the client supplied dataSource
- (id)dataSource;

// Set the dataSource
//  Args:
//    dataSource - client supplied dataSource
- (void)setDataSource:(id)dataSource;

// Utility function for determining if we should pass methods
// on to our dataSource.
//
//  Args:
//    command: the selector
//  Returns:
//    YES if the dataSource responds to command
- (BOOL)doesDataSourceRespondToSelector:(SEL)command;
@end

@implementation QSBViewTableViewDataSourceProxy

- (id)initWithViewTableView:(QSBResultsViewTableView *)view
                 dataSource:(id)dataSource{
  self = [super init];
  if (self != nil) {
    tableView_ = view;
    [self setDataSource:dataSource];
  }
  return self;
}

- (void)setDataSource:(id)dataSource {
  dataSource_ = dataSource;  // Intentional weak reference
}

- (id)dataSource {
  return dataSource_;
}

- (BOOL)doesDataSourceRespondToSelector:(SEL)command {
  id<NSObject> dataSource = [tableView_ dataSource];
  return [dataSource respondsToSelector:command];
}


#pragma mark NSTableDataSource protocol wrappers

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row {
  id obj = nil;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    obj = [[self dataSource] tableView:tableView
             objectValueForTableColumn:tableColumn
                                   row:row];
  }
  return obj;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)obj
   forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    [[self dataSource] tableView:tableView setObjectValue:obj
                  forTableColumn:tableColumn row:row];
  }
}

// All the rest of these implementations just call through to the client's
// dataSource's method if it was kind enough to provide one for us.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  NSInteger count = 0;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    count = [[self dataSource] numberOfRowsInTableView:tableView];
  }
  return count;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
  BOOL acceptDrop = NO;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    acceptDrop = [[self dataSource] tableView:tableView acceptDrop:info
                                          row:row dropOperation:operation];
  }
  return acceptDrop;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation {
  NSDragOperation dragOperation = NSDragOperationNone;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    dragOperation = [[self dataSource] tableView:tableView
                         validateDrop:info
                          proposedRow:row
                proposedDropOperation:operation];
  }
  return dragOperation;
}

- (BOOL)tableView:(NSTableView *)tableView
        writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard {
  BOOL writeRows = NO;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    writeRows =[[self dataSource] tableView:tableView
                                  writeRows:rows toPasteboard:pboard];
  }
  return writeRows;
}

- (BOOL)tableView:(NSTableView *)tableView
     writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard*)pboard {
  BOOL writeRows = NO;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    writeRows =[[self dataSource] tableView:tableView
                       writeRowsWithIndexes:rowIndexes
                               toPasteboard:pboard];
  }
  return writeRows;
}

- (NSArray *)tableView:(NSTableView *)tableView
    namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
    forDraggedRowsWithIndexes:(NSIndexSet *)indexSet {
  NSArray *array = nil;
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    array =[[self dataSource] tableView:tableView
              namesOfPromisedFilesDroppedAtDestination:dropDestination
              forDraggedRowsWithIndexes:indexSet];
  }
  return array;
}

- (void)tableView:(NSTableView *)tableView
sortDescriptorsDidChange:(NSArray *)oldDescriptors {
  if ([self doesDataSourceRespondToSelector:_cmd]) {
    [[self dataSource] tableView:tableView
        sortDescriptorsDidChange:oldDescriptors];
  }
}

@end

@implementation QSBResultsViewTableView

- (void)dealloc {
  // Clean up the delegate and datasources we may have set up
  // Must set them to nil because [super dealloc] calls setDelegate:nil
  // which will attempt to re-release these.
  [delegateProxy_ release];
  delegateProxy_ = nil;
  [dataSourceProxy_ release];
  dataSourceProxy_ = nil;
  [super dealloc];
}

// Do the indirection through our proxy to get the client supplied delegate.
- (id)delegate {
  id superDelegate = [super delegate];
  return [superDelegate delegate];
}

// Set our delegate up properly. If our super delegate isn't of type
// QSBViewTableViewDelegateProxy create a QSBViewTableViewDelegateProxy and
// install it in there with it's delegate set to |delegate|. Otherwise call our
// super setDelegate which will call through to our proxy setDelegate.
- (void)setDelegate:(id)delegate {
  if (delegate) {
    id superDelegate = [super delegate];
    if (![superDelegate isKindOfClass:[QSBViewTableViewDelegateProxy class]]) {
      delegateProxy_
        = [[QSBViewTableViewDelegateProxy alloc] initWithViewTableView:self
                                                              delegate:delegate];
      [super setDelegate:delegateProxy_];
    } else {
      // We go through this "set to nil, set back to value" dance because
      // NSTableView caches information about the what methods the delegate
      // responds to. Setting things to nil and then resetting them "clears" the
      // cache.
      [super setDelegate:nil];
      [superDelegate setDelegate:delegate];
      [super setDelegate:superDelegate];
    }
  } else {
    [super setDelegate:nil];
    [delegateProxy_ release];
    delegateProxy_ = nil;
  }
}

// Set our dataSource up properly. If our super dataSource isn't of type
// QSBViewTableViewDataSourceProxy create a QSBViewTableViewDataSourceProxy and
// install it in there with it's dataSource set to |dataSource|. Otherwise call
// our super setDataSource which will call through to our proxy setDataSource.
- (void)setDataSource:(id)dataSource {
  if (dataSource) {
    id superDataSource = [super dataSource];
    Class dsProxyClass = [QSBViewTableViewDataSourceProxy class];
    if (![superDataSource isKindOfClass:dsProxyClass]) {
      dataSourceProxy_
        = [[QSBViewTableViewDataSourceProxy alloc] initWithViewTableView:self
                                                              dataSource:dataSource];
      [super setDataSource:dataSourceProxy_];
    } else {
      // We go through this "set to nil, set back to value" dance because
      // NSTableView caches information about the what methods the dataSource
      // responds to. Setting things to nil and then resetting them "clears" the
      // cache.
      [super setDataSource:nil];
      [superDataSource setDataSource:dataSource];
      [super setDataSource:superDataSource];
    }
  } else {
    [super setDataSource:nil];
    [dataSourceProxy_ release];
    dataSourceProxy_ = nil;
  }
}


// Do the indirection through our proxy to get the client supplied dataSource.
- (id)dataSource {
  id superDataSource = [super dataSource];
  return [superDataSource dataSource];
}


// If we are reloading data, we have to strip out all of the views that our
// datasource has added in preparation for refilling the table full of
// data.
- (void)reloadData {
  NSArray *subviews = [self subviews];
  id lastSubview = nil;
  while ((lastSubview = [subviews lastObject])) {
    [lastSubview removeFromSuperviewWithoutNeedingDisplay];
  }
  [super reloadData];
}
@end

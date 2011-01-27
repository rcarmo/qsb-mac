#import <Cocoa/Cocoa.h>

#if !NSINTEGER_DEFINED
// For people building on 10.4
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#endif  // NSINTEGER_DEFINED

@interface NSObject (QLPreviewPanelDelegate)
- (NSRect)previewPanel:(NSPanel*)panel frameForURL:(NSURL*)URL;
@end

@class QLAnimationWindowEffect;

@interface QLPreviewPanelReserved : NSObject {
  BOOL ignoreOpenAndClose;
}

- (BOOL)ignoreOpenAndClose;
- (void)setIgnoreOpenAndClose:(BOOL)fp8;

@end


enum {
	QLAppearEffect = 0,
	QLFadeEffect,			
	QLZoomEffect			
};
typedef NSInteger QLPreviewPanelEffect;

@interface QLPreviewPanel : NSPanel {
  QLAnimationWindowEffect *_currentEffect;
  QLPreviewPanelEffect _openingEffect;
  BOOL _ignorePanelFrameChanges;
  QLPreviewPanelReserved *_reserved;
  double _openingTime;
}

+ (id)sharedPreviewPanel;
//+ (id)_previewPanel;
+ (BOOL)isSharedPreviewPanelLoaded;
- (id)initWithContentRect:(NSRect)fp8 styleMask:(NSUInteger)fp24 backing:(NSBackingStoreType)fp28 defer:(BOOL)fp32;
- (id)initWithCoder:(id)fp8;
- (void)dealloc;
- (BOOL)isOpaque;
- (BOOL)canBecomeKeyWindow;
- (BOOL)canBecomeMainWindow;
- (BOOL)shouldIgnorePanelFrameChanges;
- (BOOL)isOpen;
- (void)setFrame:(NSRect)fp8 display:(BOOL)fp24 animate:(BOOL)fp28;
- (id)_subEffectsForWindow:(id)fp8 itemFrame:(NSRect)fp12 transitionWindow:(id *)fp28;
- (id)_scaleEffectForItemFrame:(NSRect)fp8 transitionWindow:(id *)fp24;
- (void)_invertCurrentEffect;
- (NSRect)_currentItemFrame;
- (void)setAutosizesAndCenters:(BOOL)fp8;
- (BOOL)autosizesAndCenters;
- (void)makeKeyAndOrderFront:(id)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(QLPreviewPanelEffect)fp8;
- (void)makeKeyAndGoFullscreenWithEffect:(QLPreviewPanelEffect)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(QLPreviewPanelEffect)fp8 canClose:(BOOL)fp12;
- (void)_makeKeyAndOrderFrontWithEffect:(QLPreviewPanelEffect)fp8 canClose:(BOOL)fp12 willOpen:(BOOL)fp16 toFullscreen:(BOOL)fp20;
- (QLPreviewPanelEffect)openingEffect;
- (void)closePanel;
- (void)close;
- (void)closeWithEffect:(QLPreviewPanelEffect)fp8;
- (void)closeWithEffect:(QLPreviewPanelEffect)fp8 canReopen:(BOOL)fp12;
- (void)_closeWithEffect:(QLPreviewPanelEffect)fp8 canReopen:(BOOL)fp12;
- (void)windowEffectDidTerminate:(id)fp8;
- (void)_close:(id)fp8;
- (void)sendEvent:(id)fp8;
- (void)selectNextItem;
- (void)selectPreviousItem;
- (void)setURLs:(id)fp8 currentIndex:(NSUInteger)fp12 preservingDisplayState:(BOOL)fp16;
- (void)setURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setURLs:(id)fp8;
- (id)URLs;
- (NSUInteger)indexOfCurrentURL;
- (void)setIndexOfCurrentURL:(NSUInteger)fp8;
- (void)setDelegate:(id)fp8;
- (id)sharedPreviewView;
- (void)setSharedPreviewView:(id)fp8;
- (void)setCyclesSelection:(BOOL)fp8;
- (BOOL)cyclesSelection;
- (void)setShowsAddToiPhotoButton:(BOOL)fp8;
- (BOOL)showsAddToiPhotoButton;
- (void)setShowsiChatTheaterButton:(BOOL)fp8;
- (BOOL)showsiChatTheaterButton;
- (void)setShowsFullscreenButton:(BOOL)fp8;
- (BOOL)showsFullscreenButton;
- (void)setShowsIndexSheetButton:(BOOL)fp8;
- (BOOL)showsIndexSheetButton;
- (void)setAutostarts:(BOOL)fp8;
- (BOOL)autostarts;
- (void)setPlaysDuringPanelAnimation:(BOOL)fp8;
- (BOOL)playsDuringPanelAnimation;
- (void)setDeferredLoading:(BOOL)fp8;
- (BOOL)deferredLoading;
- (void)setEnableDragNDrop:(BOOL)fp8;
- (BOOL)enableDragNDrop;
- (void)start:(id)fp8;
- (void)stop:(id)fp8;
- (void)setShowsIndexSheet:(BOOL)fp8;
- (BOOL)showsIndexSheet;
- (void)setShareWithiChat:(BOOL)fp8;
- (BOOL)shareWithiChat;
- (void)setPlaysSlideShow:(BOOL)fp8;
- (BOOL)playsSlideShow;
- (void)setIsFullscreen:(BOOL)fp8;
- (BOOL)isFullscreen;
- (void)setMandatoryClient:(id)fp8;
- (id)mandatoryClient;
- (void)setForcedContentTypeUTI:(id)fp8;
- (id)forcedContentTypeUTI;
- (void)setDocumentURLs:(id)fp8;
- (void)setDocumentURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setDocumentURLs:(id)fp8 itemFrame:(NSRect)fp12;
- (void)setURLs:(id)fp8 itemFrame:(NSRect)fp12;
- (void)setAutoSizeAndCenterOnScreen:(BOOL)fp8;
- (void)setShowsAddToiPhoto:(BOOL)fp8;
- (void)setShowsiChatTheater:(BOOL)fp8;
- (void)setShowsFullscreen:(BOOL)fp8;
@end

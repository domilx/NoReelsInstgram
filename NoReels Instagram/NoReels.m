#import "NoReels.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <FLEX.h>
#import <UIKit/UIKit.h>

#pragma mark - NoReels

@interface NoReels ()
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation NoReels

/// +load
/// Starts FLEX explorer after 2s and begins scanning views.
+ (void)load {
    NSLog(@"[NoReels] Loaded");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [FLEXManager.sharedManager showExplorer];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self sharedInstance] startTimer];
    });
}

/// Returns the singleton instance.
+ (instancetype)sharedInstance {
    static NoReels *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

/// Starts a timer that fires every 0.5s to scan the view hierarchy.
- (void)startTimer {
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                  target:self
                                                selector:@selector(scanViews)
                                                userInfo:nil
                                                 repeats:YES];
}

/// Scans the key window for unwanted views.
- (void)scanViews {
    UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
    if (keyWindow) [self processView:keyWindow];
}

/// Recursively processes subviews to replace/hide unwanted elements.
- (void)processView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        // Replace "Reels" button in IGTabBarButton.
        if ([sub isKindOfClass:NSClassFromString(@"IGTabBarButton")] &&
            ([sub.description containsString:@"Reels"] || [sub.accessibilityLabel containsString:@"Reels"])) {
            NSLog(@"[NoReels] Replacing Reels: %@", sub);
            UIButton *btn = (UIButton *)sub;
            [btn setTitle:@"🖕" forState:UIControlStateNormal];
            [btn setTitle:@"🖕" forState:UIControlStateHighlighted];
            [btn setImage:nil forState:UIControlStateNormal];
            [btn setImage:nil forState:UIControlStateHighlighted];
            btn.enabled = NO;
            btn.userInteractionEnabled = NO;
        }
        
        // Hide IGModernFeedVideoCell unless inside IGCarouselCollectionView.
        if ([sub isKindOfClass:NSClassFromString(@"IGModernFeedVideoCell.IGModernFeedVideoCell")]) {
            if (![sub.superview isKindOfClass:NSClassFromString(@"IGCarouselCollectionView")]) {
                NSLog(@"[NoReels] Hiding video cell: %@", sub);
                sub.hidden = YES;
            } else {
                NSLog(@"[NoReels] Video cell in carousel: %@", sub);
            }
        }
        
        // Hide UICollectionViews containing IGFeedPlayableClipCell.
        if ([sub isKindOfClass:NSClassFromString(@"UICollectionView")]) {
            for (UIView *cell in sub.subviews) {
                if ([cell isKindOfClass:NSClassFromString(@"IGFeedPlayableClipCell")]) {
                    NSLog(@"[NoReels] Hiding suggestions: %@", sub);
                    sub.hidden = YES;
                    break;
                }
            }
        }
        
        [self processView:sub];
    }
}

@end

#pragma mark - NSFileManager Swizzling

@implementation NSFileManager (Swizzling)

/// +load
/// Swizzles enumeratorAtURL:... to log and return nil when URL is nil.
+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = [self class];
        SEL origSel = @selector(enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:);
        SEL newSel  = @selector(nr_enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:);
        Method origMethod = class_getInstanceMethod(cls, origSel);
        Method newMethod  = class_getInstanceMethod(cls, newSel);
        method_exchangeImplementations(origMethod, newMethod);
    });
}

- (NSDirectoryEnumerator<NSURL *> *)nr_enumeratorAtURL:(NSURL *)url
                    includingPropertiesForKeys:(NSArray<NSURLResourceKey> *)keys
                                       options:(NSDirectoryEnumerationOptions)mask
                                  errorHandler:(BOOL (^)(NSURL *, NSError *))handler {
    if (!url) {
        NSLog(@"[NoReels] enumeratorAtURL called with nil URL");
        return nil;
    }
    return [self nr_enumeratorAtURL:url includingPropertiesForKeys:keys options:mask errorHandler:handler];
}

@end

#pragma mark - IGExploreGridViewController Override

@implementation UIViewController (NoExplore)

/// +load
/// Swizzles viewDidLoad for IGExploreGridViewController to clear its view.
+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = NSClassFromString(@"IGExploreGridViewController");
        if (cls) {
            SEL origSel = @selector(viewDidLoad);
            SEL swizzledSel = @selector(nr_viewDidLoad);
            Method origMethod = class_getInstanceMethod(cls, origSel);
            Method newMethod = class_getInstanceMethod(cls, swizzledSel);
            method_exchangeImplementations(origMethod, newMethod);
        }
    });
}

- (void)nr_viewDidLoad {
    [self nr_viewDidLoad];
    if ([NSStringFromClass([self class]) isEqualToString:@"IGExploreGridViewController"]) {
        NSLog(@"[NoReels] Clearing IGExploreGridViewController view");
        UIView *replacement = [[UIView alloc] initWithFrame:self.view.bounds];
        replacement.backgroundColor = UIColor.whiteColor;
        self.view = replacement;
    }
}

@end
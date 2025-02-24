#import "NoReels.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <FLEX.h>
#import <UIKit/UIKit.h>

#pragma mark - IGTabBarButton Forward Declaration
@interface IGTabBarButton : UIButton
@end
@implementation IGTabBarButton
@end

#pragma mark - NoReels Implementation
@interface NoReels ()
@property (nonatomic, strong) NSTimer *replaceTimer;
@end

@implementation NoReels

/**
 +load
 Called automatically when the class is loaded.
 - Launches FLEX after a delay.
 - Starts a recurring timer to scan for unwanted views.
 */
+ (void)load {
    NSLog(@"[NoReels] Loaded");
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
//                   dispatch_get_main_queue(), ^{
//        [FLEXManager.sharedManager showExplorer];
//    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self sharedInstance] startReplaceTimer];
    });
}

/**
 +sharedInstance
 Provides a singleton instance of NoReels.
 */
+ (instancetype)sharedInstance {
    static NoReels *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[NoReels alloc] init];
    });
    return shared;
}

/**
 -startReplaceTimer
 Starts a timer that fires every second to scan and hide unwanted views.
 */
- (void)startReplaceTimer {
    if (self.replaceTimer) {
        [self.replaceTimer invalidate];
        self.replaceTimer = nil;
    }
    self.replaceTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 // 1 second
                                                         target:self
                                                       selector:@selector(scanAndHideUnwantedViews)
                                                       userInfo:nil
                                                        repeats:YES];
}

/**
 -scanAndHideUnwantedViews
 Called by the timer; obtains the key window and processes its view hierarchy.
 */
- (void)scanAndHideUnwantedViews {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    [self processView:keyWindow];
}

/**
 -processView:
 Recursively scans a view’s subviews to:
 • Replace any IGTabBarButton that shows “Reels” with a disabled middle-finger button.
 • Hide any IGFNFVideoView.
 • Hide UICollectionViews whose data source class name indicates suggestions.
 @param view The view to process.
 */
- (void)processView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        // Replace Reels button in IGTabBarButton.
        if ([subview isKindOfClass:NSClassFromString(@"IGTabBarButton")] ||
            [NSStringFromClass(subview.class) isEqualToString:@"IGTabBarButton"]) {
            
            NSString *desc = subview.description ?: @"";
            NSString *accLabel = subview.accessibilityLabel ?: @"";
            if ([desc containsString:@"Reels"] || [accLabel containsString:@"Reels"]) {
                NSLog(@"[NoReels] Replacing Reels button: %@", desc);
                UIButton *button = (UIButton *)subview;
                [button setTitle:@"🖕" forState:UIControlStateNormal];
                [button setTitle:@"🖕" forState:UIControlStateHighlighted];
                [button setImage:nil forState:UIControlStateNormal];
                [button setImage:nil forState:UIControlStateHighlighted];
                button.enabled = NO;
                button.userInteractionEnabled = NO;
            }
        }
        
        // Hide any IGFNFVideoView.
        if ([subview isKindOfClass:NSClassFromString(@"IGFNFVideoView")]) {
            NSLog(@"[NoReels] Hiding IGFNFVideoView: %@", subview);
            subview.hidden = YES;
        }
        
        // Hide UICollectionViews showing suggestions.
        if ([subview isKindOfClass:[UICollectionView class]]) {
            NSString *dsClass = @"";
            if ([subview respondsToSelector:@selector(dataSource)] && [subview performSelector:@selector(dataSource)]) {
                dsClass = [NSStringFromClass([[subview performSelector:@selector(dataSource)] class]) lowercaseString];
            }
            if ([dsClass containsString:@"suggestions"]) {
                NSLog(@"[NoReels] Hiding UICollectionView with suggestions dataSource: %@", subview);
                subview.hidden = YES;
            }
        }
        
        // Recursively process subviews.
        [self processView:subview];
    }
}

@end

#pragma mark - NSFileManager (Swizzling)
@implementation NSFileManager (Swizzling)

/**
 +load
 Swizzles enumeratorAtURL:includingPropertiesForKeys:options:errorHandler: to log nil URLs.
 */
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        SEL origSel = @selector(enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:);
        SEL newSel  = @selector(swizzled_enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:);
        Method origMethod = class_getInstanceMethod(cls, origSel);
        Method newMethod  = class_getInstanceMethod(cls, newSel);
        method_exchangeImplementations(origMethod, newMethod);
    });
}

/**
 -swizzled_enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:
 Logs and returns nil if the URL is nil; otherwise calls the original method.
 */
- (NSDirectoryEnumerator<NSURL *> *)swizzled_enumeratorAtURL:(NSURL *)url
                   includingPropertiesForKeys:(NSArray<NSURLResourceKey> *)keys
                                      options:(NSDirectoryEnumerationOptions)mask
                                 errorHandler:(BOOL (^)(NSURL *url, NSError *error))handler {
    if (!url) {
        NSLog(@"[NoReels] enumeratorAtURL called with nil url");
        return nil;
    }
    return [self swizzled_enumeratorAtURL:url includingPropertiesForKeys:keys options:mask errorHandler:handler];
}

@end

#pragma mark - IGExploreGridViewController (NoExplore)
@implementation UIViewController (NoExplore)

/**
 +load
 Swizzles viewDidLoad for IGExploreGridViewController to replace its view with a blank one.
 */
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class exploreVC = NSClassFromString(@"IGExploreGridViewController");
        if (exploreVC) {
            SEL originalSel = @selector(viewDidLoad);
            SEL swizzledSel = @selector(nr_viewDidLoad);
            Method originalMethod = class_getInstanceMethod(exploreVC, originalSel);
            Method swizzledMethod = class_getInstanceMethod(exploreVC, swizzledSel);
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

/**
 -nr_viewDidLoad
 Replaces the view of IGExploreGridViewController with a blank white view.
 */
- (void)nr_viewDidLoad {
    [self nr_viewDidLoad]; // Call original viewDidLoad.
    
    if ([NSStringFromClass([self class]) isEqualToString:@"IGExploreGridViewController"]) {
        NSLog(@"[NoReels] Removing IGExploreGridViewController view");
        UIView *replacement = [[UIView alloc] initWithFrame:self.view.bounds];
        replacement.backgroundColor = [UIColor whiteColor];
        self.view = replacement;
    }
}

@end

#pragma mark - UICollectionView (NoSuggestions)
@implementation UICollectionView (NoSuggestions)

/**
 +load
 Swizzles setDataSource: for UICollectionView to hide views with a data source containing "suggestions".
 */
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        SEL originalSel = @selector(setDataSource:);
        SEL swizzledSel = @selector(swizzled_setDataSource:);
        Method originalMethod = class_getInstanceMethod(cls, originalSel);
        Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

/**
 -swizzled_setDataSource:
 Calls the original setDataSource:, then hides the UICollectionView if the data source’s class name contains "suggestions".
 */
- (void)swizzled_setDataSource:(id<UICollectionViewDataSource>)dataSource {
    [self swizzled_setDataSource:dataSource]; // Call original implementation.
    
    NSString *dsClass = [NSStringFromClass([dataSource class]) lowercaseString];
    NSLog(@"[NoReels] UICollectionView dataSource: %@", dsClass);
    if ([dsClass containsString:@"suggestions"]) {
        NSLog(@"[NoReels] Hiding UICollectionView with suggestions dataSource: %@", self);
        self.hidden = YES;
    }
}

@end

#pragma mark - UILabel (NoSuggestedReels)
@implementation UILabel (NoSuggestedReels)

/**
 +load
 Swizzles setText: for UILabel to hide any label displaying "suggested reels".
 */
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = [self class];
        SEL originalSel = @selector(setText:);
        SEL swizzledSel = @selector(swizzled_setText:);
        Method originalMethod = class_getInstanceMethod(cls, originalSel);
        Method swizzledMethod = class_getInstanceMethod(cls, swizzledSel);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    });
}

/**
 -swizzled_setText:
 Hides the label if its text contains "suggested reels", then calls the original setText:.
 */
- (void)swizzled_setText:(NSString *)text {
    if ([[text lowercaseString] containsString:@"suggested reels"]) {
        NSLog(@"[NoReels] Hiding UILabel with text: %@", text);
        self.hidden = YES;
    }
    [self swizzled_setText:text]; // Call original implementation.
}

@end

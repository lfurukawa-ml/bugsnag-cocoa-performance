//
//  ViewLoadInstrumentation.mm
//  BugsnagPerformance
//
//  Created by Nick Dowell on 10/10/2022.
//

#import "ViewLoadInstrumentation.h"

#import "../BugsnagPerformanceSpan+Private.h"
#import "../Span.h"
#import "../Tracer.h"
#import "../Swizzle.h"

#import <objc/runtime.h>

#if 0
#define Trace NSLog
#else
#define Trace(...)
#endif

using namespace bugsnag;

static constexpr int kAssociatedSpan = 0;

void
ViewLoadInstrumentation::configure(BugsnagPerformanceConfiguration *config) noexcept {
    callback_ = config.viewControllerInstrumentationCallback;
    isEnabled_ = config.autoInstrumentViewControllers;
}

void
ViewLoadInstrumentation::start() noexcept {
    if (!isEnabled_) {
        return;
    }

    auto observedClasses = [NSMutableSet<Class> set];
    
    for (auto image : imagesToInstrument()) {
        Trace(@"Instrumenting %s", image);
        for (auto cls : viewControllerSubclasses(image)) {
            Trace(@" - %s", class_getName(cls));
            [observedClasses addObject:cls];
            instrument(cls);
        }
    }
    
    observedClasses_ = observedClasses;
    
    // We need to instrument UIViewController because not all subclasses will
    // override loadView and viewDidAppear:
    instrument([UIViewController class]);
}

void
ViewLoadInstrumentation::onLoadView(UIViewController *viewController) noexcept {
    if (!isEnabled_) {
        return;
    }

    if (![observedClasses_ containsObject:[viewController class]]) {
        return;
    }
    
    // Allow customer code to prevent span creation for this view controller.
    if (callback_ && !callback_(viewController)) {
        return;
    }
    
    // Prevent replacing an existing span for view controllers that override
    // loadView and call through to superclass implementation(s).
    if (objc_getAssociatedObject(viewController, &kAssociatedSpan)) {
        return;
    }

    auto viewType = BugsnagPerformanceViewTypeUIKit;
    auto className = NSStringFromClass([viewController class]);
    SpanOptions options;
    auto span = tracer_->startViewLoadSpan(viewType, className, options);
    [span addAttributes:spanAttributesProvider_->viewLoadSpanAttributes(className, viewType)];

    objc_setAssociatedObject(viewController, &kAssociatedSpan, span,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void
ViewLoadInstrumentation::onViewDidAppear(UIViewController *viewController) noexcept {
    if (!isEnabled_) {
        return;
    }

    endViewLoadSpan(viewController);
}

void ViewLoadInstrumentation::onViewWillDisappear(UIViewController *viewController) noexcept {
    if (!isEnabled_) {
        return;
    }

    endViewLoadSpan(viewController);
}

void ViewLoadInstrumentation::endViewLoadSpan(UIViewController *viewController) noexcept {
    if (!isEnabled_) {
        return;
    }

    BugsnagPerformanceSpan *span = objc_getAssociatedObject(viewController, &kAssociatedSpan);
    [span end];

    // Prevent calling -[BugsnagPerformanceSpan end] more than once.
    objc_setAssociatedObject(viewController, &kAssociatedSpan, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


// Suppress clang-tidy warnings about use of pointer arithmetic and free()
// NOLINTBEGIN(cppcoreguidelines-*)

std::vector<const char *>
ViewLoadInstrumentation::imagesToInstrument() noexcept {
    std::vector<const char *> images;
    auto appPath = NSBundle.mainBundle.bundlePath.UTF8String;
    auto count = 0U;
    auto names = objc_copyImageNames(&count);
    if (names) {
        for (auto i = 0U; i < count; i++) {
            // Instrument all images within the app bundle
            if (strstr(names[i], appPath)
#if TARGET_OS_SIMULATOR
                // and those loaded from BUILT_PRODUCTS_DIR, because Xcode
                // doesn't embed them when building for the Simulator.
                || strstr(names[i], "/DerivedData/")
#endif
                ) {
                images.push_back(names[i]);
            }
        }
        free(names);
    }
    return images;
}

std::vector<Class>
ViewLoadInstrumentation::viewControllerSubclasses(const char *image) noexcept {
    std::vector<Class> classes;
    auto count = 0U;
    auto names = objc_copyClassNamesForImage(image, &count);
    if (names) {
        for (unsigned int i = 0; i < count; i++) {
            auto cls = objc_getClass(names[i]);
            if (isViewControllerSubclass(cls)) {
                classes.push_back(cls);
            }
        }
        free(names);
    }
    return classes;
}

bool
ViewLoadInstrumentation::isViewControllerSubclass(Class cls) noexcept {
    const auto root = [UIViewController class];
    while (cls && cls != root) {
        cls = class_getSuperclass(cls);
    }
    return cls != nil;
}

void
ViewLoadInstrumentation::instrument(Class cls) noexcept {
    SEL selector = @selector(loadView);
    IMP loadView __block = nullptr;
    loadView = ObjCSwizzle::replaceInstanceMethodOverride(cls, selector, ^(id self){
        Trace(@"%@   -[%s %s]", self, class_getName(cls), sel_getName(selector));
        onLoadView(self);
        reinterpret_cast<void (*)(id, SEL)>(loadView)(self, selector);
    });

    // viewDidAppear may not fire, so as a fallback we use viewWillDisappear.
    // https://developer.apple.com/documentation/uikit/uiviewcontroller#1652793

    selector = @selector(viewDidAppear:);
    IMP viewDidAppear __block = nullptr;
    viewDidAppear = ObjCSwizzle::replaceInstanceMethodOverride(cls, selector, ^(id self, BOOL animated){
        Trace(@"%@   -[%s %s]", self, class_getName(cls), sel_getName(selector));
        reinterpret_cast<void (*)(id, SEL, BOOL)>(viewDidAppear)(self, selector, animated);
        onViewDidAppear(self);
    });

// Temporarily disabled to stop crashes while we build a more complete solution
//    selector = @selector(viewWillDisappear:);
//    IMP viewWillDisappear __block = nullptr;
//    viewWillDisappear = ObjCSwizzle::replaceInstanceMethodOverride(cls, selector, ^(id self, BOOL animated){
//        Trace(@"%@   -[%s %s]", self, class_getName(cls), sel_getName(selector));
//        reinterpret_cast<void (*)(id, SEL, BOOL)>(viewDidAppear)(self, selector, animated);
//        onViewWillDisappear(self);
//    });
}


// NOLINTEND(cppcoreguidelines-*)

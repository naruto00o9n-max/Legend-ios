#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif
UIImage * _Nullable CookiesInpaint(UIImage *source, UIImage *mask, double radius);
/// Match reconstructed gradients/colors to their untouched surroundings and
/// return alpha only inside the trusted text mask. Never changes the source.
UIImage * _Nullable CookiesMatchRestoration(UIImage *source, UIImage *candidate, UIImage *mask);
UIImage * _Nullable CookiesFillBucket(UIImage *source, CGPoint point, UIColor *color, double tolerance);
/// Region-local contour and text bounds. A pin is returned when detection fails.
NSDictionary<NSString *, id> * _Nullable CookiesDetectBubble(UIImage *source, CGPoint point);
/// Transparent text-only patch; nil when the contour or text evidence is unsafe.
NSDictionary<NSString *, id> * _Nullable CookiesWhitenBubble(UIImage *source, NSArray<NSValue *> *outline, NSArray<NSValue *> *textRects);
/// Conservative line/word mask clipped to a protected bubble interior.
NSDictionary<NSString *, id> * _Nullable CookiesCreateBubbleTextMask(CGSize size, NSArray<NSValue *> *outline, NSArray<NSValue *> *textRects, double padding);
#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END

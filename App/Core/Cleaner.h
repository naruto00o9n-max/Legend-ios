#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif
UIImage * _Nullable CookiesInpaint(UIImage *source, UIImage *mask, double radius);
/// Region-local contour and text bounds. A pin is returned when detection fails.
NSDictionary<NSString *, id> * _Nullable CookiesDetectBubble(UIImage *source, CGPoint point);
#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END

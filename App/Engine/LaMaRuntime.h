#import <Foundation/Foundation.h>
#include <stdint.h>
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif
NSDictionary<NSString *,id> *CookiesLaMaOpen(NSString *path);
NSDictionary<NSString *,id> *CookiesLaMaPredict(void *context,NSData *image,NSData *mask);
void CookiesLaMaClose(void *context);
uint64_t CookiesLaMaAvailableMemory(void);
#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END

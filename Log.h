#if CLI
#define IALLog(format, ...) printf("[i] " format "\n", ##__VA_ARGS__)
#define IALLogErr(format, ...) printf("[x] " format "\n", ##__VA_ARGS__)
#elif DEBUG
#if __has_feature(objc_arc)
#define IALLog(format, ...) NSLog(@"[IALLog] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:(format), ##__VA_ARGS__])
#define IALLogErr(format, ...) NSLog(@"[IALLogError] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:(format), ##__VA_ARGS__])
#else // for libarchive functions
#include <syslog.h>
#define IALLog(format, ...) syslog(LOG_NOTICE, "[IALLog] %s:%d: " format "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define IALLogErr(format, ...) syslog(LOG_NOTICE, "[IALLogErr] %s:%d: " format "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#endif
#else
#define IALLog(format, ...)
#define IALLogErr(format, ...)
#endif

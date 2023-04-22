#if DEBUG
#define IALLog(...) NSLog(@"[IALLog] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#define IALLogErr(...) NSLog(@"[IALLogError] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define IALLog(...)
#define IALLogErr(...)
#endif

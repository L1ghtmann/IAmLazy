#if CLI
#define IALLog(...) printf("[i] %s\n", [[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#define IALLogErr(...) printf("[x] %s\n", [[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#elif DEBUG
#define IALLog(...) NSLog(@"[IALLog] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#define IALLogErr(...) NSLog(@"[IALLogError] %s:%d: %@", __FILE__, __LINE__, [NSString stringWithFormat:__VA_ARGS__])
#else
#define IALLog(...)
#define IALLogErr(...)
#endif

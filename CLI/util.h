#import <Foundation/Foundation.h>

#define print(str) puts([str UTF8String])

NSArray *getOpts();
NSString *getHelp();
NSString *getInput();
NSString *prompt(NSArray<NSString *> *items, NSInteger upperBound);
void handleObserverForPurposeWithFilter(NSInteger purpose, BOOL filter);

#import <Foundation/Foundation.h>
#import "../Managers/IALGeneralManager.h"
#import "../Common.h"

#define print(str) puts([str UTF8String])

NSArray *getOpts(){
	NSArray *opts = @[
		@"-h",
		@"--help",
		@"-b",
		@"--backup",
		@"-r",
		@"--restore",
		@"-l",
		@"--list"
	];
	return opts;
}

NSString *getHelp(){
	NSString *msg = @"\
Usage: ial [options]\n\
Options:\n\
  [-b|--backup]       Create a backup\n\
  [-r|--restore]      Restore from a backup\n\
  [-l|--list]         List available backups\n\
  [-h|--help]         Display this page";
	return msg;
}

// https://stackoverflow.com/a/25753918
NSString *getInput(){
	@autoreleasepool{
		return [[[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] availableData] encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	}
}

int main(int argc, char **argv){
	@autoreleasepool {
		// sanity check
		NSArray *opts = getOpts();
		if(argc != 2 || ![opts containsObject:@(argv[1])]){
			print(getHelp());
		}

		// the work
		for(int i = 0; i < argc; i++){
			switch([opts indexOfObject:@(argv[i])]){
				// help
				case 0:
				case 1: {
					print(getHelp());
					break;
				}
				// backup
				case 2:
				case 3: {
					NSString *input = nil;
					do {
						print(@"Please select a backup type:");
						print(@"  [0] standard");
						print(@"  [1] developer");

						input = [getInput() stringByReplacingOccurrencesOfString:@" " withString:@""];
						NSInteger count = [[input componentsSeparatedByString:@" "] count];
						NSInteger len = [input length];
						if(count == 1 && len == 1 && [input intValue] <= 1){
							break;
						}
					} while(true);

					IALGeneralManager *gManager = [IALGeneralManager sharedManager];
					NSDate *startTime = [NSDate date];
					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					[gManager makeBackupWithFilter:input andCompletion:^(BOOL completed){
						dispatch_async(dispatch_get_main_queue(), ^(void){
							if(completed){
								NSDate *endTime = [NSDate date];
								NSTimeInterval duration = [endTime timeIntervalSinceDate:startTime];
								[NSString stringWithFormat:[[localize(@"Tweak backup completed successfully in %@ seconds!")
																		stringByAppendingString:@"\n"]
																		stringByAppendingString:localize(@"Your backup can be found in\n%@")],
																		[NSString stringWithFormat:@"%.02f", duration],
																		backupDir];
								dispatch_semaphore_signal(sema);
							}
						});
					}];
					dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
					break;
				}
				// restore
				case 4:
				case 5: {
					print(@"Restore");
					break;
				}
				// list
				case 6:
				case 7: {
					print(@"List");
					break;
				}
			}
		}

		return 0;
	}
}

#import "../Shared/Managers/IALGeneralManager.h"
#import "../Common.h"
#import "../Task.h"

#define print(str) puts([str UTF8String])

NSArray *getOpts(){
	@autoreleasepool{
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
}

NSString *getHelp(){
	@autoreleasepool{
		NSString *msg = @"\
Usage: ial [options]\n\
Options:\n\
  [-b|--backup]       Create a backup\n\
  [-r|--restore]      Restore from a backup\n\
  [-l|--list]         List available backups\n\
  [-h|--help]         Display this page";
		return msg;
	}
}

// https://stackoverflow.com/a/25753918
NSString *getInput(){
	@autoreleasepool{
		NSString *input = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] availableData] encoding:NSUTF8StringEncoding];
		NSString *cleanInput = [input stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		return [cleanInput stringByReplacingOccurrencesOfString:@" " withString:@""];
	}
}

int main(int argc, char **argv){
	@autoreleasepool {
		// sanity check
		NSArray *opts = getOpts();
		if(argc != 2 || ![opts containsObject:@(argv[1])]){
			print(getHelp());
			return 0;
		}

		// the work
		for(int i = 0; i < argc; i++){
			switch([opts indexOfObject:@(argv[i])]){
				// help
				case 0:
				case 1: {
					print(getHelp());
					return 0;
				}
				// backup
				case 2:
				case 3: {
					__block NSString *input = nil;
					do {
						print(@"Please select a backup type:");
						print(@"  [0] standard");
						print(@"  [1] developer");

						input = getInput();
						if([input length] == 1 && [input intValue] <= 1){
							break;
						}
					} while(true);

					BOOL filter = ![input boolValue];

					do {
						print(@"Please confirm that you have adequate free storage before proceeding:");
						print(@"  [0] Cancel");
						print(@"  [1] Confirm");

						input = getInput();
						if([input length] == 1 && [input intValue] <= 1){
							break;
						}
					} while(true);

					if(![input boolValue]){
						return 0;
					}

					IALGeneralManager *gManager = [[IALGeneralManager alloc] sharedManagerForPurpose:0];
					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					NSDate *startTime = [NSDate date];
					[gManager makeBackupWithFilter:filter andCompletion:^(BOOL completed){
						if(completed){
							NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
							NSString *msg = [NSString stringWithFormat:@"Tweak backup completed successfully in %.02f seconds!\nYour backup can be found in %@", duration, backupDir];
							print(msg);
							dispatch_semaphore_signal(sema);
						}
						else{
							exit(1);
						}
					}];
					dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
					break;
				}
				// restore
				case 4:
				case 5: {
					__block NSString *input = nil;
					do {
						print(@"Please select a restore type:");
						print(@"  [0] latest");
						print(@"  [1] specific");

						input = getInput();
						if([input length] == 1 && [input intValue] <= 1){
							break;
						}
					} while(true);

					IALGeneralManager *gManager = [[IALGeneralManager alloc] sharedManagerForPurpose:1];
					NSArray *backups = [gManager getBackups];
					NSUInteger count = [backups count];
					if(!count){
						print(@"No backups were found.");
						return 1;
					}
					NSString *backup = nil;
					if(![input boolValue]){
						backup = [backups firstObject];
					}
					else{
						do {
							print(@"Choose the backup you'd like to restore from:");
							for(int i = 0; i < count; i++){
								NSString *msg = [NSString stringWithFormat:@"[%d] %@", i, backups[i]];
								print(msg);
							}
							input = getInput();
							NSInteger len = [input length];
							if(len >= 1 && len <= [[NSString stringWithFormat:@"%lu", count] length] && [input intValue] < count){
								break;
							}
						} while(true);

						backup = backups[[input intValue]];
					}

					if(![backup length]){
						print(@"Chosen backup is nil?");
						return 1;
					}
					else if([backup hasSuffix:@"u.tar.gz"]){
						print(@"You have chosen to restore from a developer backup. This backup includes bootstrap packages.");
						do {
							print(@"Please confirm that you understand this and still wish to proceed with the restore");
							print(@"  [0] No");
							print(@"  [1] Yes");

							input = getInput();
							if([input length] == 1 && [input intValue] <= 1){
								break;
							}
						} while(true);

						if(![input boolValue]){
							return 0;
						}
					}

					NSString *msg = [NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backup];
					do {
						print(msg);
						print(@"  [0] No");
						print(@"  [1] Yes");

						input = getInput();
						if([input length] == 1 && [input intValue] <= 1){
							break;
						}
					} while(true);

					if(![input boolValue]){
						return 0;
					}

					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					[gManager restoreFromBackup:backup withCompletion:^(BOOL completed){
						if(completed){
							do{
								print(@"Choose a post-restore command:");
								print(@"  [0] Respring");
								print(@"  [1] UICache & Respring");
								print(@"  [2] None");

								input = getInput();
								if([input length] == 1 && [input intValue] <= 2){
									break;
								}
							} while(true);

							switch([input intValue]){
								case 0: {
									const char *args[] = {
										ROOT_PATH("/usr/bin/sbreload"),
										NULL
									};
									task(args);
									break;
								}
								case 1: {
									const char *args[] = {
										ROOT_PATH("/usr/bin/uicache"),
										"-a",
										"-r",
										NULL
									};
									task(args);
									break;
								}
								case 2:
									break;
							}

							dispatch_semaphore_signal(sema);
						}
						else{
							exit(1);
						}
					}];
					dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
					break;
				}
				// list
				case 6:
				case 7: {
					IALGeneralManager *gManager = [IALGeneralManager sharedManager];
					NSArray *backups = [gManager getBackups];
					if([backups count]){
						for(NSString *backup in backups){
							print(backup);
						}
					}
					else{
						print(@"No backups were found.");
						return 1;
					}
					break;
				}
			}
		}

		return 0;
	}
}

#import "../Shared/Managers/IALGeneralManager.h"
#import "../App/UI/IALProgressViewController.h"
#import <Common.h>
#import <Task.h>

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

NSString *prompt(NSArray<NSString *> *items, NSInteger upperBound){
	@autoreleasepool{
		__block NSString *input = nil;
		do {
			for(NSString *item in items){
				print(item);
			}
			input = getInput();
			if([input length] == 1 && [input intValue] <= upperBound){
				break;
			}
		} while(true);
		return input;
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
		// shoutout Uro
		// https://gist.github.com/uroboro/8782641c7d2412427b5487254e8f40b0
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
					NSArray *items = @[
						@"Please select a backup type:",
						@"  [0] standard",
						@"  [1] developer"
					];
					NSString *input = prompt(items, 1);

					BOOL filter = ![input boolValue];

					items = @[
						@"Please confirm that you have adequate free storage before proceeding:",
						@"  [0] Cancel",
						@"  [1] Confirm"
					];
					input = prompt(items, 1);

					if(![input boolValue]){
						return 0;
					}

					__unused IALProgressViewController *prog = [[IALProgressViewController alloc] initWithPurpose:0 withFilter:filter];
					IALGeneralManager *gManager = [IALGeneralManager sharedManager];
					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					NSDate *startTime = [NSDate date];
					[gManager makeBackupWithFilter:filter andCompletion:^(BOOL completed, NSString *info){
						if(completed){
							NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:startTime];
							NSString *msg = [NSString stringWithFormat:@"Tweak backup completed successfully in %.02f seconds!\nYour backup can be found in %@", duration, backupDir];
							if([info length]){
								msg = [[msg stringByAppendingString:@"\n"]
											stringByAppendingString:[NSString stringWithFormat:@"The following packages are not properly installed/configured and were skipped:\n%@",
											info]];
							}
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
					__unused IALProgressViewController *prog = [[IALProgressViewController alloc] initWithPurpose:1 withFilter:nil];
					IALGeneralManager *gManager = [IALGeneralManager sharedManager];
					NSArray *backups = [gManager getBackups];
					NSUInteger count = [backups count];
					if(!count){
						print(@"No backups were found.");
						return 1;
					}

					__block NSArray *items = @[
						@"Please select a restore type:",
						@"  [0] latest",
						@"  [1] specific"
					];
					__block NSString *input = prompt(items, 1);

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
						items = @[
							@"Please confirm that you understand this and still wish to proceed with the restore",
							@"  [0] No",
							@"  [1] Yes"
						];
						input = prompt(items, 1);
						if(![input boolValue]){
							return 0;
						}
					}

					NSString *msg = [NSString stringWithFormat:@"Are you sure that you want to restore from %@?", backup];
					items = @[
						msg,
						@"  [0] No",
						@"  [1] Yes"
					];
					input = prompt(items, 1);
					if(![input boolValue]){
						return 0;
					}

					dispatch_semaphore_t sema = dispatch_semaphore_create(0);
					[gManager restoreFromBackup:backup withCompletion:^(BOOL completed){
						if(completed){
							items = @[
								@"Choose a post-restore command:",
								@"  [0] Respring",
								@"  [1] UICache & Respring",
								@"  [2] None"
							];
							input = prompt(items, 2);

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

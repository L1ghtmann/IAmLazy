//
//	IALGeneralManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Reachability/Reachability.h"
#import <AudioToolbox/AudioServices.h>
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "IALBackupManager.h"
#import "../../Common.h"
#import "../../Task.h"

#if CLI
#import "../../App/UI/IALProgressViewController.h"
#endif

@implementation IALGeneralManager

#pragma mark Setup

#if CLI
-(instancetype)sharedManagerForPurpose:(NSInteger)purpose{
	static dispatch_once_t p = 0;
	__strong static IALGeneralManager *sharedManager = nil;
	dispatch_once(&p, ^{
		sharedManager = [self init];
	#pragma clang diagnostic push
	#pragma clang diagnostic ignored "-Wunused-value"
		[[IALProgressViewController alloc] initWithPurpose:purpose withFilter:_backupManager.filtered];
	#pragma clang diagnostic pop
	});
	return sharedManager;
}
#endif

+(instancetype)sharedManager{
	static dispatch_once_t p = 0;
	__strong static IALGeneralManager *sharedManager = nil;
	dispatch_once(&p, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

-(instancetype)init{
	self = [super init];

	if(self){
		[self ensureBackupDirExists];
	#if DEBUG
		[self cleanLog];
	#endif
		[self ensureUsableDpkgLock];
	}

	return self;
}

#pragma mark Functionality

-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL, NSString *))completed{
	if(filter){
		// check for internet connection
		// used for determining bootstrap packages to filter
		if(![self hasConnection]){
			[self displayErrorWithMessage:[[localize(@"Your device does not appear to be connected to the internet")
											stringByAppendingString:@"\n\n"]
											stringByAppendingString:localize(@"A network connection is required for standard backups to determine if a given package is bootstrap-vended or not")]];
			completed(NO, nil);
			return;
		}
	}

	if(!_backupManager){
		_backupManager = [[IALBackupManager alloc] init];
		[_backupManager setGeneralManager:self];
	}

	// about to do some heavy lifting ....
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		[_backupManager makeBackupWithFilter:filter andCompletion:^(BOOL done, NSString *info){
			completed(done, info);
		}];
	});
}

-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed{
	// check for internet connection
	// used (potentially) for dependency resolution of standard backup packages
	if(![self hasConnection]){
		[self displayErrorWithMessage:[[localize(@"Your device does not appear to be connected to the internet")
										stringByAppendingString:@"\n\n"]
										stringByAppendingString:localize(@"A network connection is required for restores so packages can be downloaded if need be")]];
		completed(NO);
		return;
	}

	if(!_restoreManager){
		_restoreManager = [[IALRestoreManager alloc] init];
		[_restoreManager setGeneralManager:self];
	}

	// about to do some heavy-ish lifting ....
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		[_restoreManager restoreFromBackup:backupName withCompletion:^(BOOL done){
			completed(done);
		}];
	});
}

-(BOOL)ensureBackupDirExists{
	// ensure ~/Documents/ exists
	NSError *writeError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *documentsDir = [backupDir stringByDeletingLastPathComponent];
	if(![fileManager fileExistsAtPath:documentsDir]){
		[fileManager createDirectoryAtPath:documentsDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to create %@!")
															stringByAppendingString:@"\n\n"]
															stringByAppendingString:localize(@"Info: %@")],
															documentsDir,
															writeError.localizedDescription];
			[self displayErrorWithMessage:msg];
			return NO;
		}
	}

	// check if ~/Documents/ has root ownership (it shouldn't)
	if(![fileManager isWritableFileAtPath:documentsDir]){
		NSString *msg = [NSString stringWithFormat:[[localize(@"%@ is not writeable.")
														stringByAppendingString:@"\n\n"]
														stringByAppendingString:localize(@"Please ensure that the directory's owner is mobile and not root.")],
														documentsDir];
		[self displayErrorWithMessage:msg];
		return NO;
	}

	// make backup dir if it doesn't exist already
	if(![fileManager fileExistsAtPath:backupDir]){
		[fileManager createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to create %@!")
															stringByAppendingString:@"\n\n"]
															stringByAppendingString:localize(@"Info: %@")],
															backupDir,
															writeError.localizedDescription];
			[self displayErrorWithMessage:msg];
			return NO;
		}
	}

	return YES;
}

-(BOOL)ensureUsableDpkgLock{
	// check for dpkg's tmp install file and, if it exists and has contents (padding), dpkg was interupted
	// this means that the lock-frontend is most likely locked and dpkg will be unusable until it is freed
	NSString *dpkgUpdatesDir = ROOT_PATH_NS_VAR(@"/var/lib/dpkg/updates/");
	NSString *tmpFile = [dpkgUpdatesDir stringByAppendingPathComponent:@"tmp.i"];
	if([[NSFileManager defaultManager] fileExistsAtPath:tmpFile]){
		NSError *readError = nil;
		NSString *contentsString = [NSString stringWithContentsOfFile:tmpFile encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
															stringByAppendingString:@"\n\n"]
															stringByAppendingString:localize(@"Info: %@")],
															tmpFile,
															readError.localizedDescription];
			[self displayErrorWithMessage:msg];
			return NO;
		}

		if([[contentsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] count] > 0){
			IALLog(@"dpkg appears to have been interrupted. Fixing now...");

			if(![self executeCommandAsRoot:@"unlockDpkg"]){
				[self displayErrorWithMessage:localize(@"Failed to free dpkg lock!")];
				return NO;
			}
		}
	}
	return YES;
}

-(void)cleanLog{
	NSString *log = @"/tmp/ial.log";
	// NSString *log = ROOT_PATH_NS_VAR(@"/tmp/ial.log");
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:log]){
		NSError *error = nil;
		[fileManager removeItemAtPath:log error:&error];
		if(error){
			IALLogErr(@"Failed to remove %@. Error: %@", log, error.localizedDescription);
		}
	}
}

-(BOOL)cleanupTmp{
	// has to be done as root since some files have root ownership
	BOOL ret = [self executeCommandAsRoot:@"cleanTmp"];
	if(!ret){
		NSString *msg = [NSString stringWithFormat:localize(@"Failed to cleanup %@!"), tmpDir];
		[self displayErrorWithMessage:msg];
	}
	return ret;
}

-(BOOL)updateAPT{
	// updating apt sources requires root
	BOOL ret = [self executeCommandAsRoot:@"updateAPT"];
	if(!ret){
		[self displayErrorWithMessage:localize(@"Failed to update APT sources!")];
	}
	return ret;
}

-(NSArray<NSString *> *)getBackups{
	NSError *readError = nil;
	NSArray *backupDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir error:&readError];
	if(readError){
		[self displayErrorWithMessage:[NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
																	stringByAppendingString:@" "]
																	stringByAppendingString:localize(@"Info: %@")],
																	backupDir,
																	readError.localizedDescription]];
		return [NSArray new];
	}
	else if(![backupDirContents count]){
		IALLog(@"%@ has no contents!", backupDir);
		return [NSArray new];
	}

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.tar.gz'"];
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAL-'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAmLazy-'"]; // pre v2
	NSPredicate *thePredicate2 = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, predicate2]];
	NSPredicate *thePredicate3 = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, predicate3]];
	NSArray *newBackups = [backupDirContents filteredArrayUsingPredicate:thePredicate2];
	NSArray *legacyBackups = [backupDirContents filteredArrayUsingPredicate:thePredicate3];
	if(![newBackups count] && ![legacyBackups count]){
		return [NSArray new];
	}

	NSSortDescriptor *backupVerCompare = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO comparator:^NSComparisonResult(NSString *str1, NSString *str2){
		NSCharacterSet *nonNumericChars = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
		NSMutableArray *str1Numbers = [[str1 componentsSeparatedByCharactersInSet:nonNumericChars] mutableCopy];
		NSMutableArray *str2Numbers = [[str2 componentsSeparatedByCharactersInSet:nonNumericChars] mutableCopy];

		[str1Numbers removeObject:@""];
		[str2Numbers removeObject:@""];

		return [[str1Numbers lastObject] compare:[str2Numbers lastObject] options:NSNumericSearch];
	}];
	NSArray *newSortedBackups = [newBackups sortedArrayUsingDescriptors:@[backupVerCompare]];
	NSArray *legacySortedBackups = [legacyBackups sortedArrayUsingDescriptors:@[backupVerCompare]];

	// prioritize newer backups
	return [newSortedBackups arrayByAddingObjectsFromArray:legacySortedBackups];
}

-(BOOL)executeCommandAsRoot:(NSString *)cmd{
	NSCharacterSet *alphaChars = [NSCharacterSet alphanumericCharacterSet];
	BOOL valid = ![[cmd stringByTrimmingCharactersInSet:alphaChars] length];
	if(valid){
		const char *args[] = {
			ROOT_PATH("/usr/libexec/iamlazy/AndSoAreYou"),
			[cmd UTF8String],
			NULL
		};
		int ret = task(args);
		if(ret != 0){
			IALLogErr(@"%@ failed: %d", cmd, ret);
			return NO;
		}
		return YES;
	}
	return NO;
}

-(void)updateItem:(NSInteger)item WithStatus:(CGFloat)status{
	NSString *statusStr = [NSString stringWithFormat:@"%f", status];
	NSString *name = item ? @"updateItemProgress" : @"updateItemStatus";
	#if !(CLI)
		dispatch_async(dispatch_get_main_queue(), ^(void){
			[[NSNotificationCenter defaultCenter] postNotificationName:name object:statusStr];
		});
	#else
		[[NSNotificationCenter defaultCenter] postNotificationName:name object:statusStr];
	#endif
}

-(BOOL)hasConnection{
	Reachability *reachability = [Reachability reachabilityForInternetConnection];
	BOOL reachable = YES;
	if([reachability currentReachabilityStatus] == NotReachable){
		reachable = NO;
	}
	return reachable;
}

#pragma mark Popups

-(void)displayErrorWithMessage:(NSString *)msg{
	#if !(CLI)
		dispatch_async(dispatch_get_main_queue(), ^(void){
			UIAlertController *alert = [UIAlertController
										alertControllerWithTitle:[NSString stringWithFormat:localize(@"IAmLazy Error:")]
										message:msg
										preferredStyle:UIAlertControllerStyleAlert];

			UIAlertAction *okay = [UIAlertAction
									actionWithTitle:localize(@"Okay")
									style:UIAlertActionStyleDefault
									handler:^(UIAlertAction *action){
										[_rootVC dismissViewControllerAnimated:YES completion:nil];
									}];

			[alert addAction:okay];

			// dismiss progress view controller and display error alert
			[_rootVC dismissViewControllerAnimated:YES completion:^{
				[_rootVC presentViewController:alert animated:YES completion:nil];
			}];

			AudioServicesPlaySystemSound(1107); // error

			IALLogErr(@"%@", [msg stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
		});
	#else
		IALLogErr(@"%@", [msg stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
		exit(1);
	#endif
}

@end

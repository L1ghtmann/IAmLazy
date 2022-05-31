//
//	IALGeneralManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Reachability/Reachability.h"
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "IALBackupManager.h"
#import "../Common.h"

@implementation IALGeneralManager

#pragma mark Setup

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
		[self ensureUsableDpkgLock];
	}

	return self;
}

#pragma mark Functionality

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	if(!_backupManager) _backupManager = [[IALBackupManager alloc] init];
	[_backupManager setGeneralManager:self];
	[_backupManager makeBackupOfType:type withFilter:filter];
}

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	if(![self hasConnection]){
		[self displayErrorWithMessage:@"Your device does not appear to be connected to the internet.\n\nA network connection is required for restores so packages can be downloaded if need be."];
		return;
	}

	if(!_restoreManager) _restoreManager = [[IALRestoreManager alloc] init];
	[_restoreManager setGeneralManager:self];
	[_restoreManager restoreFromBackup:backupName ofType:type];
}

-(void)ensureBackupDirExists{
	// check if Documents/ has root ownership (it shouldn't)
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager isWritableFileAtPath:@"/var/mobile/Documents/"]){
		[self displayErrorWithMessage:@"/var/mobile/Documents is not writeable.\n\nPlease ensure that the directory's owner is mobile and not root."];
		return;
	}

	// make backup and log dirs if they don't exist already
	if(![fileManager fileExistsAtPath:logDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@.\n\nError: %@", logDir, writeError];
			[self displayErrorWithMessage:msg];
			return;
		}
	}
}

-(void)ensureUsableDpkgLock{
	// check for dpkg's tmp install file and, if it exists and has contents (padding), dpkg was interupted
	// this means that the lock-frontend is most likely locked and dpkg will be unusable until it is freed
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *updatesDir = [[dpkgInfoDir stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"updates/"];
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:updatesDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@.\n\nError: %@", updatesDir, readError];
		[self displayErrorWithMessage:msg];
		return;
	}

	if(![contents count]){
		return;
	}

	NSString *tmpFile = [updatesDir stringByAppendingPathComponent:@"tmp.i"];
	if([fileManager fileExistsAtPath:tmpFile]){
		NSError *readError2 = nil;
		NSString *contentsString = [NSString stringWithContentsOfFile:tmpFile encoding:NSUTF8StringEncoding error:&readError2];
		if(readError2){
			NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@.\n\nError: %@", tmpFile, readError2];
			[self displayErrorWithMessage:msg];
			return;
		}

		if([[contentsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] count] > 0){
			NSLog(@"[IAmLazyLog] dpkg appears to have been interrupted. Fixing now...");

			[self executeCommandAsRoot:@"unlockDpkg"];
		}
	}
}

-(void)cleanupTmp{
	// has to be done as root since some files have root ownership
	[self executeCommandAsRoot:@"cleanTmp"];
}

-(void)updateAPT{
	[self executeCommandAsRoot:@"updateAPT"];
}

-(NSArray<NSString *> *)getBackups{
	NSError *readError = nil;
	NSArray *backupDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir error:&readError];
	if(readError){
		[self displayErrorWithMessage:[NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", backupDir, readError]];
		return [NSArray new];
	}

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.tar.gz'"];
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.txt'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAL-'"];
	NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAmLazy-'"]; // pre v2
	NSPredicate *predicate12 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2]];
	NSPredicate *thePredicate3 = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate12, predicate3]];
	NSPredicate *thePredicate4 = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate12, predicate4]];
	NSArray *newBackups = [backupDirContents filteredArrayUsingPredicate:thePredicate3];
	NSArray *legacyBackups = [backupDirContents filteredArrayUsingPredicate:thePredicate4];
	if(![newBackups count] && ![legacyBackups count]){
		return [NSArray new];
	}

	NSSortDescriptor *fileNameCompare = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO comparator:^NSComparisonResult(id obj1, id obj2){
		return [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch];
	}];
	NSArray *newSortedBackups = [newBackups sortedArrayUsingDescriptors:@[fileNameCompare]];
	NSArray *legacySortedBackups = [legacyBackups sortedArrayUsingDescriptors:@[fileNameCompare]];

	// prioritize newer backups
	return [newSortedBackups arrayByAddingObjectsFromArray:legacySortedBackups];
}

-(void)executeCommandAsRoot:(NSString *)cmd{
	NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
	BOOL valid = ![[cmd stringByTrimmingCharactersInSet:alphaSet] length];
	if(valid){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/libexec/iamlazy/AndSoAreYou"];
		[task setArguments:@[cmd]];
		[task launch];
		[task waitUntilExit];
	}
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
	_encounteredError = YES;

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy Error:"
								message:msg
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction *action){
								[_rootVC dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:okay];

	// dismiss progress view and display error alert
	[_rootVC dismissViewControllerAnimated:YES completion:^{
		[_rootVC presentViewController:alert animated:YES completion:nil];
	}];

	NSLog(@"[IAmLazyLog] %@", [msg stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
}

@end

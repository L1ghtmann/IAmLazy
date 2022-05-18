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
		[self displayErrorWithMessage:@"A network connection is required for restores!\n\nThis is so packages can be downloaded if need be."];
		return;
	}

	if(!_restoreManager) _restoreManager = [[IALRestoreManager alloc] init];
	[_restoreManager setGeneralManager:self];
	[_restoreManager restoreFromBackup:backupName ofType:type];
}

#pragma mark General

-(void)ensureBackupDirExists{
	// check if Documents/ has root ownership (it shouldn't)
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *msg = @"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root.";
		[self displayErrorWithMessage:msg];
		return;
	}

	// make backup and log dirs if they don't exist already
	if(![fileManager fileExistsAtPath:logDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError];
			[self displayErrorWithMessage:msg];
			return;
		}
	}
}

-(void)cleanupTmp{
	// has to be done as root since some files have root ownership
	[self executeCommandAsRoot:@"cleanTmp"];
}

-(NSString *)craftNewBackupName{
	int latestBackup;
	NSString *latest = [[self getBackups] firstObject];
	if([latest hasPrefix:@"IAL-"]){
		// get number from latest backup
		NSString *latestBackupNumber = [latest substringFromIndex:([latest rangeOfString:@"_"].location + 1)];
		latestBackup = [latestBackupNumber intValue];
	}
	else if([latest hasPrefix:@"IAmLazy-"]){ // preV2
		// get number from latest backup
		NSScanner *scanner = [[NSScanner alloc] initWithString:latest];
		[scanner setCharactersToBeSkipped:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
		[scanner scanInt:&latestBackup];
	}
	else{
		latestBackup = 0;
	}

	// grab date in desired format
	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyyMMd"];

	// craft backup name
	NSString *newBackupName = [NSString stringWithFormat:@"IAL-%@_%d", [formatter stringFromDate:[NSDate date]], (latestBackup + 1)];
	return newBackupName;
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

	NSArray *sortedBackups = [newSortedBackups arrayByAddingObjectsFromArray:legacySortedBackups];
	return sortedBackups;
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

-(BOOL)hasConnection{
	Reachability *reachability = [Reachability reachabilityForInternetConnection];
	BOOL reachable = YES;
	if([reachability currentReachabilityStatus] == NotReachable){
		reachable = NO;
	}
	return reachable;
}

@end

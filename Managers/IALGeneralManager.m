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

#pragma mark Functionality

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	if(!_backupManager) _backupManager = [[IALBackupManager alloc] init];
	[_backupManager setGeneralManager:self];
	[_backupManager makeBackupOfType:type withFilter:filter];
}

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	if(![self hasConnection]){
		[self displayErrorWithMessage:@"A network connection is required for restores!\n\nThis is so dependencies can be downloaded if need be."];
		return;
	}

	if(!_restoreManager) _restoreManager = [[IALRestoreManager alloc] init];
	[_restoreManager setGeneralManager:self];
	[_restoreManager restoreFromBackup:backupName ofType:type];
}

#pragma mark General

-(void)cleanupTmp{
	// has to be done as root since some files have root ownership
	[self executeCommandAsRoot:@"cleanTmp"];
}

-(NSString *)getLatestBackup{
	// get number from latest backup
	int latestBackup;
	NSScanner *scanner = [[NSScanner alloc] initWithString:[[self getBackups] firstObject]];
	[scanner setCharactersToBeSkipped:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
	[scanner scanInt:&latestBackup];

	// craft new backup name
	NSString *backupName = [NSString stringWithFormat:@"IAmLazy-%d", latestBackup+1];
	return backupName;
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
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAmLazy-'"];
	NSPredicate *predicate12 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2]];  // combine with "or"
	NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate12, predicate3]];  // combine with "and"
	NSArray *backups = [backupDirContents filteredArrayUsingPredicate:thePredicate];
	if(![backups count]){
		[self displayErrorWithMessage:[NSString stringWithFormat:@"%@ contains no backups!", backupDir]];
		return [NSArray new];
	}

	// sort backups (https://stackoverflow.com/a/43096808)
	NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2){
		return - [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch]; // note: "-" == NSOrderedDescending
	}];
	NSArray *sortedBackups = [backups sortedArrayUsingDescriptors:@[nameDescriptor]];
	return sortedBackups;
}

-(void)executeCommandAsRoot:(NSString *)cmd{
	NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
	BOOL valid = [[cmd stringByTrimmingCharactersInSet:alphaSet] isEqualToString:@""];
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

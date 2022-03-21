//
//	IALGeneralManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "IALBackupManager.h"
#import "../Common.h"

@implementation IALGeneralManager

+(instancetype)sharedInstance{
	static dispatch_once_t p = 0;
	__strong static IALGeneralManager *sharedInstance = nil;
	dispatch_once(&p, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
}

#pragma mark Functionality

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	if(!_backupManager) _backupManager = [[IALBackupManager alloc] init];
	[_backupManager setGeneralManager:self];
	[_backupManager makeBackupOfType:type withFilter:filter];
}

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	if(!_restoreManager) _restoreManager = [[IALRestoreManager alloc] init];
	[_restoreManager setGeneralManager:self];
	[_restoreManager restoreFromBackup:backupName ofType:type];
}

#pragma mark General

-(void)cleanupTmp{
	// has to be done as root since some files have root ownership
	[self executeCommandAsRoot:@"cleanup-tmp"];
}

-(void)cleanupTargetList{
	// remove list file now that we're done with it
	NSError *deleteError = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:targetList error:&deleteError];
	if(deleteError){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", targetList, deleteError.localizedDescription);
	}
}

-(NSString *)getLatestBackup{
	// get number from latest backup
	NSString *numberString;
	NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
	NSScanner *scanner = [NSScanner scannerWithString:[[self getBackups] firstObject]]; // get latest backup filename
	[scanner scanUpToCharactersFromSet:numbers intoString:NULL]; // remove bit before the number(s)
	[scanner scanCharactersFromSet:numbers intoString:&numberString]; // get number(s)
	int latestBackup = [numberString intValue];

	// craft new backup name
	NSString *backupName = [NSString stringWithFormat:@"IAmLazy-%d", latestBackup+1];
	return backupName;
}

-(NSArray *)getBackups{
	NSError *readError = NULL;
	NSArray *backupDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", backupDir, readError.localizedDescription);
		return [NSArray new];
	}

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.tar.gz'"];
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.txt'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAmLazy-'"];
	NSPredicate *predicate12 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2]];  // combine with "or"
	NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate12, predicate3]];  // combine with "and"
	NSArray *backups = [backupDirContents filteredArrayUsingPredicate:thePredicate];

	// sort backups (https://stackoverflow.com/a/43096808)
	NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
		return - [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch]; // note: "-" == NSOrderedDescending
	}];
	NSArray *sortedBackups = [backups sortedArrayUsingDescriptors:@[nameDescriptor]];

	return sortedBackups;
}

-(NSString *)executeCommandWithOutput:(NSString *)cmd{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", cmd]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];

	[task launch];

	NSFileHandle *handle = [pipe fileHandleForReading];
	NSData *data = [handle readDataToEndOfFile];
	[handle closeFile];

	// have to call after ^ to ensure that the output pipe doesn't fill
	// if it does, the process will hang and block waitUntilExit from returning
	[task waitUntilExit];

	NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	return output;
}

// made one for AndSoAreYou just for consistency. This isn't really necessary
-(void)executeCommandAsRoot:(NSString *)cmd{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/libexec/iamlazy/AndSoAreYou"];
	[task setArguments:@[cmd]];
	[task launch];
	[task waitUntilExit];
}

-(void)popErrorAlertWithReason:(NSString *)reason{
	[self setEncounteredError:YES];

	UIAlertController *alert = [UIAlertController
								alertControllerWithTitle:@"IAmLazy Error:"
								message:reason
								preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction
							actionWithTitle:@"Okay"
							style:UIAlertActionStyleDefault
							handler:^(UIAlertAction * action) {
								[self.rootVC dismissViewControllerAnimated:YES completion:nil];
							}];

	[alert addAction:okay];

	[self.rootVC dismissViewControllerAnimated:YES completion:^ {
		[self.rootVC presentViewController:alert animated:YES completion:nil];
	}];

	NSLog(@"[IAmLazyLog] %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
}

@end

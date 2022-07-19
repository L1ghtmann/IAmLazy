//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/libarchive.h"
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "../Common.h"

@implementation IALRestoreManager

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter postNotificationName:@"updateProgress" object:@"-0.5"];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		[_generalManager displayErrorWithMessage:@"The backup dir does not exist!"];
		return;
	}

	// check for backups
	if(![[_generalManager getBackups] count]){
		[_generalManager displayErrorWithMessage:@"No backups were found!"];
		return;
	}

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	// ensure logdir exists
	[_generalManager ensureBackupDirExists];

	[notifCenter postNotificationName:@"updateProgress" object:@"0"];

	BOOL compatible = YES;

	[notifCenter postNotificationName:@"updateProgress" object:@"0.5"];
	[self extractArchive:target];
	[notifCenter postNotificationName:@"updateProgress" object:@"1"];

	if([backupName hasSuffix:@"u.tar.gz"]){
		compatible = [self verifyBootstrapForBackup:target];
	}

	if(compatible){
		[notifCenter postNotificationName:@"updateProgress" object:@"1.5"];
		[self updateAPT];
		[notifCenter postNotificationName:@"updateProgress" object:@"2"];

		[notifCenter postNotificationName:@"updateProgress" object:@"2.5"];
		[self installDebs];
		[notifCenter postNotificationName:@"updateProgress" object:@"3"];
	}

	[_generalManager cleanupTmp];
}

-(void)extractArchive:(NSString *)backupPath{
	// extract tarball contents (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		extract_archive([backupPath UTF8String]);

		// signal that we're good to go
		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}
}

-(BOOL)verifyBootstrapForBackup:(NSString *)targetBackup{
	NSString *bootstrap = @"elucubratus";
	NSString *oldBootstrap = @"bingner_elucubratus"; // pre v2
	NSString *altBootstrap = @"procursus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oldBootstrap = @"procursus";
		altBootstrap = @"elucubratus";
	}

	BOOL check = YES;
	if([targetBackup hasSuffix:@".tar.gz"]){
		check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]];
		if(!check){
			check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, oldBootstrap]];
		}
	}

	if(!check){
		NSString *msg = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks using the %@ bootstrap.\n\nYour current jailbreak is using %@!", altBootstrap, bootstrap];
		[_generalManager displayErrorWithMessage:msg];
	}

	return check;
}

-(void)updateAPT{
	// ensure bootstrap repos' package files are up-to-date
	[_generalManager updateAPT];
}

-(void)installDebs{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"installDebs"];
}

@end

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

-(void)restoreFromBackup:(NSString *)backupName{
	_notifCenter = [NSNotificationCenter defaultCenter];
	[_notifCenter postNotificationName:@"updateItemStatus" object:@"-0.5"];
	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.0"];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		[_generalManager displayErrorWithMessage:@"The backup dir does not exist!"];
		return;
	}

	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.2"];

	// check for backups
	if(![[_generalManager getBackups] count]){
		[_generalManager displayErrorWithMessage:@"No backups were found!"];
		return;
	}

	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.4"];

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.6"];

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.8"];

	// ensure backupDir exists
	[_generalManager ensureBackupDirExists];

	[_notifCenter postNotificationName:@"updateItemProgress" object:@"1.0"];
	[_notifCenter postNotificationName:@"updateItemStatus" object:@"0"];

	BOOL compatible = YES;

	[_notifCenter postNotificationName:@"updateItemStatus" object:@"0.5"];
	[self extractArchive:target];
	[_notifCenter postNotificationName:@"updateItemStatus" object:@"1"];

	if([backupName hasSuffix:@"u.tar.gz"]){
		compatible = [self verifyBootstrapForBackup:target];
	}

	if(compatible){
		[_notifCenter postNotificationName:@"updateItemStatus" object:@"1.5"];
		[self updateAPT];
		[_notifCenter postNotificationName:@"updateItemStatus" object:@"2"];

		[_notifCenter postNotificationName:@"updateItemStatus" object:@"2.5"];
		[self installDebs];
		[_notifCenter postNotificationName:@"updateItemStatus" object:@"3"];
	}

	[_generalManager cleanupTmp];
}

-(void)extractArchive:(NSString *)backupPath{
	// extract tarball contents (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		extract_archive([backupPath UTF8String]); // UI fails to update due to hold below :/

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
	[_notifCenter postNotificationName:@"updateItemProgress" object:@"0.0"];
	[_generalManager updateAPT];
	[_notifCenter postNotificationName:@"updateItemProgress" object:@"1.0"];
}

-(void)installDebs{
	// get debs from tmpDir
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", tmpDir, readError];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}
	else if(![tmpDirContents count]){
		NSString *msg = [NSString stringWithFormat:@"%@ is empty?!", tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSMutableArray *debs = [NSMutableArray new];
	NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
	[validChars addCharactersInString:@"+-."];
	for(NSString *item in tmpDirContents){
		BOOL valid = ![[item stringByTrimmingCharactersInSet:validChars] length];
		if(valid){
			NSString *path = [tmpDir stringByAppendingPathComponent:item];
			if([[item pathExtension] isEqualToString:@"deb"]){
				[debs addObject:path];
			}
		}
	}
	if(![debs count]){
		NSString *msg = [NSString stringWithFormat:@"%@ has no debs!", tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSUInteger total = [debs count];
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;
	for(int i = 0; i < total; i++){
		// installing via apt/dpkg requires root
		[_generalManager executeCommandAsRoot:@"installDeb"];

		progress+=progressPerPart;
		[_notifCenter postNotificationName:@"updateItemProgress" object:[NSString stringWithFormat:@"%f", progress]];
	}
}

@end

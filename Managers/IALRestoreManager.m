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

-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed{
	[_generalManager updateItemStatus:-0.5];
	[_generalManager updateItemProgress:0];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		[_generalManager displayErrorWithMessage:localize(@"restore_err_1")];
		return;
	}

	[_generalManager updateItemProgress:0.2];

	// check for backups
	if(![[_generalManager getBackups] count]){
		[_generalManager displayErrorWithMessage:localize(@"restore_err_2")];
		return;
	}

	[_generalManager updateItemProgress:0.4];

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:@"%@ -- %@ -- %@!", localize(@"restore_err_3"), backupName, localize(@"restore_err_4")];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	[_generalManager updateItemProgress:0.6];

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	[_generalManager updateItemProgress:0.8];

	[_generalManager ensureBackupDirExists];

	[_generalManager updateItemProgress:1];
	[_generalManager updateItemStatus:0];

	[_generalManager updateItemStatus:0.5];
	[self extractArchive:target];
	[_generalManager updateItemStatus:1];

	BOOL compatible = YES;
	if([backupName hasSuffix:@"u.tar.gz"]){
		compatible = [self verifyBootstrapForBackup:target];
	}

	if(compatible){
		[_generalManager updateItemStatus:1.5];
		[self updateAPT];
		[_generalManager updateItemStatus:2];

		[_generalManager updateItemStatus:2.5];
		[self installDebs];
		[_generalManager updateItemStatus:3];
	}

	[_generalManager cleanupTmp];
	completed(compatible);
}

-(void)extractArchive:(NSString *)backupPath{
	extract_archive([backupPath fileSystemRepresentation]);
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
		if(!check){ // pre v2
			check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, oldBootstrap]];
		}
	}

	if(!check){
		NSString *msg = [NSString stringWithFormat:@"%@ %@ %@.\n\n%@ %@!", localize(@"restore_err_5"), altBootstrap, localize(@"bootstrap"), localize(@"restore_err_6"), bootstrap];
		[_generalManager displayErrorWithMessage:msg];
	}

	return check;
}

-(void)updateAPT{
	// ensure bootstrap repos' package files are up-to-date
	[_generalManager updateItemProgress:0];
	[_generalManager updateAPT];
	[_generalManager updateItemProgress:1];
}

-(void)installDebs{
	// get debs from tmpDir
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"%@ %@! %@: %@", localize(@"gen_err_4"), tmpDir, localize(@"info"), readError.localizedDescription];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}
	else if(![tmpDirContents count]){
		NSString *msg = [NSString stringWithFormat:@"%@ %@?!", tmpDir, localize(@"restore_err_7")];
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
		NSString *msg = [NSString stringWithFormat:@"%@ %@!", tmpDir, localize(@"restore_err_8")];
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
		[_generalManager updateItemProgress:progress];
	}
}

@end

//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/libarchive.h"
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "../../Common.h"

@implementation IALRestoreManager

-(void)restoreFromBackup:(NSString *)backupName withCompletion:(void (^)(BOOL))completed{
	[_generalManager updateItemStatus:-0.5];
	[_generalManager updateItemProgress:0];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		[_generalManager displayErrorWithMessage:localize(@"The backup dir does not exist!")];
		completed(NO);
		return;
	}

	[_generalManager updateItemProgress:0.2];

	// check for backups
	if(![[_generalManager getBackups] count]){
		[_generalManager displayErrorWithMessage:localize(@"No backups were found!")];
		completed(NO);
		return;
	}

	[_generalManager updateItemProgress:0.4];

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:localize(@"The target backup -- %@ -- could not be found!"), backupName];
		[_generalManager displayErrorWithMessage:msg];
		completed(NO);
		return;
	}

	[_generalManager updateItemProgress:0.6];

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		if(![_generalManager cleanupTmp]){
			completed(NO);
			return;
		}
	}

	[_generalManager updateItemProgress:0.8];

	if(![_generalManager ensureBackupDirExists]){
		completed(NO);
		return;
	}

	[_generalManager updateItemProgress:1];
	[_generalManager updateItemStatus:0];

	[_generalManager updateItemStatus:0.5];
	if(![self extractArchive:target]){
		completed(NO);
		return;
	}
	[_generalManager updateItemStatus:1];

	BOOL compatible = YES;
	if([backupName hasSuffix:@"u.tar.gz"]){
		compatible = [self verifyBootstrapForBackup:target];
	}

	if(compatible){
		[_generalManager updateItemStatus:1.5];
		if(![self updateAPT]){
			completed(NO);
			return;
		}
		[_generalManager updateItemStatus:2];

		[_generalManager updateItemStatus:2.5];
		if(![self installDebs]){
			completed(NO);
			return;
		}
		[_generalManager updateItemStatus:3];
	}

	if(![_generalManager cleanupTmp]){
		completed(NO);
		return;
	}
	completed(compatible);
}

-(BOOL)extractArchive:(NSString *)backupPath{
	return extract_archive([backupPath fileSystemRepresentation]);
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
		NSString *msg = [NSString stringWithFormat:[[localize(@"The backup you're trying to restore from was made for jailbreaks using the %@ bootstrap.")
														stringByAppendingString:@"\n\n"]
														stringByAppendingString:localize(@"Your current jailbreak is using %@!")],
														altBootstrap,
														bootstrap];
		[_generalManager displayErrorWithMessage:msg];
	}

	return check;
}

-(BOOL)updateAPT{
	// ensure bootstrap repos' package files are up-to-date
	[_generalManager updateItemProgress:0];
	BOOL ret = [_generalManager updateAPT];
	[_generalManager updateItemProgress:1];
	return ret;
}

-(BOOL)installDebs{
	// get debs from tmpDir
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
														stringByAppendingString:@" "]
														stringByAppendingString:localize(@"Info: %@")],
														tmpDir,
														readError.localizedDescription];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}
	else if(![tmpDirContents count]){
		NSString *msg = [NSString stringWithFormat:localize(@"%@ is empty?!"), tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}

	NSMutableArray *debs = [NSMutableArray new];
	NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
	[validChars addCharactersInString:@"+-."];
	for(NSString *item in tmpDirContents){
		BOOL valid = ![[item stringByTrimmingCharactersInSet:validChars] length];
		if(valid){
			if([[item pathExtension] isEqualToString:@"deb"]){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];
				[debs addObject:path];
			}
		}
	}
	if(![debs count]){
		NSString *msg = [NSString stringWithFormat:localize(@"%@ has no debs!"), tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}

	NSUInteger total = [debs count];
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;
	for(int i = 0; i < total; i++){
		// installing via apt/dpkg requires root
		BOOL ret = [_generalManager executeCommandAsRoot:@"installDeb"];
		if(!ret){
			NSString *msg = [NSString stringWithFormat:localize(@"Failed to install %@!"), debs[i]];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];
	}

	return YES;
}

@end

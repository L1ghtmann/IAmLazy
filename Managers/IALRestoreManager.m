//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/NVHTarGzip/NVHTarFile.h"
#import "../Compression/GZIP/NSData+GZIP.h"
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "../Common.h"

@implementation IALRestoreManager

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	// reset errors
	[_generalManager setEncounteredError:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		NSString *reason = @"The backup dir does not exist!";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for backups
	if(![[_generalManager getBackups] count]){
		NSString *reason = @"No backups were found!";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for target backup
	NSString *target = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *reason = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

	if(type == 0){
		// check for old tmp files
		if([fileManager fileExistsAtPath:tmpDir]){
			[_generalManager cleanupTmp];
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		[self unpackArchive:backupName];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make log dir if it doesn't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError = NULL;
			[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

		BOOL compatible = YES;
		if([backupName containsString:@"u.tar"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
			[self installDebs];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];
		}

		[_generalManager cleanupTmp];
	}
	else{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		// write new target list to file
		NSError *writeError = NULL;
		[target writeToFile:targetList atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write target to %@! Error: %@", targetList, writeError.localizedDescription);
			return;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make log dir if it doesn't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError2 = NULL;
			[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError2];
			if(writeError2){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError2.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

		BOOL compatible = YES;
		if([backupName containsString:@"u.txt"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
			[self installList];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];
		}

		[_generalManager cleanupTargetList];
	}
}

-(void)unpackArchive:(NSString *)backupName{
	NSString *backupPath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	NSString *tarPath = [[NSString stringWithFormat:@"/tmp/%@", backupName] stringByDeletingPathExtension];

	// convert backup to gzip data and then back to tar data
	NSData *gzipData = [NSData dataWithContentsOfFile:backupPath];
	NSData *tarData = [gzipData gunzippedData];
	NSError *writeError = NULL;
	[tarData writeToFile:tarPath options:NSDataWritingAtomic error:&writeError];
	if(writeError){
		NSLog(@"[IAmLazyLog] Failed to write tarData to file: %@", writeError.localizedDescription);
	}
	// convert tar data to tarball to extract contents from
	else{
		NVHTarFile* tarFile = [[NVHTarFile alloc] initWithPath:tarPath];
		[tarFile createFilesAndDirectoriesAtPath:tmpDir completion:^(NSError* error){
			if(error){
				NSLog(@"[IAmLazyLog] Failed to extract tarball: %@", error.localizedDescription);
			}
			// delete the tarball
			NSError *deleteError = NULL;
			[[NSFileManager defaultManager] removeItemAtPath:tarPath error:&deleteError];
			if(deleteError){
				NSLog(@"[IAmLazyLog] Failed to delete tarball: %@", deleteError.localizedDescription);
			}
		}];
	}
}

-(BOOL)verifyBootstrapForBackup:(NSString *)targetBackup{
	NSString *bootstrap = @"bingner_elucubratus";
	NSString *oppBootstrap = @"procursus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"bingner_elucubratus";
	}

	BOOL check = YES;
	if(![[targetBackup pathExtension] isEqualToString:@"txt"]){ // deb backup
		check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]];
	}
	else{ // list backuo
		check = [[NSString stringWithContentsOfFile:targetBackup encoding:NSUTF8StringEncoding error:NULL] containsString:[NSString stringWithFormat:@"## made on %@ ##", bootstrap]];
	}

	if(!check){
		NSString *reason = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[_generalManager popErrorAlertWithReason:reason];
	}

	return check;
}

-(void)installDebs{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"install-debs"];
}

-(void)installList{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"install-list"];
}

@end

//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/Light-Untar/NSFileManager+Tar.h"
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

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	if(type == 0){
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		[self unpackArchive:backupName];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make log dir if it doesn't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError = nil;
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
	}
	else{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		// prep target list
		if(![fileManager fileExistsAtPath:tmpDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}
		NSError *writeError = nil;
		[fileManager copyItemAtPath:target toPath:[tmpDir stringByAppendingPathComponent:backupName] error:&writeError];
		if(writeError){
			NSString *reason = [NSString stringWithFormat:@"Failed to copy %@. \n\nError: %@", target, writeError.localizedDescription];
			[_generalManager popErrorAlertWithReason:reason];
			return;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make log dir if it doesn't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError2 = nil;
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
	}

	[_generalManager cleanupTmp];
}

-(void)unpackArchive:(NSString *)backupName{
	dispatch_semaphore_t sema = dispatch_semaphore_create(0); // wait for async block
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{ // prevent main thread from hanging
		// convert backup to gzip data and then back to tar data
		NSString *backupPath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
		NSData *gzipData = [NSData dataWithContentsOfFile:backupPath];
		NSData *tarData = [gzipData gunzippedData];

		// extract tar data
		NSError *writeError = nil;
		[[NSFileManager defaultManager] createFilesAndDirectoriesAtPath:@"/tmp" withTarData:tarData error:&writeError progress:^(float progress){
			// extraction (basically) completed
			// math from (https://stackoverflow.com/a/18063950)
			CGFloat nearest = floorf(progress * 100 + 0.5) / 100;
			if(nearest == 1.0){
				// signal that we're good to go
				dispatch_semaphore_signal(sema);
			}
		}];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to extract tar data: %@", writeError.localizedDescription);
		}
	});
	// more stackoverflow magic (https://stackoverflow.com/a/4326754)
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    }
}

-(BOOL)verifyBootstrapForBackup:(NSString *)targetBackup{
	NSString *bootstrap = @"elucubratus";
	NSString *oppBootstrap = @"procursus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"elucubratus";
	}

	BOOL check = YES;
	if(![[targetBackup pathExtension] isEqualToString:@"txt"]){ // deb backup
		check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]];
	}
	else{ // list backup
		NSString *content = [NSString stringWithContentsOfFile:targetBackup encoding:NSUTF8StringEncoding error:NULL];
		NSArray *bits = [content componentsSeparatedByString:@"\n"];
		check = [[bits firstObject] isEqualToString:bootstrap];
	}

	if(!check){
		NSString *reason = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[_generalManager popErrorAlertWithReason:reason];
	}

	return check;
}

-(void)installDebs{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"installDebs"];
}

-(void)installList{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"installList"];
}

@end

//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "../Common.h"

@implementation IALRestoreManager

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	// reset errors
	[_generalManager setEncounteredError:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];

	// check for backup dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		NSString *reason = @"The backup dir does not exist!";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for backups
	int backupCount = [[_generalManager getBackups] count];
	if(!backupCount){
		NSString *reason = @"No backups were found!";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for target backup
	NSString *target = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	if(![[NSFileManager defaultManager] fileExistsAtPath:target]){
		NSString *reason = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

	if(type == 0){
		// check for old tmp files
		if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
			[_generalManager cleanupTmp];
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		[self unpackArchive:backupName];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make log dir if it doesn't exist already
		if(![[NSFileManager defaultManager] fileExistsAtPath:logDir]){
			NSError *writeError = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

		BOOL compatible = YES;
		if([backupName containsString:@"u.tar"]){
			compatible = [self verifyBootstrapOfTarball];
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

		BOOL compatible = YES;
		if([backupName containsString:@"u.txt"]){
			compatible = [self verifyBootstrapOfList:target];
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
	[_generalManager executeCommand:[NSString stringWithFormat:@"tar -xf %@%@ -C /tmp", backupDir, backupName]];
}

-(BOOL)verifyBootstrapOfTarball{
	NSString *bootstrap = @"bingner_elucubratus";
	NSString *oppBootstrap = @"procursus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"bingner_elucubratus";
	}

	if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]]){
		NSString *reason = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[_generalManager popErrorAlertWithReason:reason];
		return NO;
	}

	return YES;
}

-(BOOL)verifyBootstrapOfList:(NSString *)list{
	NSString *bootstrap = @"bingner_elucubratus";
	NSString *oppBootstrap = @"procursus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"bingner_elucubratus";
	}

	if(![[NSString stringWithContentsOfFile:list encoding:NSUTF8StringEncoding error:NULL] containsString:bootstrap]){
		NSString *reason = [NSString stringWithFormat:@"The list you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[_generalManager popErrorAlertWithReason:reason];
		return NO;
	}

	return YES;
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

#import "IAmLazyManager.h"
#import "Common.h"

@implementation IAmLazyManager

+(instancetype)sharedInstance {
	static dispatch_once_t p = 0;
    __strong static IAmLazyManager* sharedInstance = nil;
    dispatch_once(&p, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void)makeTweakBackup{
	NSLog(@"IAmLazyLog starting tweak backup . . .");

	// make note of start time
	self.startTime = [NSDate date];

	// check if Documents/ has root ownership
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = [NSString stringWithFormat:@"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root"];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", reason);
		return;
	}

	// check for old tmp files
	if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		NSLog(@"IAmLazyLog found old tmp files!");
		[self cleanupTmp];
	}

	// get all packages
	self.allPackages = [self getAllPackages];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

	// filter out bootstrap-specific packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
	self.userPackages = [self getUserPackages];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

	// make fresh tmp directory
	if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
	}

	// gather bits for packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
	[self gatherDebFiles];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

	// build debs from bits
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2.7"];
	[self buildDebs];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"3"];

	// make archive of all packages and cleanup after ourselves
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"3.7"];
	[self makeTarball];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"4"];

	// check that the backup size looks right (kb or b means something likely went wrong)
	[self verifyBackup];

	// make note of end time
	self.endTime = [NSDate date];

	NSLog(@"IAmLazyLog tweak backup completed in %@ seconds!", [self getDuration]);
}

-(NSArray *)getAllPackages{
	NSMutableArray *allPackages = [NSMutableArray new];

	NSString *output = [self executeCommandWithOutput:@"dpkg-query -W --showformat '${Package}\n'" andWait:YES];
	NSArray *lines = [output componentsSeparatedByString:@"\n"]; // split at newlines

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] 'gsc.'"]; // filter unwanted local packages
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] 'cy+'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] 'firmware'"];
	NSPredicate *thePredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2, predicate3]];  // combine with "or"
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the antipredicate of ^
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];

	for(NSString *package in packages){
		if([package length]){
			[allPackages addObject:package];
		}
	}

	NSLog(@"IAmLazyLog %lu total packages", allPackages.count);

	return allPackages;
}

-(NSArray *)getUserPackages{
	NSLog(@"IAmLazyLog filtering for user packages . . .");

	NSMutableArray *userPackages = [NSMutableArray new];

	// filter out bootstrap packages and coolstar's packages/packages that depend on their packages, as they aren't cross-compatible
	NSArray *maintainers = [NSArray arrayWithObjects:@"Sam Bingner", @"Jay Freeman (saurik)", @"Hayden Seay", @"CoolStar", @"coolstar", nil];

	for(NSString *package in self.allPackages){
		NSString *info = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg -s %@", package] andWait:YES];

		BOOL bootstrapPackage = NO;
		for(NSString *maintainer in maintainers){
			if([info rangeOfString:maintainer].location != NSNotFound){
				bootstrapPackage = YES;
				break;
			}
		}

		// also filter out IAmLazy since it'll be installed anyway
		if(!bootstrapPackage && ![package isEqualToString:@"me.lightmann.iamlazy"]){
			[userPackages addObject:package];
		}
	}

	NSLog(@"IAmLazyLog %lu user packages", userPackages.count);

	// get size estimate (used for verifcation later)
	NSString *output = [self executeCommandWithOutput:@"dpkg-query -Wf '${Package}\n${Installed-Size}\n'" andWait:YES];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	int index = 0;
	int userPackagesTotal = 0;
	for(NSString *line in lines){
		if([userPackages containsObject:line]){
			userPackagesTotal += [lines[index+1] intValue];
		}
		index++;
	}

	[self setEstimatedBackupSize:(userPackagesTotal/1000)*.5]; // kilobytes -> megabytes, then halved

	return userPackages;
}

-(void)gatherDebFiles{
	NSLog(@"IAmLazyLog gathering deb files . . .");

	// get file paths for packages
	for(NSString *package in self.userPackages){
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];

		// make dir to hold stuff for the tweak
		if(![[NSFileManager defaultManager] fileExistsAtPath:tweakDir]){
			[[NSFileManager defaultManager] createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:nil];
		}

		NSMutableArray *files = [NSMutableArray new];

		NSString *output = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -L %@", package] andWait:NO];
		NSArray *lines = [output componentsSeparatedByString:@"\n"]; // split at newline

		// find known files
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF contains[c] '.'"];
		NSArray *knownFiles = [lines filteredArrayUsingPredicate:thePredicate];
		for(NSString *path in knownFiles){
			// ignore these
			if([path isEqualToString:@"/."] || ![path length]){
				continue;
			}
			else {
				[files addObject:path];
			}
		}

		// find lingering things
		NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate];
		NSArray *otherStuff = [lines filteredArrayUsingPredicate:theAntiPredicate];
		for(NSString *path in otherStuff){
			// ignore these
			if([path isEqualToString:@"/."] || ![path length]){
				continue;
			}
			// check if path leads to dir and if not, copy
			else{
				if(![[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileType] isEqualToString:@"NSFileTypeDirectory"]){
					[files addObject:path];
				}
			}
		}

		// put all files-to-copy in a list for easier writing
		NSString *filePaths = [[files valueForKey:@"description"] componentsJoinedByString:@"\n"];

		// this is nice because it overwrites the file content, unlike the write method from NSFileManager
		BOOL fileList = [filePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:nil];
		if(!fileList){
			NSString *reason = [NSString stringWithFormat:@"failed to make filesToCopy.txt"];
			[self popErrorAlertWithReason:reason];
			NSLog(@"IAmLazyLog %@", reason);
		}

		// give 'go' for files to be copied
		if([[NSFileManager defaultManager] fileExistsAtPath:filesToCopy]){
			[self copyFilesToDirectory:tweakDir];
		}
		else{
			NSLog(@"IAmLazyLog filesToCopy.txt blank or DNE");
		}

		// make control file
		[self makeControlForPackage:package inDirectory:tweakDir];
	}

	// remove filesToCopy.txt now that we're done
	[self executeCommand:[NSString stringWithFormat:@"rm %@", filesToCopy]];

	NSLog(@"IAmLazyLog gathered deb files!");
}

-(void)copyFilesToDirectory:(NSString *)tweakDir{
	NSString *fileContents = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:nil];
	NSArray *files = [fileContents componentsSeparatedByString:@"\n"];
	NSLog(@"IAmLazyLog copying %lu files to %@", [files count], tweakDir);

	// has to be copied as root in order to retain attributes (ownership, etc)
	[self executeCommandAsRoot:@[@"copy-files", tweakDir]];
}

-(void)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
	NSLog(@"IAmLazyLog making control file for %@ in %@ . . .", package, tweakDir);

	// get info for package
	NSString *output = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -s %@", package] andWait:YES];
	NSString *noStatusLine = [output stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""];

	NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];

	// make DEBIAN dir
	if (![[NSFileManager defaultManager] fileExistsAtPath:debian]){
		[[NSFileManager defaultManager] createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:nil];
	}

	// write info to file
	BOOL control = [[NSFileManager defaultManager] createFileAtPath:[debian stringByAppendingPathComponent:@"control"] contents:[noStatusLine dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
	if(!control){
		NSString *reason = [NSString stringWithFormat:@"failed to make control file for %@", package];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", reason);
	}
}

-(void)buildDebs{
	NSLog(@"IAmLazyLog building debs . . .");

	for(NSString *package in self.userPackages){
		NSString *packageDir = [NSString stringWithFormat:@"%@%@", tmpDir, package];
		[self executeCommand:[NSString stringWithFormat:@"dpkg-deb -b %@", packageDir]];
	}

	NSLog(@"IAmLazyLog built debs!");

	[self cleanupTmpSubDirs];
}

-(void)cleanupTmpSubDirs{
	NSLog(@"IAmLazyLog cleaning up tmp subdirs . . .");

	// has to be done as root since files have root perms
	// doing each dir explicitly to ensure no accidental deletions
	for(NSString *packageName in self.userPackages){
		[self executeCommandAsRoot:@[@"post-build", packageName]];
	}

	NSLog(@"IAmLazyLog cleaned up tmp subdirs!");
}

-(void)makeTarball{
	NSLog(@"IAmLazyLog making tarball . . .");

	// make backup dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		[[NSFileManager defaultManager] createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:nil];
	}

	int latestBackup = [self getLatestBackup];

	NSString *backupName = [NSString stringWithFormat:@"IAmLazy-%d.tar.xz", latestBackup+1];

	[self executeCommand:[NSString stringWithFormat:@"cd %@ && tar --remove-files -cJf %@ -C /var/tmp me.lightmann.iamlazy", backupDir, backupName]];

	NSLog(@"IAmLazyLog made %@ and cleaned up tmp dir!", backupName);
}

-(void)verifyBackup{
	NSLog(@"IAmLazyLog verifying backup . . .");

	NSString *path = [NSString stringWithFormat:@"%@IAmLazy-%d.tar.xz", backupDir, [self getLatestBackup]];

	if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
		NSString *reason = [NSString stringWithFormat:@"%@ doesn't exist!", path];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", reason);
		return;
	}

	CGFloat backupSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize]/1000000; // bytes -> megabytes

	if(backupSize >= self.estimatedBackupSize*.5 && backupSize <= self.estimatedBackupSize*1.5){
		NSLog(@"IAmLazyLog backup looks good!");
	}
	else{
		NSString *reason = [NSString stringWithFormat:@"Something went wrong. \n\n%@ doesn't look right. \n\nPlease try making another backup", path];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", reason);

		// delete the backup since it doesn't look too hot
		[self executeCommand:[NSString stringWithFormat:@"rm %@", path]];
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [self.endTime timeIntervalSinceDate:self.startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

-(void)restoreFromBackup{
	NSLog(@"IAmLazyLog restoring from latest backup . . .");

	BOOL check1 = YES;
	BOOL check2 = YES;
	BOOL check3 = YES;

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];

	// check for backup dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		check1 = NO;
	}

	if(check1){
		int backupCount = [[self getBackups] count];

		// check for backups
		if(!backupCount){
			check2 = NO;
		}

		if(check2){
			NSString *latestBackupName = [NSString stringWithFormat:@"IAmLazy-%d.tar.xz", [self getLatestBackup]];

			// check for target backup
			if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", backupDir, latestBackupName]]){
				check3 = NO;
			}

			if(check3){
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

				// check for old tmp files
				if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
					NSLog(@"IAmLazyLog found old tmp files!");
					[self cleanupTmp];
				}

				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
				[self unpackArchive:latestBackupName];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
				[self installDebs];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

				NSLog(@"IAmLazyLog successfully restored from backup (%@)!", latestBackupName);
			}
			else{
				NSString *reason = [NSString stringWithFormat:@"target backup -- %@ -- could not be found!", latestBackupName];
				[self popErrorAlertWithReason:reason];
				NSLog(@"IAmLazyLog restore aborted because: %@", reason);
			}
		}
		else{
			NSString *reason = @"no backups were found!";
			[self popErrorAlertWithReason:reason];
			NSLog(@"IAmLazyLog restore aborted because: %@", reason);
		}
	}
	else{
		NSString *reason = @"backup dir does not exist!";
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog restore aborted because: %@", reason);
	}
}

-(void)restoreFromBackup:(NSString *)backupName{
	NSLog(@"IAmLazyLog restoring from %@ . . .", backupName);

	BOOL check1 = YES;
	BOOL check2 = YES;
	BOOL check3 = YES;

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];

	// check for backup dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		check1 = NO;
	}

	if(check1){
		int backupCount = [[self getBackups] count];

		// check for backups
		if(!backupCount){
			check2 = NO;
		}

		if(check2){
			// check for target backup
			if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", backupDir, backupName]]){
				check3 = NO;
			}

			if(check3){
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

				// check for old tmp files
				if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
					NSLog(@"IAmLazyLog found old tmp files!");
					[self cleanupTmp];
				}

				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
				[self unpackArchive:backupName];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
				[self installDebs];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

				NSLog(@"IAmLazyLog successfully restored from backup (%@)!", backupName);
			}
			else{
				NSString *reason = [NSString stringWithFormat:@"target backup -- %@ -- could not be found!", backupName];
				[self popErrorAlertWithReason:reason];
				NSLog(@"IAmLazyLog restore aborted because: %@", reason);
			}
		}
		else{
			NSString *reason = @"no backups were found!";
			[self popErrorAlertWithReason:reason];
			NSLog(@"IAmLazyLog restore aborted because: %@", reason);
		}
	}
	else{
		NSString *reason = @"backup dir does not exist!";
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog restore aborted because: %@", reason);
	}
}

-(void)unpackArchive:(NSString *)backupName{
	NSLog(@"IAmLazyLog unpacking archive . . .");

	[self executeCommand:[NSString stringWithFormat:@"cd %@ && tar --xz -xf %@ -C /var/tmp", backupDir, backupName]];

	NSLog(@"IAmLazyLog unpacked archive!");
}

-(void)installDebs{
	NSLog(@"IAmLazyLog installing debs . . .");

	[self executeCommandAsRoot:@[@"install-debs"]];

	NSLog(@"IAmLazyLog installed debs!");

	[self cleanupTmp];
}

-(CGFloat)getSizeOfAllPackages{
	NSString *output = [self executeCommandWithOutput:@"dpkg-query -Wf '${Installed-Size}\n'" andWait:YES];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	int totalkbSize = 0;
	for(NSString *line in lines){
		if([line length]){
			totalkbSize += [line intValue];
		}
	}

	// use 1/3 of this value as a rough estimate for the backup size
	// this really isn't that accurate, but it gives a good ballpark figure
	CGFloat totalSizeInMB = totalkbSize/1000;

	return totalSizeInMB;
}

-(NSArray *)getBackups{
	NSMutableArray *backups = [NSMutableArray new];

	NSArray *backupDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir error:NULL];
	[backupDirContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *filename = (NSString *)obj;
		NSString *extension = [[filename pathExtension] lowercaseString];
		if([extension isEqualToString:@"xz"]){
			[backups addObject:filename];
		}
	}];

	return backups;
}

-(int)getLatestBackup{
	int latestBackup = 0;

	NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
	for(NSString *fileName in [self getBackups]){
		NSString *numberString;

		NSScanner *scanner = [NSScanner scannerWithString:fileName];
		[scanner scanUpToCharactersFromSet:numbers intoString:NULL]; // remove bit before the number(s)
		[scanner scanCharactersFromSet:numbers intoString:&numberString]; // get number(s)
		int backupNumber = [numberString intValue];

		if(backupNumber > latestBackup) latestBackup = backupNumber;
		else continue;
	}

	return latestBackup;
}

-(void)cleanupTmp{
	NSLog(@"IAmLazyLog cleaning up tmp dir . . .");

	[self executeCommand:[NSString stringWithFormat:@"rm -rf %@", tmpDir]];

	NSLog(@"IAmLazyLog cleaned up tmp dir!");
}

// Note: using the desired binaries (e.g., rm, rsync) as the launch path occasionally causes a crash (EXC_CORPSE_NOTIFY) because abort() was called???
// to fix this, switched the launch path to bourne shell and, voila, no crash!
-(void)executeCommand:(NSString *)cmd{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", cmd]];
	[task launch];
	[task waitUntilExit];
}

-(NSString *)executeCommandWithOutput:(NSString *)cmd andWait:(BOOL)wait{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", cmd]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];

	[task launch];
	if(wait) [task waitUntilExit];

	NSFileHandle *handle = [pipe fileHandleForReading];
	NSData *data = [handle readDataToEndOfFile];
	NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	return output;
}

// made one for AndSoAreYou just for consistency. This isn't really necessary
-(void)executeCommandAsRoot:(NSArray *)args{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/libexec/iamlazy/AndSoAreYou"];
	[task setArguments:args];
	[task launch];
	[task waitUntilExit];
}

-(void)popErrorAlertWithReason:(NSString *)reason{
	self.encounteredError = YES;

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy encountered an error:" message:reason preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self.rootVC dismissViewControllerAnimated:YES completion:nil];
	}];

    [alert addAction:okay];

	[self.rootVC dismissViewControllerAnimated:YES completion:^ {
		[self.rootVC presentViewController:alert animated:YES completion:nil];
	}];
}

@end

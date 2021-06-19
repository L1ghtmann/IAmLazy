#import "IAmLazyManager.h"
#import "Common.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IAmLazyManager

+(instancetype)sharedInstance{
	static dispatch_once_t p = 0;
    __strong static IAmLazyManager* sharedInstance = nil;
    dispatch_once(&p, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void)makeTweakBackupWithFilter:(BOOL)filter{
	NSLog(@"IAmLazyLog starting tweak backup . . .");

	// reset errors
	[self setEncounteredError:NO];

	// make note of start time
	[self setStartTime:[NSDate date]];

	// check if Documents/ has root ownership (it shouldn't)
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = [NSString stringWithFormat:@"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root"];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
		return;
	}

	// check for old tmp files
	if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		NSLog(@"IAmLazyLog found old tmp files!");
		[self cleanupTmp];
	}

	// get all packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];
	NSArray *allPackages = [self getAllPackages];
	if(![allPackages count]){
		NSString *reason = [NSString stringWithFormat:@"Failed to generate list of installed packages! \n\nPlease try again."];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
		return;
	}
	[self setAllPackages:allPackages];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

	// filter out bootstrap-specific packages (or not)
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
	if(filter){
		NSArray *userPackages = [self getUserPackages];
		if(![userPackages count]){
			NSString *reason = [NSString stringWithFormat:@"Failed to filter list for user packages! \n\nPlease try again."];
			[self popErrorAlertWithReason:reason];
			NSLog(@"IAmLazyLog %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
			return;
		}
		[self setUserPackages:userPackages];
	}
	else [self setUserPackages:self.allPackages];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

	// gather bits for packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
	[self gatherDebFiles];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

	// build debs from bits
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2.7"];
	[self buildDebs];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"3"];

	// for unfiltered backups, create hidden file specifying the bootstrap it was created on
	if(!filter) [self makeBootstrapFile];

	// make archive of all packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"3.7"];
	[self makeTarballWithFilter:filter];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"4"];

	// make note of end time
	[self setEndTime:[NSDate date]];

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
		// filter out IAmLazy since it'll be installed anyway
		if([package length] && ![package isEqualToString:@"me.lightmann.iamlazy"]){
			[allPackages addObject:package];
		}
	}

	NSLog(@"IAmLazyLog %lu total packages", [allPackages count]);

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

		if(!bootstrapPackage){
			[userPackages addObject:package];
		}
	}

	NSLog(@"IAmLazyLog %lu user packages", userPackages.count);

	return userPackages;
}

-(void)gatherDebFiles{
	NSLog(@"IAmLazyLog gathering bits for debs . . .");

	for(NSString *package in self.userPackages){
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
				if(![[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileType] isEqualToString:@"NSFileTypeDirectory"]){
					[files addObject:path];
				}
			}
		}

		// put all the files we want copied in a list for easier writing
		NSString *filePaths = [[files valueForKey:@"description"] componentsJoinedByString:@"\n"];

		// make fresh tmp directory
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
			[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		[filePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];

		// make dir to hold stuff for the tweak
		if(![[NSFileManager defaultManager] fileExistsAtPath:tweakDir]){
			[[NSFileManager defaultManager] createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:NULL];
		}

		// give 'go' for files to be copied
		if([[NSFileManager defaultManager] fileExistsAtPath:filesToCopy]){
			[self copyFilesToDirectory:tweakDir];
		}
		else{
			NSLog(@"IAmLazyLog filesToCopy.txt DNE for %@", package);
		}

		// make control file
		[self makeControlForPackage:package inDirectory:tweakDir];
	}

	// remove filesToCopy.txt now that we're done using it
	[[NSFileManager defaultManager] removeItemAtPath:filesToCopy error:NULL];

	NSLog(@"IAmLazyLog gathered bits for debs!");
}

-(void)copyFilesToDirectory:(NSString *)tweakDir{
	NSString *fileContents = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:NULL];
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
	if(![[NSFileManager defaultManager] fileExistsAtPath:debian]){
		[[NSFileManager defaultManager] createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	// write info to file
	[[NSFileManager defaultManager] createFileAtPath:[debian stringByAppendingPathComponent:@"control"] contents:[noStatusLine dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

-(void)buildDebs{
	NSLog(@"IAmLazyLog building debs . . .");

	for(NSString *package in self.userPackages){
		NSString *packageDir = [NSString stringWithFormat:@"%@%@", tmpDir, package];
		[self executeCommand:[NSString stringWithFormat:@"dpkg-deb -b %@", packageDir]];
	}

	NSLog(@"IAmLazyLog built debs!");
}

-(void)makeBootstrapFile{
	NSLog(@"IAmLazyLog making hidden bootstrap file . . .");

	NSString *bootstrap = @"bingner_elucubratus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
	}
	NSString *file = [NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap];
	[[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];

	NSLog(@"IAmLazyLog made hidden bootstrap file!");
}

-(void)makeTarballWithFilter:(BOOL)filter{
	NSLog(@"IAmLazyLog making tarball . . .");

	// get number from latest backup
	NSString *numberString;
	NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
	NSScanner *scanner = [NSScanner scannerWithString:[[self getBackups] firstObject]]; // get latest backup filename
	[scanner scanUpToCharactersFromSet:numbers intoString:NULL]; // remove bit before the number(s)
	[scanner scanCharactersFromSet:numbers intoString:&numberString]; // get number(s)
	int latestBackup = [numberString intValue];

	// craft new backup name
	NSString *backupName;
	if(filter) backupName = [NSString stringWithFormat:@"IAmLazy-%d.tar.xz", latestBackup+1];
	else backupName = [NSString stringWithFormat:@"IAmLazy-%du.tar.xz", latestBackup+1];

	// make backup dir if it doesn't exist already
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		[[NSFileManager defaultManager] createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	// make tarball (excludes subdirs in tmp dir)
	// note: bourne shell doesn't support glob qualifiers (hence the "find ...." ugliness)
	// ensure file structure is only me.lightmann.iamlazy/ not /var/tmp/me.lightmann.iamlazy/ (having --strip-components=2 on the restore end breaks compatibility w older backups)
	[self executeCommand:[NSString stringWithFormat:@"cd /var/tmp && find ./me.lightmann.iamlazy -maxdepth 1 ! -type d -print0 | xargs -0 tar -cJf %@%@", backupDir, backupName]];

	NSLog(@"IAmLazyLog made %@!", backupName);

	[self cleanupTmp];
	[self verifyBackup:backupName];
}

-(void)verifyBackup:(NSString *)backupName{
	NSLog(@"IAmLazyLog verifying backup . . .");

	NSString *path = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
		NSString *reason = [NSString stringWithFormat:@"%@ doesn't exist!", path];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog %@", reason);
		return;
	}

	NSLog(@"IAmLazyLog backup looks good!");
}

-(NSString *)getDuration{
	NSTimeInterval duration = [self.endTime timeIntervalSinceDate:self.startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

-(void)restoreFromBackup:(NSString *)backupName{
	NSLog(@"IAmLazyLog restoring from %@ . . .", backupName);

	// reset errors
	[self setEncounteredError:NO];

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

				BOOL compatible = YES;
				if([backupName containsString:@"u.tar.xz"]){
					compatible = [self verifyBootstrap];
				}

				if(compatible){
					[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
					[self installDebs];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

					NSLog(@"IAmLazyLog successfully restored from backup (%@)!", backupName);
				}
			}
			else{
				NSString *reason = [NSString stringWithFormat:@"Target backup -- %@ -- could not be found!", backupName];
				[self popErrorAlertWithReason:reason];
				NSLog(@"IAmLazyLog restore aborted because: %@", reason);
			}
		}
		else{
			NSString *reason = @"No backups were found!";
			[self popErrorAlertWithReason:reason];
			NSLog(@"IAmLazyLog restore aborted because: %@", reason);
		}
	}
	else{
		NSString *reason = @"The backup dir does not exist!";
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog restore aborted because: %@", reason);
	}
}

-(void)unpackArchive:(NSString *)backupName{
	NSLog(@"IAmLazyLog unpacking archive . . .");

	[self executeCommand:[NSString stringWithFormat:@"tar --xz -xf %@%@ -C /var/tmp", backupDir, backupName]];

	NSLog(@"IAmLazyLog unpacked archive!");
}

-(BOOL)verifyBootstrap{
	NSLog(@"IAmLazyLog verifying that the device is on a compatible bootstrap . . .");

	NSString *bootstrap = @"bingner_elucubratus";
	NSString *oppBootstrap = @"procursus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"bingner_elucubratus";
	}

	if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]]){
		NSString *reason = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[self popErrorAlertWithReason:reason];
		NSLog(@"IAmLazyLog restore aborted because: %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
		return NO;
	}

	NSLog(@"IAmLazyLog bootstrap looks good! Proceeding with the restore . . .");

	return YES;
}

-(void)installDebs{
	NSLog(@"IAmLazyLog installing debs . . .");

	[self executeCommandAsRoot:@[@"install-debs"]];

	NSLog(@"IAmLazyLog installed debs!");

	[self cleanupTmp];
}

-(void)cleanupTmp{
	NSLog(@"IAmLazyLog cleaning up tmp dir . . .");

	// adjust tmp dir perms and delete
	[self executeCommandAsRoot:@[@"pre-cleanup"]];
	[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];

	NSLog(@"IAmLazyLog cleaned up tmp dir!");
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

	// sort backups (https://stackoverflow.com/a/43096808)
	NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES comparator:^NSComparisonResult(id obj1, id obj2) {
		return - [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch]; // note: "-" == NSOrderedDescending
	}];
	NSArray *sortedBackups = [backups sortedArrayUsingDescriptors:@[nameDescriptor]];

	return sortedBackups;
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
	[handle closeFile];
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
	[self setEncounteredError:YES];

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"IAmLazy Error:" message:reason preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction *okay = [UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
		[self.rootVC dismissViewControllerAnimated:YES completion:nil];
	}];

    [alert addAction:okay];

	[self.rootVC dismissViewControllerAnimated:YES completion:^ {
		[self.rootVC presentViewController:alert animated:YES completion:nil];
	}];
}

@end

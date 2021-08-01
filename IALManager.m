#import "IALManager.h"
#import "Common.h"

// Lightmann
// Made during covid
// IAmLazy

@implementation IALManager

+(instancetype)sharedInstance{
	static dispatch_once_t p = 0;
    __strong static IALManager* sharedInstance = nil;
    dispatch_once(&p, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark Backup

-(void)makeTweakBackupWithFilter:(BOOL)filter{
	// reset errors
	[self setEncounteredError:NO];

	// make note of start time
	[self setStartTime:[NSDate date]];

	// check if Documents/ has root ownership (it shouldn't)
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = @"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root.";
		[self popErrorAlertWithReason:reason];
		return;
	}

	// check for old tmp files
	if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		[self cleanupTmp];
	}

	// get all packages
	if(!filter){
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];
		NSArray *allPackages = [self getAllPackages];
		if(![allPackages count]){
			NSString *reason = @"Failed to generate list of installed packages! \n\nPlease try again.";
			[self popErrorAlertWithReason:reason];
			return;
		}
		[self setPackages:allPackages];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];
	}

	// get user packages (filter out bootstrap packages)
	else{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];
		NSArray *userPackages = [self getUserPackages];
		if(![userPackages count]){
			NSString *reason = @"Failed to generate list of user packages! \n\nPlease try again.";
			[self popErrorAlertWithReason:reason];
			return;
		}
		[self setPackages:userPackages];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];
	}

	// make fresh tmp directory
	if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		NSError *error = NULL;
		[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&error];
		if(error){
			NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, error.localizedDescription];
			[self popErrorAlertWithReason:reason];
			return;
		}
	}

	// gather bits for packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
	[self gatherPackageFiles];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

	// build debs from bits
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
	[self buildDebs];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

	// for unfiltered backups, create hidden file specifying the bootstrap it was created on
	if(!filter) [self makeBootstrapFile];

	// make backup dir if it doesn't exist already
	if(![[NSFileManager defaultManager] fileExistsAtPath:backupDir]){
		NSError *error = NULL;
		[[NSFileManager defaultManager] createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:&error];
		if(error){
			NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", backupDir, error.localizedDescription];
			[self popErrorAlertWithReason:reason];
			return;
		}
	}

	// make archive of all packages
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2.7"];
	[self makeTarballWithFilter:filter];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"3"];

	// make note of end time
	[self setEndTime:[NSDate date]];
}

-(NSArray *)getAllPackages{
	NSMutableArray *allPackages = [NSMutableArray new];

	NSString *output = [self executeCommandWithOutput:@"dpkg-query -Wf '${Package;-50}${Priority}\n'" andWait:YES];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF endswith 'required'"]; // filter out local packages
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the opposite of ^
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];

	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed by the user anyway
		if([line length] && ![line containsString:@"me.lightmann.iamlazy"]){
			NSArray *bits = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if([bits count]) [allPackages addObject:bits.firstObject];
		}
	}

	return allPackages;
}

-(NSArray *)getUserPackages{
	NSMutableArray *userPackages = [NSMutableArray new];

	NSString *output = [self executeCommandWithOutput:@"dpkg-query -Wf '${Package;-50}${Maintainer}\n'" andWait:YES];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF contains 'Sam Bingner'"]; // filter out bootstrap packages
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF contains 'Jay Freeman (saurik)'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF contains 'Hayden Seay'"];
	NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"SELF contains 'CoolStar'"];
	NSPredicate *thePredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2, predicate3, predicate4]];  // combine with "or"
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the opposite of ^
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];

	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed by the user anyway
		if([line length] && ![line containsString:@"me.lightmann.iamlazy"]){
			NSArray *bits = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if([bits count]) [userPackages addObject:bits.firstObject];
		}
	}

	return userPackages;
}

-(void)gatherPackageFiles{
	for(NSString *package in self.packages){
		NSMutableArray *files = [NSMutableArray new];

		NSString *output = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -L %@", package] andWait:NO]; // will hang if wait == YES
		NSArray *lines = [output componentsSeparatedByString:@"\n"];
		for(NSString *line in lines){
			if(![line length] || [line isEqualToString:@"/."]){
				continue; // disregard
			}
			// TODO: find a more elegant way of doing this
			// some packages contain 1 instance of the following paths in their lists, meaning they will be picked up below and copied, which we don't want as they're general
			else if([line isEqualToString:@"/Library/MobileSubstrate"] || [line isEqualToString:@"/Library/PreferenceBundles"] || [line isEqualToString:@"/Library/PreferenceLoader/Preferences"] || [line isEqualToString:@"/usr/bin"]){
				continue; // disregard
			}

			// check to see how many times the current filepath is present in the list output
			// shoutout Cœur on StackOverflow for this efficient code (https://stackoverflow.com/a/57869286)
			int count = [[NSMutableString stringWithString:output] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, output.length)];

			if(count == 1){ // this is good; means it's unique!
				[files addObject:line];
			}
			else{
				// sometimes files will have similar names (e.g., /usr/bin/zip, /usr/bin/zipcloak, /usr/bin/zipnote, /usr/bin/zipsplit)
				// though /usr/bin/zip will have a count > 1, since it's present in the other filepaths, we want to avoid disregarding it
				// since it's a valid file. instead, we want to disregard all dirs and symlinks that don't lead to files that are part of
				// the package's list structure. in the above example, that would mean disregarding /usr and /usr/bin
				NSError *readError = NULL;
				NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:line error:&readError];
				if(readError){
					NSLog(@"[IAmLazyLog] Failed to get attributes for %@! Error: %@", line, readError.localizedDescription);
					continue;
				}

				NSString *type = [fileAttributes fileType];
				if(![type isEqualToString:@"NSFileTypeDirectory"] && ![type isEqualToString:@"NSFileTypeSymbolicLink"]){
					[files addObject:line];
				}
				else if([type isEqualToString:@"NSFileTypeSymbolicLink"]){
					// want to grab any symlniks that lead to files, but ignore those that lead to dirs
					// this will traverse any links and check for the existence of a file at the link's final destination
					BOOL isDir = NO;
					if([[NSFileManager defaultManager] fileExistsAtPath:line isDirectory:&isDir] && !isDir){
						[files addObject:line];
					}
				}
			}
		}

		// put all the files we want copied in a list for easier writing
		NSString *filePaths = [[files valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![filePaths length]){
			NSLog(@"[IAmLazyLog] filePaths list is blank for %@!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError = NULL;
		[filePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write filePaths to %@ for %@! Error: %@", filesToCopy, package, writeError.localizedDescription);
			continue;
		}

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];

		// make dir to hold stuff for the tweak
		if(![[NSFileManager defaultManager] fileExistsAtPath:tweakDir]){
			NSError *error = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:&error];
			if(error){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", tweakDir, writeError.localizedDescription);
				continue;
			}
		}

		// again, this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError2 = NULL;
		[tweakDir writeToFile:targetDirectory atomically:YES encoding:NSUTF8StringEncoding error:&writeError2];
		if(writeError2){
			NSLog(@"[IAmLazyLog] Failed to write tweakDir to %@ for %@! Error: %@", targetDirectory, package, writeError2.localizedDescription);
			continue;
		}

		[self copyFilesToTargetDirectory];
		[self makeControlForPackage:package inDirectory:tweakDir];
	}

	// remove .filesToCopy and .targetDirectory now that we're done w them
	NSError *error = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:filesToCopy error:&error];
	if(error){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", filesToCopy, error.localizedDescription);
	}

	NSError *error2 = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:targetDirectory error:&error2];
	if(error2){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", targetDirectory, error2.localizedDescription);
	}
}

-(void)copyFilesToTargetDirectory{
	// Note: have to copy as root in order to retain attributes (ownership, etc)
	[self executeCommandAsRoot:@"copy-files"];
}

-(void)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
	// get info for package
	NSString *output = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -s %@", package] andWait:YES];
	NSString *noStatusLine = [output stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""];
	NSString *info = [noStatusLine stringByAppendingString:@"\n"]; // ensure final newline (deb will fail to build if missing)

	NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];

	// make DEBIAN dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:debian]){
		NSError *error = NULL;
		[[NSFileManager defaultManager] createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&error];
		if(error){
			NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", debian, error.localizedDescription);
			return;
		}
	}

	// write info to file
	NSData *data = [info dataUsingEncoding:NSUTF8StringEncoding];
	NSString *control = [debian stringByAppendingPathComponent:@"control"];
	[[NSFileManager defaultManager] createFileAtPath:control contents:data attributes:nil];
}

-(void)buildDebs{
	// Note: have to run as root for some packages to be built correctly (e.g., sudo, openssh-client, etc)
	// if this isn't done as root, said packages will be corrupt and produce the error:
	// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation
	[self executeCommandAsRoot:@"build-debs"];
}

-(void)makeBootstrapFile{
	NSString *bootstrap = @"bingner_elucubratus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
	}

	NSString *file = [NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap];
	[[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
}

-(void)makeTarballWithFilter:(BOOL)filter{
	// get number from latest backup
	NSString *numberString;
	NSCharacterSet *numbers = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
	NSScanner *scanner = [NSScanner scannerWithString:[[self getBackups] firstObject]]; // get latest backup filename
	[scanner scanUpToCharactersFromSet:numbers intoString:NULL]; // remove bit before the number(s)
	[scanner scanCharactersFromSet:numbers intoString:&numberString]; // get number(s)
	int latestBackup = [numberString intValue];

	// craft new backup name
	NSString *backupName;
	if(filter) backupName = [NSString stringWithFormat:@"IAmLazy-%d.tar.gz", latestBackup+1];
	else backupName = [NSString stringWithFormat:@"IAmLazy-%du.tar.gz", latestBackup+1];

	// make tarball (excludes subdirs in tmp dir)
	// note: bourne shell doesn't support glob qualifiers (hence the "find ...." ugliness)
	// ensure file structure is only me.lightmann.iamlazy/ not /var/tmp/me.lightmann.iamlazy/ (having --strip-components=2 on the restore end breaks compatibility w older backups)
	[self executeCommand:[NSString stringWithFormat:@"cd /var/tmp && find ./me.lightmann.iamlazy -maxdepth 1 ! -type d -print0 | xargs -0 tar -czf %@%@", backupDir, backupName]];

	[self cleanupTmp];
	[self verifyBackup:backupName];
}

-(void)verifyBackup:(NSString *)backupName{
	NSString *path = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
		NSString *reason = [NSString stringWithFormat:@"%@ DNE!", path];
		[self popErrorAlertWithReason:reason];
		return;
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [self.endTime timeIntervalSinceDate:self.startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

#pragma mark Restore

-(void)restoreFromBackup:(NSString *)backupName{
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
					[self cleanupTmp];
				}

				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
				[self unpackArchive:backupName];
				[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

				BOOL compatible = YES;
				if([backupName containsString:@"u.tar"]){
					compatible = [self verifyBootstrap];
				}

				if(compatible){
					[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
					[self installDebs];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];
				}
			}
			else{
				NSString *reason = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
				[self popErrorAlertWithReason:reason];
			}
		}
		else{
			NSString *reason = @"No backups were found!";
			[self popErrorAlertWithReason:reason];
		}
	}
	else{
		NSString *reason = @"The backup dir does not exist!";
		[self popErrorAlertWithReason:reason];
	}
}

-(void)unpackArchive:(NSString *)backupName{
	[self executeCommand:[NSString stringWithFormat:@"tar -xf %@%@ -C /var/tmp", backupDir, backupName]];
}

-(BOOL)verifyBootstrap{
	NSString *bootstrap = @"bingner_elucubratus";
	NSString *oppBootstrap = @"procursus";
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oppBootstrap = @"bingner_elucubratus";
	}

	if(![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]]){
		NSString *reason = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", oppBootstrap, bootstrap];
		[self popErrorAlertWithReason:reason];
		return NO;
	}

	return YES;
}

-(void)installDebs{
	[self executeCommandAsRoot:@"install-debs"];
	[self cleanupTmp];
}

#pragma mark General

-(void)cleanupTmp{
	// has to be done as root since some files have root ownership
	[self executeCommandAsRoot:@"cleanup-tmp"];
}

-(NSArray *)getBackups{
	NSMutableArray *backups = [NSMutableArray new];

	NSError *readError = NULL;
	NSArray *backupDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:backupDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", backupDir, readError.localizedDescription);
		return [NSArray new];
	}

	for(NSString *filename in backupDirContents){
		if([filename containsString:@"IAmLazy-"] && [filename containsString:@".tar."]){
			[backups addObject:filename];
		}
	}

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
-(void)executeCommandAsRoot:(NSString *)cmd{
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/libexec/iamlazy/AndSoAreYou"];
	[task setArguments:@[cmd]];
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

	NSLog(@"[IAmLazyLog] %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
}

@end

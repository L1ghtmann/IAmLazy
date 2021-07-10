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
	// reset errors
	[self setEncounteredError:NO];

	// make note of start time
	[self setStartTime:[NSDate date]];

	// check if Documents/ has root ownership (it shouldn't)
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = [NSString stringWithFormat:@"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root."];
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
			NSString *reason = [NSString stringWithFormat:@"Failed to generate list of installed packages! \n\nPlease try again."];
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
			NSString *reason = [NSString stringWithFormat:@"Failed to generate list of user packages! \n\nPlease try again."];
			[self popErrorAlertWithReason:reason];
			return;
		}
		[self setPackages:userPackages];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];
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
	NSArray *lines = [output componentsSeparatedByString:@"\n"]; // split at newlines

	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF endswith 'required'"]; // filter out local packages
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the opposite of ^
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];

	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed anyway by the user
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
	NSArray *lines = [output componentsSeparatedByString:@"\n"]; // split at newlines

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF contains 'Sam Bingner'"]; // filter out bootstrap packages
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF contains 'Jay Freeman (saurik)'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF contains 'Hayden Seay'"];
	NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"SELF contains 'CoolStar'"];
	NSPredicate *thePredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2, predicate3, predicate4]];  // combine with "or"
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the opposite of ^
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];

	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed anyway by the user
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

		// Note: the fastest and most reliable way to gather all package files is to pipe dpkg-query -L into xargs (w dpkg-query -S)
		// thanks to iOS' restrictive memory usage parameters, however, this is not plausible for some devices and setups
		// xargs can be quite the memory hog and will occasionally reach the arbitrary memory threshold set by Apple,
		// resulting in jetsam killing the Preferences process, which in turn stops the backup from proceeding past this step
		// to avoid this, we divvy up the process so as to avoid painfully running dpkg-query -S on every line individually
		NSString *output = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -L %@", package] andWait:NO]; // will hang if wait == YES
		NSArray *lines = [output componentsSeparatedByString:@"\n"]; // split at newline

		// find known things
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF contains[c] '.'"];
		NSArray *knownThings = [lines filteredArrayUsingPredicate:thePredicate];
		for(NSString *path in knownThings){
			if([path length] && ![path isEqualToString:@"/."]){
				// assuming any file/dir/symlink with "."
				// is exclusive to the current package
				// yes, i know this isn't great....
				[files addObject:path];
			}
		}

		// find lingering things
		NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate];
		NSArray *otherThings = [lines filteredArrayUsingPredicate:theAntiPredicate];
		for(NSString *path in otherThings){
			if([path length]){
				// take installed files for package and check that they are exclusive to said package (not like /bin or something general)
				NSString *output2 = [self executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -S %@", path] andWait:NO];
				NSArray *bits = [output2 componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
				if([bits count] == 2 && [bits.firstObject isEqualToString:[package stringByAppendingString:@":"]]){
					[files addObject:bits.lastObject];
				}
			}
		}

		// put all the files we want copied in a list for easier writing
		NSString *filePaths = [[files valueForKey:@"description"] componentsJoinedByString:@"\n"];

		// make fresh tmp directory
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
			[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
		}

		// write filepaths that we're going to copy to a file
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
			NSLog(@"IAmLazyLog %@ DNE for %@", filesToCopy, package);
		}

		// make control file
		[self makeControlForPackage:package inDirectory:tweakDir];
	}

	// remove filesToCopy.txt now that we're done using it
	[[NSFileManager defaultManager] removeItemAtPath:filesToCopy error:NULL];
}

-(void)copyFilesToDirectory:(NSString *)tweakDir{
	NSString *fileContents = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:NULL];
	NSArray *files = [fileContents componentsSeparatedByString:@"\n"];
	if(![files count]){
		NSLog(@"IAmLazyLog no filesToCopy for %@!", tweakDir);
		return;
	}

	// has to be copied as root in order to retain attributes (ownership, etc)
	[self executeCommandAsRoot:@[@"copy-files", tweakDir]];
}

-(void)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
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
	// Note: have to run as root for some packages to be built correctly (e.g., sudo, openssh-client, etc)
	// if this isn't done as root, said packages will be corrupt and produce the error:
	// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation
	[self executeCommandAsRoot:@[@"build-debs"]];
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
				if([backupName containsString:@"u.tar.xz"]){
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
	[self executeCommandAsRoot:@[@"install-debs"]];
	[self cleanupTmp];
}

-(void)cleanupTmp{
	// adjust tmp dir perms and delete
	[self executeCommandAsRoot:@[@"pre-cleanup"]];
	[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
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

	NSLog(@"IAmLazyLog %@", [reason stringByReplacingOccurrencesOfString:@"\n" withString:@""]);
}

@end

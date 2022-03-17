//
//	IALBackupManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALGeneralManager.h"
#import "IALBackupManager.h"
#import "../Common.h"

@implementation IALBackupManager

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	// reset errors
	[_generalManager setEncounteredError:NO];

	// make note of start time
	[self setStartTime:[NSDate date]];

	// check if Documents/ has root ownership (it shouldn't)
	if([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = @"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root.";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for old tmp files
	if([[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	// get all packages
	if(!filter){
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];
		NSArray *allPackages = [self getAllPackages];
		if(![allPackages count]){
			NSString *reason = @"Failed to generate list of installed packages! \n\nPlease try again.";
			[_generalManager popErrorAlertWithReason:reason];
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
			[_generalManager popErrorAlertWithReason:reason];
			return;
		}
		[self setPackages:userPackages];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];
	}

	if(type == 0){
		// make fresh tmp directory
		if(![[NSFileManager defaultManager] fileExistsAtPath:tmpDir]){
			NSError *writeError = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

		// gather bits for packages
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		[self gatherPackageFiles];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make backup and log dirs if they don't exist already
		if(![[NSFileManager defaultManager] fileExistsAtPath:logDir]){
			NSError *writeError = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

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
	}
	else{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		// put all packages in a list for easier writing
		NSString *fileContent = [[self.packages valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![fileContent length]){
			NSLog(@"[IAmLazyLog] fileContent is blank!");
			return;
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
		// get latest backup name and append the text file extension
		NSString *latest = [_generalManager getLatestBackup];
		NSString *listName;
		if(!filter){
			listName = [latest stringByAppendingString:@"u.txt"];
		}
		else{
			listName = [latest stringByAppendingString:@".txt"];
		}

		// write to file
		NSString *file = [NSString stringWithFormat:@"%@%@", backupDir, listName];
		[[NSFileManager defaultManager] createFileAtPath:file contents:[fileContent dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

		// make note of the bootstrap that the list was made on
		if(!filter){
			NSString *bootstrap = @"bingner_elucubratus";
			if([[NSFileManager defaultManager] fileExistsAtPath:@"/.procursus_strapped"]){
				bootstrap = @"procursus";
			}

			NSString *madeOn = [NSString stringWithFormat:@"\n\n## made on %@ ##", bootstrap];

			NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
			[fileHandle seekToEndOfFile];
			[fileHandle writeData:[madeOn dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle closeFile];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

		[self verifyList:listName];
	}

	// make note of end time
	[self setEndTime:[NSDate date]];
}

-(NSArray *)getAllPackages{
	NSMutableArray *allPackages = [NSMutableArray new];

	NSString *output = [_generalManager executeCommandWithOutput:@"dpkg-query -Wf '${Package;-50}${Priority}\n'"];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH 'required'"]; // filter out local packages
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

	NSString *output = [_generalManager executeCommandWithOutput:@"dpkg-query -Wf '${Package;-50}${Maintainer}\n'"];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Sam Bingner'"]; // filter out bootstrap repo packages
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Jay Freeman (saurik)'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'CoolStar'"];
	NSPredicate *predicate4 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Hayden Seay'"];
	NSPredicate *predicate5 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Cameron Katri'"];
	NSPredicate *predicate6 = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Procursus Team'"];
	NSPredicate *thePredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate1, predicate2, predicate3, predicate4, predicate5, predicate6]];  // combine with "or"
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
		NSMutableArray *genericFiles = [NSMutableArray new];
		NSMutableArray *directories = [NSMutableArray new];

		// get generic files and directories and sort into respective arrays
		NSString *output = [_generalManager executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -L %@", package]];
		NSArray *lines = [output componentsSeparatedByString:@"\n"];
		for(NSString *line in lines){
			if(![line length] || [line isEqualToString:@"/."]){
				continue; // disregard
			}

			NSError *readError = NULL;
			NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:line error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get attributes for %@! Error: %@", line, readError.localizedDescription);
				continue;
			}

			NSString *type = [fileAttributes fileType];

			// check to see how many times the current filepath is present in the list output
			// shoutout Cœur on StackOverflow for this efficient code (https://stackoverflow.com/a/57869286)
			int count = [[NSMutableString stringWithString:output] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, output.length)];

			if(count == 1){ // this is good, means it's unique!
				if([type isEqualToString:@"NSFileTypeDirectory"]){
					[directories addObject:line];
				}
				else{
					[genericFiles addObject:line];
				}
			}
			else{
				// sometimes files will have similar names (e.g., /usr/bin/zip, /usr/bin/zipcloak, /usr/bin/zipnote, /usr/bin/zipsplit)
				// though /usr/bin/zip will have a count > 1, since it's present in the other filepaths, we want to avoid disregarding it
				// since it's a valid file. instead, we want to disregard all dirs and symlinks that don't lead to files as they're simply
				// part of the package's list structure. in the above example, that would mean disregarding /usr and /usr/bin
				if(![type isEqualToString:@"NSFileTypeDirectory"] && ![type isEqualToString:@"NSFileTypeSymbolicLink"]){
					[genericFiles addObject:line];
				}
				else if([type isEqualToString:@"NSFileTypeSymbolicLink"]){
					// want to grab any symlniks that lead to files, but ignore those that lead to dirs
					// this will traverse any links and check for the existence of a file at the link's final destination
					BOOL isDir = NO;
					if([[NSFileManager defaultManager] fileExistsAtPath:line isDirectory:&isDir] && !isDir){
						[genericFiles addObject:line];
					}
				}
			}
		}

		// get DEBIAN files (e.g., pre/post scripts) and put into an array
		NSString *output2 = [_generalManager executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -c %@", package]];
		NSArray *lines2 = [output2 componentsSeparatedByString:@"\n"];
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.md5sums'"]; // dpkg generates this dynamically at installation
		NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate]; // find the opposite of ^
		NSArray *debianFiles = [lines2 filteredArrayUsingPredicate:theAntiPredicate];

		// put the files we want to copy into lists for easier writing
		NSString *gFilePaths = [[genericFiles valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![gFilePaths length]){
			NSLog(@"[IAmLazyLog] gFilePaths list is blank for %@!", package);
		}

		NSString *dFilePaths = [[debianFiles valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![dFilePaths length]){
			NSLog(@"[IAmLazyLog] dFilePaths list is blank for %@!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError = NULL;
		[gFilePaths writeToFile:gFilesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write gFilePaths to %@ for %@! Error: %@", gFilesToCopy, package, writeError.localizedDescription);
			continue;
		}

		NSError *writeError2 = NULL;
		[dFilePaths writeToFile:dFilesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&writeError2];
		if(writeError2){
			NSLog(@"[IAmLazyLog] Failed to write dFilePaths to %@ for %@! Error: %@", dFilesToCopy, package, writeError2.localizedDescription);
			continue;
		}

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];

		// make dir to hold stuff for the tweak
		if(![[NSFileManager defaultManager] fileExistsAtPath:tweakDir]){
			NSError *writeError3 = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:&writeError3];
			if(writeError3){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", tweakDir, writeError3.localizedDescription);
				continue;
			}
		}

		// again, this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError4 = NULL;
		[tweakDir writeToFile:targetDir atomically:YES encoding:NSUTF8StringEncoding error:&writeError4];
		if(writeError4){
			NSLog(@"[IAmLazyLog] Failed to write tweakDir to %@ for %@! Error: %@", targetDir, package, writeError4.localizedDescription);
			continue;
		}

		[self makeSubDirectories:directories inDirectory:tweakDir];
		[self copyGenericFiles];
		[self makeControlForPackage:package inDirectory:tweakDir];
		[self copyDEBIANFiles];
	}

	// remove list files now that we're done w them
	NSError *deleteError = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:gFilesToCopy error:&deleteError];
	if(deleteError){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", gFilesToCopy, deleteError.localizedDescription);
	}

	NSError *deleteError2 = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:dFilesToCopy error:&deleteError2];
	if(deleteError2){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", dFilesToCopy, deleteError2.localizedDescription);
	}

	NSError *deleteError3 = NULL;
	[[NSFileManager defaultManager] removeItemAtPath:targetDir error:&deleteError3];
	if(deleteError3){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", targetDir, deleteError3.localizedDescription);
	}
}

-(void)makeSubDirectories:(NSArray *)directories inDirectory:(NSString *)tweakDir{
	for(NSString *dir in directories){
		NSString *path = [NSString stringWithFormat:@"%@%@", tweakDir, dir];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
			NSError *writeError = NULL;
			[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", path, writeError.localizedDescription);
				continue;
			}
		}
	}
}

-(void)copyGenericFiles{
	// have to run as root in order to retain file attributes (ownership, etc)
	[_generalManager executeCommandAsRoot:@"copy-generic-files"];
}

-(void)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
	// get info for package
	NSString *output = [_generalManager executeCommandWithOutput:[NSString stringWithFormat:@"dpkg-query -s %@", package]];
	NSString *noStatusLine = [output stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""];
	NSString *info = [noStatusLine stringByAppendingString:@"\n"]; // ensure final newline (deb will fail to build if missing)

	NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];

	// make DEBIAN dir
	if(![[NSFileManager defaultManager] fileExistsAtPath:debian]){
		NSError *writeError = NULL;
		[[NSFileManager defaultManager] createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", debian, writeError.localizedDescription);
			return;
		}
	}

	// write info to file
	NSData *data = [info dataUsingEncoding:NSUTF8StringEncoding];
	NSString *control = [debian stringByAppendingPathComponent:@"control"];
	[[NSFileManager defaultManager] createFileAtPath:control contents:data attributes:nil];
}

-(void)copyDEBIANFiles{
	// have to copy as root in order to retain file attributes (ownership, etc)
	[_generalManager executeCommandAsRoot:@"copy-debian-files"];
}

-(void)buildDebs{
	// have to run as root for some packages to be built correctly (e.g., sudo, openssh-client, etc)
	// if this isn't done as root, said packages will be corrupt and produce the error:
	// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation
	[_generalManager executeCommandAsRoot:@"build-debs"];

	// confirm that we successfully built debs
	[self verifyDebs];
}

-(void)verifyDebs{
	NSError *readError = NULL;
	NSArray *tmp = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", tmpDir, readError.localizedDescription);
	}

	NSArray *debs = [tmp filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"]];
	if(![debs count]){
		NSString *reason = [NSString stringWithFormat:@"Failed to build debs! Please check %@build_log.txt.", logDir];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}
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
	// get latest backup name and append the gzip tar extension
	NSString *latest = [_generalManager getLatestBackup];
	NSString *backupName;
	if(!filter){
		backupName = [latest stringByAppendingString:@"u.tar.gz"];
	}
	else{
		backupName = [latest stringByAppendingString:@".tar.gz"];
	}

	// make tarball
	// ensure file structure is ONLY me.lightmann.iamlazy/ not /tmp/me.lightmann.iamlazy/
	// having --strip-components=2 on the restore end breaks compatibility w older backups
	[_generalManager executeCommand:[NSString stringWithFormat:@"cd /tmp && tar -czf %@%@ me.lightmann.iamlazy/ --remove-files \\;", backupDir, backupName]];

	// confirm the backup now exists where expected
	[self verifyBackup:backupName];
}

-(void)verifyBackup:(NSString *)backupName{
	NSString *path = [NSString stringWithFormat:@"%@%@", backupDir, backupName];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
		NSString *reason = [NSString stringWithFormat:@"%@ DNE!", path];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}
}

-(void)verifyList:(NSString *)listName{
	NSString *path = [NSString stringWithFormat:@"%@%@", backupDir, listName];
	if(![[NSFileManager defaultManager] fileExistsAtPath:path]){
		NSString *reason = [NSString stringWithFormat:@"%@ DNE!", path];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [self.endTime timeIntervalSinceDate:self.startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

@end
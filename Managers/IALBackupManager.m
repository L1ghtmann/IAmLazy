//
//	IALBackupManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "IALGeneralManager.h"
#import "IALBackupManager.h"
#import "../libarchive.h"
#import "../Common.h"
#import <NSTask.h>

@implementation IALBackupManager

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	// reset errors
	[_generalManager setEncounteredError:NO];

	// make note of start time
	[self setStartTime:[NSDate date]];

	// check if Documents/ has root ownership (it shouldn't)
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *reason = @"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root.";
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
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
		if(![fileManager fileExistsAtPath:tmpDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *reason = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, writeError.localizedDescription];
				[_generalManager popErrorAlertWithReason:reason];
				return;
			}
		}

		// gather bits for packages
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		NSArray *controls = [self getControlFiles];
		if(![controls count]){
			NSString *reason = @"Failed to generate controls for installed packages! \n\nPlease try again.";
			[_generalManager popErrorAlertWithReason:reason];
			return;
		}
		[self setControls:controls];
		[self gatherPackageFiles];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		// make backup and log dirs if they don't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
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
		NSString *filePath = [NSString stringWithFormat:@"%@%@", backupDir, listName];
		[fileManager createFileAtPath:filePath contents:[fileContent dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

		// note bootstrap the list was made on
		if(!filter){
			NSString *bootstrap = @"elucubratus";
			if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
				bootstrap = @"procursus";
			}

			NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
			[fileHandle writeData:[[bootstrap stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle closeFile];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];

		[self verifyFileAtPath:filePath];
	}

	// make note of end time
	[self setEndTime:[NSDate date]];
}

-(NSArray *)getAllPackages{
	NSMutableArray *allPackages = [NSMutableArray new];

	// get list of all installed packages and their priorities
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/dpkg-query"];
	[task setArguments:@[@"-Wf", @"${Package;-50}${Priority}\n"]];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];

	[task launch];

	NSFileHandle *handle = [pipe fileHandleForReading];
	NSData *data = [handle readDataToEndOfFile];
	[handle closeFile];

	// have to call after ^ to ensure that the output pipe doesn't fill
	// if it does, the process will hang and block waitUntilExit from returning
	[task waitUntilExit];

	NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];

	// filter out packages with the 'requried' priorty
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH 'required'"];
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate];
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];
	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed by the user anyway
		if([line length] && ![line containsString:@"me.lightmann.iamlazy"]){
			// split the package name from its priority and then add the package name to the allPackages array
			NSArray *bits = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			if([bits count]) [allPackages addObject:[bits firstObject]];
		}
	}

	return allPackages;
}

-(NSArray *)getReposToFilter{
	NSArray *reposToFilter = @[
		@"apt.bingner.com",
		@"apt.procurs.us",
		@"repo.theodyssey.dev"
	];
	return reposToFilter;
}

-(NSArray *)getUserPackages{
	NSMutableArray *userPackages;

	// get apt lists
	NSError *readError = nil;
	NSString *aptListsDir = @"/var/lib/apt/lists/";
	NSArray *aptLists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aptListsDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", aptListsDir, readError.localizedDescription);
		return nil;
	}

	// get packages to ignore
	NSMutableArray *packagesToIgnore = [NSMutableArray new];
	for(NSString *repo in [self getReposToFilter]){
		NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"self ENDSWITH '_Packages'"];
		NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"self BEGINSWITH %@", repo];
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1,predicate2]];
		NSArray *pkgLists = [aptLists filteredArrayUsingPredicate:thePredicate];
		for(NSString *list in pkgLists){ // count should be 1
			NSError *readError2 = nil;
			NSString *content = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@%@", aptListsDir, list] encoding:NSUTF8StringEncoding error:&readError2];
			if(readError2){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@%@! Error: %@", aptListsDir, list, readError2.localizedDescription);
				continue;
			}
			NSArray *lines = [content componentsSeparatedByString:@"\n"];

			NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Package:'"];
			NSArray *packages = [lines filteredArrayUsingPredicate:predicate];
			NSArray *packagesWithNoDups = [[NSOrderedSet orderedSetWithArray:packages] array]; // remove dups and retain order
			for(NSString *line in packagesWithNoDups){
				if(![line length]) continue;
				NSString *cleanLine = [line stringByReplacingOccurrencesOfString:@"Package: " withString:@""];
				if([cleanLine length]) [packagesToIgnore addObject:cleanLine];
			}
		}
	}

	// grab all installed packages and remove the ones we want to ignore
	userPackages = [[self getAllPackages] mutableCopy];
	[userPackages removeObjectsInArray:packagesToIgnore];

	return userPackages;
}

-(NSArray *)getControlFiles{
	NSMutableArray *controls = [NSMutableArray new];

	// get control files for all installed packages
	NSError *readError = nil;
	NSString *path = @"/var/lib/dpkg/status";
	NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError.localizedDescription);
		return nil;
	}

	// divvy up massive control string into individual strings
	NSMutableString *controlFile = [NSMutableString new];
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	for(int i = 0; i < [lines count]; i++){
		NSString *line = lines[i];
		if([line length]){
			if(![controlFile length]) [controlFile appendString:line];
			else [controlFile appendString:[@"\n" stringByAppendingString:line]];
		}
		else{
			[controls addObject:[controlFile copy]];
			if(i != [lines count]) [controlFile setString:@""];
			else controlFile = nil;
		}
	}

	return controls;
}

-(void)gatherPackageFiles{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for(NSString *package in self.packages){
		NSMutableArray *genericFiles = [NSMutableArray new];
		NSMutableArray *directories = [NSMutableArray new];

		// get installed files
		NSError *readError = nil;
		NSString *path = [NSString stringWithFormat:@"/var/lib/dpkg/info/%@.list", package];
		NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError.localizedDescription);
			continue;
		}

		// get generic files and directories and sort into respective arrays
		NSArray *lines = [contents componentsSeparatedByString:@"\n"];
		for(NSString *line in lines){
			if(![line length] || [line isEqualToString:@"/."]){
				continue; // disregard
			}

			NSError *readError2 = nil;
			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:line error:&readError2];
			if(readError2){
				NSLog(@"[IAmLazyLog] Failed to get attributes for %@! Error: %@", line, readError2.localizedDescription);
				continue;
			}

			NSString *type = [fileAttributes fileType];

			// check to see how many times the current filepath is present in the list output
			// shoutout Cœur on StackOverflow for this efficient code (https://stackoverflow.com/a/57869286)
			int count = [[NSMutableString stringWithString:contents] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, [contents length])];

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
					if([fileManager fileExistsAtPath:line isDirectory:&isDir] && !isDir){
						[genericFiles addObject:line];
					}
				}
			}
		}

		// put the files we want to copy into lists for easier writing
		NSString *gFilePaths = [[genericFiles valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![gFilePaths length]){
			NSLog(@"[IAmLazyLog] gFilePaths list is blank for %@!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError = nil;
		[gFilePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write gFilePaths to %@ for %@! Error: %@", filesToCopy, package, writeError.localizedDescription);
			continue;
		}

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];

		// make dir to hold stuff for the tweak
		if(![fileManager fileExistsAtPath:tweakDir]){
			NSError *writeError3 = nil;
			[fileManager createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:&writeError3];
			if(writeError3){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", tweakDir, writeError3.localizedDescription);
				continue;
			}
		}

		[self makeSubDirectories:directories inDirectory:tweakDir];
		[self copyGenericFiles];
		[self makeControlForPackage:package inDirectory:tweakDir];
		[self copyDEBIANFiles];
	}

	// remove list file now that we're done w it
	NSError *deleteError = nil;
	[fileManager removeItemAtPath:filesToCopy error:&deleteError];
	if(deleteError){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", filesToCopy, deleteError.localizedDescription);
	}
}

-(void)makeSubDirectories:(NSArray *)directories inDirectory:(NSString *)tweakDir{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for(NSString *dir in directories){
		NSString *path = [NSString stringWithFormat:@"%@%@", tweakDir, dir];
		if(![fileManager fileExistsAtPath:path]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", path, writeError.localizedDescription);
				continue;
			}
		}
	}
}

-(void)copyGenericFiles{
	// have to run as root in order to retain file attributes (ownership, etc)
	[_generalManager executeCommandAsRoot:@"cpGFiles"];
}

-(void)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
	// get info for package
	NSString *pkg = [@"Package: " stringByAppendingString:package];
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", pkg];
	NSArray *theOne = [self.controls filteredArrayUsingPredicate:thePredicate];
	NSString *relevantControl = [theOne firstObject]; // count should be 1
	NSString *noStatusLine = [relevantControl stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""];
	NSString *info = [noStatusLine stringByAppendingString:@"\n"]; // ensure final newline (deb will fail to build if missing)

	// make DEBIAN dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];
	if(![fileManager fileExistsAtPath:debian]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", debian, writeError.localizedDescription);
			return;
		}
	}

	// write info to file
	NSData *data = [info dataUsingEncoding:NSUTF8StringEncoding];
	NSString *control = [debian stringByAppendingPathComponent:@"control"];
	[fileManager createFileAtPath:control contents:data attributes:nil];
}

-(void)copyDEBIANFiles{
	// have to copy as root in order to retain file attributes (ownership, etc)
	[_generalManager executeCommandAsRoot:@"cpDFiles"];
}

-(void)buildDebs{
	// have to run as root for some packages to be built correctly (e.g., sudo, openssh-client, etc)
	// if this isn't done as root, said packages will be corrupt and produce the error:
	// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation
	[_generalManager executeCommandAsRoot:@"buildDebs"];

	// confirm that we successfully built debs
	[self verifyDebs];
}

-(void)verifyDebs{
	NSError *readError = nil;
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
	NSString *bootstrap = @"elucubratus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
	}

	NSString *file = [NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap];
	[fileManager createFileAtPath:file contents:nil attributes:nil];
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
	NSString *backupPath = [NSString stringWithFormat:@"%@%@", backupDir, backupName];

	// make tarball (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0); // wait for async block
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
		write_archive([backupPath UTF8String]);

		// signal that we're good to go
		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    }

	// confirm the gzip archive now exists where expected
	[self verifyFileAtPath:backupPath];
}

-(void)verifyFileAtPath:(NSString *)filePath{
	if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
		NSString *reason = [NSString stringWithFormat:@"%@ DNE!", filePath];
		[_generalManager popErrorAlertWithReason:reason];
		return;
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [self.endTime timeIntervalSinceDate:self.startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

@end

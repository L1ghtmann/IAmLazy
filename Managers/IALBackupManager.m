//
//	IALBackupManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/libarchive.h"
#import "IALGeneralManager.h"
#import "IALBackupManager.h"
#import "../Common.h"

@implementation IALBackupManager

-(void)makeBackupOfType:(NSInteger)type withFilter:(BOOL)filter{
	// reset errors
	[_generalManager setEncounteredError:NO];

	// make note of start time
	_startTime = [NSDate date];

	// check if Documents/ has root ownership (it shouldn't)
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager isWritableFileAtPath:@"/var/mobile/Documents/"] == 0){
		NSString *msg = @"/var/mobile/Documents is not writeable. \n\nPlease ensure that the directory's owner is mobile and not root.";
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter postNotificationName:@"updateProgress" object:@"null"];

	// get packages
	NSArray *packages;
	if(!filter) packages = [self getAllPackages];
	else packages = [self getUserPackages];
	if(![packages count]){
		NSString *msg = @"Failed to generate list of packages! \n\nPlease try again.";
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	[notifCenter postNotificationName:@"updateProgress" object:@"0"];

	if(type == 0){
		// make fresh tmp directory
		if(![fileManager fileExistsAtPath:tmpDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, writeError];
				[_generalManager displayErrorWithMessage:msg];
				return;
			}
		}

		[notifCenter postNotificationName:@"updateProgress" object:@"0.7"];

		// gather bits for packages
		_controlFiles = [self getControlFiles];
		if(![_controlFiles count]){
			NSString *msg = @"Failed to generate controls for installed packages! \n\nPlease try again.";
			[_generalManager displayErrorWithMessage:msg];
			return;
		}
		[self gatherFilesForPackages:packages];

		[notifCenter postNotificationName:@"updateProgress" object:@"1"];

		// make backup and log dirs if they don't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError];
				[_generalManager displayErrorWithMessage:msg];
				return;
			}
		}

		// build debs from bits
		[notifCenter postNotificationName:@"updateProgress" object:@"1.7"];
		[self buildDebs];
		[notifCenter postNotificationName:@"updateProgress" object:@"2"];

		// for unfiltered backups, create specify the bootstrap it was created on
		if(!filter) [self makeBootstrapFile];

		// make archive of packages
		[notifCenter postNotificationName:@"updateProgress" object:@"2.7"];
		[self makeTarballWithFilter:filter];
		[notifCenter postNotificationName:@"updateProgress" object:@"3"];
	}
	else{
		[notifCenter postNotificationName:@"updateProgress" object:@"0.7"];

		// put all packages in a list for easier writing
		NSString *fileContent = [[packages valueForKey:@"description"] componentsJoinedByString:@"\n"];
		if(![fileContent length]){
			[_generalManager displayErrorWithMessage:@"fileContent is blank!"];
			return;
		}

		[notifCenter postNotificationName:@"updateProgress" object:@"1"];
		[notifCenter postNotificationName:@"updateProgress" object:@"1.7"];

		// get latest backup name and append the text file extension
		NSString *listName;
		NSString *latest = [_generalManager getLatestBackup];
		if(!filter) listName = [latest stringByAppendingString:@"u.txt"];
		else listName = [latest stringByAppendingPathExtension:@"txt"];

		// make backup and log dirs if they don't exist already
		if(![fileManager fileExistsAtPath:logDir]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError];
				[_generalManager displayErrorWithMessage:msg];
				return;
			}
		}

		// write to file
		NSString *filePath = [backupDir stringByAppendingPathComponent:listName];
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

		[notifCenter postNotificationName:@"updateProgress" object:@"2"];

		[self verifyFileAtPath:filePath];
	}

	// make note of end time
	_endTime = [NSDate date];
}

-(NSArray<NSString *> *)getAllPackages{
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
	if(![lines count]) return [NSArray new];

	// filter out packages with the 'requried' priorty
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH 'required'"];
	NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate];
	NSArray *packages = [lines filteredArrayUsingPredicate:theAntiPredicate];
	NSCharacterSet *whiteSpace = [NSCharacterSet whitespaceCharacterSet];
	NSMutableArray *allPackages = [NSMutableArray new];
	for(NSString *line in packages){
		// filter out IAmLazy since it'll be installed by the user anyway
		if([line length] && ![line hasPrefix:@"me.lightmann.iamlazy"]){
			// split the package name from its priority and then add the package name to the allPackages array
			NSArray *bits = [line componentsSeparatedByCharactersInSet:whiteSpace];
			if([bits count]) [allPackages addObject:[bits firstObject]];
		}
	}
	return allPackages;
}

-(NSArray<NSString *> *)getReposToFilter{
	NSArray *reposToFilter = @[
		@"apt.bingner.com",
		@"apt.procurs.us",
		@"repo.theodyssey.dev"
	];
	return reposToFilter;
}

-(NSArray<NSString *> *)getUserPackages{
	// get apt lists
	NSError *readError = nil;
	NSArray *aptLists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aptListsDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", aptListsDir, readError);
		return [NSArray new];
	}

	// get packages to ignore
	NSMutableArray *packagesToIgnore = [NSMutableArray new];
	NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '_Packages'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Package:'"];
	for(NSString *repo in [self getReposToFilter]){
		NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", repo];
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1,predicate2]];
		NSArray *pkgLists = [aptLists filteredArrayUsingPredicate:thePredicate];
		if(![pkgLists count]) continue;

		// count should be one for pkgLists
		for(NSString *list in pkgLists){
			NSError *readError2 = nil;
			NSString *listPath = [aptListsDir stringByAppendingPathComponent:list];
			NSString *content = [NSString stringWithContentsOfFile:listPath encoding:NSUTF8StringEncoding error:&readError2];
			if(readError2){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", listPath, readError2);
				continue;
			}

			NSArray *lines = [content componentsSeparatedByString:@"\n"];
			if(![lines count]) continue;

			NSArray *packages = [lines filteredArrayUsingPredicate:predicate3];
			NSArray *packagesWithNoDups = [[NSOrderedSet orderedSetWithArray:packages] array]; // remove dups and retain order
			for(NSString *line in packagesWithNoDups){
				if(![line length]) continue;
				NSString *cleanLine = [line stringByReplacingOccurrencesOfString:@"Package: " withString:@""];
				if([cleanLine length]) [packagesToIgnore addObject:cleanLine];
			}
		}
	}

	// grab all installed packages and remove the ones we want to ignore
	NSMutableArray *userPackages = [[self getAllPackages] mutableCopy];
	[userPackages removeObjectsInArray:packagesToIgnore];
	return userPackages;
}

-(NSArray<NSString *> *)getControlFiles{
	// get control files for all installed packages
	NSError *readError = nil;
	NSString *dpkgStatusDir = @"/var/lib/dpkg/status";
	NSString *contents = [NSString stringWithContentsOfFile:dpkgStatusDir encoding:NSUTF8StringEncoding error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", dpkgStatusDir, readError);
		return [NSArray new];
	}

	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	if(![lines count]) return [NSArray new];

	// divvy up massive control string into individual strings
	NSMutableArray *controls = [NSMutableArray new];
	NSMutableString *controlFile = [NSMutableString new];
	for(int i = 0; i < [lines count]; i++){
		NSString *line = lines[i];
		if([line length]){
			if(![controlFile length]) [controlFile appendString:line];
			else [controlFile appendString:[@"\n" stringByAppendingString:line]];
		}
		else{
			// when we hit an empty line it's a new control
			[controls addObject:[controlFile copy]];
			if(i != [lines count]) [controlFile setString:@""];
			else controlFile = nil;
		}
	}
	return controls;
}

-(void)gatherFilesForPackages:(NSArray<NSString *> *)packages{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
	[set addCharactersInString:@"+-."];
	NSString *dir = @"NSFileTypeDirectory";
	NSString *symLink = @"NSFileTypeSymbolicLink";
	for(NSString *package in packages){
		BOOL valid = ![[package stringByTrimmingCharactersInSet:set] length];
		if(valid){
			// get installed files
			NSError *readError = nil;
			NSString *path = [[dpkgInfoDir stringByAppendingPathComponent:package] stringByAppendingPathExtension:@"list"];
			NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
				continue;
			}

			NSArray *lines = [contents componentsSeparatedByString:@"\n"];
			if(![lines count]) continue;

			// get generic files and directories and sort into respective arrays
			NSMutableArray *genericFiles = [NSMutableArray new];
			NSMutableArray *directories = [NSMutableArray new];
			for(NSString *line in lines){
				if(![line length] || [line isEqualToString:@"/."] || [[line lastPathComponent] isEqualToString:@".."] || [[line lastPathComponent] isEqualToString:@"."]){
					continue; // disregard
				}

				NSError *readError2 = nil;
				NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:line error:&readError2];
				if(readError2){
					NSLog(@"[IAmLazyLog] Failed to get attributes for %@! Error: %@", line, readError2);
					continue;
				}

				// for categorization below
				NSString *type = [fileAttributes fileType];

				// check to see how many times the current filepath is present in the list output
				// shoutout Cœur on StackOverflow for this efficient code (https://stackoverflow.com/a/57869286)
				int count = [[NSMutableString stringWithString:contents] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, [contents length])];

				if(count == 1){ // this is good, means it's unique!
					if([type isEqualToString:dir]){
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
					if(![type isEqualToString:dir] && ![type isEqualToString:symLink]){
						[genericFiles addObject:line];
					}
					else if([type isEqualToString:symLink]){
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
				NSLog(@"[IAmLazyLog] Failed to write gFilePaths to %@ for %@! Error: %@", filesToCopy, package, writeError);
				continue;
			}

			// make dir to hold stuff for the tweak
			NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];
			if(![fileManager fileExistsAtPath:tweakDir]){
				NSError *writeError3 = nil;
				[fileManager createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:&writeError3];
				if(writeError3){
					NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", tweakDir, writeError3);
					continue;
				}
			}

			[self makeSubDirectories:directories inDirectory:tweakDir];
			[self copyGenericFiles];
			[self makeControlForPackage:package inDirectory:tweakDir];
			[self copyDEBIANFiles];
		}
	}

	// remove list file now that we're done w it
	NSError *deleteError = nil;
	[fileManager removeItemAtPath:filesToCopy error:&deleteError];
	if(deleteError){
		NSLog(@"[IAmLazyLog] Failed to delete %@! Error: %@", filesToCopy, deleteError);
	}
}

-(void)makeSubDirectories:(NSArray<NSString *> *)directories inDirectory:(NSString *)tweakDir{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for(NSString *dir in directories){
		NSString *path = [tweakDir stringByAppendingPathComponent:dir];
		if(![fileManager fileExistsAtPath:path]){
			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", path, writeError);
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
	NSArray *theOne = [_controlFiles filteredArrayUsingPredicate:thePredicate];
	if(![theOne count]) return;

	NSString *relevantControl = [theOne firstObject];
	NSString *noStatusLine = [relevantControl stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""];
	NSString *info = [noStatusLine stringByAppendingString:@"\n"]; // ensure final newline (deb will fail to build if missing)

	// make DEBIAN dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *debian = [tweakDir stringByAppendingString:@"/DEBIAN/"];
	if(![fileManager fileExistsAtPath:debian]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to create %@! Error: %@", debian, writeError);
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
	// have to run as root in order to retain file attributes (ownership, etc)
	[_generalManager executeCommandAsRoot:@"buildDebs"];

	// confirm that we successfully built debs
	[self verifyDebs];
}

-(void)verifyDebs{
	NSError *readError = nil;
	NSArray *tmp = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", tmpDir, readError];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSArray *debs = [tmp filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"]];
	if(![debs count]){
		NSString *msg = [NSString stringWithFormat:@"Failed to build debs! Please check %@build_log.txt.", logDir];
		[_generalManager displayErrorWithMessage:msg];
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
	NSString *backupName;
	NSString *latest = [_generalManager getLatestBackup];
	if(!filter) backupName = [latest stringByAppendingString:@"u.tar.gz"];
	else backupName = [latest stringByAppendingPathExtension:@"tar.gz"];
	NSString *backupPath = [backupDir stringByAppendingPathComponent:backupName];

	// make tarball (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0); // wait for async block
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		write_archive([backupPath UTF8String]);

		// signal that we're good to go
		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    }

	// confirm the gzip archive now exists
	[self verifyFileAtPath:backupPath];

	[_generalManager cleanupTmp];
}

-(void)verifyFileAtPath:(NSString *)filePath{
	if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
		NSString *msg = [NSString stringWithFormat:@"%@ DNE!", filePath];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}
}

-(NSString *)getDuration{
	NSTimeInterval duration = [_endTime timeIntervalSinceDate:_startTime];
	return [NSString stringWithFormat:@"%.02f", duration];
}

@end

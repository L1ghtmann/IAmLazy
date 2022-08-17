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

-(void)makeBackupWithFilter:(BOOL)filter{
	// check for old tmp files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	// ensure backupdir exists
	[_generalManager ensureBackupDirExists];

	_filtered = filter;
	[_generalManager updateItemStatus:-0.5];

	// get control files
	_controlFiles = [self getControlFiles];
	if(![_controlFiles count]){
		[_generalManager displayErrorWithMessage:@"Failed to generate controls for installed packages!"];
		return;
	}

	// get packages
	if(!_filtered) _packages = [self getAllPackages];
	else _packages = [self getUserPackages];
	if(![_packages count]){
		[_generalManager displayErrorWithMessage:@"Failed to generate list of packages!"];
		return;
	}

	[_generalManager updateItemStatus:0];

	// make fresh tmp directory
	if(![fileManager fileExistsAtPath:tmpDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@.\n\nError: %@", tmpDir, writeError];
			[_generalManager displayErrorWithMessage:msg];
			return;
		}
	}

	// gather bits for packages
	[_generalManager updateItemStatus:0.5];
	[self gatherFilesForPackages];
	[_generalManager updateItemStatus:1];

	// build debs from bits
	[_generalManager updateItemStatus:1.5];
	[self buildDebs];
	[_generalManager updateItemStatus:2];

	// specify the bootstrap it was created on
	if(!_filtered) [self makeBootstrapFile];

	// make archive of packages
	[_generalManager updateItemStatus:2.5];
	[self makeTarball];
	[_generalManager updateItemStatus:3];
}

-(NSArray<NSString *> *)getControlFiles{
	[_generalManager updateItemProgress:0];

	// get control files for all installed packages
	NSError *readError = nil;
	NSString *dpkgStatus = @"/var/lib/dpkg/status";
	NSString *contents = [NSString stringWithContentsOfFile:dpkgStatus encoding:NSUTF8StringEncoding error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", dpkgStatus, readError];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}

	NSArray *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	if(![lines count]){
		NSString *msg = [NSString stringWithFormat:@"%@ is blank?!", dpkgStatus];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}

	[_generalManager updateItemProgress:0.1];

	// divvy up massive control collection into individual control files
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

	[_generalManager updateItemProgress:0.2];

	return controls;
}

-(NSArray<NSString *> *)getAllPackages{
	NSMutableArray *packages = [NSMutableArray new];

	// filter out packages with the 'requried' priorty
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSPredicate *thePredicate1 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Package:'"];
	NSPredicate *thePredicate2 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Priority:'"];
	NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
	[validChars addCharactersInString:@"+-."];

	NSUInteger total = [_controlFiles count];
	CGFloat parts = 0.8;
	if(_filtered) parts = 0.5;
	CGFloat progressPerPart = (parts/total);
	CGFloat progress = 0.2;

	for(NSString *control in _controlFiles){
		NSArray *lines = [control componentsSeparatedByCharactersInSet:newlineChars];
		if(![lines count]){
			continue;
		}

		// get package name
		NSString *packageLine = [[lines filteredArrayUsingPredicate:thePredicate1] firstObject];
		NSString *package = [packageLine stringByReplacingOccurrencesOfString:@"Package: " withString:@""];
		if(![package length] || [package isEqualToString:@"me.lightmann.iamlazy"]){
			// filter out IAmLazy since it'll be installed by the user anyway
			continue;
		}

		BOOL valid = ![[package stringByTrimmingCharactersInSet:validChars] length];
		if(valid){
			// get package priority
			NSArray *priorityLines = [lines filteredArrayUsingPredicate:thePredicate2];
			if(![priorityLines count]){
				// local package
				[packages addObject:package];
			}
			else if(![[priorityLines firstObject] hasSuffix:@"required"]){
				// non-required package
				[packages addObject:package];
			}
		}

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];
	}
	return packages;
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
	// get repo apt lists
	NSError *readError = nil;
	NSString *aptListsDir = @"/var/lib/apt/lists/";
	NSArray *aptLists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aptListsDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", aptListsDir, readError];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}
	else if(![aptLists count]){
		NSString *msg = [NSString stringWithFormat:@"%@ has no contents?!", aptListsDir];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}

	[_generalManager updateItemProgress:0.8];

	// ensure bootstrap repos' package files are up-to-date
	[_generalManager updateAPT];

	[_generalManager updateItemProgress:0.9];

	// get packages to ignore
	NSMutableArray *packagesToIgnore = [NSMutableArray new];
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '_Packages'"];
	NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'Package:'"];
	for(NSString *repo in [self getReposToFilter]){
		NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", repo];
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, predicate2]];
		NSArray *pkgLists = [aptLists filteredArrayUsingPredicate:thePredicate];
		if(![pkgLists count]){
			continue;
		}

		// count should be one for pkgLists
		for(NSString *list in pkgLists){
			NSError *readError2 = nil;
			NSString *listPath = [aptListsDir stringByAppendingPathComponent:list];
			NSString *content = [NSString stringWithContentsOfFile:listPath encoding:NSUTF8StringEncoding error:&readError2];
			if(readError2){
				NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", listPath, readError2];
				[_generalManager displayErrorWithMessage:msg];
				return [NSArray new];
			}

			NSArray *lines = [content componentsSeparatedByCharactersInSet:newlineChars];
			if(![lines count]){
				NSString *msg = [NSString stringWithFormat:@"%@ has no contents?!", listPath];
				[_generalManager displayErrorWithMessage:msg];
				return [NSArray new];
			}

			NSArray *packages = [lines filteredArrayUsingPredicate:predicate3];
			NSArray *packagesWithNoDups = [[NSOrderedSet orderedSetWithArray:packages] array]; // remove dups and retain order
			for(NSString *line in packagesWithNoDups){
				if(![line length]){
					continue;
				}

				NSString *cleanLine = [line stringByReplacingOccurrencesOfString:@"Package: " withString:@""];
				if([cleanLine length]){
					[packagesToIgnore addObject:cleanLine];
				}
			}
		}
	}

	// grab all installed packages and remove the ones we want to ignore
	NSMutableArray *userPackages = [[self getAllPackages] mutableCopy];
	[userPackages removeObjectsInArray:packagesToIgnore];
	return userPackages;
}

-(void)gatherFilesForPackages{
	NSString *dir = @"NSFileTypeDirectory";
	NSString *symLink = @"NSFileTypeSymbolicLink";
	NSString *dpkgInfoDir = @"/var/lib/dpkg/info/";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSString *filesToCopy = [tmpDir stringByAppendingPathComponent:@".filesToCopy"];

	NSUInteger total = ([_packages count] * 5); // 5 steps/pkg
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;

	for(NSString *package in _packages){
		// get installed files
		NSError *readError = nil;
		NSString *path = [[dpkgInfoDir stringByAppendingPathComponent:package] stringByAppendingPathExtension:@"list"];
		NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
			continue;
		}

		NSArray *lines = [contents componentsSeparatedByCharactersInSet:newlineChars];
		if(![lines count]){
			NSLog(@"[IAmLazyLog] %@ has no content?!", path);
			continue;
		}

		// determine unique generic files and directories
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
			NSUInteger count = [[NSMutableString stringWithString:contents] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, [contents length])];

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
			NSLog(@"[IAmLazyLog] %@ has no generic files!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		NSError *writeError = nil;
		[gFilePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write generic files to %@ for %@! Error: %@", filesToCopy, package, writeError);
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

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];

		[self makeSubDirectories:directories inDirectory:tweakDir];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];

		[self copyGenericFiles];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];

		[self makeControlForPackage:package inDirectory:tweakDir];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];

		[self copyDEBIANFiles];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];
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
	NSArray *relevantControls = [_controlFiles filteredArrayUsingPredicate:thePredicate];
	if(![relevantControls count]){
		NSString *msg = [NSString stringWithFormat:@"There appear to be no controls for %@?!", package];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSString *theOne = [relevantControls firstObject];
	NSString *noStatusLine = [theOne stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""]; // dpkg adds this at installation
	if(![noStatusLine length]){
		NSString *msg = [NSString stringWithFormat:@"The control for %@ is blank?!", package];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// ensure final newline (deb will fail to build if missing)
	NSString *info = [noStatusLine stringByAppendingString:@"\n"];

	// make DEBIAN dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *debian = [tweakDir stringByAppendingPathComponent:@"DEBIAN/"];
	if(![fileManager fileExistsAtPath:debian]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@! Error: %@", debian, writeError];
			[_generalManager displayErrorWithMessage:msg];
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
	NSUInteger total = [_packages count];
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;
	for(int i = 0; i < total; i++){
		// have to run as root in order to retain file attributes (ownership, etc)
		[_generalManager executeCommandAsRoot:@"buildDeb"];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];
	}

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
	else if(![tmp count]){
		NSString *msg = [NSString stringWithFormat:@"%@ has no contents!", tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSArray *debs = [tmp filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"]];
	if(![debs count]){
		[_generalManager displayErrorWithMessage:@"Failed to build debs! Not sure how we got here honestly."];
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

-(void)makeTarball{
	// craft new backup name and append the gzip tar extension
	NSString *backupName;
	NSString *new = [self craftNewBackupName];
	if(!_filtered) backupName = [new stringByAppendingString:@"u.tar.gz"];
	else backupName = [new stringByAppendingPathExtension:@"tar.gz"];
	NSString *backupPath = [backupDir stringByAppendingPathComponent:backupName];

	// make tarball (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		write_archive([backupPath UTF8String]); // UI fails to update due to hold below :/

		// signal that we're good to go
		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}

	[self verifyFileAtPath:backupPath];

	[_generalManager cleanupTmp];
}

-(NSString *)craftNewBackupName{
	NSUInteger latestBackup = 0;
	NSArray *backups = [_generalManager getBackups];
	if([backups count]){
		NSString *latest = [backups firstObject];
		NSCharacterSet *nonNumericChars = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
		NSMutableArray *numbers = [[latest componentsSeparatedByCharactersInSet:nonNumericChars] mutableCopy];
		[numbers removeObject:@""]; // array contains numbers and an empty string(s); we only want the numbers
		if([numbers count]){
			latestBackup = [[numbers lastObject] intValue]; // supports both the current and legacy naming schemes
		}
	}

	// grab date in desired format
	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyyMMd"];
	return [NSString stringWithFormat:@"IAL-%@_%lu", [formatter stringFromDate:[NSDate date]], (latestBackup + 1)];
}

-(void)verifyFileAtPath:(NSString *)filePath{
	if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
		NSString *msg = [NSString stringWithFormat:@"%@ DNE!", filePath];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}
}

@end

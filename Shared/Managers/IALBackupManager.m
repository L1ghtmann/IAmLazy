//
//	IALBackupManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/libarchive.h"
#import "IALGeneralManager.h"
#import "IALBackupManager.h"
#import "../../Common.h"

@implementation IALBackupManager

-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL, NSString *))completed{
	// check for old tmp files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:tmpDir]){
		if(![_generalManager cleanupTmp]){
			completed(NO, nil);
			return;
		}
	}

	if(![_generalManager ensureBackupDirExists]){
		completed(NO, nil);
		return;
	}

	_filtered = filter;
	[_generalManager updateItem:ItemTypeStatus WithStatus:-0.5];

	_controlFiles = [self getControlFiles];
	if(![_controlFiles count]){
		[_generalManager displayErrorWithMessage:localize(@"Failed to generate controls for installed packages!")];
		completed(NO, nil);
		return;
	}

	if(!_filtered) _packages = [self getAllPackages];
	else _packages = [self getUserPackages];
	if(![_packages count]){
		[_generalManager displayErrorWithMessage:localize(@"Failed to generate list of packages!")];
		completed(NO, nil);
		return;
	}

	[_generalManager updateItem:ItemTypeStatus WithStatus:0];

	// make fresh tmp directory
	if(![fileManager fileExistsAtPath:tmpDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to create %@!")
															stringByAppendingString:@"\n\n"]
															stringByAppendingString:localize(@"Info: %@")],
															tmpDir,
															writeError.localizedDescription];
			[_generalManager displayErrorWithMessage:msg];
			completed(NO, nil);
			return;
		}
	}

	[_generalManager updateItem:ItemTypeStatus WithStatus:0.5];
	if(![self gatherFilesForPackages]){
		completed(NO, nil);
		return;
	}
	[_generalManager updateItem:ItemTypeStatus WithStatus:1];

	[_generalManager updateItem:ItemTypeStatus WithStatus:1.5];
	if(![self buildDebs]){
		completed(NO, nil);
		return;
	}
	[_generalManager updateItem:ItemTypeStatus WithStatus:2];

	// specify the bootstrap it was created on
	if(!_filtered){
		if(![self markBackupAs:0]){
			completed(NO, nil);
			return;
		}
	}

	// specify rootless
	if([@THEOS_PACKAGE_INSTALL_PREFIX length]){
		if(![self markBackupAs:1]){
			completed(NO, nil);
			return;
		}
	}

	// make archive of packages
	[_generalManager updateItem:ItemTypeStatus WithStatus:2.5];
	if(![self makeTarball]){
		completed(NO, nil);
		return;
	}
	[_generalManager updateItem:ItemTypeStatus WithStatus:3];

	completed(YES, [_skip count] ? [_skip componentsJoinedByString:@",\n"] : nil);
}

-(NSArray<NSString *> *)getControlFiles{
	[_generalManager updateItem:ItemTypeProgress WithStatus:0];

	// get control files for all installed packages
	NSError *readError = nil;
	NSString *dpkgStatus = ROOT_PATH_NS_VAR(@"/var/lib/dpkg/status");
	NSString *contents = [NSString stringWithContentsOfFile:dpkgStatus encoding:NSUTF8StringEncoding error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
														stringByAppendingString:@" "]
														stringByAppendingString:localize(@"Info: %@")],
														dpkgStatus,
														readError.localizedDescription];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}

	NSArray *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	if(![lines count]){
		NSString *msg = [NSString stringWithFormat:localize(@"%@ is blank?!"), dpkgStatus];
		[_generalManager displayErrorWithMessage:msg];
		return [NSArray new];
	}

	[_generalManager updateItem:ItemTypeProgress WithStatus:0.1];

	// divvy up massive control collection into individual control files
	NSMutableArray *controls = [NSMutableArray new];
	NSMutableString *controlFile = [NSMutableString new];
	for(NSString *line in lines){
		if([line length]){
			if([controlFile length]){
				[controlFile appendString:@"\n"];
			}
			[controlFile appendString:line];
		}
		// when we hit an empty line it's a new control
		else{
			[controls addObject:[controlFile copy]];
			[controlFile setString:@""];
		}
	}

	[_generalManager updateItem:ItemTypeProgress WithStatus:0.2];

	IALLog(@"Read %lu controls", [controls count]);

	return controls;
}

-(NSMutableArray<NSString *> *)getAllPackages{
	NSMutableArray *packages = [NSMutableArray new];

	// filter out packages with the 'requried' priority
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
		if(![package length] || [package isEqualToString:@"me.lightmann.iamlazy"] || [package isEqualToString:@"me.lightmann.iamlazy-cli"]){
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
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];
	}

	IALLog(@"Found %lu packages", [packages count]);

	return packages;
}

-(void)canisterCheckPackages:(NSArray<NSString *> *)packages withCallback:(void (^)(BOOL success, NSArray *data))callback{
	if(![packages count]){
		IALLogErr(@"Packages array passed to Canister check is empty!");
		callback(NO, nil);
		return;
	}

	// Define proper HTTP enconding spec
	// https://github.com/daltoniam/swifthttp/issues/178
	NSMutableCharacterSet *set = [NSMutableCharacterSet new];
	[set formUnionWithCharacterSet:[NSCharacterSet URLQueryAllowedCharacterSet]];
	[set removeCharactersInString:@"[].:/?&=;+!@#$()',*\""]; // HTTP disallowed

	// Canister multi package GET
	NSString *ids = [[packages componentsJoinedByString:@","] stringByAddingPercentEncodingWithAllowedCharacters:set];
	NSString *reqStr = [@"https://api.canister.me/v2/jailbreak/package/multi?priority=bootstrap&ids=" stringByAppendingString:ids];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:reqStr]];
	[request setHTTPMethod:@"GET"];

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	[[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSInteger responseCode = [(NSHTTPURLResponse *)response statusCode];
		if(responseCode != 200){
			IALLogErr(@"%@; HTTP status code: %li", error.localizedDescription, responseCode);
			callback(NO, nil);
			return;
		}

		// expected GET response is a JSON dict
		NSError *jsonErr = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
		if(!jsonErr){
			// 'data' object expected as array of dicts
			id multiData = [json objectForKey:@"data"];
			if(multiData && [multiData isKindOfClass:[NSArray class]]){
				multiData = (NSArray *)multiData;

				// array for the package ids we will ignore
				NSMutableArray *filter = [NSMutableArray new];
				for(int i = 0; i < [multiData count]; i++){
					id pkgInfo = multiData[i]; // one dict per package queried
					if(pkgInfo && [pkgInfo isKindOfClass:[NSDictionary class]]){
						pkgInfo = (NSDictionary *)pkgInfo;

						// package id
						id pkg = [pkgInfo objectForKey:@"package"];
						if(pkg && [pkg isKindOfClass:[NSString class]]){
							pkg = (NSString *)pkg;
						}
						else{
							IALLogErr(@"Canister's 'package' data object was of unexpected type!");
							callback(NO, nil);
							return;
						} // end package id

						// package repository
						id repoInfo = [pkgInfo objectForKey:@"repository"];
						if(repoInfo && [repoInfo isKindOfClass:[NSDictionary class]]){
							repoInfo = (NSDictionary *)repoInfo;

							// bootstrap status
							id isBootstrap = [repoInfo objectForKey:@"isBootstrap"];
							if(isBootstrap && [isBootstrap isKindOfClass:[NSNumber class]]){
								if([isBootstrap boolValue]){
									// bootstrap-vended package
									// these can cause issues if
									// installed on incompatible jbs
									[filter addObject:pkg];
								}
							}
							else{
								IALLogErr(@"Canister's %@'s repository's 'isBootstrap' was of unexpected type!", pkg);
								callback(NO, nil);
								return;
							} // end bootstrap status
						}
						else{
							IALLogErr(@"Canister's %@'s 'repository' was of unexpected type!", pkg);
							callback(NO, nil);
							return;
						} // end package repository
					}
					else{
						IALLogErr(@"Canister's data's components were of unexpected type!");
						callback(NO, nil);
						return;
					} // end pkgInfo
				} // end for loop
				callback(YES, filter);
			}
			else{
				IALLogErr(@"Canister 'data' object was of unexpected type!");
				callback(NO, nil);
				return;
			} // end data
		}
		else{
			IALLogErr(@"Canister's response was of unexpected type! Serialization error: %@", jsonErr.localizedDescription);
			callback(NO, nil);
			return;
		} // end JSON serialization
	}] resume];
}

-(NSMutableArray<NSString *> *)getUserPackages{
	[_generalManager updateItem:ItemTypeProgress WithStatus:0.8];

	dispatch_semaphore_t sem = dispatch_semaphore_create(0);

	// get packages to ignore
	__block NSMutableArray *packages = [[self getAllPackages] mutableCopy];
	[self canisterCheckPackages:packages withCallback:^(BOOL success, NSArray *filter){
		if(success && [filter count]){
			// remove packages that we want to ignore from list
			[packages removeObjectsInArray:filter];
		}
		else{
			// return and bail out
			packages = [NSMutableArray new];
		}

		// we're good to go
		dispatch_semaphore_signal(sem);
	}];

	// wait for block to return before proceeding
	dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

	[_generalManager updateItem:ItemTypeProgress WithStatus:0.9];

	IALLog(@"Found %lu packages after Canister filter", [packages count]);

	return packages;
}

-(BOOL)gatherFilesForPackages{
	NSString *dpkgInfoDir = ROOT_PATH_NS_VAR(@"/var/lib/dpkg/info/");
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSString *filesToCopy = [tmpDir stringByAppendingPathComponent:@".filesToCopy"];

	_skip = [NSMutableArray new];

	NSUInteger total = ([_packages count] * 5); // 5 steps per pkg
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;

	NSError *error = nil;
	for(NSString *package in _packages){
		// get installed files
		IALLog(@"Gathering files for %@", package);
		NSString *path = [[dpkgInfoDir stringByAppendingPathComponent:package] stringByAppendingPathExtension:@"list"];
		NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		if(error){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
															stringByAppendingString:@" "]
															stringByAppendingString:localize(@"Info: %@")],
															path,
															error.localizedDescription];
			// [_generalManager displayErrorWithMessage:msg];
			IALLogErr(@"%@", msg);
			error = nil;

			// skip any packages that are not 'Field 3: state: "installed"' (have an entry in /var/lib/dpkg/status but no files on-device)
			[_skip addObject:package];

			continue;
		}

		NSArray *lines = [contents componentsSeparatedByCharactersInSet:newlineChars];
		if(![lines count]){
			NSString *msg = [NSString stringWithFormat:localize(@"%@ has no contents!"), path];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		/*
			Three part process:
			1) fix symlink lines
			2) find unique items
			3) characterize files and dirs
		*/

		// first pass: symlinks
		NSPredicate *symlink = [NSPredicate predicateWithFormat:@"SELF CONTAINS '->'"];
		NSArray *symlinks = [lines filteredArrayUsingPredicate:symlink];
		NSMutableArray *updatedLines = [lines mutableCopy];
		for(NSString *line in symlinks){
			// find line
			NSInteger index = [updatedLines indexOfObject:line];

			// grab relevant bit
			NSArray *bits = [line componentsSeparatedByString:@" "];
			NSString *newLine = bits.firstObject;

			// replace with relevant bit
			[updatedLines replaceObjectAtIndex:index withObject:newLine];
		}

		// second pass: find unique items
		NSMutableArray *unique = [NSMutableArray array];
		NSInteger count = [updatedLines count];
		for(NSInteger i = 0; i < count; i++){
			NSString *line = updatedLines[i];
			if(![line length] || [line isEqualToString:@"/."] || [[line lastPathComponent] isEqualToString:@".."] || [[line lastPathComponent] isEqualToString:@"."]){
				continue;
			}

			/*
				here, we want to somehow distinguish between the package's list structure
				and the actual files/directories that the package places on-device

				to do this, we make use of the fact that 1) directories are not suffixed
				with "/" in the packacge's list structure and 2) that the list is ordered.
				by appending "/" to the given line and checking for a prefix match in
				the subsequent line, we can see if the given line is part of the
				directory structure, as it will be present in other lines, or if it's
				a unique item installed by the package, as it will differ in its prefix

				test:
						/var/jb/usr/lib/TweakInject.dylib & /var/jb/usr/lib/TweakInject
						from 'ellekit' should both pass as should /var/jb/usr/include/llvm
						& /var/jb/usr/include/llvm-c from 'llvm-dev'
			*/
			NSString *nextLine = (i < count - 1) ? updatedLines[i + 1] : nil;
			if(!nextLine || ![nextLine hasPrefix:[line stringByAppendingString:@"/"]]){
				[unique addObject:line];
			}
		}

		// third pass: characterize files and dirs
		NSMutableArray *files = [NSMutableArray new];
		NSMutableArray *directories = [NSMutableArray new];
		for(NSString *line in unique){
			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:line error:&error];
			if(error){
				IALLogErr(@"Failed to get attributes for %@! Info: %@", line, error.localizedDescription);
				error = nil;
				continue;
			}

			if([fileAttributes fileType] == NSFileTypeDirectory){
				[directories addObject:line];
			}
			else{
				// also treating symlinks
				// as files (i.e., cp not mkdir)
				[files addObject:line];
			}
		}

		// put the files we want to copy into lists for easier writing
		NSString *gFilePaths = [files componentsJoinedByString:@"\n"];
		if(![gFilePaths length]){
			IALLog(@"%@ has no generic files!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		[gFilePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if(error){
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to write generic files to %@ for %@!")
															stringByAppendingString:@" "]
															stringByAppendingString:localize(@"Info: %@")],
															filesToCopy,
															package,
															error.localizedDescription];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];
		if(![self makeControlForPackage:package inDirectory:tweakDir]){
			// skip any packages that are unconfigued or half-installed
			[_skip addObject:package];
			continue;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];

		if(![self makeSubDirectories:directories inDirectory:tweakDir]){
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];

		if(![self copyFilesOfType:0]){
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];

		if(![self copyFilesOfType:1]){
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];
	}

	// remove list file now that we're done w it
	[fileManager removeItemAtPath:filesToCopy error:nil];

	// skip borked installs
	[_packages removeObjectsInArray:_skip];

	return YES;
}

-(BOOL)makeControlForPackage:(NSString *)package inDirectory:(NSString *)tweakDir{
	// get info for package
	NSString *pkg = [@"Package: " stringByAppendingString:package];
	NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", pkg];
	NSArray *relevantControls = [_controlFiles filteredArrayUsingPredicate:thePredicate];
	if(![relevantControls count]){
		// Using error log as opposed to alert as borked pkgs are skipped
		// (and the entire backup does not stop because of one package)
		NSString *msg = [NSString stringWithFormat:@"There appear to be no controls for %@?!", package];
		IALLogErr(@"%@", msg);
		return NO;
	}

	NSString *theOne = [relevantControls firstObject];
	if (![theOne length]){
		NSString *msg = [NSString stringWithFormat:@"The control for %@ is blank?!", package];
		IALLogErr(@"%@", msg);
		return NO;
	}
	/*
	https://manpages.ubuntu.com/manpages/impish/en/man1/dpkg.1.html
		Field 1: selection state: "install" || "hold" acceptable as sufficiently installed
		Field 2: flag: "ok" acceptable as package is in a known state
		Field 3: state: "installed" acceptable as sufficiently configured
	*/
	else if([theOne rangeOfString:@"Status: install ok installed"].location == NSNotFound &&
			[theOne rangeOfString:@"Status: hold ok installed"].location == NSNotFound){
		NSString *msg = [NSString stringWithFormat:@"%@ is not fully installed?!", package];
		IALLogErr(@"%@", msg);
		return NO;
	}

	NSError *error = nil;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Status:\\s.*\n" options:NSRegularExpressionCaseInsensitive error:&error];
	if(error){
		NSString *msg = [NSString stringWithFormat:@"Regex error: %@", error.localizedDescription];
		IALLogErr(@"%@", msg);
		return NO;
	}
	NSString *noStatusLine = [regex stringByReplacingMatchesInString:theOne options:0 range:NSMakeRange(0, [theOne length]) withTemplate:@""];
	if(![noStatusLine length]){
		NSString *msg = [NSString stringWithFormat:@"The control for %@ is blank?!", package];
		IALLogErr(@"%@", msg);
		return NO;
	}

	// ensure final newline (deb will fail to build if missing)
	NSString *info = [noStatusLine stringByAppendingString:@"\n\n"];

	// make DEBIAN dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *debian = [tweakDir stringByAppendingPathComponent:@"DEBIAN/"];
	if(![fileManager fileExistsAtPath:debian]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:debian withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@! Info: %@", debian, writeError.localizedDescription];
			IALLogErr(@"%@", msg);
			return NO;
		}
	}

	// write info to file
	NSData *data = [info dataUsingEncoding:NSUTF8StringEncoding];
	NSString *control = [debian stringByAppendingPathComponent:@"control"];
	[fileManager createFileAtPath:control contents:data attributes:nil];

	IALLog(@"Wrote control for %@", package);

	return YES;
}

-(BOOL)makeSubDirectories:(NSArray<NSString *> *)directories inDirectory:(NSString *)tweakDir{
	NSError *writeError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for(NSString *dir in directories){
		NSString *path = [tweakDir stringByAppendingPathComponent:dir];
		if(![fileManager fileExistsAtPath:path]){
			[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to create %@!")
																stringByAppendingString:@" "]
																stringByAppendingString:localize(@"Info: %@")],
																path,
																writeError.localizedDescription];
				[_generalManager displayErrorWithMessage:msg];
				return NO;
			}
		}
	}
	return YES;
}

-(BOOL)copyFilesOfType:(NSInteger)type{
	NSString *cmd, *msg;
	switch(type){
		case 0:{
			cmd = @"cpGFiles";
			msg = @"Failed to copy generic files!";
			break;
		}
		case 1:{
			cmd = @"cpDFiles";
			msg = @"Failed to copy DEBIAN files!";
			break;
		}
	}
	// have to run as root in order to retain file attributes (ownership, etc)
	BOOL ret = [_generalManager executeCommandAsRoot:cmd];
	if(!ret){
		[_generalManager displayErrorWithMessage:localize(msg)];
	}
	return ret;
}

-(BOOL)buildDebs{
	// write general use 'debian-binary' to file
	NSData *data = [@"2.0\n" dataUsingEncoding:NSUTF8StringEncoding];
	NSString *formatVer = [tmpDir stringByAppendingPathComponent:@"debian-binary"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager createFileAtPath:formatVer contents:data attributes:nil];

	NSUInteger total = [_packages count];
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;
	for(int i = 0; i < total; i++){
		// have to run as root in order to retain file attributes (ownership, etc)
		BOOL ret = [_generalManager executeCommandAsRoot:@"buildDeb"];
		if(!ret){
			NSString *msg = [NSString stringWithFormat:localize(@"Failed to build deb for %@!"), _packages[i]];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		progress+=progressPerPart;
		[_generalManager updateItem:ItemTypeProgress WithStatus:progress];
	}

	// remove 'debian-binary' now that we're done w it
	[fileManager removeItemAtPath:formatVer error:nil];

	return [self verifyDebs];
}

-(BOOL)verifyDebs{
	NSError *readError = nil;
	NSArray *tmp = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to get contents of %@!")
														stringByAppendingString:@" "]
														stringByAppendingString:localize(@"Info: %@")],
														tmpDir,
														readError.localizedDescription];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}
	else if(![tmp count]){
		NSString *msg = [NSString stringWithFormat:localize(@"%@ has no contents!"), tmpDir];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}

	NSArray *debs = [tmp filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"]];
	if(![debs count]){
		[_generalManager displayErrorWithMessage:localize(@"Failed to build debs! Not sure how we got here honestly.")];
		return NO;
	}

	return YES;
}

-(BOOL)markBackupAs:(NSInteger)type{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *file;
	switch(type){
		case 0:{
			NSString *bootstrap = @"elucubratus";
			if([fileManager fileExistsAtPath:ROOT_PATH_NS_VAR(@"/.procursus_strapped")]){
				bootstrap = @"procursus";
			}
			file = [NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap];
			break;
		}
		case 1:{
			NSString *txt = @".rootless";
			file = [tmpDir stringByAppendingPathComponent:txt];
			break;
		}
	}
	return [fileManager createFileAtPath:file contents:nil attributes:nil];
}

-(BOOL)makeTarball{
	// craft new backup name and append the gzip tar extension
	NSString *backupName;
	NSString *new = [self craftNewBackupName];
	if(!_filtered) backupName = [new stringByAppendingString:@"u.tar.gz"];
	else backupName = [new stringByAppendingPathExtension:@"tar.gz"];
	NSString *backupPath = [backupDir stringByAppendingPathComponent:backupName];

	BOOL status = write_archive([tmpDir fileSystemRepresentation], [backupPath fileSystemRepresentation], NO);
	if(status){
		status = [self verifyFileAtPath:backupPath];
	}
	else{
		[_generalManager displayErrorWithMessage:localize(@"Failed to build final archive!")];
	}
	[_generalManager cleanupTmp];
	return status;
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
			// supports both the current and legacy naming schemes
			latestBackup = [[numbers lastObject] intValue];
		}
	}

	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"yyyyMMd"];
	return [NSString stringWithFormat:@"IAL-%@_%lu", [formatter stringFromDate:[NSDate date]], (latestBackup + 1)];
}

-(BOOL)verifyFileAtPath:(NSString *)filePath{
	if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
		NSString *msg = [NSString stringWithFormat:@"%@ DNE!", filePath];
		[_generalManager displayErrorWithMessage:msg];
		return NO;
	}
	return YES;
}

@end

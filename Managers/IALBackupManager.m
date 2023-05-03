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

-(void)makeBackupWithFilter:(BOOL)filter andCompletion:(void (^)(BOOL))completed{
	// check for old tmp files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	[_generalManager ensureBackupDirExists];
	_filtered = filter;
	[_generalManager updateItemStatus:-0.5];

	_controlFiles = [self getControlFiles];
	if(![_controlFiles count]){
		[_generalManager displayErrorWithMessage:localize(@"Failed to generate controls for installed packages!")];
		return;
	}

	if(!_filtered) _packages = [self getAllPackages];
	else _packages = [self getUserPackages];
	if(![_packages count]){
		[_generalManager displayErrorWithMessage:localize(@"Failed to generate list of packages!")];
		return;
	}

	[_generalManager updateItemStatus:0];

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
			return;
		}
	}

	[_generalManager updateItemStatus:0.5];
	[self gatherFilesForPackages];
	[_generalManager updateItemStatus:1];

	[_generalManager updateItemStatus:1.5];
	if(![self buildDebs]) return;
	[_generalManager updateItemStatus:2];

	// specify the bootstrap it was created on
	if(!_filtered) [self makeBootstrapFile];

	// make archive of packages
	[_generalManager updateItemStatus:2.5];
	[self makeTarball];
	[_generalManager updateItemStatus:3];

	completed(YES);
}

-(NSArray<NSString *> *)getControlFiles{
	[_generalManager updateItemProgress:0];

	// get control files for all installed packages
	NSError *readError = nil;
	NSString *dpkgStatus = @"/var/lib/dpkg/status";
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

-(void)canisterCheckPackages:(NSArray<NSString *> *)packages withCallback:(void (^)(BOOL success, NSArray *data))callback{
	if(![packages count]){
		IALLogErr(@"Packages array passed to Canister check is empty!");
		callback(NO, nil);
	}

	// Canister multi package GET
	NSString *ids = [[packages componentsJoinedByString:@","] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	NSString *reqStr = [@"https://api.canister.me/v2/jailbreak/package/multi?ids=" stringByAppendingString:ids];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	[request setURL:[NSURL URLWithString:reqStr]];
	[request setHTTPMethod:@"GET"];

	NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	[[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSInteger responseCode = [(NSHTTPURLResponse *)response statusCode];
		if(responseCode != 200){
			IALLogErr(@"%@; HTTP status code: %li", [error localizedDescription], responseCode);
			callback(NO, nil);
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

						id pkg = [pkgInfo objectForKey:@"package"]; // package id
						if(pkg && [pkg isKindOfClass:[NSString class]]){
							pkg = (NSString *)pkg;

							id repoInfo = [pkgInfo objectForKey:@"repository"]; // package origin info
							if(repoInfo && [repoInfo isKindOfClass:[NSDictionary class]]){
								repoInfo = (NSDictionary *)repoInfo;

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
								}
							}
							else{
								IALLogErr(@"Canister's %@'s 'repository' was of unexpected type!", pkg);
								callback(NO, nil);
							}
						}
						else{
							IALLogErr(@"Canister's 'package' data object was of unexpected type!");
							callback(NO, nil);
						}
					}
					else{
						IALLogErr(@"Canister's data's components were of unexpected type!");
						callback(NO, nil);
					}
				}
				callback(YES, filter);
			}
			else{
				IALLogErr(@"Canister 'data' object was of unexpected type!");
				callback(NO, nil);
			}
		}
		else{
			IALLogErr(@"Canister's response was of unexpected type! Serialization error: %@", [jsonErr localizedDescription]);
			callback(NO, nil);
		}
	}] resume];
}

-(NSArray<NSString *> *)getUserPackages{
	[_generalManager updateItemProgress:0.8];

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

	[_generalManager updateItemProgress:0.9];

	return packages;
}

-(void)gatherFilesForPackages{
	NSString *dpkgInfoDir = @"/var/lib/dpkg/info/";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	NSString *filesToCopy = [tmpDir stringByAppendingPathComponent:@".filesToCopy"];

	NSUInteger total = ([_packages count] * 5); // 5 steps per pkg
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;

	NSError *error = nil;
	for(NSString *package in _packages){
		// get installed files
		NSString *path = [[dpkgInfoDir stringByAppendingPathComponent:package] stringByAppendingPathExtension:@"list"];
		NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
		if(error){
			IALLogErr(@"Failed to get contents of %@! Info: %@", path, error.localizedDescription);
			error = nil;
			continue;
		}

		NSArray *lines = [contents componentsSeparatedByCharactersInSet:newlineChars];
		if(![lines count]){
			IALLogErr(@"%@ has no content?!", path);
			continue;
		}

		// determine unique generic files and directories
		NSMutableArray *genericFiles = [NSMutableArray new];
		NSMutableArray *directories = [NSMutableArray new];
		for(NSString *line in lines){
			if(![line length] || [line isEqualToString:@"/."] || [[line lastPathComponent] isEqualToString:@".."] || [[line lastPathComponent] isEqualToString:@"."]){
				continue;
			}

			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:line error:&error];
			if(error){
				IALLogErr(@"Failed to get attributes for %@! Info: %@", line, error.localizedDescription);
				error = nil;
				continue;
			}

			// for categorization below
			NSString *type = [fileAttributes fileType];

			// check to see how many times the current filepath is present in the list output
			// shoutout Cœur on StackOverflow for this efficient code (https://stackoverflow.com/a/57869286)
			NSUInteger count = [[NSMutableString stringWithString:contents] replaceOccurrencesOfString:line withString:line options:NSLiteralSearch range:NSMakeRange(0, [contents length])];

			if(count == 1){ // this is good, means it's unique!
				if(type == NSFileTypeDirectory){
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
				if(type != NSFileTypeDirectory && type != NSFileTypeSymbolicLink){
					[genericFiles addObject:line];
				}
				else if(type == NSFileTypeSymbolicLink){
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
			IALLog(@"%@ has no generic files!", package);
		}

		// this is nice because it overwrites the file's content, unlike the write method from NSFileManager
		[gFilePaths writeToFile:filesToCopy atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if(error){
			IALLogErr(@"Failed to write generic files to %@ for %@! Info: %@", filesToCopy, package, error.localizedDescription);
			error = nil;
			continue;
		}

		// make dir to hold stuff for the tweak
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:package];
		if(![fileManager fileExistsAtPath:tweakDir]){
			[fileManager createDirectoryAtPath:tweakDir withIntermediateDirectories:YES attributes:nil error:&error];
			if(error){
				IALLogErr(@"Failed to create %@! Info: %@", tweakDir, error.localizedDescription);
				error = nil;
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
	[fileManager removeItemAtPath:filesToCopy error:&error];
	if(error){
		IALLogErr(@"Failed to delete %@! Info: %@", filesToCopy, error.localizedDescription);
	}
}

-(void)makeSubDirectories:(NSArray<NSString *> *)directories inDirectory:(NSString *)tweakDir{
	NSError *writeError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for(NSString *dir in directories){
		NSString *path = [tweakDir stringByAppendingPathComponent:dir];
		if(![fileManager fileExistsAtPath:path]){
			[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				IALLogErr(@"Failed to create %@! Info: %@", path, writeError.localizedDescription);
				writeError = nil;
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
		NSString *msg = [NSString stringWithFormat:localize(@"There appear to be no controls for %@?!"), package];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	NSString *theOne = [relevantControls firstObject];
	NSString *noStatusLine = [theOne stringByReplacingOccurrencesOfString:@"Status: install ok installed\n" withString:@""]; // dpkg adds this at installation
	if(![noStatusLine length]){
		NSString *msg = [NSString stringWithFormat:[[localize(@"The control for")
														stringByAppendingString:@" "]
														stringByAppendingString:localize(@"%@ is blank?!")],
														package];
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
			NSString *msg = [NSString stringWithFormat:[[localize(@"Failed to create %@!")
															stringByAppendingString:@" "]
															stringByAppendingString:localize(@"Info: %@")],
															debian,
															writeError.localizedDescription];
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

-(BOOL)buildDebs{
	NSUInteger total = [_packages count];
	CGFloat progressPerPart = (1.0/total);
	CGFloat progress = 0.0;
	for(int i = 0; i < total; i++){
		// have to run as root in order to retain file attributes (ownership, etc)
		[_generalManager executeCommandAsRoot:@"buildDeb"];

		progress+=progressPerPart;
		[_generalManager updateItemProgress:progress];
	}

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

	write_archive([backupPath fileSystemRepresentation]);

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
			// supports both the current and legacy naming schemes
			latestBackup = [[numbers lastObject] intValue];
		}
	}

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

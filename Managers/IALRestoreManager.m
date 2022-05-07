//
//	IALRestoreManager.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Compression/libarchive.h"
#import "IALGeneralManager.h"
#import "IALRestoreManager.h"
#import "../Common.h"

@implementation IALRestoreManager

-(void)restoreFromBackup:(NSString *)backupName ofType:(NSInteger)type{
	// reset errors
	[_generalManager setEncounteredError:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"null"];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		NSString *msg = @"The backup dir does not exist!";
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// check for backups
	if(![[_generalManager getBackups] count]){
		NSString *msg = @"No backups were found!";
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0"];

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	// make log dir if it doesn't exist already
	if(![fileManager fileExistsAtPath:logDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", logDir, writeError];
			[_generalManager displayErrorWithMessage:msg];
			return;
		}
	}

	if(type == 0){
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];
		[self extractArchive:target];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

		BOOL compatible = YES;
		if([backupName containsString:@"u.tar.gz"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
			[self installDebs];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];
		}
	}
	else{
		BOOL compatible = YES;
		if([backupName containsString:@"u.txt"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"0.7"];

			dispatch_semaphore_t sema = dispatch_semaphore_create(0); // wait for async block
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				// get pkgs available from installed repos
				NSArray *availablePkgs = [self getAvailablePackages];
				if(![availablePkgs count]){
					NSString *msg = @"Failed to generate list of available packages! \n\nPlease try again.";
					[_generalManager displayErrorWithMessage:msg];
					return;
				}

				// get packages from list
				NSArray *listPkgs = [self getPackagesForList:target];
				if(![listPkgs count]){
					NSString *msg = @"Failed to find valid packages in the target list! \n\nPlease try again.";
					[_generalManager displayErrorWithMessage:msg];
					return;
				}

				// get download url for pkg deb
				NSMutableArray *debUrls = [NSMutableArray new];
				for(NSString *pkg in listPkgs){
					NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"ANY SELF.@allKeys ==[cd] %@", pkg];
					NSArray *results = [availablePkgs filteredArrayUsingPredicate:thePredicate];
					if(![results count]){
						NSLog(@"[IAmLazyLog] %@ has no download candidate!", pkg);
						continue;
					}
					[debUrls addObject:[[[results lastObject] allValues] firstObject]];
				}
				if(![debUrls count]){
					NSString *msg = @"Failed to determine deb urls for desired packages! \n\nPlease try again.";
					[_generalManager displayErrorWithMessage:msg];
					return;
				}
				[self setDebURLS:debUrls];

				// signal that we're good to go
				dispatch_semaphore_signal(sema);
			});
			while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
			}

			// create tmpDir
			if(![fileManager fileExistsAtPath:tmpDir]){
				NSError *writeError = nil;
				[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
				if(writeError){
					NSString *msg = [NSString stringWithFormat:@"Failed to create %@. \n\nError: %@", tmpDir, writeError];
					[_generalManager displayErrorWithMessage:msg];
					return;
				}
			}

			// prep for download tasks
			__block BOOL downloadsComplete = NO;
			[[NSNotificationCenter defaultCenter] addObserverForName:@"downloadsComplete" object:nil queue:nil usingBlock:^(NSNotification *notif) {
				downloadsComplete = YES;
			}];

			// used below to determine when to post ^ notif
			[self setExpectedDownloads:[_debURLS count]];

			// download debs from urls
			NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"me.lightmann.iamlazy"];
			NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
			for(NSURL *url in _debURLS){
				NSURLRequest *request = [NSURLRequest requestWithURL:url];
				NSURLSessionTask *task = [session downloadTaskWithRequest:request];
				[task resume];
			}

			// wait for 'done' notif
			while(!downloadsComplete){
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
			}

			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1"];

			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"1.7"];
			[self installDebs];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"updateProgress" object:@"2"];
		}
	}

	[_generalManager cleanupTmp];
}

-(void)extractArchive:(NSString *)backupPath{
	// extract tarball contents (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		extract_archive([backupPath UTF8String]);

		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}
}

-(BOOL)verifyBootstrapForBackup:(NSString *)targetBackup{
	NSString *bootstrap = @"elucubratus";
	NSString *altBootstrap = @"procursus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		altBootstrap = @"elucubratus";
	}

	BOOL check = YES;
	if(![[targetBackup pathExtension] isEqualToString:@"txt"]){ // deb backup
		check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]];
	}
	else{ // list backup
		NSError *readError = nil;
		NSString *content = [NSString stringWithContentsOfFile:targetBackup encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to verify bootstrap for %@", targetBackup];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		NSArray *bits = [content componentsSeparatedByString:@"\n"];
		if(![bits count]){
			NSString *msg = [NSString stringWithFormat:@"%@ appears to be blank?", targetBackup];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		check = [[bits firstObject] isEqualToString:bootstrap];
	}

	if(!check){
		NSString *msg = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks running the %@ bootstrap. \n\nYour current jailbreak is using %@!", altBootstrap, bootstrap];
		[_generalManager displayErrorWithMessage:msg];
	}

	return check;
}

-(NSDictionary<NSString *, NSString *> *)getAptListLocations{
	NSDictionary *aptListLocations = @{
		@"cydia" : @"/var/lib/apt/lists/",
		@"sileo" : @"/var/mobile/Documents", // NEED TO DETERMINE
		@"sileo2" : @"/var/mobile/Documents", // NEED TO DETERMINE
		@"zebra" : @"/var/mobile/Library/Application Support/xyz.willy.Zebra/lists/",
		@"installer" : @"/var/mobile/Library/Application Support/Installer/SourcesFiles/"
	};
	return aptListLocations;
}

-(NSDictionary<NSString *, NSString *> *)getSourceListLocations{
	NSDictionary *sourceListLocations = @{
		@"cydia" : @"/etc/apt/sources.list.d/cydia.list",
		@"sileo" : @"/var/mobile/Documents/me.lightmann.iamlazy/IAL-49u.txt", // NEED TO DETERMINE
		@"sileo2" : @"/var/mobile/Documents/me.lightmann.iamlazy/IAL-49u.txt", // NEED TO DETERMINE
		@"zebra" : @"/var/mobile/Library/Application Support/xyz.willy.Zebra/sources.list",
		@"installer" : @"/var/mobile/Library/Application Support/Installer/APT/sources.list"
	};
	return sourceListLocations;
}

-(NSArray<NSString *> *)getAvailablePackages{
	// check for installed pkg managers
	NSMutableArray *pkgManagers = [NSMutableArray new];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/Applications/Cydia.app/Cydia"]){
		[pkgManagers addObject:@"cydia"];
	}
	if([fileManager fileExistsAtPath:@"/Applications/Sileo.app/Sileo"]){
		// check device jailbroken with checkra1n
		if([fileManager fileExistsAtPath:@"/.bootstrapped"]){
			[pkgManagers addObject:@"sileo2"];
		}
		else{
			[pkgManagers addObject:@"sileo"];
		}
	}
	if([fileManager fileExistsAtPath:@"/Applications/Zebra.app/Zebra"]){
		[pkgManagers addObject:@"zebra"];
	}
	if([fileManager fileExistsAtPath:@"/Applications/Installer.app/Installer"]){
		[pkgManagers addObject:@"installer"];
	}
	else{
		NSLog(@"[IAmLazyLog] There appear to be no package managers installed!");
		return [NSArray new];
	}

	// get apt and source list locations
	NSMutableArray *srcListPaths = [NSMutableArray new];
	NSMutableArray *aptListPaths = [NSMutableArray new];
	NSDictionary *src = [self getSourceListLocations];
	NSDictionary *apt = [self getAptListLocations];
	for(NSString *key in pkgManagers){
		[srcListPaths addObject:[src valueForKey:key]];
		[aptListPaths addObject:[apt valueForKey:key]];
	}

	// get installed repo links
	NSMutableArray *srcLinkPaths = [NSMutableArray new];
	for(NSString *path in srcListPaths){
		if([fileManager fileExistsAtPath:path]){
			NSError *readError = nil;
			NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSMacOSRomanStringEncoding error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
				continue;
			}

			NSArray *srcListContents = [contents componentsSeparatedByString:@"\n"];
			if(![srcListContents count]) continue;

			for(NSString *line in srcListContents){
				if([line length] && [line containsString:@"deb"]){
					NSArray *bits = [line componentsSeparatedByString:@" "];
					if([bits count] >= 2){
						// first entry is "deb" and second is the repo url
						[srcLinkPaths addObject:bits[1]];
					}
				}
			}
		}
	}

	// get Packages files for each installed repo
	NSMutableArray *pkgsAndUrls = [NSMutableArray new];
	for(NSString *path in aptListPaths){
		if([fileManager fileExistsAtPath:path]){
			NSError *readError = nil;
			NSArray *listDirContents = [fileManager contentsOfDirectoryAtPath:path error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
				continue;
			}

			NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH 'Packages'"];
			NSArray *packageFiles = [listDirContents filteredArrayUsingPredicate:thePredicate];
			if(![packageFiles count]){
				NSLog(@"[IAmLazyLog] %@ contains no *Package files!", path);
				continue;
			}

			for(NSString *packageFile in packageFiles){
				NSError *readError2 = nil;
				NSString *file = [path stringByAppendingPathComponent:packageFile];
				NSString *contents = [NSString stringWithContentsOfFile:file encoding:NSMacOSRomanStringEncoding error:&readError2];
				if(readError2){
					NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", file, readError2);
					return [NSArray new];
				}

				NSArray *lines = [contents componentsSeparatedByString:@"\n"];
				if(![lines count]) continue;

				// get available pkgs and their respective deb links
				NSMutableArray *pkgs = [NSMutableArray new];
				NSMutableArray *urls = [NSMutableArray new];
				for(int i = 0; i < [lines count]; i++){
					NSString *line = lines[i];
					if([line length]){
						if([line hasPrefix:@"Package:"]){
							[pkgs addObject:[line stringByReplacingOccurrencesOfString:@"Package: " withString:@""]];
						}
						else if([line hasPrefix:@"Filename:"]){
							NSString *localFilePath = [line stringByReplacingOccurrencesOfString:@"Filename: " withString:@""];

							NSString *justFile = [file stringByReplacingOccurrencesOfString:path withString:@""];
							NSString *repo = [justFile substringWithRange:NSMakeRange(0, [justFile rangeOfString:@"_"].location)];

							NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", repo];
							NSArray *repoUrl = [srcLinkPaths filteredArrayUsingPredicate:thePredicate];
							if([repoUrl count]){
								NSURL *baseUrl = [NSURL URLWithString:[repoUrl firstObject]];
								NSURL *url = [baseUrl URLByAppendingPathComponent:localFilePath];
								[urls addObject:url];
							}
						}
					}
				}

				// assign each pkg (key) and url (value) to a dictionary
				for(int i = 0; i < [urls count]; i++){
					NSDictionary *dict = @{
						pkgs[i] : urls[i]
					};
					[pkgsAndUrls addObject:dict];
				}
			}
		}
	}

	return pkgsAndUrls;
}

-(NSArray<NSString *> *)getPackagesForList:(NSString *)target{
	NSError *readError = nil;
	NSString *tweakList = [NSString stringWithContentsOfFile:target encoding:NSUTF8StringEncoding error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", target, readError);
		return [NSArray new];
	}

	NSArray	*tweaks = [tweakList componentsSeparatedByString:@"\n"];
	if(![tweaks count]){
		NSLog(@"[IAmLazyLog] %@ is blank!", target);
		return [NSArray new];
	}

	NSMutableArray *pkgs = [NSMutableArray new];
	NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
	[set addCharactersInString:@"+-."];
	for(NSString *tweak in tweaks){
		BOOL valid = [[tweak stringByTrimmingCharactersInSet:set] isEqualToString:@""];
		if(valid){
			// ignore unfiltered list backup's bootstrap identifier
			if([tweak isEqualToString:@"elucubratus"] || [tweak isEqualToString:@"procursus"]){
				continue;
			}

			[pkgs addObject:tweak];
		}
	}

	return pkgs;
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
	if(error){
		_expectedDownloads--;
		NSLog(@"[IAmLazyLog] %@ task failed with error: %@", [[task originalRequest] URL], error);
	}
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
	NSString *fileName = [[[downloadTask originalRequest] URL] lastPathComponent];
	NSInteger underscore = [fileName rangeOfString:@"_"].location;

	if(underscore == NSNotFound) underscore = [fileName length];

	NSError *readError = nil;
	NSData *fileData = [NSData dataWithContentsOfURL:location options:0 error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to read %@ data. Error: %@", location, readError);
		return;
	}

	NSString *header = [[NSString alloc] initWithBytes:[fileData bytes] length:([fileData length], 7) encoding:NSASCIIStringEncoding];
	if([header isEqualToString:@"!<arch>"]){ // ensure file is a .deb by checking for the diagnostic 7 byte header
		NSError *writeError = nil;
		// have to strip "illegal" characters from the filename so it passes the checks in AndSoAreYou
		NSString *cleanFileName = [[fileName substringWithRange:NSMakeRange(0, underscore)] stringByAppendingPathExtension:@"deb"];
		[fileData writeToFile:[tmpDir stringByAppendingPathComponent:cleanFileName] options:NSDataWritingAtomic error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write %@ data to file. Error: %@", location, writeError);
			return;
		}
	}

	_actualDownloads++;
	if(_actualDownloads == _expectedDownloads){
		// signal that the downloads that didn't error have completed and we can move on to install
		[[NSNotificationCenter defaultCenter] postNotificationName:@"downloadsComplete" object:nil];
	}
}

-(void)installDebs{
	// installing via apt/dpkg requires root
	[_generalManager executeCommandAsRoot:@"installDebs"];
}

@end

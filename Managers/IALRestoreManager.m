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
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	[notifCenter postNotificationName:@"updateProgress" object:@"-0.5"];

	// check for backup dir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:backupDir]){
		[_generalManager displayErrorWithMessage:@"The backup dir does not exist!"];
		return;
	}

	// check for backups
	if(![[_generalManager getBackups] count]){
		[_generalManager displayErrorWithMessage:@"No backups were found!"];
		return;
	}

	// check for target backup
	NSString *target = [backupDir stringByAppendingPathComponent:backupName];
	if(![fileManager fileExistsAtPath:target]){
		NSString *msg = [NSString stringWithFormat:@"The target backup -- %@ -- could not be found!", backupName];
		[_generalManager displayErrorWithMessage:msg];
		return;
	}

	// check for old tmp files
	if([fileManager fileExistsAtPath:tmpDir]){
		[_generalManager cleanupTmp];
	}

	// ensure logdir exists
	[_generalManager ensureBackupDirExists];

	[notifCenter postNotificationName:@"updateProgress" object:@"0"];

	BOOL compatible = YES;
	if(type == 0){
		[notifCenter postNotificationName:@"updateProgress" object:@"0.5"];
		[self extractArchive:target];
		[notifCenter postNotificationName:@"updateProgress" object:@"1"];

		if([backupName hasSuffix:@"u.tar.gz"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[notifCenter postNotificationName:@"updateProgress" object:@"1.5"];
			[self updateAPT];
			[notifCenter postNotificationName:@"updateProgress" object:@"2"];

			[notifCenter postNotificationName:@"updateProgress" object:@"2.5"];
			[self installDebs];
			[notifCenter postNotificationName:@"updateProgress" object:@"3"];
		}
	}
	else{
		if([backupName hasSuffix:@"u.txt"]){
			compatible = [self verifyBootstrapForBackup:target];
		}

		if(compatible){
			[notifCenter postNotificationName:@"updateProgress" object:@"0.5"];
			[self updateAPT];
			[notifCenter postNotificationName:@"updateProgress" object:@"1"];

			[notifCenter postNotificationName:@"updateProgress" object:@"1.5"];
			[self downloadDebsFromURLS:[self getDebURLSForList:target]];
			[notifCenter postNotificationName:@"updateProgress" object:@"2"];

			[notifCenter postNotificationName:@"updateProgress" object:@"2.5"];
			[self installDebs];
			[notifCenter postNotificationName:@"updateProgress" object:@"3"];
		}
	}

	[_generalManager cleanupTmp];
}

-(void)extractArchive:(NSString *)backupPath{
	// extract tarball contents (and avoid stalling the main thread)
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		extract_archive([backupPath UTF8String]);

		// signal that we're good to go
		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){ // stackoverflow magic (https://stackoverflow.com/a/4326754)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}
}

-(BOOL)verifyBootstrapForBackup:(NSString *)targetBackup{
	NSString *bootstrap = @"elucubratus";
	NSString *oldBootstrap = @"bingner_elucubratus"; // pre v2
	NSString *altBootstrap = @"procursus";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
		bootstrap = @"procursus";
		oldBootstrap = @"procursus";
		altBootstrap = @"elucubratus";
	}

	BOOL check = YES;
	if([targetBackup hasSuffix:@".tar.gz"]){
		check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, bootstrap]];
		if(!check) check = [fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@.made_on_%@", tmpDir, oldBootstrap]];
	}
	else{ // list backup
		NSError *readError = nil;
		NSString *content = [NSString stringWithContentsOfFile:targetBackup encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to verify bootstrap for %@", targetBackup];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		NSArray *bits = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if(![bits count]){
			NSString *msg = [NSString stringWithFormat:@"%@ appears to be blank?", targetBackup];
			[_generalManager displayErrorWithMessage:msg];
			return NO;
		}

		check = [[bits firstObject] isEqualToString:bootstrap];
		if(!check) check = [[bits lastObject] isEqualToString:[NSString stringWithFormat:@"## made on %@ ##", oldBootstrap]];
	}

	if(!check){
		NSString *msg = [NSString stringWithFormat:@"The backup you're trying to restore from was made for jailbreaks using the %@ bootstrap.\n\nYour current jailbreak is using %@!", altBootstrap, bootstrap];
		[_generalManager displayErrorWithMessage:msg];
	}

	return check;
}

-(void)updateAPT{
	// ensure bootstrap repos' package files are up-to-date
	[_generalManager updateAPT];
}

-(NSDictionary<NSString *, NSString *> *)getAptListLocations{
	NSDictionary *aptListLocations = @{
		@"cydia" : @"/var/lib/apt/lists/",
		@"zebra" : @"/var/mobile/Library/Application Support/xyz.willy.Zebra/lists/"
		/*
		@"sileo" : @"/var/lib/apt/lists/",
		@"sileo2" : @"/var/lib/apt/sileolists/", // superfluous
		@"installer" : @"/var/mobile/Library/Application Support/Installer/SourcesFiles/" // these are XZ-compressed?!
		*/
	};
	return aptListLocations;
}

-(NSDictionary<NSString *, NSString *> *)getSourceListLocations{
	NSDictionary *sourceListLocations = @{
		@"cydia" : @"/etc/apt/sources.list.d/cydia.list",
		@"zebra" : @"/var/mobile/Library/Application Support/xyz.willy.Zebra/sources.list"
		/*
		@"sileo" : @[@"/etc/apt/sources.list.d/sileo.sources", // bruh.
						@"/etc/apt/sources.list.d/procursus.sources", // "URIs:" not "deb"
						@"/etc/apt/sources.list.d/odyssey.sources",
						@"/etc/apt/sources.list.d/taurine.sources"],
		@"sileo2" : @"/etc/apt/sileo.list.d/sileo.sources", // not sure if this is still a thing?
		@"installer" : @"/var/mobile/Library/Application Support/Installer/APT/sources.list"
		*/
	};
	return sourceListLocations;
}

-(NSArray<NSDictionary<NSString *, NSString *> *> *)getAvailablePackages{
	// check for installed pkg managers
	NSMutableArray *pkgManagers = [NSMutableArray new];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if([fileManager fileExistsAtPath:@"/Applications/Cydia.app/Cydia"]){
		[pkgManagers addObject:@"cydia"];
	}
	if([fileManager fileExistsAtPath:@"/Applications/Zebra.app/Zebra"]){
		[pkgManagers addObject:@"zebra"];
	}
	/*
	if([fileManager fileExistsAtPath:@"/Applications/Sileo.app/Sileo"]){
		// check if device is running Procursus
		if([fileManager fileExistsAtPath:@"/.procursus_strapped"]){
			[pkgManagers addObject:@"sileo"];
		}
		// if device is running Elucubratus, the ported Sileo uses Cydia's list
	}
	if([fileManager fileExistsAtPath:@"/Applications/Installer.app/Installer"]){
		[pkgManagers addObject:@"installer"];
	}
	*/
	if(![pkgManagers count]){
		NSLog(@"[IAmLazyLog] No supported package managers appear to be installed.");
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

	// get installed repo urls
	NSMutableArray *repoURLS = [NSMutableArray new];
	NSCharacterSet *newlineChars = [NSCharacterSet newlineCharacterSet];
	for(NSString *path in srcListPaths){
		if([fileManager fileExistsAtPath:path]){
			NSError *readError = nil;
			NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSMacOSRomanStringEncoding error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
				continue;
			}

			NSArray *srcListContents = [contents componentsSeparatedByCharactersInSet:newlineChars];
			if(![srcListContents count]){
				continue;
			}

			for(NSString *line in srcListContents){
				if([line length] && [line hasPrefix:@"deb"]){
					NSArray *bits = [line componentsSeparatedByString:@" "];
					if([bits count] >= 2){
						// 1st obj is "deb", 2nd is the repo url, 3rd may or may not exist
						// Note: this array *will* contain duplicate repo urls
						[repoURLS addObject:bits[1]];
					}
				}
			}
		}
	}

	// assign available packages to their respective download urls
	NSMutableArray *pkgsAndUrls = [NSMutableArray new];
	for(NSString *path in aptListPaths){
		if([fileManager fileExistsAtPath:path]){
			NSError *readError = nil;
			NSArray *listDirContents = [fileManager contentsOfDirectoryAtPath:path error:&readError];
			if(readError){
				NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", path, readError);
				continue;
			}
			else if(![listDirContents count]){
				NSLog(@"[IAmLazyLog] %@ has no contents!", path);
				continue;
			}

			// grab repos' Packages files
			NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH 'Packages'"];
			NSArray *packageFiles = [listDirContents filteredArrayUsingPredicate:thePredicate];
			if(![packageFiles count]){
				NSLog(@"[IAmLazyLog] %@ contains no Package files!", path);
				continue;
			}

			for(NSString *packageFile in packageFiles){
				NSError *readError2 = nil;
				NSString *file = [path stringByAppendingPathComponent:packageFile];
				NSString *contents = [NSString stringWithContentsOfFile:file encoding:NSMacOSRomanStringEncoding error:&readError2];
				if(readError2){
					NSLog(@"[IAmLazyLog] Failed to get contents of %@! Error: %@", file, readError2);
					continue;
				}

				NSArray *lines = [contents componentsSeparatedByCharactersInSet:newlineChars];
				if(![lines count]){
					continue;
				}

				// grab package names and craft download urls
				NSMutableArray *pkgs = [NSMutableArray new];
				NSMutableArray *urls = [NSMutableArray new];
				for(NSString *line in lines){
					if([line length]){
						if([line hasPrefix:@"Package:"]){
							NSString *package = [line stringByReplacingOccurrencesOfString:@"Package: " withString:@""];
							if([package length]){
								[pkgs addObject:package];
							}
						}
						else if([line hasPrefix:@"Filename:"]){
							NSString *localFilePath = [line stringByReplacingOccurrencesOfString:@"Filename: " withString:@""];
							if(![localFilePath length]){
								continue;
							}

							NSString *justFile = [file stringByReplacingOccurrencesOfString:path withString:@""];
							if(![justFile length]){
								continue;
							}

							NSString *repo = [justFile substringWithRange:NSMakeRange(0, [justFile rangeOfString:@"_"].location)];
							if(![repo length]){
								continue;
							}

							NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", repo];
							NSArray *repoUrl = [repoURLS filteredArrayUsingPredicate:thePredicate];
							if([repoUrl count]){ // count is 2
								// confirm string is valid url (https://stackoverflow.com/a/20892574)
								NSString *urlString = [repoUrl firstObject];
								NSUInteger length = [urlString length];
								if(!length){
									continue;
								}

								NSError *initError = nil;
								NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&initError];
								if(initError){
									NSLog(@"[IAmLazyLog] Failed to initialize data detector! Error: %@", initError);
									continue;
								}

								NSRange stringRange = NSMakeRange(0, length);
								NSRange notFoundRange = (NSRange){NSNotFound, 0};
								NSRange linkRange = [dataDetector rangeOfFirstMatchInString:urlString options:0 range:stringRange];
								if(!NSEqualRanges(linkRange, notFoundRange) && NSEqualRanges(linkRange, stringRange)){
									NSURL *baseUrl = [NSURL URLWithString:urlString];
									NSURL *url = [baseUrl URLByAppendingPathComponent:localFilePath];
									[urls addObject:url];
								}
							}
						}
					}
				}

				// assign key (package) value (url) pairs
				for(int i = 0; i < [urls count]; i++){
					[pkgsAndUrls addObject:@{pkgs[i] : urls[i]}];
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

	NSArray *tweaks = [tweakList componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	if(![tweaks count]){
		NSLog(@"[IAmLazyLog] %@ is empty!", target);
		return [NSArray new];
	}

	NSMutableArray *pkgs = [NSMutableArray new];
	NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
	[validChars addCharactersInString:@"+-."];
	for(NSString *tweak in tweaks){
		BOOL valid = ![[tweak stringByTrimmingCharactersInSet:validChars] length];
		if(valid){
			// ignore unfiltered list backup's bootstrap identifier
			if([tweak isEqualToString:@"elucubratus"] || [tweak isEqualToString:@"bingner_elucubratus"] || [tweak isEqualToString:@"procursus"]){
				continue;
			}
			[pkgs addObject:tweak];
		}
	}
	return pkgs;
}

-(NSArray<NSURL *> *)getDebURLSForList:(NSString *)target{
	NSMutableArray *debURLS = [NSMutableArray new];

	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		// get pkgs available from installed repos
		NSArray *availablePkgs = [self getAvailablePackages];
		if(![availablePkgs count]){
			dispatch_semaphore_signal(sema); // exit wait block
			[_generalManager displayErrorWithMessage:@"Failed to generate list of available packages!"];
			return;
		}

		// get desired packages (from backup list)
		NSArray *desiredPkgs = [self getPackagesForList:target];
		if(![desiredPkgs count]){
			dispatch_semaphore_signal(sema);
			[_generalManager displayErrorWithMessage:@"Failed to find valid packages in the target list!"];
			return;
		}

		// get download urls for desired packages
		NSString *logDir = [backupDir stringByAppendingPathComponent:@"logs/"];
		NSString *log = [logDir stringByAppendingPathComponent:@"download_log.txt"];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *pkg in desiredPkgs){
			NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"ANY SELF.@allKeys==[cd] %@", pkg];
			NSArray *results = [availablePkgs filteredArrayUsingPredicate:thePredicate];
			if(![results count]){
				NSString *msg = [NSString stringWithFormat:@"%@ has no download candidate!", pkg];
				if(![logText length]) [logText appendString:msg];
				else [logText appendString:[@"\n" stringByAppendingString:msg]];
				NSLog(@"[IAmLazyLog] %@", msg);
				continue;
			}

			NSArray *pkgValues = [[results lastObject] allValues];
			if(![pkgValues count]){
				NSLog(@"[IAmLazyLog] %@'s dict has no values!", pkg);
				continue;
			}

			// pkgValues count should be exactly one
			[debURLS addObject:[pkgValues firstObject]];
		}

		if([logText length]){
			NSError *writeError = nil;
			[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
			if(writeError){
				NSLog(@"[IAmLazyLog Failed to write to %@! Error: %@", log, writeError);
			}
		}
		else{
			logText = nil;
		}

		if(![debURLS count]){
			dispatch_semaphore_signal(sema);
			NSString *msg = [NSString stringWithFormat:@"Failed to determine deb urls for desired packages!\n\nPlease check %@download_log.txt.", logDir];
			[_generalManager displayErrorWithMessage:msg];
			return;
		}

		dispatch_semaphore_signal(sema);
	});
	while(dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)){
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}

	return debURLS;
}

-(void)downloadDebsFromURLS:(NSArray<NSURL *> *)urls{
	// create tmpDir
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if(![fileManager fileExistsAtPath:tmpDir]){
		NSError *writeError = nil;
		[fileManager createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to create %@.\n\nError: %@", tmpDir, writeError];
			[_generalManager displayErrorWithMessage:msg];
			return;
		}
	}

	// prep for download tasks
	// TODO: there's probably a better way to do this?
	__block BOOL downloadsComplete = NO;
	[[NSNotificationCenter defaultCenter] addObserverForName:@"downloadsComplete" object:nil queue:nil usingBlock:^(NSNotification *notif) {
		downloadsComplete = YES;
	}];

	// used below to determine when to post ^ notif
	_expectedDownloads = [urls count];

	// download debs from urls
	NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"me.lightmann.iamlazy"];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
	for(NSURL *url in urls){
		NSURLRequest *request = [NSURLRequest requestWithURL:url];
		BOOL valid = [NSURLConnection canHandleRequest:request];
		if(valid){
			NSURLSessionTask *task = [session downloadTaskWithRequest:request];
			[task resume];
		}
	}

	// wait for 'done' notif
	while(!downloadsComplete){
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0]];
	}

}

// URLSessionTaskDelegate
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
	if(error){
		_expectedDownloads--;
		NSLog(@"[IAmLazyLog] %@ task failed with error: %@", [[task originalRequest] URL], error);
	}
}

// NSURLSessionDownloadDelegate
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
	NSString *fileName = [[[downloadTask originalRequest] URL] lastPathComponent];
	NSInteger underscore = [fileName rangeOfString:@"_"].location;
	if(underscore == NSNotFound){
		underscore = [fileName length];
	}

	NSError *readError = nil;
	NSData *fileData = [NSData dataWithContentsOfURL:location options:0 error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] Failed to read %@ data. Error: %@", location, readError);
		return;
	}

	// ensure file is a .deb by checking for the distinctive 7 byte header
	NSString *header = [[NSString alloc] initWithBytes:[fileData bytes] length:([fileData length], 7) encoding:NSASCIIStringEncoding];
	if([header isEqualToString:@"!<arch>"]){
		NSError *writeError = nil;
		// have to strip "illegal" characters from the filename so it passes the checks in AndSoAreYou
		NSString *cleanFileName = [[fileName substringWithRange:NSMakeRange(0, underscore)] stringByAppendingPathExtension:@"deb"];
		[fileData writeToFile:[tmpDir stringByAppendingPathComponent:cleanFileName] options:NSDataWritingAtomic error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] Failed to write %@ data to file. Error: %@", location, writeError);
			return;
		}

		NSError *deleteError = nil;
		// pretty sure the delegate requests deletion of the file, but just to be sure
		[[NSFileManager defaultManager] removeItemAtURL:location error:&deleteError];
		if(deleteError){
			NSLog(@"[IAmLazyLog] Failed to delete %@. Error: %@", location, deleteError);
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

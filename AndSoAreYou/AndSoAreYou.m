//
//	AndSoAreYou.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Common.h"
#import <sys/stat.h>
#import <NSTask.h>

// have this so we don't have
// to r/w filenames from a file
NSString *getCurrentPackage(){
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tmpDirFiles = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSLog(@"[IALLogError] AndSoAreYou: Failed to get contents of %@! Info: %@", tmpDir, readError.localizedDescription);
		return @"err";
	}
	else if(![tmpDirFiles count]){
		return @"err";
	}

	NSMutableDictionary *dirsAndCreationDates = [NSMutableDictionary new];
	NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
	[validChars addCharactersInString:@"+-."];
	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm:ss.SSS"];
	for(NSString *file in tmpDirFiles){
		BOOL valid = ![[file stringByTrimmingCharactersInSet:validChars] length];
		if(valid){
			NSString *filePath = [tmpDir stringByAppendingPathComponent:file];

			BOOL isDir = NO;
			if([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir){
				NSError *readError2 = nil;
				NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:&readError2];
				if(readError2){
					NSLog(@"[IALLogError] AndSoAreYou: Failed to get attributes of %@! Info: %@", filePath, readError2.localizedDescription);
					continue;
				}

				NSDate *creationDate = [fileAttributes fileCreationDate];
				NSString *dateString = [formatter stringFromDate:creationDate];
				[dirsAndCreationDates setValue:file forKey:dateString];
			}
		}
	}

	NSArray *dates = [dirsAndCreationDates allKeys];
	NSSortDescriptor *compare = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
	NSArray *sortedDates = [dates sortedArrayUsingDescriptors:@[compare]];
	return [dirsAndCreationDates objectForKey:[sortedDates firstObject]];
}

int proc_pidpath(int pid, void *buffer, uint32_t buffersize); // libproc.h

int main(int argc, char *argv[]){
	if(argc != 2){
		printf("Houston, we have a problem: an invalid argument (or arguments) was provided!\n");
		return 1;
	}

	// get attributes of IAmLazy
	struct stat iamlazy;
	if(lstat("/Applications/IAmLazy.app/IAmLazy", &iamlazy) != 0){
		printf("Wut?\n");
		return 1;
	}

	// get current process' parent PID
	pid_t ppid = getppid();

	// get absolute path of the command running at 'ppid'
	char buffer[PATH_MAX];
	int ret = proc_pidpath(ppid, buffer, sizeof(buffer));

	// get attributes of parent process' command
	struct stat parent;
	lstat(buffer, &parent);

	// "The st_ino and st_dev, taken together, uniquely identify the file" - GNU
	// st_ino - The file's serial number
	// st_dev - Identifies the device containing the file
	// https://www.gnu.org/software/libc/manual/html_node/Attribute-Meanings.html
	if(ret < 0 || (parent.st_dev != iamlazy.st_dev || parent.st_ino != iamlazy.st_ino)){
		printf("Oh HELL nah!\n");
		return 1;
	}

	setuid(0);
	setgid(0);

	if(strcmp(argv[1], "unlockDpkg") == 0){
		// kill dpkg to free the lock
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/killall"];
		[task setArguments:@[@"dpkg"]];
		[task launch];
		[task waitUntilExit];

		// configure any unconfigured packages
		NSTask *task2 = [[NSTask alloc] init];
		[task2 setLaunchPath:@"/usr/bin/dpkg"];
		[task2 setArguments:@[@"--configure", @"-a"]];
		[task2 launch];
		[task2 waitUntilExit];

		NSLog(@"[IALLog] AndSoAreYou: dpkg should be fixed!");
	}
	else if(strcmp(argv[1], "cleanTmp") == 0){
		NSError *deleteError = nil;
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&deleteError];
		if(deleteError){;
			NSLog(@"[IALLogError] AndSoAreYou: Failed to delete %@! Info: %@", tmpDir, deleteError.localizedDescription);
			return 1;
		}
	}
	else if(strcmp(argv[1], "updateAPT") == 0){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/apt"];
		[task setArguments:@[@"update"]];
		[task launch];
		[task waitUntilExit];

		NSLog(@"[IALLog] AndSoAreYou: apt sources up-to-date!");
	}
	else if(strcmp(argv[1], "cpGFiles") == 0){
		// recreate directory structure and copy files
		NSError *readError = nil;
		NSString *filesToCopy = [tmpDir stringByAppendingPathComponent:@".filesToCopy"];
		NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSLog(@"[IALLogError] AndSoAreYou: Failed to get contents of %@! Info: %@", filesToCopy, readError.localizedDescription);
			return 1;
		}

		NSArray *files = [toCopy componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if(![files count]){
			NSLog(@"[IALLogError] %@ has no contents?!", filesToCopy);
			return 1;
		}

		NSString *current = getCurrentPackage();
		if(![current length] || [current isEqualToString:@"err"]){
			NSLog(@"[IALLogError] AndSoAreYou: getCurrentPackage() failed.");
			return 1;
		}

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:current];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		for(NSString *file in files){
			if(![file length] || ![fileManager fileExistsAtPath:file] || [[file lastPathComponent] isEqualToString:@".."] || [[file lastPathComponent] isEqualToString:@"."]){
				continue;
			}

			// recreate parent directory structure
			NSError *writeError = nil;
			NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
			NSString *newPath = [tweakDir stringByAppendingPathComponent:dirStructure];
			[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSLog(@"[IALLogError] AndSoAreYou: Failed to create %@! Info: %@", newPath, writeError.localizedDescription);
				continue;
			}

			// 're-enable' tweaks that've been 'disabled' with iCleaner Pro
			NSString *extension = [file pathExtension];
			if([[extension lowercaseString] isEqualToString:@"disabled"]){
				extension = @"dylib";
			}
			NSString *newFile = [[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
			NSString *newFilePath = [newPath stringByAppendingPathComponent:newFile];

			NSError *writeError2 = nil;
			[fileManager copyItemAtPath:file toPath:newFilePath error:&writeError2];
			if(writeError2){
				NSLog(@"[IALLogError] AndSoAreYou: Failed to copy %@! Info: %@", file, writeError2.localizedDescription);
			}
		}
	}
	else if(strcmp(argv[1], "cpDFiles") == 0){
		// get DEBIAN files (e.g., maintainer scripts)
		NSError *readError = nil;
		NSString *dpkgInfoDir = @"/var/lib/dpkg/info/";
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *dpkgInfo = [fileManager contentsOfDirectoryAtPath:dpkgInfoDir error:&readError];
		if(readError){
			NSLog(@"[IALLogError] AndSoAreYou: Failed to get contents of %@! Info: %@", dpkgInfoDir, readError.localizedDescription);
			return 1;
		}
		else if(![dpkgInfo count]){
			NSLog(@"[IALLogError] AndSoAreYou: %@ is empty?!", dpkgInfoDir);
			return 1;
		}

		NSString *tweakName = getCurrentPackage();
		if(![tweakName length] || [tweakName isEqualToString:@"err"]){
			NSLog(@"[IALLogError] AndSoAreYou: getCurrentPackage() failed.");
			return 1;
		}

		NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", tweakName];
		NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.md5sums'"];
		NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.list'"];
		NSPredicate *predicate23 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate2, predicate3]];
		NSPredicate *antiPredicate23 = [NSCompoundPredicate notPredicateWithSubpredicate:predicate23]; // dpkg generates these at installation
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, antiPredicate23]];
		NSArray *debainFiles = [dpkgInfo filteredArrayUsingPredicate:thePredicate];
		if(![debainFiles count]){
			NSLog(@"[IALLog] AndSoAreYou: %@ has no DEBIAN files.", tweakName);
			return 1;
		}

		NSString *debian = [[tmpDir stringByAppendingPathComponent:tweakName] stringByAppendingPathComponent:@"DEBIAN/"];
		for(NSString *file in debainFiles){
			NSString *filePath = [dpkgInfoDir stringByAppendingPathComponent:file];
			if(![file length] || ![fileManager fileExistsAtPath:filePath] || [file isEqualToString:@".."] || [file isEqualToString:@"."]){
				continue;
			}

			// remove tweakName prefix
			NSString *strippedName = [file stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
			if(![strippedName length]){
				continue;
			}

			NSError *writeError = nil;
			[fileManager copyItemAtPath:filePath toPath:[debian stringByAppendingPathComponent:strippedName] error:&writeError];
			if(writeError){
				NSLog(@"[IALLogError] AndSoAreYou: Failed to copy %@! Info: %@", filePath, writeError.localizedDescription);
			}
		}
	}
	else if(strcmp(argv[1], "buildDeb") == 0){
		NSString *current = getCurrentPackage();
		if(![current length] || [current isEqualToString:@"err"]){
			// have this check because if a removed package's install is borked
			// and it shows as being installed despite not having any files on-device,
			// this build step will go past the number of actual package dirs and will
			// try to build tmpDir as a deb (which will obv fail), so we need to catch it
			NSLog(@"[IALLogError] AndSoAreYou: getCurrentPackage() failed.");
			return 1;
		}
		NSString *tweak = [tmpDir stringByAppendingPathComponent:current];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/dpkg-deb"];
		[task setArguments:@[
			@"-b",
			@"-Zgzip",
			@"-z9",
			tweak
		]];
		[task launch];
		[task waitUntilExit];

		NSError *deleteError = nil;
		// delete dir with files now that deb has been built
		[fileManager removeItemAtPath:tweak error:&deleteError];
		if(deleteError){
			NSLog(@"[IALLogError] AndSoAreYou: Failed to delete %@! Info: %@", tweak, deleteError.localizedDescription);
		}

		if([fileManager fileExistsAtPath:[tweak stringByAppendingPathExtension:@"deb"]]){
			NSLog(@"[IALLog] AndSoAreYou: %@.deb created successfully!", tweak);
		}
		else{
			NSLog(@"[IALLogError] AndSoAreYou: %@.deb failed to build!", tweak);
		}
	}
	else if(strcmp(argv[1], "installDeb") == 0){
		// get debs from tmpDir
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			NSLog(@"[IALLogError] AndSoAreYou: Failed to get contents of %@! Info: %@", tmpDir, readError.localizedDescription);
			return 1;
		}
		else if(![tmpDirContents count]){
			NSLog(@"[IALLogError] AndSoAreYou: %@ is empty?!", tmpDir);
			return 1;
		}

		BOOL end = NO;
		NSMutableArray *debs = [NSMutableArray new];
		NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
		[validChars addCharactersInString:@"+-."];
		for(NSString *item in tmpDirContents){
			BOOL valid = ![[item stringByTrimmingCharactersInSet:validChars] length];
			if(valid){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];
				if([[item pathExtension] isEqualToString:@"deb"]){
					[debs addObject:path];
				}
			}
		}
		if(![debs count]){
			NSLog(@"[IALLogError] AndSoAreYou: %@ has no debs!", tmpDir);
			return 1;
		}
		else if([debs count] == 1){
			// https://youtu.be/i6XQY8jebs4
			NSLog(@"[IALLog] AndSoAreYou: the laaaaaaassssst debbbbbbbbb....");
			end = YES;
		}

		NSString *deb = [debs firstObject];
		// there's an issue on u0 where the IAL
		// app may be killed (w/o a crash log)
		// this leaves the AndSoAreYou child process
		// running, but we don't want that so we check
		// to see if the IAL process is alive and, if
		// not, finish the current package and return
		// TODO: figure out and fix
		BOOL alive = !kill(ppid, 0);
		if(!alive){
			NSLog(@"[IALLogError] AndSoAreYou: IAL process was killed. Returning.");
			return 1;
		}

		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/dpkg"];
		[task setArguments:@[@"-i", deb]];
		[task launch];
		[task waitUntilExit];

		NSError *deleteError = nil;
		// delete deb now that it's been installed
		[fileManager removeItemAtPath:deb error:&deleteError];
		if(deleteError){;
			NSLog(@"[IALLogError] AndSoAreYou: Failed to delete %@! Info: %@", deb, deleteError.localizedDescription);
			return 1;
		}

		// check deb install
		// Note: this is costly, but likely worth it for sanity
		NSString *path = [deb stringByDeletingPathExtension];
		NSString *tweak = [path lastPathComponent];
		NSTask *task2 = [[NSTask alloc] init];
		[task2 setLaunchPath:@"/usr/bin/dpkg"];
		[task2 setArguments:@[@"-s", tweak]];

		NSPipe *pipe = [NSPipe pipe];
		[task2 setStandardOutput:pipe];

		[task2 launch];

		NSFileHandle *handle = [pipe fileHandleForReading];
		NSData *data = [handle readDataToEndOfFile];
		[handle closeFile];

		// have to call after ^ to ensure that the output pipe doesn't fill
		// if it does, the process will hang and block waitUntilExit from returning
		[task2 waitUntilExit];

		NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if([output containsString:@"Status: install ok installed"]){
			NSLog(@"[IALLog] AndSoAreYou: %@ installed successfully!", tweak);
		}
		else{
			NSLog(@"[IALLogError] AndSoAreYou: (potentially) failed to install %@!", tweak);
			if(!end) return 1;
		}

		if(end){
			// resolve any lingering things
			// (e.g., conflicts, partial installs due to dependencies, etc)
			NSTask *task3 = [[NSTask alloc] init];
			[task3 setLaunchPath:@"/usr/bin/apt-get"];
			[task3 setArguments:@[
				@"install",
				@"-fy",
				@"--allow-unauthenticated"
			]];
			[task3 launch];
			[task3 waitUntilExit];

			// ensure everything that can be configured is
			NSTask *task4 = [[NSTask alloc] init];
			[task4 setLaunchPath:@"/usr/bin/dpkg"];
			[task4 setArguments:@[@"--configure", @"-a"]];
			[task4 launch];
			[task4 waitUntilExit];

			NSLog(@"[IALLog] AndSoAreYou: apt fixed and dpkg configured (just in case).");
		}
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

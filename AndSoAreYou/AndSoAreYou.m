//
//	AndSoAreYou.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Common.h"
#import <sys/stat.h>

NSString *getCurrentPackage(){
	NSError *readError = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *tmpDirFiles = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
	if(readError){
		NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get contents of %@! Error: %@", tmpDir, readError);
		return @"readErr";
	}
	else if(![tmpDirFiles count]){
		return @"readErr";
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
					NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get attributes of %@! Error: %@", filePath, readError2);
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

	// get absolute path of the command running at 'pid'
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
	setuid(0);

	if(strcmp(argv[1], "unlockDpkg") == 0){
		// kill dpkg to free the lock and then
		// configure any unconfigured packages
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/killall"];
		[task setArguments:@[@"dpkg"]];
		[task launch];
		[task waitUntilExit];

		NSTask *task2 = [[NSTask alloc] init];
		[task2 setLaunchPath:@"/usr/bin/dpkg"];
		[task2 setArguments:@[@"--configure", @"-a"]];
		[task2 launch];
		[task2 waitUntilExit];
	}
	else if(strcmp(argv[1], "cleanTmp") == 0){
		// delete temporary directory
		NSError *deleteError = nil;
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&deleteError];
		if(deleteError){;
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to delete %@! Error: %@", tmpDir, deleteError);
			return 1;
		}
	}
	else if(strcmp(argv[1], "updateAPT") == 0){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/apt-get"];
		[task setArguments:@[@"update"]];
		[task launch];
		[task waitUntilExit];
	}
	else if(strcmp(argv[1], "cpGFiles") == 0){
		// recreate directory structure and copy files
		NSError *readError = nil;
		NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get contents of %@! Error: %@", filesToCopy, readError);
			return 1;
		}

		NSArray *files = [toCopy componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		if(![files count]){
			return 1;
		}

		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:getCurrentPackage()];
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
				NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to create %@! Error: %@", newPath, writeError);
				continue;
			}

			// 'reenable' tweaks that've been disabled with iCleaner Pro
			NSString *extension = [file pathExtension];
			if([[extension lowercaseString] isEqualToString:@"disabled"]){
				extension = @"dylib";
			}
			NSString *newFile = [[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
			NSString *newFilePath = [newPath stringByAppendingPathComponent:newFile];

			// copy file
			NSError *writeError2 = nil;
			[fileManager copyItemAtPath:file toPath:newFilePath error:&writeError2];
			if(writeError2){
				NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to copy %@! Error: %@", file, writeError2);
			}
		}
	}
	else if(strcmp(argv[1], "cpDFiles") == 0){
		// get DEBIAN files (e.g., maintainer scripts)
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *dpkgInfo = [fileManager contentsOfDirectoryAtPath:dpkgInfoDir error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get contents of %@! Error: %@", dpkgInfoDir, readError);
			return 1;
		}
		else if(![dpkgInfo count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ is empty!", dpkgInfoDir);
			return 1;
		}

		NSString *tweakName = getCurrentPackage();
		NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", tweakName];
		NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.md5sums'"];
		NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.list'"];
		NSPredicate *predicate23 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate2, predicate3]];
		NSPredicate *antiPredicate23 = [NSCompoundPredicate notPredicateWithSubpredicate:predicate23]; // dpkg generates these at installation
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, antiPredicate23]];
		NSArray *debainFiles = [dpkgInfo filteredArrayUsingPredicate:thePredicate];
		if(![debainFiles count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ has no DEBIAN files.", tweakName);
			return 1;
		}

		// copy files
		NSString *debian = [[tmpDir stringByAppendingPathComponent:tweakName] stringByAppendingPathComponent:@"DEBIAN/"];
		for(NSString *file in debainFiles){
			NSString *filePath = [dpkgInfoDir stringByAppendingPathComponent:file];
			if(![file length] || ![fileManager fileExistsAtPath:filePath] || [file isEqualToString:@".."] || [file isEqualToString:@"."]){
				continue;
			}

			// remove tweakName prefix and copy file
			NSString *strippedName = [file stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
			if(![strippedName length]){
				continue;
			}

			NSError *writeError = nil;
			[fileManager copyItemAtPath:filePath toPath:[debian stringByAppendingPathComponent:strippedName] error:&writeError];
			if(writeError){
				NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to copy %@! Error: %@", filePath, writeError);
			}
		}
	}
	else if(strcmp(argv[1], "buildDebs") == 0){
		// get tweak dirs from tmpDir
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get contents of %@! Error: %@", tmpDir, readError);
			return 1;
		}
		else if(![tmpDirContents count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ is empty!", tmpDir);
			return 1;
		}

		NSMutableArray *tweakDirs = [NSMutableArray new];
		NSMutableCharacterSet *validChars = [NSMutableCharacterSet alphanumericCharacterSet];
		[validChars addCharactersInString:@"+-."];
		for(NSString *item in tmpDirContents){
			BOOL valid = ![[item stringByTrimmingCharactersInSet:validChars] length];
			if(valid){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];

				BOOL isDir = NO;
				if([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir){
					[tweakDirs addObject:path];
				}
			}
		}
		if(![tweakDirs count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ has no valid tweak dirs!", tmpDir);
			return 1;
		}

		// build debs and remove respective dirs when done
		NSString *log = [logDir stringByAppendingPathComponent:@"build_log.txt"];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *tweak in tweakDirs){
			NSTask *task = [[NSTask alloc] init];
			[task setLaunchPath:@"/usr/bin/dpkg-deb"];
			[task setArguments:@[
				@"-b",
				@"-Zgzip",
				@"-z9",
				tweak
			]];

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
			[logText appendString:output];

			NSError *deleteError = nil;
			// delete dir with files now that deb has been built
			[fileManager removeItemAtPath:tweak error:&deleteError];
			if(deleteError){
				NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to delete %@! Error: %@", tweak, deleteError);
			}
		}

		NSError *writeError = nil;
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to write to %@! Error: %@", log, writeError);
		}
	}
	else if(strcmp(argv[1], "installDebs") == 0){
		// get debs from tmpDir
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to get contents of %@! Error: %@", tmpDir, readError);
			return 1;
		}
		else if(![tmpDirContents count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ is empty!", tmpDir);
			return 1;
		}

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
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@ has no debs!", tmpDir);
			return 1;
		}

		// install debs one by one
		NSString *log = [logDir stringByAppendingPathComponent:@"restore_log.txt"];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *deb in debs){
			// there's an issue on u0 where the IAL
			// app may be killed (w/o a crash log)
			// this leaves the AndSoAreYou child process
			// running, but we don't want that so we check
			// to see if the IAL process is alive and, if
			// not, finish the current package and return
			BOOL alive = !kill(ppid, 0);
			if(!alive){
				NSLog(@"[IAmLazyLog] AndSoAreYou: IAL process was killed; returning.");
				return 1;
			}

			NSTask *task = [[NSTask alloc] init];
			[task setLaunchPath:@"/usr/bin/dpkg"];
			[task setArguments:@[@"-i", deb]];

			NSPipe *pipe = [NSPipe pipe];
			[task setStandardOutput:pipe];

			[task launch];

			NSFileHandle *handle = [pipe fileHandleForReading];
			NSData *data = [handle readDataToEndOfFile];
			[handle closeFile];

			[task waitUntilExit];

			NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			[logText appendString:output];
		}

		NSError *writeError = nil;
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to write to %@! Error: %@", log, writeError);
		}

		// resolve any lingering things (e.g., conflicts, partial installs due to dependencies, etc)
		NSString *log2 = [logDir stringByAppendingPathComponent:@"fixup_log.txt"];
		NSMutableString *log2Text = [NSMutableString new];

		NSTask *task2 = [[NSTask alloc] init];
		[task2 setLaunchPath:@"/usr/bin/apt-get"];
		[task2 setArguments:@[
			@"install",
			@"-fy",
			@"--allow-unauthenticated"
		]];

		NSPipe *pipe2 = [NSPipe pipe];
		[task2 setStandardOutput:pipe2];

		[task2 launch];

		NSFileHandle *handle2 = [pipe2 fileHandleForReading];
		NSData *data2 = [handle2 readDataToEndOfFile];
		[handle2 closeFile];

		[task2 waitUntilExit];

		NSString *output2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
		[log2Text appendString:output2];

		// ensure everything that can be configured is
		NSTask *task3 = [[NSTask alloc] init];
		[task3 setLaunchPath:@"/usr/bin/dpkg"];
		[task3 setArguments:@[@"--configure", @"-a"]];

		NSPipe *pipe3 = [NSPipe pipe];
		[task3 setStandardOutput:pipe3];

		[task3 launch];

		NSFileHandle *handle3 = [pipe3 fileHandleForReading];
		NSData *data3 = [handle3 readDataToEndOfFile];
		[handle3 closeFile];

		[task3 waitUntilExit];

		NSString *output3 = [[NSString alloc] initWithData:data3 encoding:NSUTF8StringEncoding];
		[log2Text appendString:output3];

		NSError *writeError2 = nil;
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:&writeError2];
		if(writeError2){
			NSLog(@"[IAmLazyLog] AndSoAreYou: Failed to write to %@! Error: %@", log2, writeError2);
		}
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

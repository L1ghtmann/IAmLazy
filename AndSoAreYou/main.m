//
//	main.m
//	IAmLazy (AndSoAreYou)
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
		NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", tmpDir, readError];
		NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
		return @"";
	}
	else if(![tmpDirFiles count]){
		return @"";
	}

	NSMutableDictionary *dirsAndCreationDates = [NSMutableDictionary new];
	NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
	[set addCharactersInString:@"+-."];
	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm:ss.SSS"];
	for(NSString *file in tmpDirFiles){
		BOOL valid = ![[file stringByTrimmingCharactersInSet:set] length];
		if(valid){
			NSString *filePath = [tmpDir stringByAppendingPathComponent:file];

			BOOL isDir = NO;
			if([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir){
				NSError *readError2 = nil;
				NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:&readError2];
				if(readError2){
					NSString *msg = [NSString stringWithFormat:@"Failed to get attributes of %@! Error: %@", filePath, readError2];
					NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
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
	NSString *latestDir = [dirsAndCreationDates objectForKey:[sortedDates firstObject]];
	return latestDir;
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
	pid_t pid = getppid();

	// get absolute path of the command running at 'pid'
	char buffer[PATH_MAX]; // limits.h
	int ret = proc_pidpath(pid, buffer, sizeof(buffer));

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

	if(strcmp(argv[1], "cleanTmp") == 0){
		// delete temporary directory
		NSError *deleteError = nil;
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&deleteError];
		if(deleteError){
			NSString *msg = [NSString stringWithFormat:@"Failed to delete %@! Error: %@", tmpDir, deleteError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}
	}
	else if(strcmp(argv[1], "cpGFiles") == 0){
		// recreate directory structure and copy files
		NSError *readError = nil;
		NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", filesToCopy, readError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}

		NSArray *files = [toCopy componentsSeparatedByString:@"\n"];
		if(![files count]) return 1;

		NSString *tweakName = getCurrentPackage();
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		for(NSString *file in files){
			if(![file length] || ![fileManager fileExistsAtPath:file] || [[file lastPathComponent] isEqualToString:@".."] || [[file lastPathComponent] isEqualToString:@"."]){
				continue;
			}

			// recreate parent directory structure
			NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
			NSString *newPath = [tweakDir stringByAppendingPathComponent:dirStructure];
			if(![[newPath substringFromIndex:[newPath length] - 1] isEqualToString:@"/"]){
				newPath = [newPath stringByAppendingString:@"/"]; // add missing trailing slash
			}

			NSError *writeError = nil;
			[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:@"Failed to create %@! Error: %@", newPath, writeError];
				NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
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
				NSString *msg = [NSString stringWithFormat:@"Failed to copy %@! Error: %@", file, writeError2];
				NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			}
		}
	}
	else if(strcmp(argv[1], "cpDFiles") == 0){
		// get DEBIAN files (e.g., maintainer scripts)
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *dpkgInfo = [fileManager contentsOfDirectoryAtPath:dpkgInfoDir error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", dpkgInfoDir, readError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}
		else if(![dpkgInfo count]){
			NSString *msg = [NSString stringWithFormat:@"%@ is empty!", dpkgInfoDir];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
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
			NSString *msg = [NSString stringWithFormat:@"%@ has no DEBIAN files.", tweakName];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}

		// copy files
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];
		NSString *debian = [tweakDir stringByAppendingString:@"/DEBIAN/"];
		for(NSString *file in debainFiles){
			NSString *filePath = [dpkgInfoDir stringByAppendingPathComponent:file];
			if(![file length] || ![fileManager fileExistsAtPath:filePath] || [file isEqualToString:@".."] || [file isEqualToString:@"."]){
				continue;
			}

			// remove tweakName prefix and copy file
			NSError *writeError = nil;
			NSString *strippedName = [file stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
			[fileManager copyItemAtPath:filePath toPath:[debian stringByAppendingPathComponent:strippedName] error:&writeError];
			if(writeError){
				NSString *msg = [NSString stringWithFormat:@"Failed to copy %@! Error: %@", filePath, writeError];
				NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			}
		}
	}
	else if(strcmp(argv[1], "buildDebs") == 0){
		// get tweak dirs from tmpDir
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", tmpDir, readError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}
		else if(![tmpDirContents count]){
			NSString *msg = [NSString stringWithFormat:@"%@ is empty!", tmpDir];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}

		NSMutableArray *tweakDirs = [NSMutableArray new];
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];
		for(NSString *item in tmpDirContents){
			BOOL valid = ![[item stringByTrimmingCharactersInSet:set] length];
			if(valid){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];

				BOOL isDir = NO;
				if([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir){
					[tweakDirs addObject:path];
				}
			}
		}
		if(![tweakDirs count]){
			NSLog(@"[IAmLazyLog] AndSoAreYou: tweakDirs is empty!");
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
			[fileManager removeItemAtPath:tweak error:&deleteError];
			if(deleteError){
				NSString *msg = [NSString stringWithFormat:@"Failed to delete %@! Error: %@", tweak, deleteError];
				NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			}
		}

		NSError *writeError = nil;
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to write to %@! Error: %@", log, writeError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
		}
	}
	else if(strcmp(argv[1], "installDebs") == 0){
		// get debs from tmpDir
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			NSString *msg = [NSString stringWithFormat:@"Failed to get contents of %@! Error: %@", tmpDir, readError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}
		else if(![tmpDirContents count]){
			NSString *msg = [NSString stringWithFormat:@"%@ is empty!", tmpDir];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}

		NSMutableArray *debs = [NSMutableArray new];
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];
		for(NSString *item in tmpDirContents){
			BOOL valid = ![[item stringByTrimmingCharactersInSet:set] length];
			if(valid){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];
				if([[item pathExtension] isEqualToString:@"deb"]){
					[debs addObject:path];
				}
			}
		}
		if(![debs count]){
			NSString *msg = [NSString stringWithFormat:@"%@ has no debs!", tmpDir];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
			return 1;
		}

		// install debs one by one
		NSString *log = [logDir stringByAppendingPathComponent:@"restore_log.txt"];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *deb in debs){
			NSTask *task = [[NSTask alloc] init];
			[task setLaunchPath:@"/usr/bin/dpkg"];
			[task setArguments:@[@"-i", deb]];

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
		}

		NSError *writeError = nil;
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError){
			NSString *msg = [NSString stringWithFormat:@"Failed to write to %@! Error: %@", log, writeError];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
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

		// have to call after ^ to ensure that the output pipe doesn't fill
		// if it does, the process will hang and block waitUntilExit from returning
		[task2 waitUntilExit];

		NSString *output2 = [[NSString alloc] initWithData:data2 encoding:NSUTF8StringEncoding];
		[log2Text appendString:output2];

		NSError *writeError2 = nil;
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:&writeError2];
		if(writeError2){
			NSString *msg = [NSString stringWithFormat:@"Failed to write to %@! Error: %@", log2, writeError2];
			NSLog(@"[IAmLazyLog] AndSoAreYou: %@", msg);
		}
	}
	else if(strcmp(argv[1], "rebootUserspace") == 0){
		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/bin/launchctl"];
		[task setArguments:@[@"reboot", @"userspace"]];
		[task launch];
		[task waitUntilExit];
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

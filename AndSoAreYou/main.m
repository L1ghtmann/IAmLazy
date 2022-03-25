//
//	main.m
//	IAmLazy (AndSoAreYou)
//
//	Created by Lightmann during COVID-19
//

#import "../Common.h"
#import <sys/stat.h>
#import <NSTask.h>

NSString *getCurrentPackage(){
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDateFormatter *formatter =  [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"HH:mm:ss.SSS"];

	NSMutableDictionary *dirsAndCreationDates = [NSMutableDictionary new];
	NSArray *tmpDirFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:NULL];
	for(NSString *file in tmpDirFiles){
		NSString *filePath = [tmpDir stringByAppendingPathComponent:file];

		BOOL isDir = NO;
		if([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir){
			NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:NULL];
			NSDate *creationDate = [fileAttributes fileCreationDate];
			NSString *dateString = [formatter stringFromDate:creationDate];
			[dirsAndCreationDates setValue:file forKey:dateString];
		}
	}

	NSArray *dates = [dirsAndCreationDates allKeys];
	NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
	NSArray *sortedDates = [dates sortedArrayUsingDescriptors:@[descriptor]];

	NSString *latestDir = [dirsAndCreationDates objectForKey:[sortedDates firstObject]];
	return latestDir;
}

int proc_pidpath(int pid, void *buffer, uint32_t buffersize); // libproc.h

int main(int argc, char *argv[]) {
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
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
	}
	else if(strcmp(argv[1], "cpGFiles") == 0){
		NSString *tweakName = getCurrentPackage();
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];

		// recreate directory structure and copy files
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:NULL];
		NSArray *files = [toCopy componentsSeparatedByString:@"\n"];
		if([files count]){
			for(NSString *file in files){
				if(![file length] || ![fileManager fileExistsAtPath:file]){
					continue;
				}

				// recreate parent directory structure
				NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
				NSString *newPath = [NSString stringWithFormat:@"%@%@", tweakDir, dirStructure];
				if(![[newPath substringFromIndex:[newPath length]-1] isEqualToString:@"/"]) newPath = [newPath stringByAppendingString:@"/"]; // add missing trailing slash
				[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:NULL];

				// 'reenable' tweaks that've been disabled with iCleaner Pro (i.e., change extension from .disabled back to .dylib)
				NSString *extension = [file pathExtension];
				if([[[file pathExtension] lowercaseString] isEqualToString:@"disabled"]) extension = @"dylib";
				NSString *newFile = [newPath stringByAppendingString:[[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension]];

				// copy file
				[fileManager copyItemAtPath:file toPath:newFile error:NULL];
			}
		}
	}
	else if(strcmp(argv[1], "cpDFiles") == 0){
		NSString *tweakName = getCurrentPackage();
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];
		NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];

		// get DEBIAN files (e.g., pre/post scripts)
		NSTask *task = [[NSTask alloc] init];
		NSMutableArray *args = [NSMutableArray new];
		[task setLaunchPath:@"/usr/bin/dpkg-query"];
		[args addObject:@"-c"];
		[args addObject:tweakName];
		[task setArguments:args];

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

		// grab the files
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.md5sums'"]; // dpkg generates this dynamically at installation
		NSPredicate *theAntiPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:thePredicate];
		NSArray *debianFiles = [lines filteredArrayUsingPredicate:theAntiPredicate];

		// copy files
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if([debianFiles count]){
			for(NSString *file in debianFiles){
				if(![file length] || ![fileManager fileExistsAtPath:file]){
					continue;
				}

				// remove tweakName prefix and copy file
				NSString *fileName = [file lastPathComponent];
				NSString *strippedName = [fileName stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
				[fileManager copyItemAtPath:file toPath:[NSString stringWithFormat:@"%@%@", debian, strippedName] error:NULL];
			}
		}
	}
	else if(strcmp(argv[1], "buildDebs") == 0){
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *log = [NSString stringWithFormat:@"%@build_log.txt", logDir];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:NULL];
		NSMutableArray *tweakDirs = [NSMutableArray new];
		for(NSString *item in tmpDirContents){
			NSString *path = [tmpDir stringByAppendingString:item];

			BOOL isDir = NO;
			if([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir){
				[tweakDirs addObject:path];
			}
		}

		// Note: the default compression for dpkg-deb is xz (as of 1.15.6), which will occassionally cause an error:
		// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation if there
		// is a dpkg version conflict. in order to fix this, we need to use gzip compression

		// build debs and remove respective dir when done
		NSMutableString *logText = [NSMutableString new];
		for(NSString *tweak in tweakDirs){
			NSTask *task = [[NSTask alloc] init];
			NSMutableArray *args = [NSMutableArray new];
			[task setLaunchPath:@"/usr/bin/dpkg-deb"];
			[args addObject:@"-b"];
			[args addObject:@"-Zgzip"];
			[args addObject:@"-z9"];
			[args addObject:tweak];
			[task setArguments:args];

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

			[fileManager removeItemAtPath:tweak error:NULL];
		}
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else if(strcmp(argv[1], "installDebs") == 0){
		// get debs from tmpDir
		NSString *log = [NSString stringWithFormat:@"%@restore_log.txt", logDir];
		NSArray *tmpDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:NULL];
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"];
		NSArray *debs = [tmpDirContents filteredArrayUsingPredicate:thePredicate];

		// install debs and resolve missing dependencies
		// TODO: find a better way of doing this
		NSMutableString *logText = [NSMutableString new];
		for(NSString *deb in debs){
			NSString *path = [tmpDir stringByAppendingString:deb];

			NSTask *task = [[NSTask alloc] init];
			NSMutableArray *args = [NSMutableArray new];
			[task setLaunchPath:@"/usr/bin/apt-get"];
			[args addObject:@"install"];
			[args addObject:@"-y"];
			[args addObject:@"--allow-unauthenticated"];
			[args addObject:path];
			[task setArguments:args];

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
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		// resolve any lingering things (e.g., partial installs due to dependencies)
		NSString *log2 = [NSString stringWithFormat:@"%@fixup_log.txt", logDir];
		NSMutableString *log2Text = [NSMutableString new];
		for(NSString *deb in debs){
			NSString *path = [tmpDir stringByAppendingString:deb];

			NSTask *task = [[NSTask alloc] init];
			NSMutableArray *args = [NSMutableArray new];
			[task setLaunchPath:@"/usr/bin/apt-get"];
			[args addObject:@"install"];
			[args addObject:@"-fy"];
			[args addObject:@"--allow-unauthenticated"];
			[args addObject:path];
			[task setArguments:args];

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
			[log2Text appendString:output];
		}
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else if(strcmp(argv[1], "installList") == 0){
		// get target list from tmpDir
		NSArray *tmpDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:NULL];
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.txt'"];
		NSArray *lists = [tmpDirContents filteredArrayUsingPredicate:thePredicate];
		NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
		NSArray *sortedLists = [lists sortedArrayUsingDescriptors:@[descriptor]]; // if, for some reason, there are mutliple lists present
		NSString *targetListFile = [tmpDir stringByAppendingPathComponent:[sortedLists firstObject]];

		// get packages to install
		NSString *tweakList = [NSString stringWithContentsOfFile:targetListFile encoding:NSUTF8StringEncoding error:NULL];
		NSArray	*tweaks = [tweakList componentsSeparatedByString:@"\n"];

		// make sure info on available packages is up-to-date
		NSTask *updateTask = [[NSTask alloc] init];
		NSMutableArray *updateTaskArgs = [NSMutableArray new];
		[updateTask setLaunchPath:@"/usr/bin/apt-get"];
		[updateTaskArgs addObject:@"update"];
		[updateTask setArguments:updateTaskArgs];
		[updateTask launch];
		[updateTask waitUntilExit];

		// install packages from tweak list
		// TODO: find a better way of doing this
		NSString *log = [NSString stringWithFormat:@"%@restore_log.txt", logDir];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *tweak in tweaks){
			NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
			NSString *run1 = [tweak stringByReplacingOccurrencesOfString:@"." withString:@""];
			NSString *run2 = [run1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
			BOOL valid = [[run2 stringByTrimmingCharactersInSet:alphaSet] isEqualToString:@""];
			if(valid){
				NSTask *task = [[NSTask alloc] init];
				NSMutableArray *args = [NSMutableArray new];
				[task setLaunchPath:@"/usr/bin/apt-get"];
				[args addObject:@"install"];
				[args addObject:@"-y"];
				[args addObject:@"--allow-unauthenticated"];
				[args addObject:tweak];
				[task setArguments:args];

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
		}
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		// resolve any lingering things (e.g., partial installs due to dependencies)
		NSString *log2 = [NSString stringWithFormat:@"%@fixup_log.txt", logDir];
		NSMutableString *log2Text = [NSMutableString new];
		for(NSString *tweak in tweaks){
			NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
			NSString *run1 = [tweak stringByReplacingOccurrencesOfString:@"." withString:@""];
			NSString *run2 = [run1 stringByReplacingOccurrencesOfString:@"-" withString:@""];
			BOOL valid = [[run2 stringByTrimmingCharactersInSet:alphaSet] isEqualToString:@""];
			if(valid){
				NSTask *task = [[NSTask alloc] init];
				NSMutableArray *args = [NSMutableArray new];
				[task setLaunchPath:@"/usr/bin/apt-get"];
				[args addObject:@"install"];
				[args addObject:@"-fy"];
				[args addObject:@"--allow-unauthenticated"];
				[args addObject:tweak];
				[task setArguments:args];

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
				[log2Text appendString:output];
			}
		}
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

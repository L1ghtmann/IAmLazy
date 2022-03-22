//
//	main.m
//	IAmLazy (AndSoAreYou)
//
//	Created by Lightmann during COVID-19
//

#import <sys/stat.h>
#import "../Common.h"

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

	if(strcmp(argv[1], "cleanup-tmp") == 0){
		// delete temporary directory
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
	}
	else if(strcmp(argv[1], "copy-generic-files") == 0){
		NSString *tweakDir = [NSString stringWithContentsOfFile:targetDir encoding:NSUTF8StringEncoding error:NULL];

		// recreate directory structure and copy files
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *filesToCopy = [NSString stringWithContentsOfFile:gFilesToCopy encoding:NSUTF8StringEncoding error:NULL];
		NSArray *lines = [filesToCopy componentsSeparatedByString:@"\n"];
		if([lines count]){
			for(NSString *file in lines){
				if(![file length]) continue;

				// recreate parent directory structure
				NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
				NSString *newPath = [NSString stringWithFormat:@"%@%@", tweakDir, dirStructure];
				if(![[newPath substringFromIndex:[newPath length]-1] isEqualToString:@"/"]) newPath = [newPath stringByAppendingString:@"/"]; // add missing slash
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
	else if(strcmp(argv[1], "copy-debian-files") == 0){
		NSString *tweakDir = [NSString stringWithContentsOfFile:targetDir encoding:NSUTF8StringEncoding error:NULL];
		NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];
		NSString *tweakName = [tweakDir lastPathComponent];

		// copy files
		NSString *filesToCopy = [NSString stringWithContentsOfFile:dFilesToCopy encoding:NSUTF8StringEncoding error:NULL];
		NSArray *lines = [filesToCopy componentsSeparatedByString:@"\n"];
		if([lines count]){
			for(NSString *file in lines){
				if(![file length]) continue;

				// remove tweakName prefix and copy file
				NSString *fileName = [file lastPathComponent];
				NSString *strippedName = [fileName stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
				[[NSFileManager defaultManager] copyItemAtPath:file toPath:[NSString stringWithFormat:@"%@%@", debian, strippedName] error:NULL];
			}
		}
	}
	else if(strcmp(argv[1], "build-debs") == 0){
		// Note: the default compression for dpkg-deb is xz (as of 1.15.6), which will occassionally cause an error:
		// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation if there
		// is a dpkg version conflict. in order to fix this, we need to use gzip compression

		// build debs from collected files and then remove the respective file dir when done
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
	else if(strcmp(argv[1], "install-debs") == 0){
		// get debs from tmpDir
		NSString *log = [NSString stringWithFormat:@"%@restore_log.txt", logDir];
				NSError *error = nil; // testing
		NSArray *tmpDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:&error];
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.deb'"];
		NSArray *debs = [tmpDirContents filteredArrayUsingPredicate:thePredicate];

		// install debs and resolve missing dependencies
		NSMutableString *logText = [NSMutableString new];
				if(![tmpDirContents count]) [logText appendString:[NSString stringWithFormat:@"%@", error.localizedDescription]]; // testing
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
	else if(strcmp(argv[1], "install-list") == 0){
		NSString *targetListFile = [NSString stringWithContentsOfFile:targetList encoding:NSUTF8StringEncoding error:NULL];
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
		NSString *log = [NSString stringWithFormat:@"%@restore_log.txt", logDir];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *tweak in tweaks){
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
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		// resolve any lingering things (e.g., partial installs due to dependencies)
		NSString *log2 = [NSString stringWithFormat:@"%@fixup_log.txt", logDir];
		NSMutableString *log2Text = [NSMutableString new];
		for(NSString *tweak in tweaks){
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
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

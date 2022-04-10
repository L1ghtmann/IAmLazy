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
	NSArray *tmpDirFiles = [fileManager contentsOfDirectoryAtPath:tmpDir error:NULL];
	if(![tmpDirFiles count]) return @"";
	NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
	[set addCharactersInString:@"+-."];
	for(NSString *file in tmpDirFiles){
		BOOL valid = [[file stringByTrimmingCharactersInSet:set] isEqualToString:@""];
		if(valid){
			NSString *filePath = [tmpDir stringByAppendingPathComponent:file];

			BOOL isDir = NO;
			if([fileManager fileExistsAtPath:filePath isDirectory:&isDir] && isDir){
				NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:NULL];
				NSDate *creationDate = [fileAttributes fileCreationDate];
				NSString *dateString = [formatter stringFromDate:creationDate];
				[dirsAndCreationDates setValue:file forKey:dateString];
			}
		}
	}

	NSArray *dates = [dirsAndCreationDates allKeys];
	NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
	NSArray *sortedDates = [dates sortedArrayUsingDescriptors:@[descriptor]];
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
		[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
	}
	else if(strcmp(argv[1], "cpGFiles") == 0){
		NSString *tweakName = getCurrentPackage();
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];

		// recreate directory structure and copy files
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:NULL];
		NSArray *files = [toCopy componentsSeparatedByString:@"\n"];
		if(![files count]) return 1;
		for(NSString *file in files){
			if(![file length] || ![fileManager fileExistsAtPath:file] || [[file lastPathComponent] isEqualToString:@".."] || [[file lastPathComponent] isEqualToString:@"."]){
				continue;
			}

			// recreate parent directory structure
			NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
			NSString *newPath = [tweakDir stringByAppendingPathComponent:dirStructure];
			if(![[newPath substringFromIndex:[newPath length] - 1] isEqualToString:@"/"]) newPath = [newPath stringByAppendingString:@"/"]; // add missing trailing slash
			[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:NULL];

			// 'reenable' tweaks that've been disabled with iCleaner Pro (i.e., change extension from .disabled back to .dylib)
			NSString *extension = [file pathExtension];
			if([[[file pathExtension] lowercaseString] isEqualToString:@"disabled"]) extension = @"dylib";
			NSString *newFile = [newPath stringByAppendingPathComponent:[[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension]];

			// copy file
			[fileManager copyItemAtPath:file toPath:newFile error:NULL];
		}
	}
	else if(strcmp(argv[1], "cpDFiles") == 0){
		NSString *tweakName = getCurrentPackage();
		NSString *tweakDir = [tmpDir stringByAppendingPathComponent:tweakName];
		NSString *debian = [tweakDir stringByAppendingString:@"/DEBIAN/"];
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];

		BOOL valid = [[tweakName stringByTrimmingCharactersInSet:set] isEqualToString:@""];
		if(valid){
			// get DEBIAN files (e.g., pre/post scripts)
			NSString *dpkgInfoDir = @"/var/lib/dpkg/info/";
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSArray *dpkgInfo = [fileManager contentsOfDirectoryAtPath:dpkgInfoDir error:NULL];
			if(![dpkgInfo count]) return 1;

			NSPredicate *predicate1 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", tweakName];
			NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.md5sums'"];
			NSPredicate *predicate3 = [NSPredicate predicateWithFormat:@"SELF CONTAINS '.list'"];
			NSPredicate *predicate23 = [NSCompoundPredicate orPredicateWithSubpredicates:@[predicate2, predicate3]];
			NSPredicate *antiPredicate23 = [NSCompoundPredicate notPredicateWithSubpredicate:predicate23]; // dpkg generates these at installation
			NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate1, antiPredicate23]];
			NSArray *debainFiles = [dpkgInfo filteredArrayUsingPredicate:thePredicate];
			if(![debainFiles count]) return 1;

			// copy files
			for(NSString *file in debainFiles){
				NSString *filePath = [dpkgInfoDir stringByAppendingPathComponent:file];
				if(![file length] || ![fileManager fileExistsAtPath:filePath] || [file isEqualToString:@".."] || [file isEqualToString:@"."]){
					continue;
				}

				// remove tweakName prefix and copy file
				NSString *strippedName = [file stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""];
				[fileManager copyItemAtPath:filePath toPath:[debian stringByAppendingPathComponent:strippedName] error:NULL];
			}
		}
	}
	else if(strcmp(argv[1], "buildDebs") == 0){
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSString *log = [logDir stringByAppendingPathComponent:@"build_log.txt"];

		// get tweak dirs from tmpDir
		NSMutableArray *tweakDirs = [NSMutableArray new];
		NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:NULL];
		if(![tmpDirContents count]) return 1;
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];
		for(NSString *item in tmpDirContents){
			BOOL valid = [[item stringByTrimmingCharactersInSet:set] isEqualToString:@""];
			if(valid){
				NSString *path = [tmpDir stringByAppendingPathComponent:item];

				BOOL isDir = NO;
				if([fileManager fileExistsAtPath:path isDirectory:&isDir] && isDir){
					[tweakDirs addObject:path];
				}
			}
		}

		// build debs and remove respective dir when done
		NSMutableString *logText = [NSMutableString new];
		if(![tweakDirs count]) return 1;
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

			[fileManager removeItemAtPath:tweak error:NULL];
		}
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else if(strcmp(argv[1], "installDebs") == 0){
		// install debs
		NSString *log = [logDir stringByAppendingPathComponent:@"restore_log.txt"];
		NSMutableString *logText = [NSMutableString new];

		NSTask *task = [[NSTask alloc] init];
		[task setLaunchPath:@"/usr/bin/dpkg"];
		[task setArguments:@[
			@"-iR",
			tmpDir
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

		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];

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

		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else if(strcmp(argv[1], "installList") == 0){
		// get target list from tmpDir
		NSArray *tmpDirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpDir error:NULL];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.txt'"];
		NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'IAmLazy-'"];
		NSPredicate *thePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, predicate2]];  // combine with "and"
		NSArray *lists = [tmpDirContents filteredArrayUsingPredicate:thePredicate];
		if(![lists count]) return 1;
		NSString *targetListFile = [tmpDir stringByAppendingPathComponent:[lists firstObject]];

		// get packages to install
		NSString *tweakList = [NSString stringWithContentsOfFile:targetListFile encoding:NSUTF8StringEncoding error:NULL];
		NSArray	*tweaks = [tweakList componentsSeparatedByString:@"\n"];
		if(![tweaks count]) return 1;

		// make sure info on available packages is up-to-date
		// Note: if list isn't in /var/lib/apt/lists/ it isn't queried
		NSTask *updateTask = [[NSTask alloc] init];
		[updateTask setLaunchPath:@"/usr/bin/apt-get"];
		[updateTask setArguments:@[@"update"]];
		[updateTask launch];
		[updateTask waitUntilExit];

		// install packages from tweak list
		NSString *log = [logDir stringByAppendingPathComponent:@"restore_log.txt"];
		NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
		[set addCharactersInString:@"+-."];
		NSMutableString *logText = [NSMutableString new];
		for(NSString *tweak in tweaks){
			BOOL valid = [[tweak stringByTrimmingCharactersInSet:set] isEqualToString:@""];
			if(valid){
				NSTask *task = [[NSTask alloc] init];
				[task setLaunchPath:@"/usr/bin/apt-get"];
				[task setArguments:@[
					@"install",
					@"-y",
					@"--allow-unauthenticated",
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
			}
		}
		[logText writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		// nothing else to do
		NSString *log2 = [logDir stringByAppendingPathComponent:@"fixup_log.txt"];
		NSString *log2Text = @"There's no fixup log for a list restore.\n";
		[log2Text writeToFile:log2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

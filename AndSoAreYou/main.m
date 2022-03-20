//
//	main.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <sys/stat.h>
#import "../Common.h"

int proc_pidpath(int pid, void *buffer, uint32_t buffersize); // libproc.h

void executeCommand(NSString *cmd){
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", cmd]];
	[task launch];
	[task waitUntilExit];
}

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
		for(NSString *file in lines){
			NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
			NSString *newPath = [NSString stringWithFormat:@"%@%@", tweakDir, dirStructure];
			if(![[newPath substringFromIndex:[newPath length]-1] isEqualToString:@"/"]) newPath = [newPath stringByAppendingString:@"/"]; // add missing slash
			[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:NULL]; // recreate parent directory structure
			NSString *extension = [file pathExtension];
			// 'reenable' tweaks that've been disabled with iCleaner Pro (i.e., change extension from .disabled back to .dylib)
			if([[[file pathExtension] lowercaseString] isEqualToString:@"disabled"]) extension = @"dylib";
			NSString *newFile = [newPath stringByAppendingString:[[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension]];
			[fileManager copyItemAtPath:file toPath:newFile error:NULL]; // copy file
		}
	}
	else if(strcmp(argv[1], "copy-debian-files") == 0){
		NSString *tweakDir = [NSString stringWithContentsOfFile:targetDir encoding:NSUTF8StringEncoding error:NULL];
		NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];
		NSString *tweakName = [tweakDir lastPathComponent];

		// copy files
		NSString *filesToCopy = [NSString stringWithContentsOfFile:dFilesToCopy encoding:NSUTF8StringEncoding error:NULL];
		NSArray *lines = [filesToCopy componentsSeparatedByString:@"\n"];
		for(NSString *file in lines){
			NSString *fileName = [file lastPathComponent];
			NSString *strippedName = [fileName stringByReplacingOccurrencesOfString:[tweakName stringByAppendingString:@"."] withString:@""]; // remove tweakName prefix
			[[NSFileManager defaultManager] copyItemAtPath:file toPath:[NSString stringWithFormat:@"%@%@", debian, strippedName] error:NULL]; // copy file
		}
	}
	else if(strcmp(argv[1], "build-debs") == 0){
		// Note: the default compression for dpkg-deb is xz (as of 1.15.6), which will occassionally cause an error:
		// "unexpected end of file in archive member header in packageName.deb" upon extraction/installation if there
		// is a dpkg version conflict. in order to fix this, we need to use gzip compression

		// build debs from collected files and then remove the respective file dir when done
		NSString *cmd = [NSString stringWithFormat:@"find %@ -maxdepth 1 -type d -exec dpkg-deb -b -Zgzip -z9 {} \\; -exec rm -r {} \\; > %@build_log.txt", tmpDir, logDir];
		executeCommand(cmd);
	}
	else if(strcmp(argv[1], "install-debs") == 0){
		// install debs and resolve missing dependencies
		// doing each deb individually to ensure that the entire process isn't nuked if a totally unconfigurable package (e.g., incompatible iOS vers, unmeetable dependencies, etc) is met
		NSString *cmd = [NSString stringWithFormat:@"find %@ -name '*.deb' -exec apt-get install -y --allow-unauthenticated {} \\; > %@restore_log.txt", tmpDir, logDir];
		executeCommand(cmd);

		// resolve any lingering things (e.g., partial installs due to dependencies)
		NSString *cmd2 = [NSString stringWithFormat:@"find %@ -name '*.deb' -exec apt-get install -fy --allow-unauthenticated {} \\; > %@fixup_log.txt", tmpDir, logDir];
		executeCommand(cmd2);
	}
	else if(strcmp(argv[1], "install-list") == 0){
		NSString *tweakList = [NSString stringWithContentsOfFile:targetList encoding:NSUTF8StringEncoding error:NULL];

		// make sure info on available packages is up-to-date
		NSString *cmd = [NSString stringWithFormat:@"apt-get update"];
		executeCommand(cmd);

		// install packages from tweak list
		// doing one package at a time to ensure that the entire process isn't nuked if an unknown, unfindable, and/or incompatible package is met
		NSString *cmd2 = [NSString stringWithFormat:@"xargs -n 1 -a %@ apt-get install -y --allow-unauthenticated > %@restore_log.txt", tweakList, logDir];
		executeCommand(cmd2);

		// resolve any lingering things (e.g., partial installs due to dependencies)
		NSString *cmd3 = [NSString stringWithFormat:@"xargs -n 1 -a %@ apt-get install -fy --allow-unauthenticated > %@fixup_log.txt", tweakList, logDir];
		executeCommand(cmd3);
	}
	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

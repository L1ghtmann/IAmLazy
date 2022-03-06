//
//	main.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import "../Common.h"

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

	setuid(0);
	setuid(0);

	if(strcmp(argv[1], "cleanup-tmp") == 0){
		// delete temporary directory
		NSString *cmd = [NSString stringWithFormat:@"rm -rf %@", tmpDir];
		executeCommand(cmd);
	}

	else if(strcmp(argv[1], "copy-generic-files") == 0){
		NSString *tweakDir = [NSString stringWithContentsOfFile:targetDir encoding:NSUTF8StringEncoding error:NULL];

		/*
			There are three main approaches to copying files:
				1) one massive copy cmd with all desired source files specified
				2) running a cmd for each file individually
				3) read files to copy from a file

			1 -- quick, but can lead to an NSInternalInconsistencyException being thrown with reason: "Couldn't posix_spawn: error 7" (error 7 == E2BIG)
			this occurs because the cmd's arg length > arg length limit for posix defined by KERN_ARGMAX, which can be checked with "sysctl kern.argmax"
			from what I can tell, the limit is ~262144 (including spaces), which can be exceeded by themes with thousands of files and complex dir structures

			2 -- works, but is really slow compared to 1 & 3

			3 -- solid and quick af (so we're going with this)
			rsync has this functionality built-in with the --files-from flag, but rsync isn't preinstalled, so that means we'd have yet another dependency
			alternatively, we can use xargs' -a flag, where it will read from a file and properly divvy up the args into mutliple cmds if ARG_MAX is exceeded
		*/

		// copy files and file structure
		NSString *cmd = [NSString stringWithFormat:@"xargs -d '\n' -a %@ cp -a --parents -t %@", gFilesToCopy, tweakDir];
		executeCommand(cmd);
	}

	else if(strcmp(argv[1], "copy-debian-files") == 0){
		NSString *tweakDir = [NSString stringWithContentsOfFile:targetDir encoding:NSUTF8StringEncoding error:NULL];
		NSString *tweakName = [tweakDir stringByReplacingOccurrencesOfString:tmpDir withString:@""];
		NSString *debian = [NSString stringWithFormat:@"%@/DEBIAN/", tweakDir];

		// copy files
		NSString *cmd = [NSString stringWithFormat:@"xargs -d '\n' -a %@ cp -a -t %@", dFilesToCopy, debian];
		executeCommand(cmd);

		// rename files (remove tweakName prefix)
		NSString *cmd2 = [NSString stringWithFormat:@"cd %@ && find . -name '%@.*' | while read f; do mv $f ${f##*.}; done", debian, tweakName];
		executeCommand(cmd2);
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

	else{
		printf("Houston, we have a problem: an invalid argument was provided!\n");
		return 1;
	}

	return 0;
}

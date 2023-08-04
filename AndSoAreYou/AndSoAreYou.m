//
//	AndSoAreYou.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <Foundation/Foundation.h>
#import "../Common.h"
#import <sys/stat.h>
#import "../Task.h"

// have this so we don't have
// to r/w filenames from a file
NSString *getCurrentPackage(){
	@autoreleasepool{
		NSError *readError = nil;
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *tmpDirFiles = [fileManager contentsOfDirectoryAtPath:tmpDir error:&readError];
		if(readError){
			IALLogErr(@"Failed to get contents of %@! Info: %@", tmpDir, readError.localizedDescription);
			return @"err";
		}
		else if(![tmpDirFiles count]){
			IALLogErr(@"%@ is empty?!", tmpDir);
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
					NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:filePath error:&readError];
					if(readError){
						IALLogErr(@"Failed to get attributes of %@! Info: %@", filePath, readError.localizedDescription);
						readError = nil;
						continue;
					}

					NSDate *creationDate = [fileAttributes fileCreationDate];
					NSString *dateString = [formatter stringFromDate:creationDate];
					[dirsAndCreationDates setValue:file forKey:dateString];
				}
			}
		}

		NSArray *dates = [dirsAndCreationDates allKeys];
		if(![dates count]){
			return @"err";
		}
		NSSortDescriptor *compare = [NSSortDescriptor sortDescriptorWithKey:nil ascending:NO selector:@selector(compare:)];
		NSArray *sortedDates = [dates sortedArrayUsingDescriptors:@[compare]];
		return [dirsAndCreationDates objectForKey:[sortedDates firstObject]];
	}
}

// libproc.h
int proc_listpids(uint32_t type, uint32_t typeinfo, void *buffer, int buffersize);
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize);

// proc_info.h
#define PROC_ALL_PIDS				1
#define PROC_PIDPATHINFO_MAXSIZE	(4*MAXPATHLEN)

int main(int argc, char *argv[]){
	@autoreleasepool{
		if(argc != 2){
			puts("Nah.");
			return 1;
		}

		// get attributes of IAmLazy
		struct stat iamlazy;
		char bin[PATH_MAX];
	#if !(CLI)
		strcpy(bin, ROOT_PATH("/Applications/IAmLazy.app/IAmLazy"));
	#else
		strcpy(bin, ROOT_PATH("/usr/local/bin/ial"));
	#endif
		if(lstat(bin, &iamlazy) != 0){
			puts("Wut?");
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
			puts("Oh HELL nah!");
			return 1;
		}

		setuid(0);
		setgid(0);

		if(strcmp(argv[1], "unlockDpkg") == 0){
			// kill dpkg to free the lock
			// https://stackoverflow.com/q/3018054
			int pNum = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
			pid_t pids[pNum];
			proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
			for(int i = 0; i < pNum; i++){
				pid_t pid = pids[i];
				if(!pid) continue;
				char pathBuf[PROC_PIDPATHINFO_MAXSIZE];
				proc_pidpath(pid, pathBuf, sizeof(pathBuf));
				if(strlen(pathBuf) > 0 && strcmp(pathBuf, ROOT_PATH("/usr/bin/dpkg")) == 0){
					int ret = kill(pid, SIGTERM);
					if(ret < 0){
						IALLogErr(@"unlockDpkg failed: %d", ret);
						return 1;
					}
				}
			}

			// configure any unconfigured packages
			const char *args2[] = {
				ROOT_PATH("/usr/bin/dpkg"),
				"--configure",
				"-a",
				NULL
			};
			ret = task(args2);
			if(ret < 0){
				IALLogErr(@"unlockDpkg failed: %d", ret);
				return 1;
			}
			IALLog(@"dpkg should be fixed.");
		}
		else if(strcmp(argv[1], "cleanTmp") == 0){
			NSError *deleteError = nil;
			[[NSFileManager defaultManager] removeItemAtPath:tmpDir error:&deleteError];
			if(deleteError){;
				IALLogErr(@"Failed to delete %@! Info: %@", tmpDir, deleteError.localizedDescription);
				return 1;
			}
		}
		else if(strcmp(argv[1], "updateAPT") == 0){
			const char *args[] = {
				ROOT_PATH("/usr/bin/apt"),
				"update",
				"--allow-insecure-repositories",
				"--allow-unauthenticated",
				NULL
			};
			ret = task(args);
			if(ret < 0){
				IALLogErr(@"updateApt failed: %d", ret);
				return 1;
			}
			IALLog(@"apt sources up-to-date.");
		}
		else if(strcmp(argv[1], "cpGFiles") == 0){
			NSString *current = getCurrentPackage();
			if(![current length] || [current isEqualToString:@"err"]){
				IALLogErr(@"getCurrentPackage() failed.");
				return 1;
			}

			NSError *error = nil;
			NSString *filesToCopy = [tmpDir stringByAppendingPathComponent:@".filesToCopy"];
			NSString *toCopy = [NSString stringWithContentsOfFile:filesToCopy encoding:NSUTF8StringEncoding error:&error];
			if(error){
				IALLogErr(@"Failed to get contents of %@! Info: %@", filesToCopy, error.localizedDescription);
				return 1;
			}

			NSArray *files = [toCopy componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			if(![files count]){
				IALLogErr(@"%@ has no contents?!", filesToCopy);
				return 1;
			}

			NSString *tweakDir = [tmpDir stringByAppendingPathComponent:current];
			NSFileManager *fileManager = [NSFileManager defaultManager];
			for(NSString *file in files){
				if(![file length] || ![fileManager fileExistsAtPath:file] || [[file lastPathComponent] isEqualToString:@".."] || [[file lastPathComponent] isEqualToString:@"."]){
					continue;
				}

				// recreate parent directory structure
				NSString *dirStructure = [file stringByDeletingLastPathComponent]; // grab parent directory structure
				NSString *newPath = [tweakDir stringByAppendingPathComponent:dirStructure];
				[fileManager createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&error];
				if(error){
					IALLogErr(@"Failed to create %@! Info: %@", newPath, error.localizedDescription);
					return 1;
				}

				// 're-enable' tweaks that've been 'disabled' with iCleaner Pro
				NSString *extension = [file pathExtension];
				if([[extension lowercaseString] isEqualToString:@"disabled"]){
					extension = @"dylib";
				}
				NSString *newFile = [[[file lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
				NSString *newFilePath = [newPath stringByAppendingPathComponent:newFile];

				[fileManager copyItemAtPath:file toPath:newFilePath error:&error];
				if(error){
					IALLogErr(@"Failed to copy %@! Info: %@", file, error.localizedDescription);
					error = nil;
				}
			}
		}
		else if(strcmp(argv[1], "cpDFiles") == 0){
			NSString *tweakName = getCurrentPackage();
			if(![tweakName length] || [tweakName isEqualToString:@"err"]){
				IALLogErr(@"getCurrentPackage() failed.");
				return 1;
			}

			// get DEBIAN files (e.g., maintainer scripts)
			NSError *error = nil;
			NSString *dpkgInfoDir = ROOT_PATH_NS_VAR(@"/var/lib/dpkg/info/");
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSArray *dpkgInfo = [fileManager contentsOfDirectoryAtPath:dpkgInfoDir error:&error];
			if(error){
				IALLogErr(@"Failed to get contents of %@! Info: %@", dpkgInfoDir, error.localizedDescription);
				return 1;
			}
			else if(![dpkgInfo count]){
				IALLogErr(@"%@ is empty?!", dpkgInfoDir);
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
				IALLog(@"%@ has no DEBIAN files.", tweakName);
				return 0;
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

				NSString *newPath = [debian stringByAppendingPathComponent:strippedName];
				[fileManager copyItemAtPath:filePath toPath:newPath error:&error];
				if(error){
					IALLogErr(@"Failed to copy %@! Info: %@", filePath, error.localizedDescription);
					error = nil;
					continue;
				}

				// ensure correct perms
				if(lchmod([newPath fileSystemRepresentation], 00755) != 0){
					IALLogErr(@"Failed to set %@ perms!", newPath);
					return 1;
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
				IALLogErr(@"getCurrentPackage() failed.");
				return 1;
			}

			NSString *tweak = [tmpDir stringByAppendingPathComponent:current];
			const char *args[] = {
				ROOT_PATH("/usr/bin/dpkg-deb"),
				"-b",
				"-Zgzip",
				"-z9",
				[tweak fileSystemRepresentation],
				NULL
			};
			ret = task(args);
			if(ret < 0){
				IALLogErr(@"buildDeb failed: %d for: %@", ret, current);
				return 1;
			}

			// delete dir with files now that deb has been built
			NSError *deleteError = nil;
			NSFileManager *fileManager = [NSFileManager defaultManager];
			[fileManager removeItemAtPath:tweak error:&deleteError];
			if(deleteError){
				IALLogErr(@"Failed to delete %@! Info: %@", tweak, deleteError.localizedDescription);
			}

			if(![fileManager fileExistsAtPath:[tweak stringByAppendingPathExtension:@"deb"]]){
				IALLogErr(@"%@.deb failed to build!", tweak);
				return 1;
			}
			IALLog(@"%@.deb created successfully!", tweak);
		}
		else if(strcmp(argv[1], "installDeb") == 0){
			// get debs from tmpDir
			NSError *error = nil;
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSArray *tmpDirContents = [fileManager contentsOfDirectoryAtPath:tmpDir error:&error];
			if(error){
				IALLogErr(@"Failed to get contents of %@! Info: %@", tmpDir, error.localizedDescription);
				return 1;
			}
			else if(![tmpDirContents count]){
				IALLogErr(@"%@ is empty?!", tmpDir);
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
				IALLogErr(@"%@ has no debs!", tmpDir);
				return 1;
			}
			else if([debs count] == 1){
				// https://youtu.be/i6XQY8jebs4
				IALLog(@"the laaaaaaassssst debbbbbbbbb....");
				end = YES;
			}

			// There seems to be an issue with uicache on u0 where
			// it will kill the IAL process (w/o a crash log):
			//	- uicache requests "container lookup" >
			//	- lsd parses bundle info and regsiters something >
			//	- frontboard gets notification of newly "installed" app >
			//	- springboard terminates process via runningboardd in
			//		order to "uninstall" (i.e., replace) the container
			//
			// Have found this occurs occasionally when called from a postinst
			// and will leave the AndSoAreYou child process running.
			// We don't want that, so check to see if the IAL process is
			// alive and, if not, finish the current package and return
			BOOL alive = !kill(ppid, 0);
			if(!alive){
				IALLogErr(@"IAL process was killed. Returning.");
				return 0;
			}

			NSString *deb = [debs firstObject];
			IALLog(@"Attempting install of %@", deb);
			const char *args[] = {
				ROOT_PATH("/usr/bin/dpkg"),
				"-i",
				[deb fileSystemRepresentation],
				NULL
			};
			ret = task(args);
			if(ret < 0){
				IALLogErr(@"installDeb failed: %d for: %@", ret, deb);
				return 1;
			}
			IALLog(@"Installed %@", deb);

			// delete deb now that it's been installed
			[fileManager removeItemAtPath:deb error:&error];
			if(error){;
				IALLogErr(@"Failed to delete %@! Info: %@", deb, error.localizedDescription);
				return 1;
			}

			if(end){
				IALLog(@"Done installing packages.");

				// resolve any lingering things
				// (e.g., conflicts, partial installs due to dependencies, etc)
				const char *args[] = {
					ROOT_PATH("/usr/bin/apt-get"),
					"install",
					"-fy",
					"--allow-unauthenticated",
					NULL
				};
				ret = task(args);
				if(ret < 0){
					IALLogErr(@"installDeb failed: %d for apt fixup.", ret);
					return 1;
				}

				// ensure everything that can be configured is
				const char *args2[] = {
					ROOT_PATH("/usr/bin/dpkg"),
					"--configure",
					"-a",
					NULL
				};
				ret = task(args2);
				if(ret < 0){
					IALLogErr(@"installDeb failed: %d for dpkg configure.", ret);
					return 1;
				}
				IALLog(@"apt fixed and dpkg configured (just in case).");

				sleep(1);
			}
		}
		else{
			puts("Houston, we have a problem: an invalid argument was provided!");
			return 1;
		}

		return 0;
	}
}

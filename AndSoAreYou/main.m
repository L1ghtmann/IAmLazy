#import <stdio.h>
#import <string.h>
#import <dlfcn.h>
#import <unistd.h>
#import <stdlib.h>
#import "../Common.h"

#define FLAG_PLATFORMIZE (1 << 1)

// (https://github.com/coolstar/electra/blob/cydia/docs/getting-started.md#setting-uid-0)
// 'get root' stuff below courtesy of the Electra team

// Platformize binary
void platformize_me() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;

    // Reset errors
    dlerror();
    typedef void (*fix_entitle_prt_t)(pid_t pid, uint32_t what);
    fix_entitle_prt_t ptr = (fix_entitle_prt_t)dlsym(handle, "jb_oneshot_entitle_now");

    const char *dlsym_error = dlerror();
    if (dlsym_error) return;

    ptr(getpid(), FLAG_PLATFORMIZE);
}

// Patch setuid
void patch_setuid() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;

    // Reset errors
    dlerror();
    typedef void (*fix_setuid_prt_t)(pid_t pid);
    fix_setuid_prt_t ptr = (fix_setuid_prt_t)dlsym(handle, "jb_oneshot_fix_setuid_now");

    const char *dlsym_error = dlerror();
    if (dlsym_error) return;

    ptr(getpid());
}

void executeCommand(NSString *cmd){
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:@[@"-c", cmd]];
	[task launch];
	[task waitUntilExit];
}

int main(int argc, char *argv[]) {
    patch_setuid();
    platformize_me();
    setuid(0);
    setuid(0);

    if(strcmp(argv[1], "cleanup-tmp") == 0 && argc == 2){
        // remove tmp dir
        NSString *cmd = [NSString stringWithFormat:@"rm -rf %@", tmpDir];
        executeCommand(cmd);
    }

    else if(strcmp(argv[1], "copy-files") == 0 && argc == 3){
        const char* ctweakdir = argv[2];
        NSString *tweakDir = [NSString stringWithCString:ctweakdir encoding:NSASCIIStringEncoding];

        /*
            There are three main approaches to copying files:
                1) one massive copy cmd with all desired source files specified
                2) iterate through an array of files, running a cmd for each file individually
                3) read files to copy from a file

            1 -- quick, but can lead to an NSInternalInconsistencyException being thrown with reason: "Couldn't posix_spawn: error 7" (error 7 == E2BIG)
            this occurs because the cmd's arg length > arg length limit for posix defined by KERN_ARGMAX, which can be checked with "sysctl kern.argmax"
            from what I can tell, the limit is ~262144 (including spaces), which can be exceeded by themes with thousands of files and complex dir structures

            2 -- works, but is really slow compared to 1 & 3

            3 -- solid and quick af (so we're going with this)
        */

        // copy files
        NSString *cmd = [NSString stringWithFormat:@"rsync -ar --files-from=%@ / %@", filesToCopy, tweakDir];
        executeCommand(cmd);
    }

    else if(strcmp(argv[1], "post-build") == 0 && argc == 3){
        const char* cpackage = argv[2];
        NSString *package = [NSString stringWithCString:cpackage encoding:NSASCIIStringEncoding];

        // remove package-specific subdir
        NSString *cmd = [NSString stringWithFormat:@"rm -rf %@%@", tmpDir, package];
        executeCommand(cmd);
    }

    else if(strcmp(argv[1], "install-debs") == 0 && argc == 2){
        // force install debs
        NSString *cmd = [NSString stringWithFormat:@"dpkg -iR %@", tmpDir];
        executeCommand(cmd);

        // resolve dependencies for configured packages and remove unconfirgurable packages (e.g., incompatible iOS vers, etc)
        NSString *cmd2 = [NSString stringWithFormat:@"apt-get install -fy --allow-unauthenticated"];
        executeCommand(cmd2);
    }

    else{
        printf("Houston, we have a problem: an invalid arguement(s) was provided\n");
        exit(EXIT_FAILURE);
    }

    return 0;
}

#include "Task.h"
#include <stdio.h>
#include <spawn.h>
#include <string.h>
#include <stdlib.h>
// #include <rootless.h>
#include <sys/wait.h>
#include <sys/syslog.h>

#if DEBUG
#include <fcntl.h>
#endif

#if CLI
#define print(loc, val) printf("[i] %s: %d\n", loc, val)
#define printErr(loc, val) printf("[x] %s: %d\n", loc, val)
#elif DEBUG
#define print(loc, val) syslog(LOG_WARNING, "[IALLog] %s: %d\n", loc, val)
#define printErr(loc, val) syslog(LOG_WARNING, "[IALLogErr] %s: %d\n", loc, val)
#else
#define print(loc, val)
#define printErr(loc, val)
#endif

extern char **environ;

int task(const char *args[]){
	pid_t pid;
	// FIX: palera1n
	// this is unprefixed by default ????
	// print(getenv("PATH"), 99); // test
	if(strstr(getenv("PATH"), "/var/jb") == NULL){
		// https://github.com/opa334/Dopamine/blob/1595dbf05561e55aa36e8dd39a77ebe2a5dd00c1/Packages/Fugu15KernelExploit/Sources/Fugu15KernelExploit/oobPCI.swift#L252
		setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/var/jb/sbin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/bin", 1);
	}
	// print(getenv("PATH"), 99); // test
#if DEBUG
	posix_spawn_file_actions_t fd_actions;
	posix_spawn_file_actions_init(&fd_actions);
	// posix_spawn_file_actions_addopen(&fd_actions, 2, ROOT_PATH("/tmp/ial.log"), O_WRONLY | O_CREAT | O_APPEND, 0644);
	posix_spawn_file_actions_addopen(&fd_actions, 2, "/tmp/ial.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
	int ret = posix_spawn(&pid, args[0], &fd_actions, NULL, (char* const*)args, environ);
#else
	int ret = posix_spawn(&pid, args[0], NULL, NULL, (char* const*)args, environ);
#endif
	if(ret != 0){
		printErr("posix_spawn() ret", ret);
		return ret;
	}

	pid_t wait = waitpid(pid, &ret, 0);
	if(wait == -1){
		printErr("waitpid() ret", wait);
		return wait;
	}
	else if(WIFSIGNALED(ret)){
		int tSig = WTERMSIG(ret);
		printErr("child proc sigterm", tSig);
		return tSig;
	}
	else if(WIFEXITED(ret)){
		int eStat = WEXITSTATUS(ret);
		if(eStat != 0){
			printErr("child proc estat", eStat);
		}
		return eStat ?: ret;
	}
	printErr("child proc ret", ret);
	return ret;
}

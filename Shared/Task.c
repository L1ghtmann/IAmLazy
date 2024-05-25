//
//	Task.c
//	IAmLazy
//
//	Created by Lightmann
//

#include <Log.h>
#include <Task.h>
#include <stdio.h>
#include <spawn.h>
#include <string.h>
#include <stdlib.h>
// #include <rootless.h>
#include <sys/wait.h>

#if CLI
#include <fcntl.h>
#endif

extern char **environ;

int task(const char *args[]){
	pid_t pid;
	// fix for palera1n (et al ?)
	// this is unprefixed by default ????
	if(strstr(getenv("PATH"), "/var/jb") == NULL){
		// https://github.com/opa334/Dopamine/blob/1595dbf05561e55aa36e8dd39a77ebe2a5dd00c1/Packages/Fugu15KernelExploit/Sources/Fugu15KernelExploit/oobPCI.swift#L252
		setenv("PATH", "/sbin:/bin:/usr/sbin:/usr/bin:/var/jb/sbin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/usr/bin", 1);
	}
#if DEBUG
	posix_spawn_file_actions_t fd_actions;
	posix_spawn_file_actions_init(&fd_actions);
	// posix_spawn_file_actions_addopen(&fd_actions, 2, ROOT_PATH("/tmp/ial.log"), O_WRONLY | O_CREAT | O_APPEND, 0666);
	posix_spawn_file_actions_addopen(&fd_actions, 2, "/tmp/ial.log", O_WRONLY | O_CREAT | O_APPEND, 0666);
	int ret = posix_spawn(&pid, args[0], &fd_actions, NULL, (char* const*)args, environ);
	posix_spawn_file_actions_destroy(&fd_actions);
#else
	int ret = posix_spawn(&pid, args[0], NULL, NULL, (char* const*)args, environ);
#endif
	if(ret != 0){
		IALLogErr("posix_spawn() ret: %d", ret);
		return ret;
	}

	pid_t wait = waitpid(pid, &ret, 0);
	if(wait == -1){
		IALLogErr("waitpid() ret: %d", wait);
		return wait;
	}
	else if(WIFSIGNALED(ret)){
		int tSig = WTERMSIG(ret);
		IALLogErr("child proc sigterm: %d", tSig);
		return tSig;
	}
	else if(WIFEXITED(ret)){
		int eStat = WEXITSTATUS(ret);
		if(eStat != 0){
			IALLogErr("child proc estat: %d", eStat);
		}
		return eStat ?: ret;
	}
	IALLog("child proc ret: %d", ret);
	return ret;
}

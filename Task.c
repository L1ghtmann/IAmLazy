#include "Task.h"
#include <string.h>
#include <stdio.h>
#include <spawn.h>
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
#if DEBUG
	posix_spawn_file_actions_t fd_actions;
	posix_spawn_file_actions_init(&fd_actions);
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

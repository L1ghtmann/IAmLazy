#include "Task.h"
#include <spawn.h>
#include <sys/wait.h>

extern char **environ;

int task(const char *args[]){
	pid_t pid;
	int ret = posix_spawn(&pid, args[0], NULL, NULL, (char* const*)args, environ);
	if(ret == 0){
		waitpid(pid, &ret, 0);
	}
	return WEXITSTATUS(ret);
}

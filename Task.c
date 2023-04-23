#include "Task.h"
#include <spawn.h>
#include <sys/wait.h>

int task(const char *args[]){
	pid_t pid;
	int status;
	posix_spawn(&pid, args[0], NULL, NULL, (char* const*)args, NULL);
	waitpid(pid, &status, 0);
	return status;
}

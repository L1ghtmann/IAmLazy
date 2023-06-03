//
//	postinst.m
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#import <rootless.h>
#import <sys/stat.h>
#import <unistd.h>
#import <stdio.h>

int main(){
	@autoreleasepool{
		// root:wheel & 6755 the helper binary
		int retChown = lchown(ROOT_PATH("/usr/libexec/iamlazy/AndSoAreYou"), 0, 0);
		int retChmod = lchmod(ROOT_PATH("/usr/libexec/iamlazy/AndSoAreYou"), 06755);
		if(retChown != 0 || retChmod != 0){
			puts("ERROR: Failed to set AndSoAreYou perms!");
			return 1;
		}
		return 0;
	}
}

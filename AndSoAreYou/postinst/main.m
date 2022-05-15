#import <unistd.h>
#import <sys/stat.h>

int main(){
	// root:wheel & 6755 the helper binary
	int retChown = lchown("/usr/libexec/iamlazy/AndSoAreYou", 0, 0);
	int retChmod = lchmod("/usr/libexec/iamlazy/AndSoAreYou", 06755);
	if(retChown != 0 || retChmod != 0){
		return 1;
	}

	return 0;
}

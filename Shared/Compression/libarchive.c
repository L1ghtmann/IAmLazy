//
// 	libarchive.c
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#include <libarchive/archive_entry.h>
#include <CoreFoundation/CFString.h>
#include <libarchive/archive.h>
#include <dispatch/queue.h>
// #include <rootless.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>

#if CLI
#define IALLog(format, ...) printf("[i] " format "\n", ##__VA_ARGS__)
#define IALLogErr(format, ...) printf("[x] " format "\n", ##__VA_ARGS__)
#elif DEBUG
#include <syslog.h>
#define IALLog(format, ...) syslog(LOG_NOTICE, "[IALLog] " format "\n", ##__VA_ARGS__)
#define IALLogErr(format, ...) syslog(LOG_NOTICE, "[IALLogErr] " format "\n", ##__VA_ARGS__)
#else
#define IALLog(...)
#define IALLogErr(...)
#endif

int get_file_count(const char *path){
	struct dirent *entry;
	// DIR *directory = opendir(ROOT_PATH(path));
	DIR *directory = opendir(path);
	if(!directory){
		IALLogErr("failed to opendir %s!", path);
		return 0;
	}

	int file_count = 0;
	while((entry = readdir(directory))){
		// if entry is a regular file
		if(entry->d_type == DT_REG){
			file_count++;
		}
	}
	closedir(directory);
	return file_count;
}

bool write_archive(const char *src, const char *outname){
	struct archive *a, *disk;
	struct archive_entry *entry;
	char buff[8192];
	int r, len, fd;

	disk = archive_read_disk_new();
    archive_read_disk_set_standard_lookup(disk);

	a = archive_write_new();
	archive_write_add_filter_gzip(a);
	archive_write_set_format_pax_restricted(a);
	archive_write_open_filename(a, outname);

	int count = get_file_count(src);
	if(count == 0){
		IALLogErr("%s file count is 0!", src);
		return false;
	}

	float progress_per_part = (1.0/count);
	float progress = 0.0;

	r = archive_read_disk_open(disk, src);
	if(r != ARCHIVE_OK){
		IALLogErr("failed to open %s: %s", src, archive_error_string(disk));
		return false;
	}

	while(true){
		entry = archive_entry_new();
		r = archive_read_next_header2(disk, entry);
		if(r == ARCHIVE_EOF){
			break;
		}
		else if(r != ARCHIVE_OK){
			IALLogErr("read failure: %s", archive_error_string(disk));
			return false;
		}
		archive_read_disk_descend(disk);

		const char *name = archive_entry_pathname(entry);

		// skip first entry that is just the basename
		// (i.e., src but without a final trailing slash)
		if(strstr(name, src) == NULL) continue;

		// don't include /tmp/ in archive
		// rename each filepath to exclude /tmp/
		char path[PATH_MAX];
		char *file = strrchr(name, '/');
		sprintf(path, "me.lightmann.iamlazy%s", file);
		archive_entry_set_pathname(entry, path);

		r = archive_write_header(a, entry);
		if(r < ARCHIVE_OK){
			IALLogErr("header write failure: %s", archive_error_string(a));
			return false;
		}
		else if(r == ARCHIVE_FATAL){
			IALLogErr("header write fatality");
			return false;
		}
		else if(r > ARCHIVE_FAILED){
			fd = open(archive_entry_sourcepath(entry), O_RDONLY);
			len = read(fd, buff, sizeof(buff));
			while (len > 0) {
				archive_write_data(a, buff, len);
				len = read(fd, buff, sizeof(buff));
			}
			close(fd);

			progress+=progress_per_part;

			CFStringRef progStr = CFStringCreateWithFormat(NULL, NULL, CFSTR("%f"), progress);
		#if !(CLI)
			dispatch_async(dispatch_get_main_queue(), ^{
				CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
			});
		#else
			CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
		#endif
			CFRelease(progStr);

			char *target = strrchr(outname, '/') + 1;
			IALLog("added %s to %s", file, target);
		}
	}
	archive_entry_free(entry);
	archive_read_close(disk);
	archive_read_free(disk);
	archive_write_close(a);
	archive_write_free(a);
	return true;
}

int copy_data(struct archive *ar, struct archive *aw){
	int r;
	const void *buff;
	size_t size;
	la_int64_t offset;

	while(true){
		r = archive_read_data_block(ar, &buff, &size, &offset);
		if(r == ARCHIVE_EOF){
			return ARCHIVE_OK;
		}
		if(r < ARCHIVE_OK){
			return r;
		}

		r = archive_write_data_block(aw, buff, size, offset);
		if(r < ARCHIVE_OK){
			IALLogErr("archive_write_data_block error: %s", archive_error_string(aw));
			return r;
		}
	}
}

bool extract_archive(const char *src, const char *dest){
	struct archive *a;
    struct archive_entry *entry;
    int flags, r;

	// item count read
	a = archive_read_new();
	archive_read_support_format_tar(a);
	archive_read_support_filter_gzip(a);
	if((r = archive_read_open_filename(a, src, 10240))){
		IALLogErr("failed to open %s for extraction [1]!", src);
		return false;
	}

	// get item count
	int count = 0;
	while(archive_read_next_header(a, &entry) == ARCHIVE_OK){
		count++;
		archive_read_data_skip(a);
	}
	archive_read_close(a);
	archive_read_free(a);

	float progress_per_part = (1.0/count);
	float progress = 0.0;

    a = archive_read_new();
    archive_read_support_format_tar(a);
    archive_read_support_filter_gzip(a);
    if((r = archive_read_open_filename(a, src, 10240))){
		IALLogErr("failed to open %s for extraction [2]!", src);
        return false;
    }

	// attributes we want to restore
    flags = ARCHIVE_EXTRACT_TIME;
    flags |= ARCHIVE_EXTRACT_PERM;
    flags |= ARCHIVE_EXTRACT_ACL;
    flags |= ARCHIVE_EXTRACT_FFLAGS;

    while(archive_read_next_header(a, &entry) == ARCHIVE_OK){
        const char *file = archive_entry_pathname(entry);

		char path[1024];
        sprintf(path, "%s/%s", dest, file);
        archive_entry_set_pathname(entry, path);

        r = archive_read_extract(a, entry, flags);
        if(r != ARCHIVE_OK){
            IALLogErr("failed to extract %s: %s", path, archive_error_string(a));
            return false;
        }

		progress+=progress_per_part;

		CFStringRef progStr = CFStringCreateWithFormat(NULL, NULL, CFSTR("%f"), progress);
	#if !(CLI)
		dispatch_async(dispatch_get_main_queue(), ^{
			CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
		});
	#else
		CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
	#endif
		CFRelease(progStr);

		char *deb = strrchr(path, '/') + 1;
		IALLog("successfully extracted %s from %s", deb, src);
    }

    archive_read_close(a);
    archive_read_free(a);
	return true;
}

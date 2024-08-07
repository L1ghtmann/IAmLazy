//
// 	libarchive.c
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#include <CoreFoundation/CFString.h>
#include <dispatch/queue.h>
#include <archive_entry.h>
#include <archive.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>
#include <Log.h>

void write_entry(struct archive *a, const char *item){
	struct archive_entry *entry = archive_entry_new();
	archive_entry_set_pathname(entry, item);
	FILE *fp = fopen(item, "rb");
	fseek(fp, 0, SEEK_END);
	size_t size = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	archive_entry_set_filetype(entry, AE_IFREG);
	archive_entry_set_size(entry, size);
	archive_entry_set_perm(entry, 0644);
	archive_write_header(a, entry);

	char buff[8192];
	while((size = fread(buff, 1, sizeof(buff), fp)) > 0){
		archive_write_data(a, buff, size);
	}
	fclose(fp);
	archive_entry_free(entry);
}

bool write_deb_archive(const char *tmp, const char *outname){
	// components
	// note: archival order of these matters
	char db[PATH_MAX], control[PATH_MAX], data[PATH_MAX];
	sprintf(db, "%sdebian-binary", tmp);
	sprintf(control, "%scontrol.tar.gz", tmp);
	sprintf(data, "%sdata.tar.gz", tmp);

	struct archive *a = archive_write_new();
	archive_write_set_format_ar_bsd(a);
	archive_write_open_filename(a, outname);

	write_entry(a, db);
	write_entry(a, control);
	write_entry(a, data);

	archive_write_close(a);
	archive_write_free(a);
	return true;
}

int get_file_count(const char *path){
	struct dirent *entry;
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

bool write_archive(const char *src, const char *outname, bool component){
	int count = 1;
	if(!component){
		count = get_file_count(src);
		if(count == 0){
			IALLogErr("%s file count is 0!", src);
			return false;
		}
	}
	float progress_per_part = (1.0/count);
	float progress = 0.0;

	struct archive *disk = archive_read_disk_new();
	archive_read_disk_set_standard_lookup(disk);

	struct archive *a = archive_write_new();
	archive_write_add_filter_gzip(a);
	archive_write_set_format_pax_restricted(a);
	archive_write_open_filename(a, outname);

	int r = archive_read_disk_open(disk, src);
	if(r != ARCHIVE_OK){
		IALLogErr("failed to open %s: %s", src, archive_error_string(disk));
		archive_read_close(disk);
		archive_read_free(disk);
		archive_write_close(a);
		archive_write_free(a);
		return false;
	}

	struct archive_entry *entry;
	while(true){
		entry = archive_entry_new();
		r = archive_read_next_header2(disk, entry);
		if(r == ARCHIVE_EOF){
			break;
		}
		else if(r != ARCHIVE_OK){
			IALLogErr("read failure: %s", archive_error_string(disk));
			archive_entry_free(entry);
			archive_read_close(disk);
			archive_read_free(disk);
			archive_write_close(a);
			archive_write_free(a);
			return false;
		}
		archive_read_disk_descend(disk);

		const char *name = archive_entry_pathname(entry);

		// skip first entry that is just the basename
		// (i.e., src but without a final trailing slash)
		if(!component && strstr(name, src) == NULL){
			continue;
		}
		else if(strcmp(name, src) == 0){
			continue;
		}

		char *relPath;
		if(!component){
			// don't include /tmp/ in archive
			// rename each filepath to exclude /tmp/
			char path[PATH_MAX];
			char *file = strrchr(name, '/');
			sprintf(path, "me.lightmann.iamlazy%s", file);
			relPath = path;
		}
		else{
			char *path = (char *)name;
			if(strstr(outname, "control")){
				// don't include dirname in archive
				// rename each filepath to exclude dirname
				path = strrchr(name, '/');
			}
			else if(strstr(outname, "data")){
				// don't include /tmp/me.lightmann.iamlazy/some.tweak.name/
				// in archive; rename each filepath to exclude this path
				path += strlen(src);
			}
			relPath = path;
		}
		archive_entry_set_pathname(entry, relPath);

		r = archive_write_header(a, entry);
		if(r < ARCHIVE_OK){
			IALLogErr("header write failure: %s", archive_error_string(a));
			archive_entry_free(entry);
			archive_read_close(disk);
			archive_read_free(disk);
			archive_write_close(a);
			archive_write_free(a);
			return false;
		}
		else if(r == ARCHIVE_FATAL){
			IALLogErr("header write fatality");
			archive_entry_free(entry);
			archive_read_close(disk);
			archive_read_free(disk);
			archive_write_close(a);
			archive_write_free(a);
			return false;
		}
		else if(r > ARCHIVE_FAILED){
			char buff[8192];
			int fd = open(archive_entry_sourcepath(entry), O_RDONLY);
			int len = read(fd, buff, sizeof(buff));
			while(len > 0){
				archive_write_data(a, buff, len);
				len = read(fd, buff, sizeof(buff));
			}
			close(fd);

			progress+=progress_per_part;
			if(!component){
				CFStringRef progStr = CFStringCreateWithFormat(NULL, NULL, CFSTR("%f"), progress);
			#if !(CLI)
				dispatch_async(dispatch_get_main_queue(), ^{
					CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
				});
			#else
				CFNotificationCenterPostNotification(CFNotificationCenterGetLocalCenter(), CFSTR("updateItemProgress"), progStr, NULL, true);
			#endif
				CFRelease(progStr);
			}

			if(!component){
				char *file = strrchr(name, '/') + 1;
				char *target = strrchr(outname, '/') + 1;
				IALLog("Added %s to %s", file, target);
			}
		}
	}
	archive_entry_free(entry);
	archive_read_close(disk);
	archive_read_free(disk);
	archive_write_close(a);
	archive_write_free(a);
	return true;
}

bool open_archive(struct archive **a, const char *src) {
    int r;
    *a = archive_read_new();
    archive_read_support_format_tar(*a);
    archive_read_support_filter_gzip(*a);
    if((r = archive_read_open_filename(*a, src, 10240))){
        archive_read_close(*a);
        archive_read_free(*a);
        return false;
    }
    return true;
}

bool extract_archive(const char *src, const char *dest){
	// item count read
	struct archive *a;
	if(!open_archive(&a, src)) {
		IALLogErr("failed to open %s for extraction [1]!", src);
		return false;
	}

	// get item count
	int count = 0;
	struct archive_entry *entry = archive_entry_new();
	while(archive_read_next_header2(a, entry) == ARCHIVE_OK){
		count++;
		archive_read_data_skip(a);
	}
	archive_read_close(a);
	archive_read_free(a);

	float progress_per_part = (1.0/count);
	float progress = 0.0;

	if(!open_archive(&a, src)) {
		IALLogErr("failed to open %s for extraction [2]!", src);
		return false;
	}

	// attributes we want to restore
	int flags = ARCHIVE_EXTRACT_TIME;
	flags |= ARCHIVE_EXTRACT_PERM;
	flags |= ARCHIVE_EXTRACT_ACL;
	flags |= ARCHIVE_EXTRACT_FFLAGS;

	while(archive_read_next_header2(a, entry) == ARCHIVE_OK){
		const char *file = archive_entry_pathname(entry);

		char path[PATH_MAX];
		sprintf(path, "%s/%s", dest, file);
		archive_entry_set_pathname(entry, path);

		int r = archive_read_extract(a, entry, flags);
		if(r != ARCHIVE_OK){
			IALLogErr("failed to extract %s: %s", path, archive_error_string(a));
			archive_read_close(a);
			archive_read_free(a);
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
		char *backup = strrchr(src, '/') + 1;
		IALLog("Extracted %s from %s", deb, backup);
	}
	archive_read_close(a);
	archive_read_free(a);
	return true;
}

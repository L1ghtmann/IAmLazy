//
// 	libarchive.c
//	IAmLazy
//
//	Created by Lightmann during COVID-19
//

#include <archive_entry.h>
#include <sys/fcntl.h>
#include <archive.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <limits.h>
#include <os/log.h>

int get_file_count(){
	int file_count = 0;

	struct dirent *entry;
	DIR *directory = opendir("/tmp/me.lightmann.iamlazy/");
	if(!directory){
		return 0;
	}

	while((entry = readdir(directory))){
		// if entry is a regular file
		if(entry->d_type == DT_REG){
			file_count++;
		}
	}
	closedir(directory);

	return file_count;
}

void write_archive(const char *outname){
	struct archive *a;
	struct archive_entry *entry;
	struct stat st;
	char buff[8192];
	int len;
	int fd;

	int file_count = get_file_count();
	if(file_count == 0){
		return;
	}

	const char *filearr[file_count];
	const char **arrptr = filearr;

	struct dirent *ent;
	DIR *directory = opendir("/tmp/me.lightmann.iamlazy/");
	if(!directory){
		return;
	}

	int count = 0;
	size_t IAL = strlen("me.lightmann.iamlazy/");
	while((ent = readdir(directory))){
		if(count > file_count){
			break;
		}

		// if entry is a regular file
		if(ent->d_type == DT_REG){
			size_t FILE = strlen(ent->d_name);

			if((SIZE_MAX - (IAL + 1)) < FILE){
				continue;
			}

			char *filepath = malloc(IAL + FILE + 1);
			if(!filepath){
				continue;
			}
			strcpy(filepath, "me.lightmann.iamlazy/");
			strcat(filepath, ent->d_name);

			filearr[count] = filepath;
			count++;
		}
	}
	closedir(directory);

	// change CWD to avoid
	// including it in archive
	chdir("/tmp/");

	a = archive_write_new();
	archive_write_add_filter_gzip(a); // gzip
	archive_write_set_format_pax_restricted(a);
	archive_write_open_filename(a, outname);
	for(int i = 0; i < file_count; i++){
		const char *file = arrptr[i];
		if(*file == 0){
			continue;
		}

		stat(file, &st);
		entry = archive_entry_new();
		archive_entry_set_pathname(entry, file);
		archive_entry_set_size(entry, st.st_size);
		archive_entry_set_filetype(entry, AE_IFREG);
		archive_entry_set_perm(entry, 0644);
		archive_write_header(a, entry);
		fd = open(file, O_RDONLY);
		len = read(fd, buff, sizeof(buff));
		while(len > 0){
			archive_write_data(a, buff, len);
			len = read(fd, buff, sizeof(buff));
		}
		close(fd);
		free((char *)filearr[i]); // malloc'd char
		archive_entry_free(entry);
	}
	archive_write_close(a);
	archive_write_free(a);
}

int copy_data(struct archive *ar, struct archive *aw){
	int r;
	const void *buff;
	size_t size;
	la_int64_t offset;

	for(;;){
		r = archive_read_data_block(ar, &buff, &size, &offset);
		if(r == ARCHIVE_EOF){
			return ARCHIVE_OK;
		}
		if(r < ARCHIVE_OK){
			return r;
		}

		r = archive_write_data_block(aw, buff, size, offset);
		if(r < ARCHIVE_OK){
			os_log_error(OS_LOG_DEFAULT, "[IAmLazyLog] libarchive: copy_data: %s", archive_error_string(aw));
			return r;
		}
	}
}

void extract_archive(const char *filename){
	struct archive *a;
	struct archive *ext;
	struct archive_entry *entry;
	int flags;
	int r;

	// attributes we want to restore
	flags = ARCHIVE_EXTRACT_TIME;
	flags |= ARCHIVE_EXTRACT_PERM;
	flags |= ARCHIVE_EXTRACT_ACL;
	flags |= ARCHIVE_EXTRACT_FFLAGS;

	// extract location
	chdir("/tmp/");

	a = archive_read_new();
	archive_read_support_format_all(a);
	archive_read_support_filter_all(a);
	ext = archive_write_disk_new();
	archive_write_disk_set_options(ext, flags);
	archive_write_disk_set_standard_lookup(ext);
	if((r = archive_read_open_filename(a, filename, 10240))){
		return;
	}

	for(;;){
		r = archive_read_next_header(a, &entry);
		if(r == ARCHIVE_EOF){
			break;
		}
		if(r < ARCHIVE_OK){
			os_log_error(OS_LOG_DEFAULT, "[IAmLazyLog] libarchive: extract_archive: %s", archive_error_string(a));
		}
		if(r < ARCHIVE_WARN){
			return;
		}

		r = archive_write_header(ext, entry);
		if(r < ARCHIVE_OK){
			os_log_error(OS_LOG_DEFAULT, "[IAmLazyLog] libarchive: extract_archive: %s", archive_error_string(ext));
		}
		else if(archive_entry_size(entry) > 0){
			r = copy_data(a, ext);
			if(r < ARCHIVE_OK){
				os_log_error(OS_LOG_DEFAULT, "[IAmLazyLog] libarchive: extract_archive: %s", archive_error_string(ext));
			}
			if(r < ARCHIVE_WARN){
				return;
			}
		}

		r = archive_write_finish_entry(ext);
		if(r < ARCHIVE_OK){
			os_log_error(OS_LOG_DEFAULT, "[IAmLazyLog] libarchive: extract_archive: %s", archive_error_string(ext));
		}
		if(r < ARCHIVE_WARN){
			return;
		}
	}
	archive_read_close(a);
	archive_read_free(a);
	archive_write_close(ext);
	archive_write_free(ext);
}

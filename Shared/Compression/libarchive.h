#include <stdbool.h>

bool write_component_archive(const char *src, const char *outname);
bool write_deb_archive(const char *tmp, const char *outname);

bool write_archive(const char *src, const char *outname);
bool extract_archive(const char *src, const char *dest);

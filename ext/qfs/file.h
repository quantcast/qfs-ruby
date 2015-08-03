#ifndef QFS_EXT_FILE_H_
#define QFS_EXT_FILE_H_

#include <ruby.h>

extern VALUE cQfsFile;

struct qfs_file {
	VALUE client;
	int fd;
};

void qfs_file_deallocate(void*);
void qfs_file_mark(void*);
VALUE qfs_file_allocate(VALUE);

void init_qfs_ext_file(void);

#endif // QFS_FILE_H_

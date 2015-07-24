#ifndef RUBY_QFS_H
#define RUBY_QFS_H

#include <ruby.h>
#include <kfs/c/qfs.h>

extern VALUE mQfs;
extern VALUE eQfsError;

// QFS structs

struct qfs_client {
	struct QFS *qfs;
};

struct qfs_file {
	VALUE client;
	int fd;
};

void Init_qfs_ext(void);

#endif

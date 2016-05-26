#ifndef RUBY_QFS_H
#define RUBY_QFS_H

#include <sys/types.h>
#include <sys/time.h>
#include <kfs/c/qfs.h>
#include <ruby.h>

extern VALUE mQfs;
extern VALUE eQfsError;

// QFS structs

struct qfs_client {
	struct QFS *qfs;
};

void Init_qfs_ext(void);

#endif

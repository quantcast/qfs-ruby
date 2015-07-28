#include "attr.h"

#include "qfs.h"
#include "util.h"

VALUE cQfsAttr;

#define QFS_ATTR_GET(f, t) static VALUE qfs_attr_##f(VALUE self) { \
	struct qfs_attr *attr; \
	Data_Get_Struct(self, struct qfs_attr, attr); \
	return t(attr->f); \
}

QFS_ATTR_GET(filename, rb_str_new2)
QFS_ATTR_GET(id, INT2FIX)
QFS_ATTR_GET(mode, INT2FIX)
QFS_ATTR_GET(uid, INT2FIX)
QFS_ATTR_GET(gid, INT2FIX)
QFS_ATTR_GET(mtime, NTIME)
QFS_ATTR_GET(ctime, NTIME)
QFS_ATTR_GET(directory, INT2BOOL)
QFS_ATTR_GET(size, INT2FIX)
QFS_ATTR_GET(chunks, INT2FIX)
QFS_ATTR_GET(directories, INT2FIX)
QFS_ATTR_GET(replicas, INT2FIX)
QFS_ATTR_GET(stripes, INT2FIX)
QFS_ATTR_GET(recovery_stripes, INT2FIX)
QFS_ATTR_GET(striper_type, INT2FIX)
QFS_ATTR_GET(stripe_size, INT2FIX)
QFS_ATTR_GET(min_stier, INT2FIX)
QFS_ATTR_GET(max_stier, INT2FIX)

void init_qfs_ext_attr() {
	cQfsAttr = rb_define_class_under(mQfs, "Attr", rb_cObject);
	rb_define_method(cQfsAttr, "filename", qfs_attr_filename, 0);
	rb_define_method(cQfsAttr, "id", qfs_attr_id, 0);
	rb_define_method(cQfsAttr, "mode", qfs_attr_mode, 0);
	rb_define_method(cQfsAttr, "uid", qfs_attr_uid, 0);
	rb_define_method(cQfsAttr, "gid", qfs_attr_gid, 0);
	rb_define_method(cQfsAttr, "mtime", qfs_attr_mtime, 0);
	rb_define_method(cQfsAttr, "ctime", qfs_attr_ctime, 0);
	rb_define_method(cQfsAttr, "directory?", qfs_attr_directory, 0);
	rb_define_method(cQfsAttr, "size", qfs_attr_size, 0);
	rb_define_method(cQfsAttr, "chunks", qfs_attr_chunks, 0);
	rb_define_method(cQfsAttr, "directories", qfs_attr_directories, 0);
	rb_define_method(cQfsAttr, "replicas", qfs_attr_replicas, 0);
	rb_define_method(cQfsAttr, "stripes", qfs_attr_stripes, 0);
	rb_define_method(cQfsAttr, "recovery_stripes", qfs_attr_recovery_stripes, 0);
	rb_define_method(cQfsAttr, "striper_type", qfs_attr_striper_type, 0);
	rb_define_method(cQfsAttr, "strip_size", qfs_attr_stripe_size, 0);
	rb_define_method(cQfsAttr, "min_stier", qfs_attr_min_stier, 0);
	rb_define_method(cQfsAttr, "max_stier", qfs_attr_max_stier, 0);
}

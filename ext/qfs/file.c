#include "file.h"

#include <ruby.h>
#include "attr.h"
#include "qfs.h"
#include "util.h"

VALUE cQfsFile;

/* This is a handle to a fd that can perform IO. */
static VALUE qfs_file_read(VALUE self, VALUE len) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(len, T_FIXNUM);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	size_t n = (size_t)NUM2INT(len);
	VALUE s = rb_str_buf_new((long)n);
	ssize_t n_read = qfs_read(client->qfs, file->fd, RSTRING_PTR(s), n);
	QFS_CHECK_ERR(n_read);
	rb_str_set_len(s, n_read);
	return s;
}

static VALUE qfs_file_tell(VALUE self) {
	struct qfs_file *file;
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	off_t offset = qfs_tell(client->qfs, file->fd);
	QFS_CHECK_ERR(offset);
	return INT2FIX(offset);
}

/* Returns a Qfs::Attr object for the file. */
static VALUE qfs_file_stat(VALUE self) {
	struct qfs_file *file;
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	struct qfs_attr *attr = ALLOC(struct qfs_attr);
	int res = qfs_stat_fd(client->qfs, file->fd, attr);
	QFS_CHECK_ERR(res);
	return Data_Wrap_Struct(cQfsAttr, NULL, free, attr);
}

static VALUE qfs_file_write(VALUE self, VALUE str) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(str, T_STRING);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	ssize_t n = qfs_write(client->qfs, file->fd, RSTRING_PTR(str),
			(size_t)RSTRING_LEN(str));
	QFS_CHECK_ERR(n);
	if (n < RSTRING_LEN(str)) {
		WARN("partial write");
	}
	return INT2FIX(n);
}

static VALUE qfs_file_close(VALUE self) {
	TRACE;
	struct qfs_file *file;
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	int err = qfs_close(client->qfs, file->fd);
	QFS_CHECK_ERR(err);
	file->fd = QFS_NIL_FD;
	file->client = Qnil;
	TRACE_R;
	return Qnil;
}

static VALUE qfs_file_chmod(VALUE self, VALUE mode) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(mode, T_FIXNUM);
	mode_t imode = (mode_t)FIX2INT(mode);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	int res = qfs_chmod_fd(client->qfs, file->fd, imode);
	QFS_CHECK_ERR(res);
	return RES2BOOL(res);
}

static VALUE qfs_file_seek(VALUE self, VALUE offset, VALUE whence) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(offset, T_FIXNUM);
	Check_Type(whence, T_FIXNUM);
	off_t toffset = (off_t)FIX2INT(offset);
	int iwhence = FIX2INT(whence);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	off_t res = qfs_seek(client->qfs, file->fd, toffset, iwhence);
	QFS_CHECK_ERR(res);
	return INT2FIX((int)res);
}

void qfs_file_deallocate(void *filevp) {
	TRACE;
	/* the client might be deallocated already, so don't try to close ourselves */
	free(filevp);
	TRACE_R;
}

void qfs_file_mark(void *filevp) {
	struct qfs_file *file = filevp;
	if (file->client) {
		rb_gc_mark(file->client);
	}
}

VALUE qfs_file_allocate(VALUE klass) {
	struct qfs_file *file = malloc(sizeof(struct qfs_file));
	file->client = Qnil;
	file->fd = QFS_NIL_FD;
	return Data_Wrap_Struct(klass, qfs_file_mark, qfs_file_deallocate, file);
}

void init_qfs_ext_file() {
	cQfsFile = rb_define_class_under(mQfs, "File", rb_cObject);
	rb_define_alloc_func(cQfsFile, qfs_file_allocate);
	rb_define_method(cQfsFile, "read_len", qfs_file_read, 1);
	rb_define_method(cQfsFile, "tell", qfs_file_tell, 0);
	rb_define_method(cQfsFile, "stat", qfs_file_stat, 0);
	rb_define_method(cQfsFile, "write", qfs_file_write, 1);
	rb_define_method(cQfsFile, "close", qfs_file_close, 0);
	rb_define_method(cQfsFile, "chmod", qfs_file_chmod, 1);
	rb_define_private_method(cQfsFile, "seek_internal", qfs_file_seek, 2);
}

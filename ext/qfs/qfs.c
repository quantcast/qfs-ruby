#include "qfs.h"

#include <ruby.h>
#include "attr.h"
#include "file.h"
#include "util.h"

VALUE mQfs;
VALUE eQfsError;

static VALUE cQfsBaseClient;
static VALUE eQfsENOENTError;

/* qfs_client */

static void qfs_client_deallocate(void *qfsvp) {
	TRACE;
	struct qfs_client *qfs = qfsvp;
	if (qfs->qfs) {
		qfs_release(qfs->qfs);
		qfs->qfs = NULL;
	}
	free(qfs);
	TRACE_R;
}

static VALUE qfs_client_allocate(VALUE klass) {
	struct qfs_client *qfs = malloc(sizeof(struct qfs_client));
	qfs->qfs = NULL;
	return Data_Wrap_Struct(klass, NULL, qfs_client_deallocate, qfs);
}

/* qfs_connect wrapper. Raises Qfs::Error on error */
static VALUE qfs_client_connect(VALUE self, VALUE host, VALUE port) {
	struct qfs_client *qfs;
	Check_Type(host, T_STRING);
	Check_Type(port, T_FIXNUM);
	Data_Get_Struct(self, struct qfs_client, qfs);
	qfs->qfs = qfs_connect(StringValueCStr(host), FIX2INT(port));
	if (!qfs->qfs) {
		rb_raise(eQfsError, "connection failed");
	}
	return Qnil;
}

/* qfs_release wrapper */
static VALUE qfs_client_release(VALUE self) {
	TRACE;
	struct qfs_client *qfs;
	Data_Get_Struct(self, struct qfs_client, qfs);
	if (!qfs->qfs) {
		qfs_release(qfs->qfs);
	}
	qfs->qfs = NULL;
	TRACE_R;
	return Qnil;
}

static VALUE qfs_client_open(int argc, VALUE *argv, VALUE self) {
	struct qfs_client *client;
	VALUE path;
	VALUE oflag;
	VALUE mode;
	VALUE params;
	rb_scan_args(argc, argv, "13", &path, &oflag, &mode, &params);
	Check_Type(path, T_STRING);
	int ioflag;
	uint16_t imode;
	char *sparams;
	if (oflag == Qnil) {
		ioflag = O_RDONLY;
	} else {
		Check_Type(oflag, T_FIXNUM);
		ioflag = FIX2INT(oflag);
	}
	if (mode == Qnil) {
		imode = 0666;
	} else {
		Check_Type(mode, T_FIXNUM);
		imode = (uint16_t)FIX2INT(mode);
	}
	if ((params = Qnil)) {
		sparams = NULL;
	} else {
		Check_Type(params, T_STRING);
		sparams = StringValueCStr(params);
	}

	Data_Get_Struct(self, struct qfs_client, client);
	int fd = qfs_open_file(client->qfs, StringValueCStr(path), ioflag, imode, sparams);
	QFS_CHECK_ERR(fd);
	struct qfs_file *file = ALLOC(struct qfs_file);
	file->client = self;
	file->fd = fd;
	return Data_Wrap_Struct(cQfsFile, qfs_file_mark, qfs_file_deallocate, file);
}

static VALUE qfs_client_readdir(VALUE self, VALUE path) {
	int left;
	int count = 0;
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);
	struct qfs_iter *iter = NULL;
	struct qfs_attr attr;
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	while ((left = qfs_readdir(client->qfs, p, &iter, &attr)) > 0) {
		struct qfs_attr *tmp_attr = ALLOC(struct qfs_attr);
		memcpy(tmp_attr, &attr, sizeof(attr));
		count += 1;
		rb_yield(Data_Wrap_Struct(cQfsAttr, NULL, free, tmp_attr));
	}
	qfs_iter_free(&iter);
	QFS_CHECK_ERR(left);
	return INT2FIX(count);
}

static VALUE qfs_client_path_checking(VALUE self, VALUE path,
		bool (*check_func)(struct QFS*, const char*)) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	bool exists = (*check_func)(client->qfs, p);
	return INT2BOOL(exists);
}

static VALUE qfs_client_exists(VALUE self, VALUE path) {
	return qfs_client_path_checking(self, path, qfs_exists);
}

static VALUE qfs_client_isfile(VALUE self, VALUE path) {
	return qfs_client_path_checking(self, path, qfs_isfile);
}

static VALUE qfs_client_isdirectory(VALUE self, VALUE path) {
	return qfs_client_path_checking(self, path, qfs_isdirectory);
}

static VALUE qfs_client_remove(VALUE self, VALUE path) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);

	// Check that the file is regular
	VALUE isfile = qfs_client_isfile(self, path);
	if (!RTEST(isfile)) {
		rb_raise(eQfsError, "Can't remove %s. It isnt a regular file",
			p);
	}

	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	int res = qfs_remove(client->qfs, p);

	// Raise an exception if the file didn't exist
	if (res == -2) {
		rb_raise(eQfsENOENTError, "Can't remove %s.  It doesn't exist",
			p);
	}

	QFS_CHECK_ERR(res);
	return INT2NUM(1);
}

static VALUE qfs_client_mkdir_base(VALUE self, VALUE path, VALUE mode,
		int (*mkdir_func)(struct QFS*, const char*, mode_t)) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);

	// check if the directory already exists
	if (RTEST(qfs_client_exists(self, path))) {
		rb_raise(eQfsError, "Can't create directory %s. It already exists",
				p);
	}

	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	Check_Type(mode, T_FIXNUM);
	uint16_t imode = (uint16_t)FIX2INT(mode);
	int res = (*mkdir_func)(client->qfs, p, imode);
	QFS_CHECK_ERR(res);
	return RES2BOOL(res);
}

static VALUE qfs_client_mkdir(VALUE self, VALUE path, VALUE mode) {
	return qfs_client_mkdir_base(self, path, mode, qfs_mkdir);
}

static VALUE qfs_client_mkdir_p(VALUE self, VALUE path, VALUE mode) {
	return qfs_client_mkdir_base(self, path, mode, qfs_mkdirs);
}

static VALUE qfs_client_rmdir_base(VALUE self, VALUE path,
		int (*rmdir_func)(struct QFS*, const char*)) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);

	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	int res = (*rmdir_func)(client->qfs, p);

	// Raise an exception if the file didn't exist
	if (res == -2) {
		rb_raise(eQfsENOENTError, "Can't remove %s.  It doesn't exist",
			p);
	}

	QFS_CHECK_ERR(res);
	return INT2NUM(res);
}

static VALUE qfs_client_rmdir(VALUE self, VALUE path) {
	return qfs_client_rmdir_base(self, path, qfs_rmdir);
}

static VALUE qfs_client_rmdirs(VALUE self, VALUE path) {
	return qfs_client_rmdir_base(self, path, qfs_rmdirs);
}

// Making multiple stat calls against the same file appears to return the
// same result, event if the properties change.  This can be reproduced by
// the permissions on a file, stat'ing it, setting the permissions to something
// else, and stat'ing it again.  This appears to be a property of the
// QFS C api.
static VALUE qfs_client_stat(VALUE self, VALUE path) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	struct qfs_attr *attr = ALLOC(struct qfs_attr);
	int res = qfs_stat(client->qfs, p, attr);
	QFS_CHECK_ERR(res);
	return Data_Wrap_Struct(cQfsAttr, NULL, free, attr);
}

static VALUE qfs_client_chmod_base(VALUE self, VALUE path, VALUE mode,
		int (*chmod_func)(struct QFS*, const char*, mode_t)) {
	Check_Type(path, T_STRING);
	Check_Type(mode, T_FIXNUM);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	char *p = StringValueCStr(path);
	uint16_t imode = (uint16_t)FIX2INT(mode);
	int res = (*chmod_func)(client->qfs, p, imode);
	QFS_CHECK_ERR(res);
	return RES2BOOL(res);
}

static VALUE qfs_client_chmod(VALUE self, VALUE path, VALUE mode) {
	return qfs_client_chmod_base(self, path, mode, qfs_chmod);
}

static VALUE qfs_client_chmod_r(VALUE self, VALUE path, VALUE mode) {
	return qfs_client_chmod_base(self, path, mode, qfs_chmod_r);
}

static VALUE qfs_client_rename(VALUE self, VALUE old, VALUE new) {
	Check_Type(old, T_STRING);
	Check_Type(new, T_STRING);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	char *old_s = StringValueCStr(old);
	char *new_s = StringValueCStr(new);
	int res = qfs_rename(client->qfs, old_s, new_s);
	QFS_CHECK_ERR(res);
	return RES2BOOL(res);
}

static VALUE qfs_set_attribute_revalidate_time(VALUE self, VALUE seconds) {
	Check_Type(seconds, T_FIXNUM);
	int secs = FIX2INT(seconds);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	qfs_set_fileattributerevalidatetime(client->qfs, secs);
	return Qnil;
}

static VALUE qfs_client_cd_base(VALUE self, VALUE path,
		int (*cd_func)(struct QFS*, const char*)) {
	Check_Type(path, T_STRING);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	char *p = StringValueCStr(path);
	int res = qfs_cd(client->qfs, p);
	QFS_CHECK_ERR(res);
	return Qnil;
}

static VALUE qfs_client_cd(VALUE self, VALUE path) {
	return qfs_client_cd_base(self, path, qfs_cd);
}

static VALUE qfs_client_setwd(VALUE self, VALUE path) {
	return qfs_client_cd_base(self, path, qfs_setwd);
}

static VALUE qfs_client_getwd(VALUE self, VALUE len) {
	Check_Type(len, T_FIXNUM);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	size_t n = (size_t)NUM2INT(len);
	VALUE str = rb_str_buf_new((long)n);
	int len_read = qfs_getwd(client->qfs, RSTRING_PTR(str), n);
	QFS_CHECK_ERR(len_read);
	if (len_read > (int)n) {
		rb_raise(eQfsError, "Failed to read the entire CWD. "
				"Path exceeded the inputted max length");
	}
	rb_str_set_len(str, len_read);
	return str;
}

void Init_qfs_ext() {
	mQfs = rb_define_module("Qfs");

	check_trace_enabled();

	cQfsBaseClient = rb_define_class_under(mQfs, "BaseClient", rb_cObject);
	rb_define_alloc_func(cQfsBaseClient, qfs_client_allocate);
	rb_define_method(cQfsBaseClient, "initialize", qfs_client_connect, 2);
	rb_define_method(cQfsBaseClient, "release", qfs_client_release, 0);
	rb_define_method(cQfsBaseClient, "open", qfs_client_open, -1);
	rb_define_method(cQfsBaseClient, "readdir", qfs_client_readdir, 1);
	rb_define_method(cQfsBaseClient, "exists", qfs_client_exists, 1);
	rb_define_method(cQfsBaseClient, "remove", qfs_client_remove, 1);
	rb_define_method(cQfsBaseClient, "isfile", qfs_client_isfile, 1);
	rb_define_method(cQfsBaseClient, "isdirectory", qfs_client_isdirectory, 1);
	rb_define_method(cQfsBaseClient, "mkdir", qfs_client_mkdir, 2);
	rb_define_method(cQfsBaseClient, "mkdir_p", qfs_client_mkdir_p, 2);
	rb_define_method(cQfsBaseClient, "rmdir", qfs_client_rmdir, 1);
	rb_define_method(cQfsBaseClient, "rmdirs", qfs_client_rmdirs, 1);
	rb_define_method(cQfsBaseClient, "stat", qfs_client_stat, 1);
	rb_define_method(cQfsBaseClient, "chmod", qfs_client_chmod, 2);
	rb_define_method(cQfsBaseClient, "rename", qfs_client_rename, 2);
	rb_define_method(cQfsBaseClient, "cd", qfs_client_cd, 1);
	rb_define_method(cQfsBaseClient, "setwd", qfs_client_setwd, 1);
	rb_define_method(cQfsBaseClient, "getwd", qfs_client_getwd, 1);
	rb_define_private_method(cQfsBaseClient, "chmod_r", qfs_client_chmod_r, 2);
	rb_define_private_method(cQfsBaseClient, "set_attribute_revalidate_time",
			qfs_set_attribute_revalidate_time, 1);

	init_qfs_ext_file();
	init_qfs_ext_attr();

	eQfsError = rb_define_class_under(mQfs, "Error", rb_eStandardError);
	eQfsENOENTError = rb_define_class_under(mQfs, "ENOENT", rb_eStandardError);
}

#include <qfs.h>

int trace = 0;

VALUE mQfs;
VALUE eQfsError;
VALUE cQfsFile;
VALUE cQfsAttr;
VALUE cQfsBaseClient;

#define QFS_NIL_FD -1

#define TRACE do { if (trace) fprintf(stderr, "TRACE: %s start\n", __func__); } while(0)
#define TRACE_R do { if (trace) fprintf(stderr, "TRACE: %s end\n", __func__); } while(0)
#define WARN(s) do { fprintf(stderr, "WARN: %s\n", s); } while(0)

#define QFS_CHECK_ERR(i) do { if (i < 0) { char buf[512]; rb_raise(eQfsError, "%s", qfs_strerror((int)i, buf, 1024)); TRACE_R; return Qnil; } } while (0)

struct qfs_client {
	struct QFS *qfs;
};

struct qfs_file {
	VALUE client;
	int fd;
};

/* qfs_attr
 * This is just a dirent. */

#define QFS_ATTR_GET(f, t) static VALUE qfs_attr_##f(VALUE self) { \
	struct qfs_attr *attr; \
	Data_Get_Struct(self, struct qfs_attr, attr); \
	return t(attr->f); \
}

#define NTIME(x) rb_time_new(x.tv_sec, x.tv_usec)
#define INT2BOOL(x) (x?Qtrue:Qfalse)

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

/* qfs_file
 * This is a handle to a fd that can perform IO. */

static VALUE qfs_file_read(VALUE self, VALUE len) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(len, T_FIXNUM);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	size_t n = NUM2INT(len);
	VALUE s = rb_str_buf_new(n);
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

static VALUE qfs_file_write(VALUE self, VALUE str) {
	struct qfs_file *file;
	struct qfs_client *client;
	Check_Type(str, T_STRING);
	Data_Get_Struct(self, struct qfs_file, file);
	Data_Get_Struct(file->client, struct qfs_client, client);
	ssize_t n = qfs_write(client->qfs, file->fd, RSTRING_PTR(str),
			RSTRING_LEN(str));
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

static void qfs_file_deallocate(void * filevp) {
	TRACE;
	/* the client might be deallocated already, so don't try to close ourselves */
	free(filevp);
	TRACE_R;
}

static void qfs_file_mark(void * filevp) {
	struct qfs_file *file = filevp;
	if (file->client) {
		rb_gc_mark(file->client);
	}
}

static VALUE qfs_file_allocate(VALUE klass) {
	struct qfs_file * file = malloc(sizeof(struct qfs_file));
	file->client = Qnil;
	file->fd = QFS_NIL_FD;
	return Data_Wrap_Struct(klass, qfs_file_mark, qfs_file_deallocate, file);
}

/* qfs_client */

static void qfs_client_deallocate(void * qfsvp) {
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
	struct qfs_client * qfs = malloc(sizeof(struct qfs_client));
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
	char * sparams;
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
		imode = FIX2INT(mode);
	}
	if (params = Qnil) {
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
	char * p = StringValueCStr(path);
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
	// TODO: make this exception safe
	qfs_iter_free(&iter);
	QFS_CHECK_ERR(left);
	return INT2FIX(count);
}

static VALUE qfs_client_exists(VALUE self, VALUE path) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	bool exists = qfs_exists(client->qfs, p);
	return INT2BOOL(exists);
}

static VALUE qfs_client_isfile(VALUE self, VALUE path) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);
	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	bool isfile = qfs_isfile(client->qfs, p);
	return INT2BOOL(isfile);
}

static VALUE qfs_client_remove(VALUE self, VALUE path) {
	Check_Type(path, T_STRING);
	char *p = StringValueCStr(path);

	// Check that the file exists
	VALUE exists = qfs_client_exists(self, path);
	if (!RTEST(exists)) {
		rb_raise(eQfsError, "Can't remove %s.  It doesnt exist",
			p);
	}

	// Check that the file is regular
	VALUE isfile = qfs_client_isfile(self, path);
	if (!RTEST(isfile)) {
		rb_raise(eQfsError, "Can't remove %s. It isnt a regular file",
			p);
	}

	struct qfs_client *client;
	Data_Get_Struct(self, struct qfs_client, client);
	int res = qfs_remove(client->qfs, p);
	QFS_CHECK_ERR(res);
	return INT2NUM(1);
}

void Init_qfs() {
	mQfs = rb_define_module("Qfs");

	if (getenv("RUBY_QFS_TRACE")) {
		trace = 1;
	}

	cQfsBaseClient = rb_define_class_under(mQfs, "BaseClient", rb_cObject);
	rb_define_alloc_func(cQfsBaseClient, qfs_client_allocate);
	rb_define_method(cQfsBaseClient, "initialize", qfs_client_connect, 2);
	rb_define_method(cQfsBaseClient, "release", qfs_client_release, 0);
	rb_define_method(cQfsBaseClient, "open", qfs_client_open, -1);
	rb_define_method(cQfsBaseClient, "readdir", qfs_client_readdir, 1);
	rb_define_method(cQfsBaseClient, "exists", qfs_client_exists, 1);
	rb_define_method(cQfsBaseClient, "remove", qfs_client_remove, 1);
	rb_define_method(cQfsBaseClient, "isfile", qfs_client_isfile, 1);

	cQfsFile = rb_define_class_under(mQfs, "File", rb_cObject);
	rb_define_alloc_func(cQfsFile, qfs_file_allocate);
	rb_define_method(cQfsFile, "read", qfs_file_read, 1);
	rb_define_method(cQfsFile, "tell", qfs_file_tell, 0);
	rb_define_method(cQfsFile, "write", qfs_file_write, 1);
	rb_define_method(cQfsFile, "close", qfs_file_close, 0);

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

	eQfsError = rb_define_class_under(mQfs, "Error", rb_eStandardError);
}

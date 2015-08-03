#ifndef QFS_EXT_UTIL_H_
#define QFS_EXT_UTIL_H_

#define QFS_NIL_FD -1

#include <ruby.h>

static int QFS_TRACE_ENABLED = 0;
static inline void check_trace_enabled() {
	if (getenv("RUBY_QFS_TRACE")) {
		QFS_TRACE_ENABLED = 1;
	}
}

#define TRACE do { if (QFS_TRACE_ENABLED) fprintf(stderr, "TRACE: %s start\n", __func__); } while(0)
#define TRACE_R do { if (QFS_TRACE_ENABLED) fprintf(stderr, "TRACE: %s end\n", __func__); } while(0)
#define WARN(s) do { fprintf(stderr, "WARN: %s\n", s); } while(0)

#define QFS_CHECK_ERR(i) do { if (i < 0) { char buf[512]; rb_raise(eQfsError, "%s", qfs_strerror((int)i, buf, 1024)); TRACE_R; return Qnil; } } while (0)

#define NTIME(x) rb_time_new(x.tv_sec, x.tv_usec)
#define INT2BOOL(x) (x?Qtrue:Qfalse)
#define RES2BOOL(x) (x>=0 ? Qtrue : Qfalse)

#endif // QFS_EXT_UTIL_H_

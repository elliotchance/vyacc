module main

struct CharPtr {
mut:
	pos int
	value []u8
	is_null bool
}

fn null_char_ptr() CharPtr {
	return CharPtr{0, []u8{}, true}
}

fn char_ptr(value string) CharPtr {
	mut buf := value.bytes()
	buf << 0
	return CharPtr{0, buf, false}
}

fn char_ptr_malloc(size int) CharPtr {
	return CharPtr{0, []u8{len: size}, false}
}

fn (mut p CharPtr) inc() CharPtr {
	p.pos++
	return p
}

fn (p CharPtr) add(len int) CharPtr {
	return CharPtr{p.pos+len, p.value, false}
}

fn (p CharPtr) subtract(len int) CharPtr {
	return CharPtr{p.pos-len, p.value, false}
}

fn (p CharPtr) add_ptr(p2 CharPtr) int {
	return p.pos + p2.pos
}

fn (p CharPtr) subtract_ptr(p2 CharPtr) int {
	return p.pos - p2.pos
}

fn (p CharPtr) less_than(p2 CharPtr) bool {
	return p.pos < p2.pos
}

fn (p CharPtr) at(index int) u8 {
	return p.value[p.pos+index]
}

fn (p CharPtr) deref() u8 {
	return p.at(0)
}

fn (p CharPtr) str() string {
	return p.value[p.pos..].bytestr()
}

fn (mut p CharPtr) set(index int, c u8) u8 {
	p.value[p.pos+index] = c
	return c
}

fn (mut p CharPtr) realloc(size int) CharPtr {
	mut buf := []u8{len: size}
	copy(mut buf, p.value)
	return CharPtr{0, buf, false}
}

fn (mut p CharPtr) free() {
	p.pos = 0
	p.value = []u8{}
	p.is_null = true
}

// FILE *fopen(const char *file_name, const char *mode_of_operation)
// fn fopen(file_name string, mode_of_operation string) ?os.File {
// 	return os.open_file(file_name, mode_of_operation) or {
// 		return none
// 	}
// }

// int fprintf(FILE *stream, const char *format, ...)
// fn fprintf(stream os.File, format string, ...) int {
// 	return 0
// }

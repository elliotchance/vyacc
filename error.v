module main

/*
void
open_error(char *filename)
{
	fprintf(stderr, "%s: cannot open source file %s: %s\n",
	    input_file_name, filename, strerror(errno));
	exit(2);
}
*/

fn (mut y YACC) open_error(filename string, err IError) ! {
	y.stderr.write_string('${y.input_file_name}: cannot open source file ${filename}: ${err}\n')!
	exit(2)
}

/*
void
open_write_error(char *filename)
{
	fprintf(stderr, "%s: cannot open target file %s for writing: %s\n",
	    input_file_name, filename, strerror(errno));
	exit(2);
}
*/

fn (mut y YACC) open_write_error(filename string, err IError) ! {
	y.stderr.write_string('${y.input_file_name}: cannot open target file ${filename} for writing: ${err}\n')!
	exit(2)
}

/*
void
tempfile_error(void)
{
	fprintf(stderr, "%s: cannot create temporary file: %s\n",
	    input_file_name, strerror(errno));
	exit(2);
}
*/

fn (mut y YACC) tempfile_error(err IError) ! {
	y.stderr.write_string('${y.input_file_name}: cannot create temporary file: ${err}\n')!
	exit(2)
}

/*
void
unterminated_comment(int c_lineno, char *c_line, char *c_cptr)
{
	fprintf(stderr, "%s:%d: unmatched / *\n",
	    input_file_name, c_lineno);
	print_pos(c_line, c_cptr);
	exit(1);
}
*/

fn (mut y YACC) unterminated_comment(c_lineno int, c_line CharPtr, c_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${c_lineno}: unmatched /*\n')!
	y.print_pos(c_line, c_cptr)
	exit(1)
}

/*
void
print_pos(char *st_line, char *st_cptr)
{
	char *s;

	if (st_line == 0)
		return;
	for (s = st_line; *s != '\n'; ++s) {
		if (isprint((unsigned char)*s) || *s == '\t')
			putc(*s, stderr);
		else
			putc('?', stderr);
	}
	putc('\n', stderr);
	for (s = st_line; s < st_cptr; ++s) {
		if (*s == '\t')
			putc('\t', stderr);
		else
			putc(' ', stderr);
	}
	putc('^', stderr);
	putc('\n', stderr);
}
*/

fn (mut y YACC) print_pos(st_line CharPtr, st_cptr CharPtr) {
	mut s := null_char_ptr()

	if st_line.is_null {
		return
	}

	s = st_line
	for (s.deref() != `\n`) {
		if isprint(s.deref()) || s.deref() == `\t` {
			putc(s.deref(), mut y.stderr)
		} else {
			putc(`?`, mut y.stderr)
		}
		s.inc()
	}

	putc(`\n`, mut y.stderr)
	s = st_line
	for (s.less_than(st_cptr)) {
		if s.deref() == `\t` {
			putc(`\t`, mut y.stderr)
		} else {
			putc(` `, mut y.stderr)
		}
		s.inc()
	}
	putc(`^`, mut y.stderr)
	putc(`\n`, mut y.stderr)
}

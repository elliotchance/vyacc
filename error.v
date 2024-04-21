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

/*
void
syntax_error(int st_lineno, char *st_line, char *st_cptr)
{
	fprintf(stderr, "%s:%d: syntax error\n",
	    input_file_name, st_lineno);
	print_pos(st_line, st_cptr);
	exit(1);
}
*/

fn (mut y YACC) syntax_error(st_lineno int, st_line CharPtr, st_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${st_lineno}: syntax error\n')!
	y.print_pos(st_line, st_cptr)
	exit(1)
}

/*
void
unexpected_EOF(void)
{
	fprintf(stderr, "%s:%d: unexpected end-of-file\n",
	    input_file_name, lineno);
	exit(1);
}
*/

fn (mut y YACC) unexpected_eof() ! {
	y.stderr.write_string('${y.input_file_name}:${y.lineno}: unexpected end-of-file\n')!
	exit(1)
}

/*
void
unterminated_text(int t_lineno, char *t_line, char *t_cptr)
{
	fprintf(stderr, "%s:%d: unmatched %%{\n",
	    input_file_name, t_lineno);
	print_pos(t_line, t_cptr);
	exit(1);
}
*/

fn (mut y YACC) unterminated_text(t_lineno int, t_line CharPtr, t_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${t_lineno}: unmatched %%{\n')!
	y.print_pos(t_line, t_cptr)
	exit(1)
}

/*
void
unterminated_string(int s_lineno, char *s_line, char *s_cptr)
{
	fprintf(stderr, "%s:%d:, unterminated string\n",
	    input_file_name, s_lineno);
	print_pos(s_line, s_cptr);
	exit(1);
}
*/

fn (mut y YACC) unterminated_string(s_lineno int, s_line CharPtr, s_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${s_lineno}:, unterminated string\n')!
	y.print_pos(s_line, s_cptr)
	exit(1)
}

/*
void
over_unionized(char *u_cptr)
{
	fprintf(stderr, "%s:%d: too many %%union declarations\n",
	    input_file_name, lineno);
	print_pos(line, u_cptr);
	exit(1);
}
*/

fn (mut y YACC) over_unionized(u_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${y.lineno}: too many %%union declarations\n')!
	y.print_pos(y.line, u_cptr)
	exit(1)
}

/*
void
unterminated_union(int u_lineno, char *u_line, char *u_cptr)
{
	fprintf(stderr, "%s:%d: unterminated %%union declaration\n",
	    input_file_name, u_lineno);
	print_pos(u_line, u_cptr);
	exit(1);
}
*/

fn (mut y YACC) unterminated_union(u_lineno int, u_line CharPtr, u_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${u_lineno}: unterminated %%union declaration\n')!
	y.print_pos(u_line, u_cptr)
	exit(1)
}

/*
void
illegal_character(char *c_cptr)
{
	fprintf(stderr, "%s:%d: illegal character\n",
	    input_file_name, lineno);
	print_pos(line, c_cptr);
	exit(1);
}
*/

fn (mut y YACC) illegal_character(c_cptr CharPtr) ! {
	y.stderr.write_string('${y.input_file_name}:${y.lineno}: illegal character\n')!
	y.print_pos(y.line, c_cptr)
	exit(1)
}

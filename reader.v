module main

import strconv

// The line size must be a positive integer.  One hundred was chosen	
// because few lines in Yacc input grammars exceed 100 characters.	
// Note that if a line exceeds LINESIZE characters, the line buffer	
// will be expanded to accommodate it.					
const linesize = 100

const line_format = '#line %d "%s"\n'

/*
void
cachec(int c)
{
	assert(cinc >= 0);
	if (cinc >= cache_size) {
		cache_size += 256;
		cache = realloc(cache, cache_size);
		if (cache == NULL)
			no_space();
	}
	cache[cinc] = c;
	++cinc;
}
*/

fn (mut y YACC) cachec(c u8) {
	y.cache += '${c}'
}

/*
void
get_line(void)
{
	FILE *f = input_file;
	int c, i;

	if (saw_eof || (c = getc(f)) == EOF) {
		if (line) {
			free(line);
			line = 0;
		}
		cptr = 0;
		saw_eof = 1;
		return;
	}
	if (line == NULL || linesize != (LINESIZE + 1)) {
		free(line);
		linesize = LINESIZE + 1;
		line = malloc(linesize);
		if (line == NULL)
			no_space();
	}
	i = 0;
	++lineno;
	for (;;) {
		line[i] = c;
		if (c == '\n') {
			cptr = line;
			return;
		}
		if (++i >= linesize) {
			linesize += LINESIZE;
			line = realloc(line, linesize);
			if (line == NULL)
				no_space();
		}
		c = getc(f);
		if (c == EOF) {
			line[i] = '\n';
			saw_eof = 1;
			cptr = line;
			return;
		}
	}
}
*/

fn (mut y YACC) get_line() ! {
	mut f := y.input_file
	mut c := u8(0)
	mut i := 0

	if y.saw_eof || f.eof() {
		if !y.line.is_null {
			y.line.free()
		}
		y.cptr.free()
		y.saw_eof = true
		return
	}

	if y.line.is_null || y.linesize != (linesize + 1) {
		y.line.free()
		y.linesize = linesize + 1
		y.line = char_ptr_malloc(linesize)
	}
	i = 0
	y.lineno++
	for (true) {
		y.line.set(i, c)
		if c == `\n` {
			y.cptr = y.line
		}
		i++
		if i >= linesize {
			y.linesize += linesize
			y.line.realloc(linesize)
		}
		c = getc(mut f)
		if f.eof() {
			y.line.set(i, `\n`)
			y.saw_eof = true
			y.cptr = y.line
			return
		}
	}
}

/*
char *
dup_line(void)
{
	char *p, *s, *t;

	if (line == NULL)
		return (0);
	s = line;
	while (*s != '\n')
		++s;
	p = malloc(s - line + 1);
	if (p == NULL)
		no_space();

	s = line;
	t = p;
	while ((*t++ = *s++) != '\n')
		continue;
	return (p);
}
*/

fn (mut y YACC) dup_line() CharPtr {
	mut p := null_char_ptr()
	mut s := null_char_ptr()
	mut t := null_char_ptr()

	if y.line.is_null {
		return null_char_ptr()
	}

	s = y.line
	for (s.at(0) != `\n`) {
		s.inc()
	}
	p = char_ptr_malloc(s.subtract_ptr(y.line) + 1)
	s = y.line
	t = p
	for (t.set(0, s.at(0)) != `\n`) {
		t.inc()
		s.inc()
	}
	t.inc()
	s.inc()

	return p
}

/*
void
skip_comment(void)
{
	char *s;
	int st_lineno = lineno;
	char *st_line = dup_line();
	char *st_cptr = st_line + (cptr - line);

	s = cptr + 2;
	for (;;) {
		if (*s == '*' && s[1] == '/') {
			cptr = s + 2;
			free(st_line);
			return;
		}
		if (*s == '\n') {
			get_line();
			if (line == NULL)
				unterminated_comment(st_lineno, st_line, st_cptr);
			s = cptr;
		} else
			++s;
	}
}
*/

fn (mut y YACC) skip_comment() ! {
	st_lineno := y.lineno
	mut st_line := y.dup_line()
	mut st_cptr := st_line.add(y.cptr.subtract_ptr(y.line))
	mut s := y.cptr.add(2)
	for (true) {
		if s.deref() == `*` && s.at(1) == `/` {
			y.cptr = s.add(2)
			st_line.free()
			return
		}
		if s.deref() == `\n` {
			y.get_line()!
			if y.line.is_null {
				y.unterminated_comment(st_lineno, st_line, st_cptr)!
			}
			s = y.cptr
		} else {
			s.inc()
		}
	}
}

/*
int
nextc(void)
{
	char *s;

	if (line == NULL) {
		get_line();
		if (line == NULL)
			return (EOF);
	}
	s = cptr;
	for (;;) {
		switch (*s) {
		case '\n':
			get_line();
			if (line == NULL)
				return (EOF);
			s = cptr;
			break;

		case ' ':
		case '\t':
		case '\f':
		case '\r':
		case '\v':
		case ',':
		case ';':
			++s;
			break;

		case '\\':
			cptr = s;
			return ('%');

		case '/':
			if (s[1] == '*') {
				cptr = s;
				skip_comment();
				s = cptr;
				break;
			} else if (s[1] == '/') {
				get_line();
				if (line == NULL)
					return (EOF);
				s = cptr;
				break;
			}
			/* fall through */

		default:
			cptr = s;
			return ((unsigned char) *s);
		}
	}
}
*/

fn (mut y YACC) nextc() !u8 {
	if y.line.is_null {
		y.get_line()!
		if y.line.is_null {
			return eof
		}
	}

	mut s := y.cptr
	for (true) {
		match s.deref() {
			`\n` {
				y.get_line()!
				if y.line.is_null {
					return eof
				}
				s = y.cptr
			}
			` `, `\t`, `\f`, `\r`, `\v`, `,`, `;` {
				s.inc()
			}
			`\\` {
				y.cptr = s
				return u8(`%`)
			}
			`/` {
				if s.at(1) == `*` {
					y.cptr = s
					y.skip_comment()!
					s = y.cptr
				} else if s.at(1) == `/` {
					y.get_line()!
					if y.line.is_null {
						return eof
					}
					s = y.cptr
				}

				y.cptr = s
				return s.deref()
			}
			else {}
		}
	}

	y.cptr = s
	return s.deref()
}

/*
int
keyword(void)
{
	int c;
	char *t_cptr = cptr;

	c = (unsigned char) *++cptr;
	if (isalpha(c)) {
		cinc = 0;
		for (;;) {
			if (isalpha(c)) {
				if (isupper(c))
					c = tolower(c);
				cachec(c);
			} else if (isdigit(c) || c == '_' || c == '.' || c == '$')
				cachec(c);
			else
				break;
			c = (unsigned char) *++cptr;
		}
		cachec(NUL);

		if (strcmp(cache, "token") == 0 || strcmp(cache, "term") == 0)
			return (TOKEN);
		if (strcmp(cache, "type") == 0)
			return (TYPE);
		if (strcmp(cache, "left") == 0)
			return (LEFT);
		if (strcmp(cache, "right") == 0)
			return (RIGHT);
		if (strcmp(cache, "nonassoc") == 0 || strcmp(cache, "binary") == 0)
			return (NONASSOC);
		if (strcmp(cache, "start") == 0)
			return (START);
		if (strcmp(cache, "union") == 0)
			return (UNION);
		if (strcmp(cache, "ident") == 0)
			return (IDENT);
		if (strcmp(cache, "expect") == 0)
			return (EXPECT);
	} else {
		++cptr;
		if (c == '{')
			return (TEXT);
		if (c == '%' || c == '\\')
			return (MARK);
		if (c == '<')
			return (LEFT);
		if (c == '>')
			return (RIGHT);
		if (c == '0')
			return (TOKEN);
		if (c == '2')
			return (NONASSOC);
	}
	syntax_error(lineno, line, t_cptr);
	/* NOTREACHED */
	return (0);
}
*/

fn (mut y YACC) keyword() !int {
	t_cptr := y.cptr

	y.cptr.inc()
	mut c := y.cptr.deref()
	if isalpha(c) {
		y.cache = ''
		for (true) {
			if isalpha(c) {
				if isupper(c) {
					c = tolower(c)
				}
				y.cachec(c)
			} else if isdigit(c) || c == `_` || c == `.` || c == `$` {
				y.cachec(c)
			} else {
				break
			}
			y.cptr.inc()
			c = y.cptr.deref()
		}
		y.cachec(0)

		if y.cache == 'token' || y.cache == 'term' {
			return k_token
		}
		if y.cache == 'type' {
			return k_type
		}
		if y.cache == 'left' {
			return k_left
		}
		if y.cache == 'right' {
			return k_right
		}
		if y.cache == 'nonassoc' || y.cache == 'binary' {
			return k_nonassoc
		}
		if y.cache == 'start' {
			return k_start
		}
		if y.cache == 'union' {
			return k_union
		}
		if y.cache == 'ident' {
			return k_ident
		}
		if y.cache == 'expect' {
			return k_expect
		}
	} else {
		y.cptr.inc()
		if c == `{` {
			return k_text
		}
		if c == `%` || c == `\\` {
			return k_mark
		}
		if c == `<` {
			return k_left
		}
		if c == `>` {
			return k_right
		}
		if c == `0` {
			return k_token
		}
		if c == `2` {
			return k_nonassoc
		}
	}
	y.syntax_error(y.lineno, y.line, t_cptr)!
	// NOTREACHED
	return 0
}

/*
void
copy_ident(void)
{
	int c;
	FILE *f = output_file;

	c = nextc();
	if (c == EOF)
		unexpected_EOF();
	if (c != '"')
		syntax_error(lineno, line, cptr);
	++outline;
	fprintf(f, "#ident \"");
	for (;;) {
		c = (unsigned char) *++cptr;
		if (c == '\n') {
			fprintf(f, "\"\n");
			return;
		}
		putc(c, f);
		if (c == '"') {
			putc('\n', f);
			++cptr;
			return;
		}
	}
}
*/

fn (mut y YACC) copy_ident() ! {
	mut f := y.output_file

	mut c := y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}

	if c != `"` {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}

	y.outline++
	f.write_string('#ident "')!
	for (true) {
		y.cptr.inc()
		c = y.cptr.deref()
		if c == `\n` {
			f.write_string('"\n')!
			return
		}
		putc(c, mut f)
		if c == `"` {
			putc(`\n`, mut f)
			y.cptr.inc()
			return
		}
	}
}

/*
void
copy_text(void)
{
	int c;
	int quote;
	FILE *f = text_file;
	int need_newline = 0;
	int t_lineno = lineno;
	char *t_line = dup_line();
	char *t_cptr = t_line + (cptr - line - 2);

	if (*cptr == '\n') {
		get_line();
		if (line == NULL)
			unterminated_text(t_lineno, t_line, t_cptr);
	}
	if (!lflag)
		fprintf(f, line_format, lineno, input_file_name);

loop:
	c = (unsigned char) *cptr++;
	switch (c) {
	case '\n':
next_line:
		putc('\n', f);
		need_newline = 0;
		get_line();
		if (line)
			goto loop;
		unterminated_text(t_lineno, t_line, t_cptr);

	case '\'':
	case '"': {
		int s_lineno = lineno;
		char *s_line = dup_line();
		char *s_cptr = s_line + (cptr - line - 1);

		quote = c;
		putc(c, f);
		for (;;) {
			c = (unsigned char) *cptr++;
			putc(c, f);
			if (c == quote) {
				need_newline = 1;
				free(s_line);
				goto loop;
			}
			if (c == '\n')
				unterminated_string(s_lineno, s_line, s_cptr);
			if (c == '\\') {
				c = (unsigned char) *cptr++;
				putc(c, f);
				if (c == '\n') {
					get_line();
					if (line == NULL)
						unterminated_string(s_lineno, s_line, s_cptr);
				}
			}
		}
	}

	case '/':
		putc(c, f);
		need_newline = 1;
		c = (unsigned char) *cptr;
		if (c == '/') {
			putc('*', f);
			while ((c = (unsigned char) *++cptr) != '\n') {
				if (c == '*' && cptr[1] == '/')
					fprintf(f, "* ");
				else
					putc(c, f);
			}
			fprintf(f, "* /");
			goto next_line;
		}
		if (c == '*') {
			int c_lineno = lineno;
			char *c_line = dup_line();
			char *c_cptr = c_line + (cptr - line - 1);

			putc('*', f);
			++cptr;
			for (;;) {
				c = (unsigned char) *cptr++;
				putc(c, f);
				if (c == '*' && *cptr == '/') {
					putc('/', f);
					++cptr;
					free(c_line);
					goto loop;
				}
				if (c == '\n') {
					get_line();
					if (line == NULL)
						unterminated_comment(c_lineno, c_line, c_cptr);
				}
			}
		}
		need_newline = 1;
		goto loop;

	case '%':
	case '\\':
		if (*cptr == '}') {
			if (need_newline)
				putc('\n', f);
			++cptr;
			free(t_line);
			return;
		}
		/* fall through */

	default:
		putc(c, f);
		need_newline = 1;
		goto loop;
	}
}
*/

fn (mut y YACC) copy_text() ! {
	mut quote := u8(0)
	mut f := y.text_file
	mut need_newline := false
	t_lineno := y.lineno
	mut t_line := y.dup_line()
	t_cptr := t_line.add(y.cptr.subtract_ptr(y.line) - 2)

	if y.cptr.deref() == `\n` {
		y.get_line()!
		if y.line.is_null {
			y.unterminated_text(t_lineno, t_line, t_cptr)!
		}
	}
	if !y.lflag {
		f.write_string(unsafe { strconv.v_sprintf(line_format, y.lineno, y.input_file_name) })!
	}

	loop:
	mut c := y.cptr.deref()
	y.cptr.inc()
	match c {
		`\n` {
			next_line:
			putc(`\n`, mut f)
			need_newline = false
			y.get_line()!
			if !y.line.is_null {
				unsafe {
					goto loop
				}
			}
			y.unterminated_text(t_lineno, t_line, t_cptr)!
		}
		`'`, `"` {
			s_lineno := y.lineno
			mut s_line := y.dup_line()
			s_cptr := s_line.add(y.cptr.subtract_ptr(y.line) - 1)

			quote = c
			putc(c, mut f)
			for (true) {
				c = y.cptr.deref()
				y.cptr.inc()
				putc(c, mut f)
				if c == quote {
					need_newline = true
					s_line.free()
					unsafe {
						goto loop
					}
				}
				if c == `\n` {
					y.unterminated_string(s_lineno, s_line, s_cptr)!
				}
				if c == `\\` {
					c = y.cptr.deref()
					y.cptr.inc()
					putc(c, mut f)
					if c == `\n` {
						y.get_line()!
						if y.line.is_null {
							y.unterminated_string(s_lineno, s_line, s_cptr)!
						}
					}
				}
			}
		}
		`/` {
			putc(c, mut f)
			need_newline = true
			c = y.cptr.deref()
			if c == `/` {
				putc(`*`, mut f)
				for true {
					c = y.cptr.inc().deref()
					if c == `\n` {
						break
					}
					if c == `*` && y.cptr.at(1) == `/` {
						f.write_string('* ')!
					} else {
						putc(c, mut f)
					}
				}
				f.write_string('*/')!
				unsafe {
					goto next_line
				}
			}
			if c == `*` {
				c_lineno := y.lineno
				mut c_line := y.dup_line()
				c_cptr := c_line.add(y.cptr.subtract_ptr(y.line) - 1)

				putc(`*`, mut f)
				y.cptr.inc()
				for (true) {
					c = y.cptr.deref()
					y.cptr.inc()
					putc(c, mut f)
					if c == `*` && y.cptr.deref() == `/` {
						putc(`/`, mut f)
						y.cptr.inc()
						c_line.free()
						unsafe {
							goto loop
						}
					}
					if c == `\n` {
						y.get_line()!
						if y.line.is_null {
							y.unterminated_comment(c_lineno, c_line, c_cptr)!
						}
					}
				}
			}
			need_newline = true
			unsafe {
				goto loop
			}
		}
		`%`, `\\` {
			if y.cptr.deref() == `}` {
				if need_newline {
					putc(`\n`, mut f)
				}
				y.cptr.inc()
				t_line.free()
				return
			}
			putc(c, mut f)
			need_newline = true
			unsafe {
				goto loop
			}
		}
		else {
			putc(c, mut f)
			need_newline = true
			unsafe {
				goto loop
			}
		}
	}
}

/*
void
copy_union(void)
{
	int c, quote, depth;
	int u_lineno = lineno;
	char *u_line = dup_line();
	char *u_cptr = u_line + (cptr - line - 6);

	if (unionized)
		over_unionized(cptr - 6);
	unionized = 1;

	if (!lflag)
		fprintf(text_file, line_format, lineno, input_file_name);

	fprintf(text_file, "#ifndef YYSTYPE_DEFINED\n");
	fprintf(text_file, "#define YYSTYPE_DEFINED\n");
	fprintf(text_file, "typedef union");
	if (dflag) {
		fprintf(union_file, "#ifndef YYSTYPE_DEFINED\n");
		fprintf(union_file, "#define YYSTYPE_DEFINED\n");
		fprintf(union_file, "typedef union");
	}

	depth = 0;
loop:
	c = (unsigned char) *cptr++;
	putc(c, text_file);
	if (dflag)
		putc(c, union_file);
	switch (c) {
	case '\n':
next_line:
		get_line();
		if (line == NULL)
			unterminated_union(u_lineno, u_line, u_cptr);
		goto loop;

	case '{':
		++depth;
		goto loop;

	case '}':
		if (--depth == 0) {
			fprintf(text_file, " YYSTYPE;\n");
			fprintf(text_file, "#endif /* YYSTYPE_DEFINED */\n");
			free(u_line);
			return;
		}
		goto loop;

	case '\'':
	case '"': {
		int s_lineno = lineno;
		char *s_line = dup_line();
		char *s_cptr = s_line + (cptr - line - 1);

		quote = c;
		for (;;) {
			c = (unsigned char) *cptr++;
			putc(c, text_file);
			if (dflag)
				putc(c, union_file);
			if (c == quote) {
				free(s_line);
				goto loop;
			}
			if (c == '\n')
				unterminated_string(s_lineno, s_line, s_cptr);
			if (c == '\\') {
				c = (unsigned char) *cptr++;
				putc(c, text_file);
				if (dflag)
					putc(c, union_file);
				if (c == '\n') {
					get_line();
					if (line == NULL)
						unterminated_string(s_lineno,
						    s_line, s_cptr);
				}
			}
		}
	}

	case '/':
		c = (unsigned char) *cptr;
		if (c == '/') {
			putc('*', text_file);
			if (dflag)
				putc('*', union_file);
			while ((c = (unsigned char) *++cptr) != '\n') {
				if (c == '*' && cptr[1] == '/') {
					fprintf(text_file, "* ");
					if (dflag)
						fprintf(union_file, "* ");
				} else {
					putc(c, text_file);
					if (dflag)
						putc(c, union_file);
				}
			}
			fprintf(text_file, "* /\n");
			if (dflag)
				fprintf(union_file, "* /\n");
			goto next_line;
		}
		if (c == '*') {
			int c_lineno = lineno;
			char *c_line = dup_line();
			char *c_cptr = c_line + (cptr - line - 1);

			putc('*', text_file);
			if (dflag)
				putc('*', union_file);
			++cptr;
			for (;;) {
				c = (unsigned char) *cptr++;
				putc(c, text_file);
				if (dflag)
					putc(c, union_file);
				if (c == '*' && *cptr == '/') {
					putc('/', text_file);
					if (dflag)
						putc('/', union_file);
					++cptr;
					free(c_line);
					goto loop;
				}
				if (c == '\n') {
					get_line();
					if (line == NULL)
						unterminated_comment(c_lineno,
						    c_line, c_cptr);
				}
			}
		}
		goto loop;

	default:
		goto loop;
	}
}
*/

fn (mut y YACC) copy_union() ! {
	mut c := u8(0)
	mut quote := 0
	mut depth := 0
	mut u_lineno := y.lineno
	mut u_line := y.dup_line()
	mut u_cptr := u_line.add(y.cptr.subtract_ptr(y.line) - 6)

	if y.unionized {
		y.over_unionized(y.cptr.subtract(6))!
	}
	y.unionized = true

	if !y.lflag {
		y.text_file.write_string(unsafe { strconv.v_sprintf(line_format, y.lineno, y.input_file_name) })!
	}

	y.text_file.write_string('#ifndef YYSTYPE_DEFINED\n')!
	y.text_file.write_string('#define YYSTYPE_DEFINED\n')!
	y.text_file.write_string('typedef union')!
	if y.dflag {
		y.union_file.write_string('#ifndef YYSTYPE_DEFINED\n')!
		y.union_file.write_string('#define YYSTYPE_DEFINED\n')!
		y.union_file.write_string('typedef union')!
	}

	depth = 0
	loop:
	c = y.cptr.deref()
	y.cptr.inc()
	putc(c, mut y.text_file)
	if y.dflag {
		putc(c, mut y.union_file)
	}
	match c {
		`\n` {
			next_line:
			y.get_line()!
			if y.line.is_null {
				y.unterminated_union(u_lineno, u_line, u_cptr)!
			}
			unsafe {
				goto loop
			}
		}
		`{` {
			depth++
			unsafe {
				goto loop
			}
		}
		`}` {
			depth--
			if depth == 0 {
				y.text_file.write_string(' YYSTYPE;\n')!
				y.text_file.write_string('#endif /* YYSTYPE_DEFINED */\n')!
				u_line.free()
				return
			}
			unsafe {
				goto loop
			}
		}
		`'`, `"` {
			mut s_lineno := y.lineno
			mut s_line := y.dup_line()
			mut s_cptr := s_line.add(y.cptr.subtract_ptr(y.line) - 1)

			quote = c
			for (true) {
				c = y.cptr.deref()
				y.cptr.inc()
				putc(c, mut y.text_file)
				if y.dflag {
					putc(c, mut y.union_file)
				}
				if c == quote {
					s_line.free()
					unsafe {
						goto loop
					}
				}
				if c == `\n` {
					y.unterminated_string(s_lineno, s_line, s_cptr)!
				}
				if c == `\\` {
					c = y.cptr.deref()
					y.cptr.inc()
					putc(c, mut y.text_file)
					if y.dflag {
						putc(c, mut y.union_file)
					}
					if c == `\n` {
						y.get_line()!
						if y.line.is_null {
							y.unterminated_string(s_lineno, s_line, s_cptr)!
						}
					}
				}
			}
		}
		`/` {
			c = y.cptr.deref()
			if c == `/` {
				putc(`*`, mut y.text_file)
				if y.dflag {
					putc(`*`, mut y.union_file)
				}
				for true {
					y.cptr.inc()
					c = y.cptr.deref()
					if c == `\n` {
						break
					}

					if c == `*` && y.cptr.at(1) == `/` {
						y.text_file.write_string('* ')!
						if y.dflag {
							y.union_file.write_string('* ')!
						}
					} else {
						putc(c, mut y.text_file)
						if y.dflag {
							putc(c, mut y.union_file)
						}
					}
				}
				y.text_file.write_string('*/\n')!
				if y.dflag {
					y.union_file.write_string('*/\n')!
				}
				unsafe {
					goto next_line
				}
			}
			if c == `*` {
				mut c_lineno := y.lineno
				mut c_line := y.dup_line()
				mut c_cptr := c_line.add(y.cptr.subtract_ptr(y.line) - 1)

				putc(`*`, mut y.text_file)
				if y.dflag {
					putc(`*`, mut y.union_file)
				}
				y.cptr.inc()
				for (true) {
					c = y.cptr.deref()
					y.cptr.inc()
					putc(c, mut y.text_file)
					if y.dflag {
						putc(c, mut y.union_file)
					}
					if c == `*` && y.cptr.deref() == `/` {
						putc(`/`, mut y.text_file)
						if y.dflag {
							putc(`/`, mut y.union_file)
						}
						y.cptr.inc()
						c_line.free()
						unsafe {
							goto loop
						}
					}
					if c == `\n` {
						y.get_line()!
						if y.line.is_null {
							y.unterminated_comment(c_lineno, c_line, c_cptr)!
						}
					}
				}
			}
			unsafe {
				goto loop
			}
		}
		else {
			unsafe {
				goto loop
			}
		}
	}
}

/*
bucket *
get_literal(void)
{
	int c, quote, i, n;
	char *s;
	bucket *bp;
	int s_lineno = lineno;
	char *s_line = dup_line();
	char *s_cptr = s_line + (cptr - line);

	quote = (unsigned char) *cptr++;
	cinc = 0;
	for (;;) {
		c = (unsigned char) *cptr++;
		if (c == quote)
			break;
		if (c == '\n')
			unterminated_string(s_lineno, s_line, s_cptr);
		if (c == '\\') {
			char *c_cptr = cptr - 1;
			unsigned long ulval;

			c = (unsigned char) *cptr++;
			switch (c) {
			case '\n':
				get_line();
				if (line == NULL)
					unterminated_string(s_lineno, s_line,
					    s_cptr);
				continue;

			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
				ulval = strtoul(cptr - 1, &s, 8);
				if (s == cptr - 1 || ulval > MAXCHAR)
					illegal_character(c_cptr);
				c = (int) ulval;
				cptr = s;
				break;

			case 'x':
				ulval = strtoul(cptr, &s, 16);
				if (s == cptr || ulval > MAXCHAR)
					illegal_character(c_cptr);
				c = (int) ulval;
				cptr = s;
				break;

			case 'a':
				c = 7;
				break;
			case 'b':
				c = '\b';
				break;
			case 'f':
				c = '\f';
				break;
			case 'n':
				c = '\n';
				break;
			case 'r':
				c = '\r';
				break;
			case 't':
				c = '\t';
				break;
			case 'v':
				c = '\v';
				break;
			}
		}
		cachec(c);
	}
	free(s_line);

	n = cinc;
	s = malloc(n);
	if (s == NULL)
		no_space();

	memcpy(s, cache, n);

	cinc = 0;
	if (n == 1)
		cachec('\'');
	else
		cachec('"');

	for (i = 0; i < n; ++i) {
		c = ((unsigned char *) s)[i];
		if (c == '\\' || c == cache[0]) {
			cachec('\\');
			cachec(c);
		} else if (isprint(c))
			cachec(c);
		else {
			cachec('\\');
			switch (c) {
			case 7:
				cachec('a');
				break;
			case '\b':
				cachec('b');
				break;
			case '\f':
				cachec('f');
				break;
			case '\n':
				cachec('n');
				break;
			case '\r':
				cachec('r');
				break;
			case '\t':
				cachec('t');
				break;
			case '\v':
				cachec('v');
				break;
			default:
				cachec(((c >> 6) & 7) + '0');
				cachec(((c >> 3) & 7) + '0');
				cachec((c & 7) + '0');
				break;
			}
		}
	}

	if (n == 1)
		cachec('\'');
	else
		cachec('"');

	cachec(NUL);
	bp = lookup(cache);
	bp->class = TERM;
	if (n == 1 && bp->value == UNDEFINED)
		bp->value = *(unsigned char *) s;
	free(s);

	return (bp);
}
*/

fn (mut y YACC) get_literal() !&Bucket {
	mut c := u8(0)
	mut i := 0
	mut n := 0
	mut s := null_char_ptr()
	mut bp := &Bucket{
		link: unsafe { 0 }
		next: unsafe { 0 }
	}
	mut s_lineno := y.lineno
	mut s_line := y.dup_line()
	mut s_cptr := s_line.add(y.cptr.subtract_ptr(y.line))

	mut quote := y.cptr.deref()
	y.cptr.inc()
	y.cache = ''
	for true {
		c = y.cptr.deref()
		y.cptr.inc()
		if c == quote {
			break
		}
		if c == `\n` {
			y.unterminated_string(s_lineno, s_line, s_cptr)!
		}
		if c == `\\` {
			mut c_cptr := y.cptr.subtract(-1)
			mut ulval := i64(0)

			c = y.cptr.deref()
			y.cptr.inc()
			match c {
				`\n` {
					y.get_line()!
					if y.line.is_null {
						y.unterminated_string(s_lineno, s_line, s_cptr)!
					}
					continue
				}
				`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7` {
					ulval = strconv.parse_int(y.cptr.subtract(1).str(), 8, 64)!
					if s.equals(y.cptr.subtract(1)) || ulval > maxchar {
						y.illegal_character(c_cptr)!
					}
					c = u8(ulval)
					y.cptr = s
				}
				`x` {
					ulval = strconv.parse_int(y.cptr.subtract(1).str(), 16, 64)!
					if s.equals(y.cptr.subtract(1)) || ulval > maxchar {
						y.illegal_character(c_cptr)!
					}
					c = u8(ulval)
					y.cptr = s
				}
				`a` {
					c = 7
				}
				`b` {
					c = `\b`
				}
				`f` {
					c = `\f`
				}
				`n` {
					c = `\n`
				}
				`r` {
					c = `\r`
				}
				`t` {
					c = `\t`
				}
				`v` {
					c = `\v`
				}
				else {}
			}
		}
		y.cachec(c)
	}
	s_line.free()

	s = char_ptr(y.cache)

	y.cache = ''
	if n == 1 {
		y.cachec(`'`)
	} else {
		y.cachec(`"`)
	}

	i = 0
	for i < n {
		c = s.at(i)
		if c == `\\` || c == y.cache[0] {
			y.cachec(`\\`)
			y.cachec(c)
		} else if isprint(c) {
			y.cachec(c)
		} else {
			y.cachec(`\\`)
			match c {
				7 {
					y.cachec(`a`)
				}
				`\b` {
					y.cachec(`b`)
				}
				`\f` {
					y.cachec(`f`)
				}
				`\n` {
					y.cachec(`n`)
				}
				`\r` {
					y.cachec(`r`)
				}
				`\t` {
					y.cachec(`t`)
				}
				`\v` {
					y.cachec(`v`)
				}
				else {
					y.cachec(((c >> 6) & 7) + `0`)
					y.cachec(((c >> 3) & 7) + `0`)
					y.cachec((c & 7) + `0`)
				}
			}
			i++
		}
	}

	if n == 1 {
		y.cachec(`'`)
	} else {
		y.cachec(`"`)
	}

	y.cachec(0)
	bp = y.lookup(y.cache)
	bp.class = symbol_term
	if n == 1 && bp.value == undefined {
		bp.value = s.deref()
	}

	return bp
}

/*
int
is_reserved(char *name)
{
	char *s;

	if (strcmp(name, ".") == 0 ||
	    strcmp(name, "$accept") == 0 ||
	    strcmp(name, "$end") == 0)
		return (1);

	if (name[0] == '$' && name[1] == '$' && isdigit((unsigned char) name[2])) {
		s = name + 3;
		while (isdigit((unsigned char) *s))
			++s;
		if (*s == NUL)
			return (1);
	}
	return (0);
}
*/

fn (mut y YACC) is_reserved(name CharPtr) bool {
	mut s := null_char_ptr()

	if name.equals_str('.') || name.equals_str('\$accept') || name.equals_str('\$end') {
		return true
	}

	if name.at(0) == `$` && name.at(1) == `$` && isdigit(name.at(2)) {
		s = name.add(3)
		for (isdigit(s.deref())) {
			s.inc()
		}
		if s.deref() == 0 {
			return true
		}
	}
	return false
}

/*
bucket *
get_name(void)
{
	int c;

	cinc = 0;
	for (c = (unsigned char) *cptr; IS_IDENT(c); c = (unsigned char) *++cptr)
		cachec(c);
	cachec(NUL);

	if (is_reserved(cache))
		used_reserved(cache);

	return (lookup(cache));
}
*/

fn (mut y YACC) get_name() !&Bucket {
	y.cache = ''
	mut c := y.cptr.deref()
	for (is_ident(c)) {
		y.cachec(c)
		y.cptr.inc()
		c = y.cptr.deref()
	}
	y.cachec(0)

	if y.is_reserved(char_ptr(y.cache)) {
		y.used_reserved(y.cache)!
	}

	return y.lookup(y.cache)
}

fn (mut y YACC) get_number() !int {
	ul := y.cptr.str().int()
	if ul > int_max {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}
	y.cptr = char_ptr('${ul}')
	return ul
}

fn (mut y YACC) get_tag() !string {
	mut t_lineno := y.lineno
	mut t_line := y.dup_line()
	mut t_cptr := t_line.add(y.cptr.subtract_ptr(y.line))

	y.cptr.inc()
	mut c := y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}

	if !isalpha(c) && c != `_` && c != `$` {
		y.illegal_tag(t_lineno, t_line, t_cptr)!
	}

	y.cache = ''
	y.cachec(c)
	y.cptr.inc()
	c = y.cptr.deref()
	for (is_ident(c)) {
		y.cachec(c)
		y.cptr.inc()
		c = y.cptr.deref()
	}
	y.cachec(0)

	c = y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}
	if c != `>` {
		y.illegal_tag(t_lineno, t_line, t_cptr)!
	}
	t_line.free()
	y.cptr.inc()

	mut i := 0
	for i < y.tag_table.len {
		if y.cache == y.tag_table[i] {
			return y.tag_table[i]
		}
		i++
	}

	y.tag_table << y.cache
	return y.cache
}

module main

// The line size must be a positive integer.  One hundred was chosen	
// because few lines in Yacc input grammars exceed 100 characters.	
// Note that if a line exceeds LINESIZE characters, the line buffer	
// will be expanded to accommodate it.					
const linesize = 100

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

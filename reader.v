module main

import strconv

// The line size must be a positive integer.  One hundred was chosen	
// because few lines in Yacc input grammars exceed 100 characters.	
// Note that if a line exceeds LINESIZE characters, the line buffer	
// will be expanded to accommodate it.					
const linesize = 100

const line_format = '#line %d "%s"\n'

fn (mut y YACC) cachec(c u8) {
	y.cache += '${c}'
}

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

fn (mut y YACC) keyword() !u8 {
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

fn (mut y YACC) get_literal() !&Bucket {
	mut c := u8(0)
	mut i := 0
	mut n := 0
	mut s := null_char_ptr()
	mut bp := &Bucket{}
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

fn (mut y YACC) declare_tokens(assoc u8) ! {
	mut c := u8(0)
	mut bp := &Bucket{}
	mut value := 0
	mut tag := ''

	if assoc != k_token {
		y.prec++
	}

	c = y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}
	if c == `<` {
		tag = y.get_tag()!
		c = y.nextc()!
		if c == eof {
			y.unexpected_eof()!
		}
	}
	for (true) {
		if isalpha(c) || c == `_` || c == `.` || c == `$` {
			bp = y.get_name()!
		} else if c == `'` || c == `"` {
			bp = y.get_literal()!
		} else {
			return
		}

		if bp == y.goal {
			y.tokenized_start(bp.name)!
		}
		bp.class = symbol_term

		if tag != '' {
			if bp.tag != '' && tag != bp.tag {
				y.retyped_warning(bp.name)!
			}
			bp.tag = tag
		}
		if assoc != k_token {
			if bp.prec != 0 && y.prec != bp.prec {
				y.reprec_warning(bp.name)!
			}
			bp.assoc = assoc
			bp.prec = y.prec
		}
		c = y.nextc()!
		if c == eof {
			y.unexpected_eof()!
		}
		if isdigit(c) {
			value = y.get_number()!
			if bp.value != undefined && value != bp.value {
				y.revalued_warning(bp.name)!
			}
			bp.value = i16(value)
			c = y.nextc()!
			if c == eof {
				y.unexpected_eof()!
			}
		}
	}
}

/*
 * %expect requires special handling as it really isn't part of the yacc
 * grammar only a flag for yacc proper.
 */
fn (mut y YACC) declare_expect(assoc int) ! {
	mut c := u8(0)

	if assoc != k_expect {
		y.prec++
	}

	/*
   * Stay away from nextc - doesn't detect EOL and will read to EOF.
   */
	y.cptr.inc()
	c = y.cptr.deref()
	if c == eof {
		y.unexpected_eof()!
	}

	for (true) {
		if isdigit(c) {
			y.sr_expect = y.get_number()!
			break
		}
		/*
		 * Looking for number before EOL.
		 * Spaces, tabs, and numbers are ok.
		 * Words, punc., etc. are syntax errors.
		 */
		else if c == `\n` || isalpha(c) || !isspace(c) {
			y.syntax_error(y.lineno, y.line, y.cptr)!
		} else {
			y.cptr.inc()
			c = y.cptr.deref()
			if c == eof {
				y.unexpected_eof()!
			}
		}
	}
}

fn (mut y YACC) declare_types() ! {
	mut c := u8(0)
	mut bp := &Bucket{}
	mut tag := ''

	c = y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}
	if c != `<` {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}
	tag = y.get_tag()!

	for (true) {
		c = y.nextc()!
		if isalpha(c) || c == `_` || c == `.` || c == `$` {
			bp = y.get_name()!
		} else if c == `'` || c == `"` {
			bp = y.get_literal()!
		} else {
			return
		}

		if bp.tag != '' && tag != bp.tag {
			y.retyped_warning(bp.name)!
		}
		bp.tag = tag
	}
}

fn (mut y YACC) declare_start() ! {
	mut c := u8(0)
	mut bp := &Bucket{}

	c = y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}
	if !isalpha(c) && c != `_` && c != `.` && c != `$` {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}
	bp = y.get_name()!
	if bp.class == symbol_term {
		y.terminal_start(bp.name)!
	}
	if unsafe { y.goal != 0 } && y.goal != bp {
		y.restarted_warning()!
	}
	y.goal = bp
}

fn (mut y YACC) read_declarations() ! {
	mut c := u8(0)
	mut k := u8(0)

	y.cache = ''

	for (true) {
		c = y.nextc()!
		if c == eof {
			y.unexpected_eof()!
		}
		if c != `%` {
			y.syntax_error(y.lineno, y.line, y.cptr)!
		}
		k = y.keyword()!
		match k {
			k_mark {
				return
			}
			k_ident {
				y.copy_ident()!
			}
			k_text {
				y.copy_text()!
			}
			k_union {
				y.copy_union()!
			}
			k_token, k_left, k_right, k_nonassoc {
				y.declare_tokens(k)!
			}
			k_expect {
				y.declare_expect(k)!
			}
			k_type {
				y.declare_types()!
			}
			k_start {
				y.declare_start()!
			}
			else {}
		}
	}
}

fn (mut y YACC) initialize_grammar() {
	y.nitems = 4
	y.nrules = 3
	y.plhs = []&Bucket{}
	y.plhs << &Bucket{}
	y.plhs << &Bucket{}
	y.plhs << &Bucket{}
	y.rprec = []i16{len: 3}
	y.rassoc = []u8{len: 3, init: k_token}
}

fn (mut y YACC) expand_items() {
	mut i := 0
	for i < 300 {
		y.pitem << &Bucket{}
		i++
	}
}

fn (mut y YACC) expand_rules() {
	mut i := 0
	for i < 100 {
		y.plhs << &Bucket{}
		y.rprec << 0
		y.rassoc << 0
		i++
	}
}

fn (mut y YACC) advance_to_start() ! {
	mut c := u8(0)
	mut bp := &Bucket{}
	mut s_cptr := null_char_ptr()
	mut s_lineno := 0

	for (true) {
		c = y.nextc()!
		if c != `%` {
			break
		}
		s_cptr = y.cptr
		match y.keyword()! {
			k_mark {
				y.no_grammar()!
			}
			k_text {
				y.copy_text()!
			}
			k_start {
				y.declare_start()!
			}
			else {
				y.syntax_error(y.lineno, y.line, s_cptr)!
			}
		}
	}

	c = y.nextc()!
	if !isalpha(c) && c != `_` && c != `.` && c != `_` {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}
	bp = y.get_name()!
	if unsafe { y.goal == 0 } {
		if bp.class == symbol_term {
			y.terminal_start(bp.name)!
		}
		y.goal = bp
	}
	s_lineno = y.lineno
	c = y.nextc()!
	if c == eof {
		y.unexpected_eof()!
	}
	if c != `:` {
		y.syntax_error(y.lineno, y.line, y.cptr)!
	}
	y.start_rule(mut bp, s_lineno)!
	y.cptr.inc()
}

fn (mut y YACC) start_rule(mut bp Bucket, s_lineno int) ! {
	if bp.class == symbol_term {
		y.terminal_lhs(s_lineno)!
	}
	bp.class = symbol_nonterm
	if y.nrules >= y.plhs.len {
		y.expand_rules()
	}
	y.plhs[y.nrules] = bp
	y.rprec[y.nrules] = undefined
	y.rassoc[y.nrules] = k_token
}

fn (mut y YACC) end_rule() ! {
	mut i := 0

	if !y.last_was_action && y.plhs[y.nrules].tag != '' {
		i = y.nitems - 1
		for unsafe { y.pitem[i] != 0 } {
			i--
			continue
		}
		if i == y.pitem.len - 1 || unsafe { y.pitem[i + 1] == 0 }
			|| y.pitem[i + 1].tag != y.plhs[y.nrules].tag {
			y.default_action_warning()!
		}
	}
	y.last_was_action = false
	if y.nitems >= y.pitem.len {
		y.expand_items()
	}
	y.nitems++
	y.nrules++
}

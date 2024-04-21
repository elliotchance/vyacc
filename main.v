module main

import os
import io.util
import flag

struct YACC {
mut:
	// C built ins
	stderr os.File
	stdin  os.File
	// main.c
	dflag bool
	lflag bool
	rflag bool
	tflag bool
	vflag bool

	symbol_prefix string
	file_prefix   string = 'y'

	lineno  int
	outline int

	explicit_file_name int

	code_file_name    string
	defines_file_name string
	input_file_name   string
	output_file_name  string
	verbose_file_name string

	action_file os.File // a temp file, used to save actions associated
	// with rules until the parser is written
	code_file    os.File // y.code.c (used when the -r option is specified)
	defines_file os.File // y.tab.h
	input_file   os.File // the input file
	output_file  os.File // y.tab.c
	text_file    os.File // a temp file, used to save text until all
	// symbols have been defined
	union_file os.File // a temp file, used to save the union
	// definition until all symbol have been
	// defined
	verbose_file os.File // y.output

	nitems  int
	nrules  int
	nsyms   int
	ntokens int
	nvars   int

	start_symbol int
	symbol_name  []string
	// short *symbol_value
	// short *symbol_prec;
	symbol_assoc string
	// short *ritem;
	// short *rlhs;
	// short *rrhs;
	rprec  []i16
	rassoc []u8
	// short **derives;
	// char *nullable;
	// reader.c
	cache string

	tag_table []string

	saw_eof         bool
	unionized       bool
	cptr            CharPtr
	line            CharPtr
	linesize        int
	goal            &Bucket = unsafe { 0 }
	prec            i16
	gensym          int
	last_was_action bool

	pitem []&Bucket
	plhs  []&Bucket

	name_pool_size int
	name_pool      string
	// symtab.c
	symbol_table map[string]&Bucket
	first_symbol &Bucket = unsafe { 0 }
	last_symbol  &Bucket = unsafe { 0 }
	// mkpar.c
	sr_expect int
}

/*
void
usage(void)
{
	fprintf(stderr, "usage: %s [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n", __progname);
	exit(1);
}
*/

fn (mut y YACC) usage() ! {
	y.stderr.write_string('usage: ${os.args[0]} [-dlrtv] [-b file_prefix] [-o output_file] [-p symbol_prefix] file\n')!
	exit(1)
}

/*
void
getargs(int argc, char *argv[])
{
	int ch;

	while ((ch = getopt(argc, argv, "b:dlo:p:rtv")) != -1) {
		switch (ch) {
		case 'b':
			file_prefix = optarg;
			break;

		case 'd':
			dflag = 1;
			break;

		case 'l':
			lflag = 1;
			break;

		case 'o':
			output_file_name = optarg;
			explicit_file_name = 1;
			break;

		case 'p':
			symbol_prefix = optarg;
			break;

		case 'r':
			rflag = 1;
			break;

		case 't':
			tflag = 1;
			break;

		case 'v':
			vflag = 1;
			break;

		default:
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc != 1)
		usage();
	if (strcmp(*argv, "-") == 0)
		input_file = stdin;
	else
		input_file_name = *argv;
}
*/

fn (mut y YACC) getargs(argv []string) ! {
	if argv.len < 2 {
		y.usage()!
	}

	mut fp := flag.new_flag_parser(argv)
	fp.skip_executable()
	y.file_prefix = fp.string('', `b`, y.file_prefix, '')
	y.dflag = fp.bool('', `d`, y.dflag, '')
	y.lflag = fp.bool('', `l`, y.lflag, '')
	y.output_file_name = fp.string('', `o`, y.output_file_name, '')
	if y.output_file_name != '' {
		y.explicit_file_name = 1
	}
	y.symbol_prefix = fp.string('', `p`, y.symbol_prefix, '')
	y.rflag = fp.bool('', `r`, y.rflag, '')
	y.tflag = fp.bool('', `t`, y.tflag, '')
	y.vflag = fp.bool('', `v`, y.vflag, '')

	if argv[argv.len - 1] == '-' {
		y.input_file = y.stdin
	} else {
		y.input_file_name = argv[argv.len - 1]
	}
}

/*
void
create_file_names(void)
{
	if (output_file_name == NULL) {
		if (asprintf(&output_file_name, "%s%s", file_prefix, OUTPUT_SUFFIX)
		    == -1)
			no_space();
	}
	if (rflag) {
		if (asprintf(&code_file_name, "%s%s", file_prefix, CODE_SUFFIX) == -1)
			no_space();
	} else
		code_file_name = output_file_name;

	if (dflag) {
		if (explicit_file_name) {
			char *suffix;

			defines_file_name = strdup(output_file_name);
			if (defines_file_name == 0)
				no_space();

			/* does the output_file_name have a known suffix */
			if ((suffix = strrchr(output_file_name, '.')) != 0 &&
			    (!strcmp(suffix, ".c") ||	/* good, old-fashioned C */
			     !strcmp(suffix, ".C") ||	/* C++, or C on Windows */
			     !strcmp(suffix, ".cc") ||	/* C++ */
			     !strcmp(suffix, ".cxx") ||	/* C++ */
			     !strcmp(suffix, ".cpp"))) {/* C++ (Windows) */
				strncpy(defines_file_name, output_file_name,
					suffix - output_file_name + 1);
				defines_file_name[suffix - output_file_name + 1] = 'h';
				defines_file_name[suffix - output_file_name + 2] = '\0';
			} else {
				fprintf(stderr, "%s: suffix of output file name %s"
				 " not recognized, no -d file generated.\n",
					__progname, output_file_name);
				dflag = 0;
				free(defines_file_name);
				defines_file_name = 0;
			}
		} else {
			if (asprintf(&defines_file_name, "%s%s", file_prefix,
				     DEFINES_SUFFIX) == -1)
				no_space();
		}
	}
	if (vflag) {
		if (asprintf(&verbose_file_name, "%s%s", file_prefix,
			     VERBOSE_SUFFIX) == -1)
			no_space();
	}
}
*/

fn (mut y YACC) create_file_names() ! {
	if y.output_file_name == '' {
		y.output_file_name = '${y.file_prefix}${output_suffix}'
	}

	if y.rflag {
		y.code_file_name = '${y.file_prefix}${code_suffix}'
	} else {
		y.code_file_name = y.output_file_name
	}

	if y.dflag {
		if y.explicit_file_name != 0 {
			y.defines_file_name = y.output_file_name

			// does the output_file_name have a known suffix
			suffix := y.output_file_name[y.output_file_name.last_index('.') or {
				y.output_file_name.len
			}..]
			println(suffix)
			if suffix == '.v' {
				y.defines_file_name = y.output_file_name[..suffix.len - y.output_file_name.len +
					1] + 'h'
			} else {
				y.stderr.write_string('${os.args[0]}: suffix of output file name ${y.output_file_name} not recognized, no -d file generated.\n')!
				y.dflag = false
				y.defines_file_name = ''
			}
		} else {
			y.defines_file_name = '${y.file_prefix}${defines_suffix}'
		}
	}

	if y.vflag {
		y.verbose_file_name = '${y.file_prefix}${verbose_suffix}'
	}
}

/*
FILE *
create_temp(void)
{
	FILE *f;

	f = tmpfile();
	if (f == NULL)
		tempfile_error();
	return f;
}
*/

fn (mut y YACC) create_temp() !os.File {
	f, _ := util.temp_file(util.TempFileOptions{}) or {
		y.tempfile_error(err)!
		exit(1)
	}

	return f
}

/*
void
open_files(void)
{
	create_file_names();

	if (input_file == NULL) {
		input_file = fopen(input_file_name, "r");
		if (input_file == NULL)
			open_error(input_file_name);
	}
	action_file = create_temp();

	text_file = create_temp();

	if (vflag) {
		verbose_file = fopen(verbose_file_name, "w");
		if (verbose_file == NULL)
			open_error(verbose_file_name);
	}
	if (dflag) {
		defines_file = fopen(defines_file_name, "w");
		if (defines_file == NULL)
			open_write_error(defines_file_name);
		union_file = create_temp();
	}
	output_file = fopen(output_file_name, "w");
	if (output_file == NULL)
		open_error(output_file_name);

	if (rflag) {
		code_file = fopen(code_file_name, "w");
		if (code_file == NULL)
			open_error(code_file_name);
	} else
		code_file = output_file;
}
*/

fn (mut y YACC) open_files() ! {
	y.create_file_names()!

	y.input_file = os.open_file(y.input_file_name, 'r') or {
		y.open_error(y.input_file_name, err)!
		return
	}
	y.action_file = y.create_temp()!

	y.text_file = y.create_temp()!

	if y.vflag {
		y.verbose_file = os.open_file(y.verbose_file_name, 'w') or {
			y.open_error(y.verbose_file_name, err)!
			return
		}
	}
	if y.dflag {
		y.defines_file = os.open_file(y.defines_file_name, 'w') or {
			y.open_write_error(y.defines_file_name, err)!
			return
		}
		y.union_file = y.create_temp()!
	}
	y.output_file = os.open_file(y.output_file_name, 'w') or {
		y.open_error(y.output_file_name, err)!
		return
	}

	if y.rflag {
		y.code_file = os.open_file(y.code_file_name, 'w') or {
			y.open_error(y.code_file_name, err)!
			return
		}
	} else {
		y.code_file = y.output_file
	}
}

/*
int
main(int argc, char *argv[])
{
#ifndef HAVE_PROGNAME
	__progname = argv[0];
#endif

#ifdef HAVE_PLEDGE
	if (pledge("stdio rpath wpath cpath", NULL) == -1)
		fatal("pledge: invalid arguments");
#endif

	getargs(argc, argv);
	open_files();
	reader();
	lr0();
	lalr();
	make_parser();
	verbose();
	output();
	return (0);
}
*/

fn main() {
	mut y := YACC{
		stderr: os.stderr()
		stdin: os.stdin()
		symbol_table: map[string]&Bucket{}
	}

	y.getargs(os.args) or { panic(err) }
	y.open_files() or { panic(err) }

	print(y)
}

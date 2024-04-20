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
	y.stderr.write_string("${y.input_file_name}: cannot open source file ${filename}: ${err}\n")!
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
	y.stderr.write_string("${y.input_file_name}: cannot open target file ${filename} for writing: ${err}\n")!
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
	y.stderr.write_string("${y.input_file_name}: cannot create temporary file: ${err}\n")!
	exit(2)
}

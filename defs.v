module main

// defines for constructing filenames

const code_suffix = '.code.v'
const defines_suffix = '.tab.h.v' // If this is removed, update README
const output_suffix = '.tab.v'
const verbose_suffix = '.output'

// keyword codes

const k_token = 0
const k_left = 1
const k_right = 2
const k_nonassoc = 3
const k_mark = 4
const k_text = 5
const k_type = 6
const k_start = 7
const k_union = 8
const k_ident = 9
const k_expect = 10

// the structure of a symbol table entry

struct Bucket {
mut:
	link  &Bucket = unsafe { 0 }
	next  &Bucket = unsafe { 0 }
	name  string
	tag   string
	value i16
	index i16
	prec  i16
	class u8
	assoc u8
}

// symbol classes

const symbol_unknown = 0
const symbol_term = 1
const symbol_nonterm = 2

// the undefined value

const undefined = -1

const maxchar = 255

// character macros

fn is_ident(c u8) bool {
	return isalnum(c) || c == `_` || c == `.` || c == `$`
}

fn numeric_value(c u8) int {
	return c - u8(`0`)
}

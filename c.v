module main

import os

const eof = -1
const int_max = 2147483647

struct CharPtr {
mut:
	pos     int
	value   []u8
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
	return CharPtr{p.pos + len, p.value, false}
}

fn (p CharPtr) subtract(len int) CharPtr {
	return CharPtr{p.pos - len, p.value, false}
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
	return p.value[p.pos + index]
}

fn (p CharPtr) deref() u8 {
	return p.at(0)
}

fn (p CharPtr) str() string {
	return p.value[p.pos..].bytestr()
}

fn (p CharPtr) equals(p2 CharPtr) bool {
	return p.value[p.pos..] == p2.value[p2.pos..]
}

fn (p CharPtr) equals_str(p2 string) bool {
	return p.value[p.pos..].bytestr() == p2
}

fn (mut p CharPtr) set(index int, c u8) u8 {
	p.value[p.pos + index] = c
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

// int getc(FILE *stream)
fn getc(mut stream os.File) u8 {
	mut buf := [u8(0)]
	stream.read(mut buf) or { return 0 }
	return buf[0]
}

// int putc(int char, FILE *stream)
fn putc(c u8, mut stream os.File) int {
	return stream.write([c]) or { 0 }
}

// TODO(elliotchance): Fix this.
fn isprint(c u8) bool {
	return true
}

// TODO(elliotchance): Fix this.
fn isalpha(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

// TODO(elliotchance): Fix this.
fn isalnum(c u8) bool {
	return isdigit(c) || isalpha(c)
}

// TODO(elliotchance): Fix this.
fn isupper(c u8) bool {
	return c >= `A` && c <= `Z`
}

// TODO(elliotchance): Fix this.
fn isdigit(c u8) bool {
	return c >= `0` && c <= `9`
}

// TODO(elliotchance): Fix this.
fn tolower(c u8) u8 {
	return '${c}'.to_lower()[0]
}

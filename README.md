Adapted from:
https://github.com/ibara/yacc/tree/master

# Changes

- `code_suffix`, `defines_suffix` and `output_suffix`: These now use the `.v`
  file names.
- `create_file_names()`: Expected output files types (`.c`, `.C`, `.cc`, `.cxx`
  and `.cpp`) now only consider `.v`.

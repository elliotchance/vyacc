// declarations
%{
    #include <stdio.h>
    int yylex();
    void yyerror(const char* msg) {
       fprintf(stderr, "%s\n", msg);
    }
%}

%%
// rules
%token NUMBER PLUS MINUS TIMES DIVIDE EOL;
%left PLUS MINUS;
%left TIMES DIVIDE;
%start statements;

statements  :   statement statements
            |   statement
            ;

statement   :   expression EOL              { printf("= %d\n", $1); }

expression  :   NUMBER                      { $$ = $1; printf("number: %d\n", $$); }
            |   expression TIMES expression { $$ = $1 * $3; printf("*: %d\n", $$); }
            |   expression PLUS expression  { $$ = $1 + $3; printf("+: %d\n", $$); }
            ;

%%
// programs
#include "lex.yy.c"

int main() {
  yyparse();
  return 1;
}

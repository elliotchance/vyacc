%{
#include<stdio.h>

int regs[26];
int base;

%}

%start list

%union { int a; }


%token DIGIT LETTER

%left '|'
%left '&'
%left '+' '-'
%left '*' '/' '%'
%left UMINUS  /*supplies precedence for unary minus */

%%                   /* beginning of rules section */

list:                       /*empty */
         |
        list stat '\n'
         |
        list error '\n'
         {
           yyerrok;
         }
         ;
stat:    expr
         {
           printf("%d\n",$1);
         }
         |
         LETTER '=' expr
         {
           regs[$1.a] = $3.a;
         }

         ;

expr:    '(' expr ')'
         {
           $$ = $2;
         }
         |
         expr '*' expr
         {

           $$.a = $1.a * $3.a;
         }
         |
         expr '/' expr
         {
           $$.a = $1.a / $3.a;
         }
         |
         expr '%' expr
         {
           $$.a = $1.a % $3.a;
         }
         |
         expr '+' expr
         {
           $$.a = $1.a + $3.a;
         }
         |
         expr '-' expr
         {
           $$.a = $1.a - $3.a;
         }
         |
         expr '&' expr
         {
           $$.a = $1.a & $3.a;
         }
         |
         expr '|' expr
         {
           $$.a = $1.a | $3.a;
         }
         |

        '-' expr %prec UMINUS
         {
           $$.a = -$2.a;
         }
         |
         LETTER
         {
           $$.a = regs[$1.a];
         }

         |
         number
         ;

number:  DIGIT
         {
           $$ = $1;
           base = ($1.a==0) ? 8 : 10;
         }       |
         number DIGIT
         {
           $$.a = base * $1.a + $2.a;
         }
         ;

%%
main()
{
 return(yyparse());
}

yyerror(s)
char *s;
{
  fprintf(stderr, "%s\n",s);
}

yywrap()
{
  return(1);
}

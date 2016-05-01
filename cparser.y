%token	IDENTIFIER I_CONSTANT F_CONSTANT STRING_LITERAL FUNC_NAME SIZEOF
%token	PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token	AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token	SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token	XOR_ASSIGN OR_ASSIGN
%token	TYPEDEF_NAME ENUMERATION_CONSTANT

%token	TYPEDEF EXTERN STATIC AUTO REGISTER INLINE
%token	CONST RESTRICT VOLATILE
%token	BOOL CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE VOID
%token	COMPLEX IMAGINARY 
%token	STRUCT UNION ENUM ELLIPSIS

%token	CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%token	ALIGNAS ALIGNOF ATOMIC GENERIC NORETURN STATIC_ASSERT THREAD_LOCAL


%token NUMBER
%token SYMBOL
%token STRING
%token VAR
%token IF
%token ELSE
%token RETURN
%token WHILE
%token FOR
%token PRINTLN

%{
#include <stdio.h>
#include "AST.h"
%}

%union {
    AST *val;
}

%right '='
%left '<' '>'
%left '+' '-'
%left '*'

%type <val> parameter_list block local_vars symbol_list 
%type <val> statements statement expr primary_expr arg_list
%type <val> SYMBOL NUMBER STRING

%start program

%%

program: /* empty */
	| external_definitions
	;

external_definitions:
	  external_definition
	| external_definitions external_definition
	;

external_definition:
	  SYMBOL parameter_list block  /* fucntion definition */
	{ defineFunction(getSymbol($1), $2, $3); }
	| type_specifier SYMBOL parameter_list block	// void func() ...
	{ defineFunction(getSymbol($2), $3, $4); }
	| type_specifier SYMBOL ';'
	{ declareVariable(getSymbol($2), NULL); }
	| type_specifier SYMBOL '=' expr ';'
        { declareVariable(getSymbol($2), $4); }
	| type_specifier SYMBOL '[' expr ']' ';'
	{ declareArray(getSymbol($2), $4); }
	;

parameter_list:
	 '(' ')'
	 { $$ = NULL; }
	| '(' symbol_list ')'
	 { $$ = $2; }
	;

block: '{' local_vars statements '}'
	{ $$ = makeAST(BLOCK_STATEMENT, $2, $3); }
	;

local_vars: 
	  /* NULL */ { $$ = NULL; }
	| type_specifier symbol_list ';'
	  { $$ = $2; }
	;

type_specifier
	: VOID
	| VAR	//!!
	| CHAR
	| SHORT
	| INT
	| LONG
	| FLOAT
	| DOUBLE
	| SIGNED
	| UNSIGNED
	| BOOL
	| COMPLEX
	| IMAGINARY	  	/* non-mandated extension */
	| atomic_type_specifier
	| struct_or_union_specifier
	| enum_specifier
	| TYPEDEF_NAME		/* after it has been defined as such */
	;

struct_or_union_specifier
	: struct_or_union '{' struct_declaration_list '}'
	| struct_or_union IDENTIFIER '{' struct_declaration_list '}'
	| struct_or_union IDENTIFIER
	;

struct_or_union
	: STRUCT
	| UNION
	;

struct_declaration_list
	: struct_declaration
	| struct_declaration_list struct_declaration
	;

struct_declaration
	: specifier_qualifier_list ';'	/* for anonymous struct/union */
	| specifier_qualifier_list struct_declarator_list ';'
	| static_assert_declaration
	;

specifier_qualifier_list
	: type_specifier specifier_qualifier_list
	| type_specifier
	| type_qualifier specifier_qualifier_list
	| type_qualifier
	;

struct_declarator_list
	: struct_declarator
	| struct_declarator_list ',' struct_declarator
	;

struct_declarator
	: ':' constant_expression
	| declarator ':' constant_expression
	| declarator
	;

enum_specifier
	: ENUM '{' enumerator_list '}'
	| ENUM '{' enumerator_list ',' '}'
	| ENUM IDENTIFIER '{' enumerator_list '}'
	| ENUM IDENTIFIER '{' enumerator_list ',' '}'
	| ENUM IDENTIFIER
	;

enumerator_list
	: enumerator
	| enumerator_list ',' enumerator
	;

enumerator	/* identifiers must be flagged as ENUMERATION_CONSTANT */
	: enumeration_constant '=' constant_expression
	| enumeration_constant
	;

atomic_type_specifier
	: ATOMIC '(' type_name ')'
	;

symbol_list: 
	  SYMBOL
	 { $$ = makeList1($1); }
	| symbol_list ',' SYMBOL
	 { $$ = addLast($1, $3); }
	;

statements:
	  statement
	 { $$ = makeList1($1); }
	| statements statement
	 { $$ = addLast($1, $2); }
	;

statement:
	 expr ';'
	 { $$ = $1; }
	| block
	 { $$ = $1; }
	| IF '(' expr ')' statement
	 { $$ = makeAST(IF_STATEMENT, $3, makeList2($5, NULL)); }
        | IF '(' expr ')' statement ELSE statement
	 { $$ = makeAST(IF_STATEMENT, $3, makeList2($5, $7)); }
	| RETURN expr ';'
	 { $$ = makeAST(RETURN_STATEMENT, $2, NULL); }
	| RETURN ';'
	 { $$ = makeAST(RETURN_STATEMENT, NULL, NULL); }
	| WHILE '(' expr ')' statement
	 { $$ = makeAST(WHILE_STATEMENT, $3, $5); }
	| FOR '(' expr ';' expr ';' expr ')' statement
	 { $$ = makeAST(FOR_STATEMENT, makeList3($3, $5, $7), $9); }
	;

expr: 	 primary_expr
	| SYMBOL '=' expr
	 { $$ = makeAST(EQ_OP, $1, $3); }
	| SYMBOL '[' expr ']' '=' expr
	 { $$ = makeAST(SET_ARRAY_OP, makeList2($1, $3), $6); }
	| expr '+' expr
	 { $$ = makeAST(PLUS_OP, $1, $3); }
	| expr '-' expr
	 { $$ = makeAST(MINUS_OP, $1, $3); }
	| expr '*' expr
	 { $$ = makeAST(MUL_OP, $1, $3); }
	| expr '<' expr
	 { $$ = makeAST(LT_OP, $1, $3); }
	| expr '>' expr
	 { $$ = makeAST(GT_OP, $1, $3); }
	;

primary_expr:
	  SYMBOL
	| NUMBER
	| STRING
	| SYMBOL '[' expr ']'
	  { $$ = makeAST(GET_ARRAY_OP, $1, $3); }
	| SYMBOL '(' arg_list ')'
	 { $$ = makeAST(CALL_OP, $1, $3); }
	| SYMBOL '(' ')'
	 { $$ = makeAST(CALL_OP, $1, NULL); }
        | '(' expr ')'
         { $$ = $2; }
	| PRINTLN '(' arg_list ')'
	 { $$ = makeAST(PRINTLN_OP, $3, NULL); }
	;

arg_list:
	 expr
	 { $$ = makeList1($1); }
	| arg_list ',' expr
	 { $$ = addLast($1, $3); }
	;

%%

/*void error(char *msg)
{
	fprintf(stderr, "compiler error: %s", msg);
	exit(1);
}*/
#include <stdarg.h>
void error(char *fmt, ...)
{
	va_list argp;
	va_start(argp, fmt);
	vfprintf(stderr, fmt, argp);
	va_end(argp);
	exit(1);
}

#if 1
#include "lex.yy.c"

// retrieve from '# digits text'
static char *source; // current input file name
yymark()
{
	if (source) free(source);
	source = (char *)calloc(yyleng, sizeof(char));
	if (source) {
		sscanf(yytext, "# %d %s", &yylineno, source);
	}
}

void yyerror(char *s)
{
	fflush(stdout);
	fprintf(stderr, "*** %d: %s near '%s'\n", yylineno, s, yytext);
}

int main(int argc, char *argv[])
{
	yyin = fopen(argv[1], "r");
	yyparse();
	fclose(yyin);
	return 0;
}
#else

#include "clex.c"
int main(int argc, char *argv[])
{
	yyparse();
	return 0;
}
#endif

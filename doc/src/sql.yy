/* -----------------------------------------------------------------------------
 * sql.yy
 *
 * A simple context-free grammar to parse SQL files and translating
 * CREATE FUNCTION statements into C++ function declarations.
 * This allows .sql files to be documented by documentation tools like Doxygen.
 *
 * Revision History:
 * 0.3: Florian Schoppmann, 29 Jan 2011, CREATE AGGREGATE supported, return
 *                                       types inferred from final function,
 *                                       line numbers are preserved
 * 0.2:          "        , 16 Jan 2011, Converted to C++
 * 0.1:          "        , 10 Jan 2011, Initial version, support for CREATE
 *                                       FUNCTION.
 * -----------------------------------------------------------------------------
 */

/* The %code directive needs bison >= 2.4 */
%require "2.4"

%code requires {
    #include <map>
    #include <fstream>
    #include <cstring>

    /*
     * FIXME: We should not disable warnings. Without this option, we would
     * get the following warnings:
     * 1) deprecated conversion from string constant to 'char*'
     * 2) ignoring return value of '...', declared with attribute
     *    warn_unused_result
     */
    #if defined(__GNUC__)
        #if (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 2))
            #pragma GCC diagnostic ignored "-Wwrite-strings"
        #endif
        #if (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3))
            #pragma GCC diagnostic ignored "-Wunused-result"
        #endif

        #pragma GCC diagnostic ignored "-Wconversion"
    #endif

    #ifdef COMPILING_SCANNER
        /* Flex expects the signature of yylex to be defined in the macro
         * YY_DECL. */
        #define YY_DECL                                        \
            int                                                \
            bison::SQLScanner::lex(                            \
                bison::SQLParser::semantic_type *yylval,    \
                bison::SQLParser::location_type *yylloc,    \
                bison::SQLDriver *driver                    \
            )
    #else
        /* In the parser, we need to call the lexer and therefore need the
         * lexer class declaration. */
        #define yyFlexLexer SQLFlexLexer
        #undef yylex
        #include "FlexLexer.h"
        #undef yyFlexLexer
    #endif

    namespace bison {

    /* Forward declaration because referenced by generated class declaration
     * SQLParser */
    class SQLDriver;

    }
}

%code provides {
    namespace bison {

    class SQLScanner;

    class SQLDriver
    {
    public:
        class CountingOStream {
        public:
            CountingOStream();
            CountingOStream &advance(int line);
            CountingOStream &operator<<(const char *str);
            CountingOStream &operator<<(char c);

            int     currentLine;
        };

        SQLDriver(const std::string &inExeName, const std::string &inFilename);
        virtual ~SQLDriver();
        void error(const SQLParser::location_type &l, const std::string &m);
        void error(const std::string &m);

        CountingOStream                 cout;
        std::map<std::string, char *>    fnToReturnType;
        SQLScanner                        *scanner;
        std::string                     exeName;
        std::string                     filename;
    };

    /* We need to subclass because SQLFlexLexer's yylex function does not have
     * the proper signature */
    class SQLScanner : public SQLFlexLexer
    {
    public:
        SQLScanner(std::istream *arg_yyin = 0, std::ostream* arg_yyout = 0);
        virtual ~SQLScanner();
        static inline char *strlowerdup(const char *inString);
        int lex(SQLParser::semantic_type *yylval,
            SQLParser::location_type *yylloc, SQLDriver *driver);
        void preScannerAction(SQLParser::semantic_type *yylval,
            SQLParser::location_type *yylloc, SQLDriver *driver);
        void more();

        char            *stringLiteralQuotation;
        unsigned long   oldLength;
    };

    class TaggedStr
    {
    public:
        TaggedStr(int inTag, char *inStr) : tag(inTag), str(inStr) { };
        virtual ~TaggedStr() { };

        int        tag;
        char    *str;
    };

    } // namespace bison

    /* "Connect" the bison parser in the driver to the flex scanner class
     * object. The C++ scanner generated by flex is a bit ugly, therefore
     * this sort of hack here.
     */
    #undef yylex
    #define yylex driver->scanner->lex
}

/* write out a header file containing the token defines */
%defines

/* use C++ and its skeleton file */
%skeleton "lalr1.cc"

/* keep track of the current position within the input */
%locations
%initial-action {
    // Initialize the initial location.
    @$.begin.filename = @$.end.filename = &driver->filename;
};

/* The name of the parser class. */
%define "parser_class_name" "SQLParser"

/* Declare that an argument declared by the braced-code `argument-declaration'
 * is an additional yyparse argument. The `argument-declaration' is used when
 * declaring functions or prototypes. The last identifier in
 * `argument-declaration' must be the argument name. */
%parse-param { SQLDriver *driver }

/* Declare that the braced-code argument-declaration is an additional yylex
 * argument declaration. */
%lex-param   { SQLDriver *driver }

/* namespace to enclose parser in */
%name-prefix="bison"

%union
{
    char            *str;
    class TaggedStr    *tStr;
    int                i;
}

%token            END        0    "end of file"
%token <str>    IDENTIFIER    "identifier"

%token <str>    COMMENT

%token            CREATE_FUNCTION
%token            CREATE_AGGREGATE

/* Function tokens */
%token            IN
%token            OUT
%token            INOUT

%token            RETURNS
%token            SETOF

%token            AS
%token            LANGUAGE
%token            IMMUTABLE
%token            STABLE
%token            VOLATILE
%token            CALLED_ON_NULL_INPUT
%token            RETURNS_NULL_ON_NULL_INPUT
%token            SECURITY_INVOKER
%token            SECURITY_DEFINER

%token          DEFAULT

/* Aggregate tokens */
%token    <i>        SFUNC
%token    <i>        PREFUNC
%token    <i>        FINALFUNC
%token            SORTOP
%token            STYPE
%token            INITCOND

/* types with more than 1 word */
%token            BIT
%token            CHARACTER
%token            DOUBLE
%token            PRECISION
%token            TIME
%token            VARYING
%token            VOID
%token            WITH
%token            WITHOUT
%token            ZONE

%token    <str>    INTEGER_LITERAL
%token  <str>   FLOAT_LITERAL
%token    <str>    STRING_LITERAL
%token  <str>   NULL_KEYWORD

/* Special tokens, for extending SQL syntax in C commands */
%token          BEGIN_SPECIAL
%token          END_SPECIAL

%type   <str>   expr
%type   <str>   prefixExpr
%type    <str>    qualifiedIdent
%type    <str>    optFnArgList fnArgList fnArgument
%type   <str>   optDefaultArgument defaultArgument
%type    <str>    optAggArgList aggArgList aggArgument
%type    <str>    argname    type baseType optLength optArray array
%type    <str>    returnDecl retType
%type    <tStr>    aggOptionList aggOption
%type    <i>        aggFunc


%% /* Grammar rules and actions follow. */

input:
    | input stmt
    | input COMMENT { driver->cout.advance(@2.begin.line) << $2; }
    | input '\n' { driver->cout << '\n'; }
;

stmt:
      ';'
    | createFnStmt ';'
    | createAggStmt ';'
;

createFnStmt:
      CREATE_FUNCTION qualifiedIdent '(' optFnArgList ')' returnDecl fnOptions {
        driver->cout.advance(@1.begin.line) << $6 << ' ' << $2 << '(' << $4 << ") { };";
        driver->fnToReturnType.insert(std::pair<std::string,char *>($2, $6));
    }
;

createAggStmt:
      CREATE_AGGREGATE qualifiedIdent '(' optAggArgList ')' '(' aggOptionList ')' {
        driver->cout.advance(@1.begin.line) << "@aggregate "
            << ($7 == NULL ? "" : $7->str) << ' ' << $2 << '(' << $4 << ") { };";
    }
;

qualifiedIdent:
      IDENTIFIER
    | IDENTIFIER '.' IDENTIFIER {
        $$ = $3;
    }
;

optFnArgList: { $$ = ""; }
    | fnArgList
;

optAggArgList:
      '*' { $$ = ""; }
    | aggArgList
;

fnArgList:
      fnArgList ',' fnArgument {
        /* Yes, we'll leak memory. And we'll fail if there is not enough.
         * We ignore all that here and below. */
        asprintf(&($$), "%s, %s", $1, $3);
    }
    | fnArgument
;

aggArgList:
      aggArgList ',' aggArgument {
        asprintf(&($$), "%s, %s", $1, $3);
    }
    | aggArgument

fnArgument:
      type optDefaultArgument {
        asprintf(&($$), "%s%s", $1, $2);
    }
    | argname type optDefaultArgument {
        asprintf(&($$), "%s %s%s", $2, $1, $3);
    }
    | argmode argname type optDefaultArgument {
        asprintf(&($$), "%s %s%s", $3, $2, $4);
    }
;

optDefaultArgument: { $$ = ""; }
    | defaultArgument
    | BEGIN_SPECIAL defaultArgument END_SPECIAL { $$ = $2; }
;

defaultArgument:
      DEFAULT expr {
        asprintf(&($$), " = %s", $2);
    }
    | '=' expr {
        asprintf(&($$), " = %s", $2);
    }
;

aggArgument:
      type optDefaultArgument
    | argname type optDefaultArgument {
        asprintf(&($$), "%s %s%s", $2, $1, $3);
    }
;

argmode:
      IN
    | OUT
    | INOUT
;

argname:
      IDENTIFIER
    | BEGIN_SPECIAL IDENTIFIER END_SPECIAL { $$ = $2; }
;

type:
      baseType optArray {
        asprintf(&($$), "%s%s", $1, $2);
    }
;

baseType:
      qualifiedIdent
    | BIT VARYING optLength {
        asprintf(&($$), "varbit%s", $3);
    }
    | CHARACTER VARYING optLength {
        asprintf(&($$), "varchar%s", $3);
    }
    | DOUBLE PRECISION { $$ = "float8"; }
    | VOID { $$ = "void"; }
;

optArray: { $$ = ""; }
    | array;

optLength: { $$ = ""; }
    | '(' INTEGER_LITERAL ')' {
        asprintf(&($$), "(%s)", $2);
    }
;

array:
      '[' ']' { $$ = "[]"; }
    | '[' INTEGER_LITERAL ']' {
        asprintf(&($$), "[%s]", $2);
    }
    | array '[' ']' {
        asprintf(&($$), "%s[]", $1);
    }
    | array '[' INTEGER_LITERAL ']' {
        asprintf(&($$), "%s[%s]", $1, $3);
    }
;

returnDecl: { $$ = "void"; }
    | RETURNS retType { $$ = $2; }
;

retType:
      type
    | SETOF type {
        asprintf(&($$), "set<%s>", $2);
    }
;

fnOptions:
    | fnOptions fnOption;

fnOption:
      AS STRING_LITERAL
    | AS STRING_LITERAL ',' STRING_LITERAL
    | LANGUAGE STRING_LITERAL
    | LANGUAGE IDENTIFIER
    | IMMUTABLE
    | STABLE
    | VOLATILE
    | CALLED_ON_NULL_INPUT
    | RETURNS_NULL_ON_NULL_INPUT
    | SECURITY_INVOKER
    | SECURITY_DEFINER
;

aggOptionList:
      aggOptionList ',' aggOption {
        if ($1 == NULL)
            $$ = $3;
        else if ($3 == NULL)
            $$ = $1;
        else if ($1->tag == token::FINALFUNC)
            $$ = $1;
        else
            $$ = $3;
    }
    | aggOption
;

aggOption:
      aggFunc '=' qualifiedIdent {
        $$ = new TaggedStr($1, driver->fnToReturnType[$3]);
    }
    | STYPE '=' type { $$ = new TaggedStr(token::STYPE, $3); }
    | INITCOND '=' expr { $$ = NULL; }
    /* FIXME: SORTOP not yet supported at this point */
;

aggFunc:
      SFUNC
    | PREFUNC
    | FINALFUNC
;

expr:
      INTEGER_LITERAL
    | FLOAT_LITERAL
    | STRING_LITERAL
    | IDENTIFIER
    | NULL_KEYWORD
    | prefixExpr
    /* FIXME: Support more or ignore completely */
;

prefixExpr:
      '+' expr {
        asprintf(&($$), "+%s", $2);
    }
    | '-' expr {
        asprintf(&($$), "-%s", $2);
    }
;

%%

namespace bison{

SQLDriver::SQLDriver(const std::string &inExeName,
    const std::string &inFilename)
    :   exeName(inExeName), filename(inFilename) { }

SQLDriver::~SQLDriver() { }

void SQLDriver::error(const SQLParser::location_type &l, const std::string &m) {
    std::cerr << exeName << ":" << l << ": " << m << std::endl;
}

void SQLDriver::error(const std::string &m) {
    std::cerr << m << std::endl;
}

SQLDriver::CountingOStream::CountingOStream() : currentLine(1) {
}

SQLDriver::CountingOStream &SQLDriver::CountingOStream::advance(int line) {
    while (currentLine < line) {
        std::cout.put('\n');
        currentLine++;
    }
    return *this;
}

SQLDriver::CountingOStream &SQLDriver::CountingOStream::operator<<(
    const char *str) {

    for (int i = 0; str[i] != 0; i++)
        if (str[i] == '\n')
            currentLine++;

    std::cout << str;
    return *this;
}

SQLDriver::CountingOStream &SQLDriver::CountingOStream::operator<<(char c) {
    if (c == '\n') currentLine++;
    std::cout.put(c);
    return *this;
}


void SQLParser::error(const SQLParser::location_type &l,
    const std::string &m) {

    driver->error(l, m);
}

} // namespace bison

/* This implementation of SQLFlexLexer::yylex() is required because it is
 * declared in FlexLexer.h. The scanner's "real" yylex function is generated by
 * flex and "connected" via YY_DECL. */
#ifdef yylex
    #undef yylex
#endif
int SQLFlexLexer::yylex()
{
    std::cerr <<
        "Error: SQLFlexLexer::yylex() was called. Use SQLScanner::lex() instead"
        << std::endl;
    return 0;
}

int    main(int argc, char **argv)
{
    std::istream        *inStream = NULL;
    std::string         filename = "<stdin>";
    bool                error = false;
    bool                customFileName = false;

    for (int i = 1; i < argc; i++) {
        if (std::strcmp(argv[1], "-f") == 0) {
            if (i < argc - 1) {
                filename = argv[++i];
                customFileName = true;
            } else {
                error = true;
                break;
            }
        } else if (inStream == NULL) {
            inStream = new std::ifstream(argv[i]);
            if (!customFileName)
                filename = argv[i];
        }
    }
    if (error) {
        std::cerr << "Usage: " << argv[0] << " [-f customFileName] [inputFile]"
            << std::endl;
        return 1;
    }

    bison::SQLDriver    driver(argv[0], filename);
    bison::SQLScanner    scanner(inStream); driver.scanner = &scanner;
    bison::SQLParser    parser(&driver);

    int result = parser.parse();

    if (inStream != NULL)
        delete inStream;

    if (result != 0)
        return result;

    std::cout << '\n';

    /*
    std::cout << "// List of functions:\n";
    for (std::map<std::string,char *>::iterator it = driver.fnToReturnType.begin();
        it != driver.fnToReturnType.end(); it++)
        std::cout << "// " << (*it).first << ": return type " << (*it).second << std::endl;
    */
    return 0;
}

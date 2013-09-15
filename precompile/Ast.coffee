fs = require 'fs'

class Enum
  #constructor: (h) ->
  #  for own k, v of h
  #    @[k] = name: k, id: v
  constructor: (a) ->
    @[v] = i+1 for v, i in a

# ascii-based characters
CHAR =
  SPACE: ' ', TAB: "\t", CR: "\r", LF: "\n", EXCLAIMATION: '!', DOUBLE_QUOTE: '"',
  SINGLE_QUOTE: "'", POUND: '#', DOLLAR: '$', PERCENT: '%', AMPERSAND: '&', 
  OPEN_PARENTHESIS: '(', CLOSE_PARENTHESIS: ')', ASTERISK: '*', PLUS: '+', 
  COMMA: ',', HYPHEN: '-', PERIOD: '.', SLASH: '/', COLON: ':', SEMICOLON: ';', 
  LESS: '<', EQUAL: '=', GREATER: '>', QUESTION: '?', AT: '@', OPEN_BRACKET: '[',
  CLOSE_BRACKET: ']', BACKSLASH: "\\", CARET: '^', UNDERSCORE: '_', GRAVE: '`', 
  OPEN_BRACE: '{', CLOSE_BRACE: '}', BAR: '|', TILDE: '~'

INDENT = new Enum 'SPACE', 'TAB', 'MIXED'

# a symbol represents a group of one or more neighboring characters
class Symbol
  constructor: (@tokens, @types, meta={}) -> # (TOKEN[], SYMBOL[], Object?): void
    @[k] = v for own k, v of meta
    return
# in our system, symbols are like tags; a node can have multiple of them
# but only a few make sense together
SYMBOL = new Enum
  'LINEBREAK','INDENT','NONSPACE','KEYWORD','LETTER','IDENTIFIER','OPERATOR',
  'LITERAL','STRING','NUMBER','INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION',
  'QUOTE','PARENTHESIS','BRACKET','BRACE','PAIR','OPEN','CLOSE',
  'COMMENT','LINE_COMMENT','MULTILINE_COMMENT','OPEN_MULTILINE_COMMENT',
  'CLOSE_MULTILINE_COMMENT','OPEN_MULTILINE_STRING',
  'CLOSE_MULTILINE_STRING','INC_LEVEL','DEC_LEVEL','OPEN_STRING',
  'CLOSE_STRING','OPEN_MULTILINE','CLOSE_MULTILINE'

# syntax
SYNTAX =
  JAVA: # proprietary to java
    KEYWORDS:
      'abstract','assert','boolean','break','byte','case','catch',
      'char','class','const','continue','default','do','double','else',
      'enum','extends','finally','float','for','goto','if','implements',
      'import','instanceof','int','interface','long','native','new',
      'package','private','protected','public','return','short','static',
      'strictfp','super','switch','synchronized','this','throw','throws',
      'transient','try','void','volatile','while'
    LITERALS: 'false','null','true'

module.exports =
class Ast # Parser
  constructor: ->

  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return

  compile: (file, buf) -> # public (String, String): void
    tokens = @lexer buf # distinguish lines, space, and words
    tokens = @tokenizer tokens # distinguish keywords, operators, identifiers
    tree   = @syntaxer tokens # create Abstract Syntax Tree (AST)

  lexer: (buf) -> # (String): TOKEN[]
    len   = buf.length # number
    char  = 1
    zchar = -1 # zero-indexed
    level = 0
    line  = 1
    symbol_array = []
    word_on_this_line = false
    space_buf = ''
    word_buf = ''
    indent_buf = ''
    indent_type_this_line = undefined
    tokens = []
    push_symbol = (chars, symbol, meta={}) -> # (String, SYMBOL): void
      meta.line = line; meta.char = char
      symbol_array.push new Symbol chars, [symbol], meta
      return
    slice_line_buf = (chars, symbol) -> # (int, SYMBOL): void
      push_symbol chars, symbol
      line++
      zchar += chars-1
      word_on_this_line = false
      indent_type_this_line = undefined
      return
    slice_word_buf = -> # (void): void
      if word_buf.length
        push_symbol word_buf, SYMBOL.NONSPACE
        word_on_this_line ||= true
        word_buf = ''
      return
    slice_space_buf = -> # (void): void
      if indent_buf.length
        push_symbol indent_buf, SYMBOL.INDENT
        indent_buf = ''
      else if space_buf.length
        push_symbol space_buf, SYMBOL.SPACE
        word_buf = ''
      return
    lookahead = (n) -> buf[zchar+n] # (int): void
    while ++zchar < len # iterate every character in buffer
      c = buf[zchar]
      char = zchar + 1

###
ok, so, the job of the lexer is to establish rules about
document format, line breaks, indentation
and to build a basic table of those types of common symbols
shared by all languages
incl. line, char, and level positioning of symbols
in some languages, indentation is ignored, but it should
still be measured while we're looping here
because multiple languages can share the same lexer
so the information it should gather about the indentation should be:
  exact string (which you can also get .length of)
  whether its SPACES, TABS, or MIXED
###

      # count win/mac/unix line-breaks
      if c is CHAR.CR and lookahead(1) is CHAR.LF # windows
        slice_line_buf 2
        continue
      else if c is CHAR.CR or c is CHAR.LF # mac or linux
        slice_line_buf 1
        continue
      else

      # count indentation
      if c is CHAR.SPACE or c is CHAR.TAB # whitespace
        slice_word_buf()
        if word_on_this_line # spacing
          # spacing inbetween characters doesn't usually matter so we won't count it
          space_buf += c
        else # indentation
          if c is CHAR.SPACE
            indent_type_this_line ||= if indent_type_this_line is INDENT.TAB then INDENT.MIXED else INDENT.SPACE
          else if c is CHAR.TAB
            indent_type_this_line ||= if indent_type_this_line is INDENT.SPACE then INDENT.MIXED else INDENT.TAB
          indent_buf += c
        continue
      else # word
        slice_space_buf()
        word_buf += c
        continue

    return tokens

  # TODO: call this symbolizer; groups one or more tokens into symbols
  tokenizer: (tokens) -> # (TOKEN[]): TOKEN[]

    pairables = [
      type: SQUARE_BRACKET.OPEN, line: 1, char: 2, token: TOKEN
      type: SQUARE_BRACKET.CLOSE, line: 2, char: 33, token: TOKEN
    ]
    pairables_by_xy =
      1:
        2: token
      2:
        33: token
    for own token in tokens
      switch token.char
        when ' '


    return tokens

  syntaxer: (tokens) -> # (TOKEN[]): SyntaxTree
    return {}













  pretty_print: ->
    return
    process.stdout.write "\n"
    for line in @lines
      n = line
      process.stdout.write '( '
      toString = (n) -> "(#{n.node_type.name} #{n.token}) "
      process.stdout.write toString n
      while n = n.right
        process.stdout.write toString n
      process.stdout.write " )\n"


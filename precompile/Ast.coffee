fs = require 'fs'

class Enum
  #constructor: (h) ->
  #  for own k, v of h
  #    @[k] = name: k, id: v
  constructor: (a) ->
    for v, i in a
      @[i] = name: i, id: v

# a token represents a character
class Token
  constructor: (@character, @types, options={}) -> # (Char, TOKEN[], Object?): void
    @[k] = v for own k, v of options
    return
# token types shared among all ASCII-based programming languages
TOKEN = new Enum
  'SPACE','TAB','CR','LF','EXCLAMATION','DOUBLE_QUOTE','SINGLE_QUOTE',
  'POUND','DOLLAR','PERCENT','AMPERSAND', 'OPEN_PARENTHESIS',
  'CLOSE_PARENTHESIS','ASTERISK','PLUS','COMMA', 'HYPHEN','PERIOD',
  'SLASH','COLON','SEMICOLON','LESS','EQUAL','GREATER','QUESTION','AT',
  'OPEN_BRACKET','CLOSE_BRACKET','BACKSLASH','CARET','UNDERSCORE',
  'GRAVE','OPEN_BRACE','CLOSE_BRACE','BAR','TILDE'

# a symbol represents a group of one or more neighboring characters
class Symbol
  constructor: (@tokens, @types, options={}) -> # (TOKEN[], SYMBOL[], Object?): void
    @[k] = v for own k, v of options
    return
# in our system, symbols are like tags; a node can have multiple of them
# but only a few make sense together
SYMBOL = new Enum
  'CRLF','WORD','KEYWORD','LETTER','IDENTIFIER','OPERATOR','LITERAL',
  'STRING','NUMBER','INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION',
  'QUOTE','PARENTHESIS','BRACKET','BRACE','PAIR','OPEN','CLOSE',
  'COMMENT','LINE_COMMENT','MULTILINE_COMMENT','OPEN_MULTILINE_COMMENT',
  'CLOSE_MULTILINE_COMMENT','OPEN_MULTILINE_STRING',
  'CLOSE_MULTILINE_STRING','OPEN_LEVEL','CLOSE_LEVEL','OPEN_STRING',
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
    lines = []
    line_buf = ''
    slice_line_buf = (divider_char_size) -> # (int): void
      lines.push line_buf
      line++
      line_buf = ''
      zchar += divider_char_size
      return
    space_buf = ''
    word_buf = ''
    tokens = []
    push_token = (token, type) -> # (String, Int): void
      tokens.push new Token token, [type], line: line, char: char
      return
    slice_word_buf = => # (void): void
      if word_buf.length
        push_token word_buf, TOKEN.WORD
        word_buf = ''
      return
    slice_space_buf = => # (void): void
      if space_buf.length
        push_token space_buf, TOKEN.SPACE
        word_buf = ''
      return

    while ++zchar < len # iterate every character in buffer
      c = buf[zchar]
      char = zchar + 1
      # split by win/mac/unix line-breaks
      if c is "\r" and buf[zchar+1] is "\n" # windows
        slice_line_buf 1
        continue
      else if c is "\r" or c is "\n" # mac or linux
        slice_line_buf 0
        continue
      else
        line_buf += c

      # split by token boundaries
      new Token


      switch c
        when ' ' then 
        when "\t"
      if c is ' ' or c is "\t" # spacing
        slice_word_buf() # TODO: designate token types here
        space_buf += c
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

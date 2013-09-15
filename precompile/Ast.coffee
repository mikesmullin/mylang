fs = require 'fs'

class Enum
  constructor: (a) ->
    for v, i in a
      @[v] = enum: v

# ascii-based characters
CHAR =
  SPACE: ' ', TAB: "\t", CR: "\r", LF: "\n", EXCLAIMATION: '!', DOUBLE_QUOTE: '"',
  SINGLE_QUOTE: "'", POUND: '#', DOLLAR: '$', PERCENT: '%', AMPERSAND: '&',
  OPEN_PARENTHESIS: '(', CLOSE_PARENTHESIS: ')', ASTERISK: '*', PLUS: '+', 
  COMMA: ',', HYPHEN: '-', PERIOD: '.', SLASH: '/', COLON: ':', SEMICOLON: ';',
  LESS: '<', EQUAL: '=', GREATER: '>', QUESTION: '?', AT: '@', OPEN_BRACKET: '[',
  CLOSE_BRACKET: ']', BACKSLASH: "\\", CARET: '^', UNDERSCORE: '_', GRAVE: '`',
  OPEN_BRACE: '{', CLOSE_BRACE: '}', BAR: '|', TILDE: '~'

INDENT = new Enum ['SPACE', 'TAB', 'MIXED']

# a symbol represents a group of one or more neighboring characters
class Symbol
  constructor: (@chars, @types, meta={}) -> # (TOKEN[], SYMBOL[], Object?): void
    @[k] = v for own k, v of meta
    return
# in our system, symbols are like tags; a node can have multiple of them
# but only a few make sense together
SYMBOL = new Enum ['LINEBREAK','INDENT','SPACE','NONSPACE','KEYWORD','LETTER',
  'IDENTIFIER','OPERATOR',
  'LITERAL','STRING','NUMBER','INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION',
  'QUOTE','PARENTHESIS','BRACKET','BRACE','PAIR','OPEN','CLOSE',
  'COMMENT','LINE_COMMENT','MULTILINE_COMMENT','OPEN_MULTILINE_COMMENT',
  'CLOSE_MULTILINE_COMMENT','OPEN_MULTILINE_STRING',
  'CLOSE_MULTILINE_STRING','INC_LEVEL','DEC_LEVEL','OPEN_STRING',
  'CLOSE_STRING','OPEN_MULTILINE','CLOSE_MULTILINE']

# syntax
SYNTAX =
  JAVA: # proprietary to java
    KEYWORDS: ['abstract','assert','boolean','break','byte','case','catch',
      'char','class','const','continue','default','do','double','else',
      'enum','extends','finally','float','for','goto','if','implements',
      'import','instanceof','int','interface','long','native','new',
      'package','private','protected','public','return','short','static',
      'strictfp','super','switch','synchronized','this','throw','throws',
      'transient','try','void','volatile','while']
    LITERALS: ['false','null','true']

module.exports =
class Ast # Parser
  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return

  compile: (file, buf) ->
    symbol_array = @lexer buf # distinguish lines, indentation, spacing, and words/non-spacing
    symbol_array = @symbolizer symbol_array # distinguish keywords, operators, identifiers in source language
    tree = @syntaxer symbol_array # create Abstract Syntax Tree (AST)

  lexer: (buf) ->
    c = ''
    len = buf.length # number
    byte = 1 # buffer cursor
    char = 0 # starts at one, resets with new lines
    line = 1
    level = 0
    zbyte = -1 # zero-indexed
    word_buf = ''
    space_buf = ''
    indent_buf = ''
    symbol_array = []
    word_on_this_line = false
    indent_type_this_line = undefined

    push_symbol = (chars, symbol, meta={}) ->
      meta.line = line; meta.char = char - chars.length; meta.byte = byte - chars.length
      symbol_array.push new Symbol chars, [symbol], meta
      return
    slice_word_buf = ->
      if word_buf.length
        push_symbol word_buf, SYMBOL.NONSPACE
        word_on_this_line ||= true
        word_buf = ''
      return
    slice_space_buf = ->
      if indent_buf.length
        push_symbol indent_buf, SYMBOL.INDENT, indent_type: indent_type_this_line
        indent_buf = ''
      else if space_buf.length
        push_symbol space_buf, SYMBOL.SPACE
        space_buf = ''
      return
    slice_line_buf = (num_chars) ->
      slice_space_buf()
      slice_word_buf()
      push_symbol buf.substr(zbyte,num_chars), SYMBOL.LINEBREAK
      line++
      char = 0
      zbyte += num_chars-1
      word_on_this_line = false
      indent_type_this_line = undefined
      return

    peekahead = (n) -> buf[zbyte+n]
    while ++zbyte < len # iterate every character in buffer
      #unless char is 0
      #  console.log c: c, byte: byte, symbol_array: JSON.stringify symbol_array
      c = buf[zbyte]
      byte = zbyte + 1
      ++char
      #if zbyte > 20 then process.exit 0

      # slice on win/mac/unix line-breaks
      if c is CHAR.CR and peekahead(1) is CHAR.LF # windows
        slice_line_buf 2
      else if c is CHAR.CR or c is CHAR.LF # mac or linux
        slice_line_buf 1

      # slice on whitespace
      else if c is CHAR.SPACE or c is CHAR.TAB # whitespace
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
      else # word/non-space
        slice_space_buf()
        word_buf += c

    slice_line_buf()
    return symbol_array

  # group one or more characters into symbols
  # also index possible pairs
  symbolizer: (symbol_array) ->
    console.log JSON.stringify symbol_array.slice(0, 10)
    #pairables = [
    #  type: SQUARE_BRACKET.OPEN, line: 1, char: 2, token: TOKEN
    #  type: SQUARE_BRACKET.CLOSE, line: 2, char: 33, token: TOKEN
    #]
    #pairables_by_xy =
    #  1:
    #    2: token
    #  2:
    #    33: token
    #for own symbol in symbol_array
    #  switch token.char
    #    when ' '
    return symbol_array

  syntaxer: (symbol_array) ->
    return {}

  pretty_print: ->
    return
    #process.stdout.write "\n"
    #for line in @lines
    #  n = line
    #  process.stdout.write '( '
    #  toString = (n) -> "(#{n.node_type.name} #{n.token}) "
    #  process.stdout.write toString n
    #  while n = n.right
    #    process.stdout.write toString n
    #  process.stdout.write " )\n"

fs = require 'fs'
deepCopy = (obj) ->
  if Object::toString.call(obj) is "[object Array]"
    out = []
    i = 0
    len = obj.length
    while i < len
      out[i] = arguments.callee(obj[i])
      i++
    return out
  if typeof obj is "object"
    out = {}
    i = undefined
    for i of obj
      out[i] = arguments.callee(obj[i])
    return out
  obj

class Enum
  constructor: (a) -> @[v] = enum: v for v, i in a

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
  constructor: (@chars, @types, meta={}) ->
    @[k] = v for own k, v of meta
    return
  # TODO: can probably make these all class members instead of instance members
  pushUniqueType: (v) ->
    @types.push v if -1 is @types.indexOf v
    return
  hasType: (type) ->
    return true for _type in @types when  _type.enum is type.enum
    return false
  removeType: (type) ->
    for _type, i in @types when _type.enum is type.enum
      @types.splice i, 1
      return
  clone: (char_delta, new_chars) ->
    symbol = deepCopy @
    symbol.chars = new_chars if new_chars
    symbol.char += char_delta
    return symbol
  split: (index, len, arr, i) ->
    l = @chars.length
    args = [i, 1]
    if index > 0
      args.push @clone 0, @chars.substr 0, index # left
    args.push @clone index, @chars.substr index, len # middle
    if ll = l-index-len > 0
      args.push @clone index+len, @chars.substr index+len, ll # right
    Array::splice.apply arr, args
    return [arr[i+1], args.length - 3]
  merge: (arr, i, len) ->
    # TODO: also adjust char position
    symbol = arr[i]
    for ii in [i+1..len+1]
      for own k, v of arr[ii]
        if k is 'chars'
          symbol[k] += v
        else if k is 'types'
          symbol[k] ||= []
          for vv in v
            symbol.pushUniqueType vv
        else
          if Object::toString.call(v) is "[object Array]"
            for vv in v
              symbol[k] ||= []
              symbol[k].push vv
          else if typeof v is 'object'
            for own kk, vv of v
              symbol[k] ||= {}
              symbol[k][kk] = vv
          else
            symbol[k] = v
    arr.splice i, len, symbol
    return [arr[i], len*-1]

# in our system, symbols are like tags; a node can have multiple of them
# but only a few make sense together
SYMBOL = new Enum ['LINEBREAK','INDENT','SPACE','WORD','NONWORD','KEYWORD','LETTER',
  'IDENTIFIER','OPERATOR','STATEMENT_END',
  'LITERAL','STRING','NUMBER','INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION',
  'QUOTE','PARENTHESIS','BRACKET','BRACE','PAIR','OPEN','CLOSE',
  'COMMENT','LINE_COMMENT','MULTILINE_COMMENT','OPEN_MULTILINE_COMMENT',
  'CLOSE_MULTILINE_COMMENT','OPEN_MULTILINE_STRING',
  'CLOSE_MULTILINE_STRING','INC_LEVEL','DEC_LEVEL','OPEN_STRING',
  'CLOSE_STRING','OPEN_MULTILINE','CLOSE_MULTILINE']

OPERATOR = new Enum ['UNARY_LEFT','UNARY_RIGHT','BINARY_LEFT_RIGHT',
  'BINARY_LEFT_LEFT','BINARY_RIGHT_RIGHT','TERNARY_RIGHT_RIGHT_RIGHT']

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
    OPERATORS: [
      { type: OPERATOR.UNARY_LEFT, name: 'postfix', symbols: [ '++', '--' ] }
      { type: OPERATOR.UNARY_RIGHT, name: 'unary', symbols: ['++', '--', '+', '-', '~', '!'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'multiplicative', symbols: ['*', '/', '%'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'additive', symbols: ['+', '-'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'shift', symbols: ['<<', '>>', '>>>'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'relational', symbols: ['<', '>', '<=', '>=', 'instanceof'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'equality', symbols: ['==', '!='] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise AND', symbols: ['&'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise exclusive OR', symbols: ['^'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise inclusive OR', symbols: ['|'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'logical AND', symbols: ['&&'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'logical OR', symbols: ['||'] }
      { type: OPERATOR.TERNARY_RIGHT_RIGHT_RIGHT, name: 'ternary', symbols: [['?',':']] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'assignment', symbols: ['=', '+=', '-=', '*=', '/=', '%=', '&=', '^=', '|=', '<<=', '>>=', '>>>='] }
    ]
    PAIRS: [
      { name: 'index', symbols: ['[', ']'] }
      { name: 'arguments', symbols: ['(', ')'] }
      { name: 'generic', symbols: ['<', '>'] }
      { name: 'block', symbols: ['{', '}'] }
      { name: 'string', symbols: ['"', '"'] }
      { name: 'character', symbols: ["'", "'"] }
      { name: 'multi-line comment', symbols: ['/*', '*/'] }
      { name: 'single-line comment', symbols: ['//'] } # no match means until end of line
      # TODO: heredocs would go here, too, if Java had any
    ]


module.exports =
class Ast # Parser
  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return

  compile: (file, buf) ->
    symbol_array = @lexer buf # distinguish lines, indentation, spacing, words, and non-words
    symbol_array = @java_symbolizer symbol_array # distinguish keywords, operators, identifiers in source language
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
    nonword_buf = ''
    symbol_array = []
    word_on_this_line = false
    indent_type_this_line = undefined

    push_symbol = (chars, symbol, meta={}) ->
      meta.line = line; meta.char = char - chars.length; meta.byte = byte - chars.length
      symbol_array.push new Symbol chars, [symbol], meta
      return
    slice_word_buf = ->
      if word_buf.length
        push_symbol word_buf, SYMBOL.WORD
        word_on_this_line ||= true
        word_buf = ''
      return
    slice_nonword_buf = ->
      if nonword_buf.length
        push_symbol nonword_buf, SYMBOL.NONWORD
        word_on_this_line ||= true
        nonword_buf = ''
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
      # TODO: link symbols by line_group array, in addition to line numbers
      slice_space_buf()
      slice_nonword_buf()
      slice_word_buf()
      if zbyte < len
        push_symbol buf.substr(zbyte,num_chars), SYMBOL.LINEBREAK
        line++
        char = 0
        zbyte += num_chars-1
        word_on_this_line = false
        indent_type_this_line = undefined
      return

    peekahead = (n) -> buf[zbyte+n]
    while ++zbyte < len # iterate every character in buffer
      c = buf[zbyte]
      byte = zbyte + 1
      ++char

      # slice on win/mac/unix line-breaks
      if c is CHAR.CR and peekahead(1) is CHAR.LF # windows
        slice_line_buf 2
      else if c is CHAR.CR or c is CHAR.LF # mac or linux
        slice_line_buf 1

      # slice on whitespace
      else if c is CHAR.SPACE or c is CHAR.TAB # whitespace
        slice_nonword_buf()
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
      else
        slice_space_buf()
        if c.match /[a-zA-Z0-9_]/ # word character
          slice_nonword_buf()
          word_buf += c
        else # non-word character
          slice_word_buf()
          nonword_buf += c

    slice_line_buf()
    return symbol_array

  # group one or more characters into symbols
  # also index possible pairs
  java_symbolizer: (symbol_array) ->
    pairables = []
    i = -1
    len = symbol_array.length
    lookahead = (n) ->
      i += n
      next_symbol()
      symbol = symbol_array[i]
      i -= n
      return symbol
    next_symbol = =>
      symbol = symbol_array[i]
      console.log "i is #{i}"
      # TODO: detect whether we are currently inside of a pair (e.g. string, comment) and ignore if needed

      if symbol.hasType SYMBOL.WORD
        console.log 'its a word'
        # keywords
        # TODO: validate that keywords have space or pairs around them but not dots--or else its not a keyword
        for keyword in SYNTAX.JAVA.KEYWORDS
          if symbol.chars is keyword
            symbol.pushUniqueType SYMBOL.KEYWORD
            return

        # literals
        for literal in SYNTAX.JAVA.LITERALS
          if symbol.chars is literal
            symbol.pushUniqueType SYMBOL.LITERAL
            return

        # number
        if symbol.chars.match /^-?\d+$/
          symbol.pushUniqueType SYMBOL.NUMBER
          if lookahead(1).chars is '.' and lookahead(2).hasType SYMBOL.NUMBER
            # merge the next two together
            [symbol, delta] = symbol.merge symbol_array, i, 3
            len += delta
            symbol.pushUniqueType SYMBOL.DECIMAL
            symbol.removeType SYMBOL.NONWORD
            symbol.removeType SYMBOL.INTEGER
          else
            symbol.pushUniqueType SYMBOL.INTEGER
          return

        # hexadecimal
        if symbol.chars.match /^0x[0-9a-fA-F]+$/
          symbol.pushUniqueType SYMBOL.NUMBER
          symbol.pushUniqueType SYMBOL.HEX
          return

        # anything else must be
        # identifiers
        symbol.pushUniqueType SYMBOL.IDENTIFIER

      else if symbol.hasType SYMBOL.NONWORD
        console.log "its a nonword #{symbol.chars}"
        match_symbol = (chars, success_cb) ->
          unless -1 is (p = symbol.chars.indexOf chars) # partial match, at least
            if symbol.chars is chars # full match
              success_cb()
            else
              console.log "matched symbol #{chars} in #{symbol.chars}"
              [symbol, delta] = symbol.split p, chars.length, symbol_array, i
              len += delta # resize length
              console.log "and adjusted len by +#{delta}"
              --i # backup and re-evaluate since we split
            return true
          return false

        # statement end
        return if match_symbol ';', ->
          symbol.pushUniqueType SYMBOL.STATEMENT_END

        # TODO: do something about operators and pairs that are next to each other in the same NONWORD
        # operators
        for operator in SYNTAX.JAVA.OPERATORS
          for chars in operator.symbols
            return if match_symbol chars, ->
              console.log "found symbol #{chars} in #{symbol.chars}"
              symbol.pushUniqueType SYMBOL.OPERATOR
              symbol.operator =
                type: operator.type
                name: operator.name

        # pairs
        # TODO: use braces pairs to determine symbol level for all symbols inbetween
        for pair in SYNTAX.JAVA.PAIRS
          for chars, k in pair.symbols
            # TODO: collapse symbols (e.g. a line_group containing only '@Override' as a NON-SPACE is one symbol plus spacing
            # how best to do this confidently? hmm... precedence? confidence levels with last step being collapse or split?
            # this is probably best moved to the syntaxer step if we cannot decide here
            return if match_symbol chars, ->
              console.log "found pair #{chars} in #{symbol.chars} at #{i}"
              symbol.pushUniqueType SYMBOL.PAIR
              if k is 0 then symbol.pushUniqueType SYMBOL.OPEN
              if k is 1 then symbol.pushUniqueType SYMBOL.CLOSE
              symbol.pair =
                name: pair.name
              pairables.push symbol


    next_symbol() while ++i < len

    @pretty_print_symbol_array symbol_array
    #console.log pairables
    return symbol_array

  syntaxer: (symbol_array) ->
    return {}

  pretty_print: ->
    return

  pretty_print_symbol_array: (symbol_array) ->
    process.stdout.write "\n"
    last_line = 1
    i = 0
    process.stdout.write '( '
    for symbol in symbol_array
      return if ++i > 50
      types = []; types.push type.enum for type in symbol.types; types = types.join ', '
      toString = -> "(#{symbol.line} #{types} #{JSON.stringify symbol.chars}) "
      if last_line isnt symbol.line
        last_line = symbol.line
        process.stdout.write " )\n( "
      process.stdout.write toString symbol
    process.stdout.write " )\n"

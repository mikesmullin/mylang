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
  hasType: (types...) ->
    for _type in @types
      for __type in types
        if _type.enum is __type.enum
          return true
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
    if (ll = l-index-len) > 0
      args.push @clone index+len, @chars.substr index+len, ll # right
    Array::splice.apply arr, args
    return [arr[i+1], args.length - 3]
  merge: (arr, i, len) ->
    symbol = arr[i]
    for ii in [i+1...i+len]
      for own k, v of arr[ii]
        if k is 'chars'
          symbol[k] += v
        else if k is 'types'
          symbol[k] ||= []
          for vv in v
            symbol.pushUniqueType vv
        else if k is 'line' or k is 'char'
          symbol[k] = Math.min symbol[k], v
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
SYMBOL = new Enum ['LINEBREAK','INDENT','WHITESPACE','WORD','NONWORD','KEYWORD',
  'LETTER','IDENTIFIER','OPERATOR','STATEMENT_END','LITERAL','STRING','NUMBER',
  'INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION','PARENTHESIS',
  'SQUARE_BRACKET','ANGLE_BRACKET','BRACE','PAIR','OPEN','CLOSE','INC_LEVEL',
  'DEC_LEVEL','COMMENT','ENDLINE_COMMENT','MULTILINE_COMMENT']

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
    PAIRS: [ # ordered by precendence
      { name: 'multi-line comment', types: [SYMBOL.COMMENT, SYMBOL.MULTILINE_COMMENT], symbols: ['/*', '*/'] }
      { name: 'single-line comment', types: [SYMBOL.COMMENT, SYMBOL.ENDLINE_COMMENT], symbols: ['//'] } # no match means until end of line
      { name: 'string', types: [SYMBOL.STRING], symbols: ['"', '"'] , escaped_by: '\\'}
      { name: 'character', types: [SYMBOL.STRING], symbols: ["'", "'"] , escaped_by: '\\'}
      { name: 'block', types: [SYMBOL.BRACE], symbols: ['{', '}'] }
      { name: 'arguments', types: [SYMBOL.PARENTHESIS], symbols: ['(', ')'] }
      { name: 'generic', types: [SYMBOL.ANGLE_BRACKET], symbols: ['<', '>'] }
      { name: 'index', types: [SYMBOL.BRACKET], symbols: ['[', ']'] }
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
    symbol_array = @lexer file, buf # distinguish lines, indentation, spacing, words, and non-words
    symbol_array = @symbolizer symbol_array # distinguish keywords, literals, identifiers in source language
    tree = @syntaxer symbol_array # create Abstract Syntax Tree (AST)

  lexer: (file, buf) ->
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

    throwError = (msg) -> throw new Error "#{file}:#{line}:#{char}: #{msg}"
    peek = (n, l=1) -> buf.substr zbyte+n, l
    is_eol = (i) ->
      return if buf[i] is CHAR.CR and buf[i+1] is CHAR.LF then 2 # windows
      else if buf[i] is CHAR.CR or buf[i] is CHAR.LF then 1 # mac or linux
      else false
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
        push_symbol space_buf, SYMBOL.WHITESPACE
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
        zbyte += num_chars-1 # skip ahead
        word_on_this_line = false
        indent_type_this_line = undefined
      return
    is_pair = ->
      for pair in SYNTAX.JAVA.PAIRS
        for search, k in pair.symbols
          if search is peek 0, search.length
            symbol = new Symbol search, [], line: line, char: char, byte: byte, pair: name: pair.name
            symbol.pushUniqueType type for type in pair.types

            # some pairs require that we find their endings immediately
            # e.g., comments
            if symbol.hasType SYMBOL.COMMENT
              if pair.symbols.length is 1 # no ending symbol means match to EOL
                x = zbyte; while ++x < len and false is is_eol(x) # EOL or EOF whichever is first
                  ;
                symbol.chars = buf.substr zbyte, x-zbyte
                return [symbol, x-zbyte]
              else
                # finds end of pairs where nothing inbetween is allowed and the end cannot be escaped
                if -1 isnt x = buf.indexOf pair.symbols[1], zbyte + search.length + pair.symbols[1].length
                  symbol.chars = buf.substr zbyte, x-zbyte+pair.symbols[1].length
                  return [symbol, x-zbyte+pair.symbols[1].length]
                else
                  throwError "unmatched comment pair \"#{search}\""

            # e.g., strings
            if symbol.hasType SYMBOL.STRING
              # finds end of pairs where nothing inbetween is allowed but the ending can be escaped; e.g., strings
              find_end_of_escaped_pair = (buf, start, match, escape) ->
                i = start
                while -1 isnt (i = buf.indexOf match, i+match.length)
                  unless escape and buf[i-escape.length] is escape
                    return i
                return -1
              if -1 isnt x = find_end_of_escaped_pair buf, zbyte+1, pair.symbols[1], pair.escaped_by
                symbol.chars = buf.substr zbyte, x-zbyte+1
                return [symbol, x-zbyte+1]
              else
                throwError "unmatched string pair \"#{search}\""

            # remaining pairs dont require us to find the ending
            # so we just mark them with separate opening and closing symbols
            symbol.pushUniqueType SYMBOL.PAIR
            symbol.pushUniqueType SYMBOL.OPEN if k is 0 or pair.symbols[0] is pair.symbols[1]
            symbol.pushUniqueType SYMBOL.CLOSE if k is 1 or pair.symbols[0] is pair.symbols[1]
            return [symbol, search.length]
    is_operator = ->
      for operator in SYNTAX.JAVA.OPERATORS
        for search in operator.symbols
          if search is peek 0, search.length
            symbol = new Symbol search, [SYMBOL.OPERATOR], line: line, char: char, byte: byte, operator: type: operator.type, name: operator.name
            return [symbol, search.length]
      return false

    while ++zbyte < len # iterate every character in buffer
      c = buf[zbyte]
      byte = zbyte + 1
      ++char

      # slice on win/mac/unix line-breaks
      if x = is_eol(zbyte) then slice_line_buf x

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

          if r = is_pair()
            [symbol, x] = r
            symbol_array.push symbol
            zbyte += x-1 # skip ahead
            continue

          # terminator
          if c is CHAR.SEMICOLON
            symbol_array.push new Symbol c, [SYMBOL.STATEMENT_END], line: line, char: char, byte: byte
            continue

          # operators
          if r = is_operator()
            [symbol, x] = r
            symbol_array.push symbol
            zbyte += x-1 # skip ahead
            continue

          nonword_buf += c

    slice_line_buf()
    return symbol_array

  # group one or more characters into symbols
  # also index possible pairs
  symbolizer: (symbol_array) ->
    i = -1
    len = symbol_array.length
    open_pairs = []
    lookaround = (n) ->
      old_i = i
      target_i = i + n
      while i < target_i
        i++
        next_symbol()
      symbol = symbol_array[i]
      i = old_i
      return symbol
    next_symbol = =>
      symbol = symbol_array[i]
      # TODO: detect whether we are currently inside of a pair (e.g. string, comment) and ignore if needed

      if symbol.hasType SYMBOL.WORD
        # keywords
        if ( # can only have whitespace or pairs around them
          (i is 0 or lookaround(-1).hasType SYMBOL.WHITESPACE, SYMBOL.PAIR) and
          (i is len or lookaround(1).hasType SYMBOL.WHITESPACE, SYMBOL.PAIR)
        )
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
          if lookaround(1).chars is '.' and lookaround(2).hasType SYMBOL.NUMBER
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
        symbol.types = [SYMBOL.IDENTIFIER]

      else if symbol.hasType SYMBOL.NONWORD
        1
        # TODO: later, determine type of opener by surroundings
        #       openers preceeded by identifiers are types of _START
        #       closers are based on last opener

    next_symbol() while ++i < len

    @pretty_print_symbol_array symbol_array
    #console.log pairables
    return symbol_array

  syntaxer: (symbol_array) ->
    # TODO: use braces pairs to determine symbol level for all symbols inbetween
    # TODO: close to the next pair that is not escaped (e.g., \", or ")" )
    # TODO: i should probably process pairs first and use lookahead until their mate is found
    #       in case the middle bits can be excluded from parsing
    # TODO: all symbols within a pair should have access to some .parentGroup value so e.g. from within a generic you can find its boundaries and members without parsing
    #       probably same with a class;
    # TODO: collapse symbols (e.g. a line_group containing only '@Override' as a NON-SPACE is one symbol plus spacing
    # how best to do this confidently? hmm... precedence? confidence levels with last step being collapse or split?
    # this is probably best moved to the syntaxer step if we cannot decide here
    # TODO: should group by all the logical ways here:
    #  classes, function, function arguments, generic, index, switch statement, for loop, etc.


    return {}

  pretty_print_symbol_array: (symbol_array) ->
    process.stdout.write "\n"
    last_line = 1
    for symbol, i in symbol_array
      return if i > 80
      types = []; types.push type.enum for type in symbol.types; types = types.join ', '
      toString = -> "(#{i}:#{symbol.line}:#{symbol.char} #{types} #{JSON.stringify symbol.chars}) "
      if last_line isnt symbol.line
        last_line = symbol.line
        process.stdout.write " )\n( "
      process.stdout.write toString symbol
    process.stdout.write "\n"

  # TODO: do statement-at-a-time translation
  #       moving outside-in from root pairs
  #       and keeping context of requires in mind OR just recognizing undefined vars and making them @ prefixed
  translate_to_coffee: (tree) ->

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
    for ii in [i+1...len]
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
  'INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION','QUOTE','PARENTHESIS',
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
    PAIRS: [
      { name: 'index', types: [SYMBOL.BRACKET], symbols: ['[', ']'] }
      { name: 'arguments', types: [SYMBOL.PARENTHESIS], symbols: ['(', ')'] }
      { name: 'generic', types: [SYMBOL.ANGLE_BRACKET], symbols: ['<', '>'] }
      { name: 'block', types: [SYMBOL.BRACE], symbols: ['{', '}'] }
      { name: 'string', types: [SYMBOL.QUOTE, SYMBOL.STRING], symbols: ['"', '"'] }
      { name: 'character', types: [SYMBOL.QUOTE, SYMBOL.STRING], symbols: ["'", "'"] }
      { name: 'multi-line comment', types: [SYMBOL.COMMENT, SYMBOL.MULTILINE_COMMENT], symbols: ['/*', '*/'] }
      { name: 'single-line comment', types: [SYMBOL.COMMENT, SYMBOL.ENDLINE_COMMENT], symbols: ['//'] } # no match means until end of line
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
    searching_for_other_pair = false
    lookaround = (n) ->
      console.log ">>> BEGIN LOOK #{i} + #{n}"
      old_i = i
      target_i = i + n
      while i < target_i
        i++
        console.log "I IS NOW #{i}"
        next_symbol()
      symbol = symbol_array[i]
      console.log "symbol #{i} is #{JSON.stringify symbol}"
      i = old_i
      console.log "<< RETURN LOOK #{i} + #{n}"
      return symbol
    next_symbol = =>
      symbol = symbol_array[i]
      console.log "i is #{i}"
      # TODO: detect whether we are currently inside of a pair (e.g. string, comment) and ignore if needed

      if symbol.hasType SYMBOL.WORD
        console.log 'its a word'
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
        symbol.pushUniqueType SYMBOL.IDENTIFIER

      else if symbol.hasType SYMBOL.NONWORD
        console.log "its a nonword #{symbol.chars}"
        match_symbol = (chars, success_cb) ->
          unless -1 is (p = symbol.chars.indexOf chars) # partial match, at least
            if symbol.chars is chars # full match
              success_cb()
            else
              console.log "found symbol \"#{chars}\" in \"#{symbol.chars}\""
              [symbol, delta] = symbol.split p, chars.length, symbol_array, i
              len += delta # resize length
              console.log "and adjusted len by +#{delta}"
              --i # backup and re-evaluate since we split
            return true
          return false

        # pairs
        for pair in SYNTAX.JAVA.PAIRS
          for chars, k in pair.symbols
            return if match_symbol chars, ->
              console.log "found pair #{chars} in #{symbol.chars} at #{i}"
              symbol.pushUniqueType SYMBOL.PAIR
              for type in pair.types
                symbol.pushUniqueType type
              # same symbol used to both open and close
              if pair.symbols[0] is pair.symbols[1]
                symbol.pushUniqueType SYMBOL.OPEN
                symbol.pushUniqueType SYMBOL.CLOSE
              # distinct opening symbol
              else if k is 0
                symbol.pushUniqueType SYMBOL.OPEN
              # distinct closing symbol
              else if k is 1
                symbol.pushUniqueType SYMBOL.CLOSE
              symbol.pair = name: pair.name
              pairables.push symbol

              console.log "searching ", searching_for_other_pair
              Ast::pretty_print_symbol_array symbol_array

              if k is 0 and symbol.hasType(SYMBOL.STRING, SYMBOL.COMMENT) and
                  not searching_for_other_pair
                # everything inbetween these symbols can be merged into a single symbol
                # so its best to find the ending pair of these types right away
                # just lookahead to until we find the next unescaped occurrence
                ii = 0
                found = false
                searching_for_other_pair = true
                console.log "SEARCHING FOR MATE TO #{chars}... WHICH LOOKS LIKE #{pair.symbols[1]}"
                while ++ii < len-i
                  s = lookaround ii
                  console.log ""
                  console.log "+++ HAVE LOOKED FROM #{i} TO +#{ii} FINDING #{JSON.stringify s}"
                  if s.hasType(SYMBOL.PAIR) and
                      s.hasType(SYMBOL.CLOSE) and
                      (s.chars is pair.symbols[1] or pair.symbols[1] is undefined)
                    console.log 'THIS SATISFIES ME', JSON.stringify s
                    found = true
                    searching_for_other_pair = false
                    console.log "will merge from #{i} +#{ii+1}"
                    # commence symbol merge
                    [symbol, delta] = symbol.merge symbol_array, i, ii+1
                    len += delta
                    break
                unless found
                  throw "FATAL: unmatched pair \"#{symbol.chars}\" found at #{symbol.line}:#{symbol.char}."

        # statement end
        return if match_symbol ';', ->
          symbol.pushUniqueType SYMBOL.STATEMENT_END

        # operators
        for operator in SYNTAX.JAVA.OPERATORS
          for chars in operator.symbols
            return if match_symbol chars, ->
              console.log "found symbol #{chars} in #{symbol.chars}"
              symbol.pushUniqueType SYMBOL.OPERATOR
              symbol.operator =
                type: operator.type
                name: operator.name

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

  pretty_print: ->
    return

  pretty_print_symbol_array: (symbol_array) ->
    process.stdout.write "\n"
    last_line = 1
    for symbol, i in symbol_array
      return if i > 80
      types = []; types.push type.enum for type in symbol.types; types = types.join ', '
      toString = -> "(#{i} #{types} #{JSON.stringify symbol.chars}) "
      if last_line isnt symbol.line
        last_line = symbol.line
        process.stdout.write " )\n( "
      process.stdout.write toString symbol
    process.stdout.write "\n"

  # TODO: do statement-at-a-time translation
  #       moving outside-in from root pairs
  #       and keeping context of requires in mind OR just recognizing undefined vars and making them @ prefixed
  translate_to_coffee: (tree) ->

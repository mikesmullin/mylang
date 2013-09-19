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
        if _type is undefined or __type is undefined
          console.log "called hasType with ", at: @, _type: _type, __type: __type, types: types
          console.trace()
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
SYMBOL = new Enum ['LINEBREAK','INDENT','WORD','TEXT','KEYWORD',
  'LETTER','ID','OP','STATEMENT_END','LITERAL','STRING','NUMBER',
  'INTEGER','DECIMAL','HEX','REGEX','PUNCTUATION','PARENTHESIS',
  'SQUARE_BRACKET','ANGLE_BRACKET','BRACE','PAIR','OPEN','CLOSE',
  'COMMENT','ENDLINE_COMMENT','MULTILINE_COMMENT',
  'CALL','INDEX','PARAM','TERMINATOR','LEVEL_INC','LEVEL_DEC',
  'ACCESS', 'TYPE', 'CAST','GENERIC_TYPE','SUPPORT',
  'DOUBLE_SPACE']

OPERATOR = new Enum ['UNARY_LEFT','UNARY_RIGHT','BINARY_LEFT_RIGHT',
  'BINARY_LEFT_LEFT','BINARY_RIGHT_RIGHT','TERNARY_RIGHT_RIGHT_RIGHT']

# syntax
SYNTAX =
  JAVA: # proprietary to java
    KEYWORDS:
      STATEMENTS: ['case','catch','continue','default','do','else','for','if','finally','goto','return','switch','try','while','throw']
      ACCESS_MODIFIERS: ['abstract','const','private','protected','public','static','synchronized','transient','volatile','final']
      TYPES: ['boolean','double','char','float','int','long','short','void']
      OTHER: ['class','new','import','package','super','this','enum','implements','extends','instanceof','interface','native','strictfp','throws']
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
      { name: 'index', types: [SYMBOL.SQUARE_BRACKET], symbols: ['[', ']'] }
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
    symbol_array = @java_syntaxer symbol_array # create Abstract Syntax Tree (AST)
    code = @translate_to_coffee symbol_array

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
    double_space = true
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
        double_space = false
      return
    slice_nonword_buf = ->
      if nonword_buf.length
        push_symbol nonword_buf, SYMBOL.TEXT
        word_on_this_line ||= true
        nonword_buf = ''
        double_space = false
      return
    slice_space_buf = ->
      if indent_buf.length
        #push_symbol indent_buf, SYMBOL.INDENT, indent_type: indent_type_this_line # all whitespace is irrelevant in java
        indent_buf = ''
      else if space_buf.length
        #push_symbol space_buf, SYMBOL.WHITESPACE
        space_buf = ''
      return
    slice_line_buf = (num_chars) ->
      # TODO: link symbols by line_group array, in addition to line numbers
      slice_space_buf()
      slice_nonword_buf()
      slice_word_buf()
      if zbyte < len
        #push_symbol buf.substr(zbyte,num_chars), SYMBOL.LINEBREAK
        if double_space
          push_symbol buf.substr(zbyte,num_chars), SYMBOL.DOUBLE_SPACE
        line++
        char = 0
        zbyte += num_chars-1 # skip ahead
        word_on_this_line = false
        indent_type_this_line = undefined
        double_space = true
      return
    is_pair = ->
      for pair in SYNTAX.JAVA.PAIRS
        for search, k in pair.symbols
          if search is peek 0, search.length
            double_space = false
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
                while -1 isnt (i = buf.indexOf match, i+match.length-1)
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
            double_space = false
            symbol = new Symbol search, [SYMBOL.OP], line: line, char: char, byte: byte, operator: type: operator.type, name: operator.name
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
            double_space = false
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
    peek = (n) ->
      old_i = i
      if n > 0
        target_i = i + n
        next_symbol() while ++i < target_i
      else
        i += n
      symbol = symbol_array[i]
      i = old_i
      return symbol
    next_symbol = =>
      symbol = symbol_array[i]
      if symbol.hasType SYMBOL.WORD
        # keywords
        if ( # cannot have nonwords around them
          (i is 0 or not peek(-1).hasType SYMBOL.TEXT) and
          (i is len or not peek(1).hasType SYMBOL.TEXT)
        )
          for group, keywords of SYNTAX.JAVA.KEYWORDS
            for keyword in keywords when symbol.chars is keyword
              symbol.pushUniqueType SYMBOL.KEYWORD
              switch group
                when 'ACCESS_MODIFIERS' then symbol.types = [SYMBOL.ACCESS]
                when 'TYPES' then symbol.types = [SYMBOL.TYPE]
              return

          # literals
          for literal in SYNTAX.JAVA.LITERALS
            if symbol.chars is literal
              symbol.types = [SYMBOL.LITERAL]
              return

        # number
        if symbol.chars.match /^-?\d+$/
          symbol.types = [SYMBOL.NUMBER]
          if peek(1).chars is '.' and peek(2).hasType SYMBOL.NUMBER
            # merge the next two together
            [symbol, delta] = symbol.merge symbol_array, i, 3
            len += delta
            symbol.pushUniqueType SYMBOL.DECIMAL
            symbol.removeType SYMBOL.TEXT
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
        symbol.types = [SYMBOL.ID]

      else if symbol.hasType SYMBOL.TEXT
        1
        # TODO: later, determine type of opener by surroundings
        #       openers preceeded by identifiers are types of _START
        #       closers are based on last opener

    next_symbol() while ++i < len
    return symbol_array

  java_syntaxer: (symbol_array) ->
    i = -1
    len = symbol_array.length
    open_pairs = []
    level = 0
    peek = (n) ->
      old_i = i
      if n > 0
        target_i = i + n
        next_symbol() while ++i < target_i
      else
        i += n
      symbol = symbol_array[i]
      i = old_i
      return symbol
    find_next = (n,test) ->
      ii = n
      while ++ii < len
        symbol = symbol_array[ii]
        return ii if test.call symbol
      return false
    next_non_space = (n,test) ->
      ii = n
      while ++ii < len and
          (symbol = symbol_array[ii]) and
          (symbol.hasType SYMBOL.LINEBREAK, SYMBOL.INDENT)
        ;
      return if test.call symbol then ii else false
    next_symbol = =>
      symbol = symbol_array[i]
      return if symbol is undefined

      symbol.level = level

      # type
      if symbol.hasType(SYMBOL.ID) and
          (not symbol.hasType(SYMBOL.ACCESS)) and
          ((n = peek(1)) and n.hasType SYMBOL.ID)
        symbol.types = [SYMBOL.TYPE]

      # array type
      if symbol.hasType(SYMBOL.ID) and
          (not symbol.hasType(SYMBOL.ACCESS)) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_BRACKET) and
          ((n = peek(2)) and n.chars is CHAR.CLOSE_BRACKET) and
          ((n = peek(3)) and n.hasType SYMBOL.ID)
        [symbol, delta] = symbol.merge symbol_array, i, 3
        symbol.types = [SYMBOL.TYPE]
        len += delta

      # generics
      if symbol.hasType(SYMBOL.ID) and
          ((p = peek(-1)) and p.chars is CHAR.LESS)
        if peek(1).chars is CHAR.GREATER
          peek(-2).pushUniqueType SYMBOL.TYPE
          # merge i-1 to i+1
          [symbol, delta] = symbol.merge symbol_array, i-2, 4
          symbol.types = [SYMBOL.TYPE, SYMBOL.GENERIC_TYPE]
          len += delta
          return
        else
          ii = i+1
          ii+=2 while symbol_array[ii].chars is CHAR.COMMA and
              symbol_array[ii+1].hasType SYMBOL.ID
          if symbol_array[ii].chars is CHAR.GREATER
            # merge i-1 to ii
            [symbol, delta] = symbol.merge symbol_array, i-2, ii-i+3
            symbol.types = [SYMBOL.TYPE, SYMBOL.GENERIC_TYPE]
            len += delta
            return

      # cast
      if symbol.hasType(SYMBOL.ID) and
          ((p = peek(-1)) and p.chars is CHAR.OPEN_PARENTHESIS) and
          ((n = peek(1)) and n.chars is CHAR.CLOSE_PARENTHESIS)
        symbol.pushUniqueType SYMBOL.TYPE
        symbol.pushUniqueType SYMBOL.CAST
        [symbol, delta] = symbol.merge symbol_array, i-1, 3
        symbol.chars = symbol.chars.substr 1, symbol.chars.length-2
        symbol.types = [SYMBOL.ID, SYMBOL.TYPE, SYMBOL.CAST]
        len += delta
        return

      # param
      if symbol.hasType(SYMBOL.ID) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_PARENTHESIS) and
          (e = find_next(i, -> @chars is CHAR.CLOSE_PARENTHESIS)) and
          (symbol_array[e+1].chars is CHAR.OPEN_BRACE)
        n.pushUniqueType SYMBOL.PARAM
        symbol_array[e].pushUniqueType SYMBOL.PARAM
        return

      # call
      if symbol.hasType(SYMBOL.ID) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_PARENTHESIS) and
          (e = find_next(i, -> @chars is CHAR.CLOSE_PARENTHESIS))
        n.pushUniqueType SYMBOL.CALL
        symbol_array[e].pushUniqueType SYMBOL.CALL
        return

      # index
      if symbol.hasType(SYMBOL.ID) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_BRACKET) and
          (e = find_next(i, -> @chars is CHAR.CLOSE_BRACKET))
        n.pushUniqueType SYMBOL.INDEX
        symbol_array[e].pushUniqueType SYMBOL.INDEX
        return

      # level++
      if symbol.chars is CHAR.OPEN_BRACE
        ++level
        symbol.pushUniqueType SYMBOL.LEVEL_INC
        symbol.pushUniqueType SYMBOL.TERMINATOR
        return

      # level--
      if symbol.chars is CHAR.CLOSE_BRACE
        --level
        symbol.pushUniqueType SYMBOL.LEVEL_DEC
        return

      # terminator (basically the semicolon and the open bracket)
      if symbol.chars is CHAR.SEMICOLON
        symbol.pushUniqueType SYMBOL.TERMINATOR
        return

      # override
      if symbol.chars is 'Override' and
          ((p = peek(-1)) and p.chars is CHAR.AT)
        [symbol, delta] = symbol.merge symbol_array, i-1, 2
        symbol.types = [SYMBOL.SUPPORT]
        len += delta
        return

      # TODO: use braces pairs to determine symbol level for all symbols inbetween


    next_symbol() while ++i < len
    return symbol_array

  translate_to_coffee: (symbol_array) ->
    # split into statements
    i = -1
    len = symbol_array.length
    statements = []
    statement = []
    while ++i < len
      symbol = symbol_array[i]
      statement.push symbol_array[i]
      if symbol.hasType SYMBOL.TERMINATOR, SYMBOL.COMMENT, SYMBOL.SUPPORT, SYMBOL.DOUBLE_SPACE, SYMBOL.LEVEL_DEC
        statement.level = symbol.level
        statements.push statement
        statement = []
    if statement.length
      statement.level = symbol.level
      statements.push statement
      statement = []

    out =
      req: ''
      mod: ''
      classes: ''
    repeat = (s, n) -> r=''; r+=s while --n >= 0; r

    i = -1
    len = symbol_array.length
    in_class_scope = false
    in_fn_scope = false
    global_ids = {}
    class_ids = {}
    last_class_id = ''
    fn_ids = {}

    for statement, y in statements
      # transform some
      # but output all
      indent = -> repeat '  ', statement.level
      toToken = (s) -> SYMBOL[s.toUpperCase()]
      oneOrMore = (start, pattern) ->
        ii = start-2
        at_least_one = false
        while statement[++ii].hasType toToken pattern
          at_least_one = true
        return if at_least_one then ii else false
      isA = (start, pattern) ->
        statement[start-1].hasType toToken pattern
      toString = (start, end) ->
        end ||= statement.length+1
        s = []
        beginning = true
        last_had_space = false
        for ii in [start-1...end-1]
          if statement[ii].hasType SYMBOL.OP, SYMBOL.KEYWORD, SYMBOL.ACCESS, SYMBOL.TYPE
            if beginning or last_had_space
              s.push statement[ii].chars+' '
            else
              s.push ' '+statement[ii].chars+' '
            last_had_space = true
          else if statement[ii].hasType SYMBOL.TERMINATOR, SYMBOL.CAST, SYMBOL.BRACE
          else if statement[ii].hasType SYMBOL.DOUBLE_SPACE
            s.push ''
          else
            last_had_space = false
            s.push statement[ii].chars
          beginning = false
        s.join ''
      hasAccessor = (start, end, accessor) ->
        for ii in [start-1..end-1]
          if statement[ii].hasType(SYMBOL.ACCESS) and
              statement[ii].chars is accessor
            return true
        return false
      isLocal = (v) -> fn_ids[v] is 1
      isGlobal = (v) -> global_ids[v] is 1
      symbol = statement[0]

      # package = module.exports
      if symbol.hasType(SYMBOL.KEYWORD) and
          symbol.chars is 'package'
        out.mod += "module.exports = # #{toString 1}"
        continue

      # import = require
      if symbol.hasType(SYMBOL.KEYWORD) and
          symbol.chars is 'import'
        file = toString 2
        [nil..., name] = file.split '.'
        out.req += "#{name} = require '#{file.replace /\./g, '/'}'\n"
        global_ids[name] = 1
        continue

      # comments
      if symbol.hasType SYMBOL.COMMENT, SYMBOL.SUPPORT
        # multi-line
        if symbol.hasType SYMBOL.MULTILINE_COMMENT
          comment = symbol.chars
            .replace(/^[\t ]*\*\/[\r\n]*/m, '') # bottom
            .replace(/^[\t ]*\*[\t ]*/mg, '') # middle
            .replace(/\/\*\*?[\r\n]*/, '') # top
            .replace(/(^[\r\n]+|[\r\n]+$)/g, '') # trim
            .replace(/^/mg, indent()) # indent
          out.classes += "#{indent()}###\n#{comment}\n#{indent()}###\n"
          continue
        # end-line
        else if symbol.hasType SYMBOL.ENDLINE_COMMENT, SYMBOL.SUPPORT
          comment = symbol.chars.replace(/^\s*\/\/\s*/mg, '')
          out.classes += "#{indent()}# #{comment}\n"
          continue

      # scope
      if symbol.hasType(SYMBOL.LEVEL_DEC)
        if in_fn_scope
          in_fn_scope = false
          fn_ids = {}
        else if in_class_scope
          in_class_scope = false
          last_class_id = ''
          class_ids = {}
        continue

      # ids
      # only if its not preceded by a dot
      # and only if it is a definition (meaning preceded by a type)
      #out.classes += '\n'
      #out.classes += '-- global_ids: '
      #out.classes += "#{id}, " for own id, nil of global_ids
      #out.classes += '\n-- class_ids: '
      #out.classes += "#{id}, " for own id, nil of class_ids
      #out.classes += '\n-- fn_ids: '
      #out.classes += "#{id}, " for own id, nil of fn_ids
      #out.classes +='\n\n'
      for s, ii in statement
        if s.hasType SYMBOL.ID
          # keep definitions in scope registry
          if statement[ii-1] and
              statement[ii-1].hasType SYMBOL.TYPE
            if in_fn_scope
              fn_ids[s.chars] = 1
            else if in_class_scope
              class_ids[s.chars] = 1
          # top-level id references
          # may need a @ prefix if not in local scope
          if in_class_scope and
              (statement[ii-1] is undefined) or
              statement[ii-1].chars isnt CHAR.PERIOD
            unless isLocal(s.chars) or isGlobal(s.chars)
              statement[ii].chars = '@'+statement[ii].chars

      #'^access+ class id'
      if (x = oneOrMore 1, 'access') and
          (statement[x].chars is 'class') and
          (isA x+2, 'id')
        out.classes += "#{indent()}#{toString x+1} # #{toString 1, x+1}\n"
        in_class_scope = true
        last_class_id = toString x+2, x+3
        continue

      # function definition
      if (x = oneOrMore 1, 'access') and
          (isA x+1, 'type') and
          (isA x+2, 'id') and
          (isA x+3, 'param') and
          (isA x+3, 'open')
        param_types = []
        fn_access_mods = []
        fn_type = ''
        fn_id = ''
        fn_params = []
        params_open = false
        in_fn_scope = true
        for ii in [0...statement.length]
          s = statement[ii]
          if s.hasType SYMBOL.ACCESS
            unless params_open
              fn_access_mods.push s.chars
          else if s.hasType SYMBOL.TYPE
            unless params_open
              fn_type = s.chars
            else
              param_types.push s.chars
          else if s.hasType(SYMBOL.PARAM) and s.hasType(SYMBOL.OPEN)
            params_open = true
          else if s.hasType SYMBOL.ID
            unless params_open
              fn_id = s.chars
            else
              fn_params.push s.chars
        if fn_params.length then fn_params
        fn_params = if fn_params then "(#{fn_params.join ', '})" else ''
        fn_id = 'constructor' if fn_id is last_class_id
        # if static accessor used, dont use @ prefix
        if fn_id[0] is '@' and hasAccessor 1, x, 'static'
          fn_id = fn_id.substr 1, fn_id.length-1
        out.classes += "#{indent()}#{fn_id}: #{fn_params} -> # #{fn_access_mods.reverse().join ' '} (#{param_types.join ', '}): #{fn_type}\n"
        continue

      #'^access+ type id'
      if (x = oneOrMore 1, 'access') and
          (isA x+1, 'type') and
          (isA x+2, 'id')
        id = toString x+2, x+3
        console.log "id is #{id}", in_class_scope: in_class_scope, in_fn_scope: in_fn_scope
        if in_class_scope and not in_fn_scope
          if id[0] is '@' and hasAccessor 1, x, 'static' # if static
            statement[x+1].chars = statement[x+1].chars.substr 1, statement[x+1].chars.length-1 # no @
        out.classes += "#{indent()}#{toString x+2} # #{toString 1, x+1}\n"
      else
        out.classes += "#{indent()}#{toString 1}\n"

      # any id not prefixed by a \.:
      #  @ unless part of requires or defined in local scope

    #@pretty_print_symbol_array symbol_array
    out = "#{out.req}\n#{out.mod}\n#{out.classes}\n"
    console.log "--- OUTPUT:------\n\n#{out}"
    #console.log "--- IDs:-----\n\n", JSON.stringify ids, null, 2
    return out

  # TODO: technically these are called tokens
  pretty_print_symbol_array: (symbol_array) ->
    process.stdout.write "\n"
    last_line = 1
    for symbol, i in symbol_array
      #return if i > 80
      types = []; types.push type.enum for type in symbol.types; types = types.join ', '
      toString = -> "(#{symbol.level} #{types} #{JSON.stringify symbol.chars}) "
      if last_line isnt symbol.line
        last_line = symbol.line
        process.stdout.write "\n"
      process.stdout.write toString symbol
    process.stdout.write "\n"

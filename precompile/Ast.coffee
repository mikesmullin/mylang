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
  isA: (str_type) ->
    @hasType SYMBOL[str_type.toUpperCase()]
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
  'DOUBLE_SPACE','BLOCK']

OPERATOR = new Enum ['UNARY_LEFT','UNARY_RIGHT','BINARY_LEFT_RIGHT',
  'BINARY_LEFT_LEFT','BINARY_RIGHT_RIGHT','TERNARY_RIGHT_RIGHT_RIGHT']

# syntax
SYNTAX =
  JAVA: # proprietary to java
    KEYWORDS:
      STATEMENTS: ['case','catch','continue','default','finally','goto','return','switch','try','throw']
      BLOCK: ['if','else','for','while','do']
      ACCESS_MODIFIERS: ['abstract','const','private','protected','public','static','synchronized','transient','volatile','final']
      TYPES: ['boolean','double','char','float','int','long','short','void']
      OTHER: ['class','new','import','package','super','this','enum','implements','extends','instanceof','interface','native','strictfp','throws']
    LITERALS: ['false','null','true']
    OPERATORS: [
      { type: OPERATOR.UNARY_LEFT, name: 'postfix', symbols: [ '++', '--' ] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'equality', symbols: ['==', '!='] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'assignment', symbols: ['+=', '-=', '*=', '/=', '%=', '&=', '^=', '|=', '<<=', '>>=', '>>>='] }
      { type: OPERATOR.UNARY_RIGHT, name: 'unary', symbols: ['++', '--', '+', '-', '~', '!'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'multiplicative', symbols: ['*', '/', '%'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'additive', symbols: ['+', '-'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'shift', symbols: ['<<', '>>', '>>>'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'relational', symbols: ['<=', '>=', '<', '>', 'instanceof', '='] } # had to move = here so it would get matched last. operator precendence doesnt matter for us since we're transpiling not fully compiling
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'logical AND', symbols: ['&&'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise AND', symbols: ['&'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise exclusive OR', symbols: ['^'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'logical OR', symbols: ['||'] }
      { type: OPERATOR.BINARY_LEFT_RIGHT, name: 'bitwise inclusive OR', symbols: ['|'] }
      { type: OPERATOR.TERNARY_RIGHT_RIGHT_RIGHT, name: 'ternary', symbols: [['?',':']] }
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


class Ast # Parser
  open: (file, cb) ->
    return unless require and (fs = require('fs'))
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      code = @compile file, data
      cb code
    return

  compile: (file, buf) ->
    symbol_array = @lexer file, buf # distinguish lines, indentation, spacing, words, and non-words
    symbol_array = @symbolizer symbol_array # distinguish keywords, literals, identifiers in source language
    symbol_array = @java_syntaxer symbol_array # create Abstract Syntax Tree (AST)
    code = @translate_to_coffee symbol_array
    return code

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
    is_pair = (high_precedence=false) ->
      for pair in SYNTAX.JAVA.PAIRS
        for search, k in pair.symbols
          if search is peek 0, search.length
            double_space = false
            symbol = new Symbol search, [], line: line, char: char, byte: byte, pair: name: pair.name
            symbol.pushUniqueType type for type in pair.types

            # some pairs require that we find their endings immediately
            # e.g., comments
            if high_precedence
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
                    unless escape and
                        buf.substr(i-escape.length, escape.length) is escape and
                        buf.substr(i-(escape.length*2), escape.length) isnt escape
                      return i
                  return -1
                if -1 isnt x = find_end_of_escaped_pair buf, zbyte+1, pair.symbols[1], pair.escaped_by
                  symbol.chars = buf.substr zbyte, x-zbyte+1
                  return [symbol, x-zbyte+1]
                else
                  throwError "unmatched string pair \"#{search}\""
            else
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

          # pair::high_precendence
          if r = is_pair true
            [symbol, x] = r
            symbol_array.push symbol
            zbyte += x-1 # skip ahead
            continue

          # operator
          if r = is_operator()
            [symbol, x] = r
            symbol_array.push symbol
            zbyte += x-1 # skip ahead
            continue

          # pair::low_precendence
          if r = is_pair false
            [symbol, x] = r
            symbol_array.push symbol
            zbyte += x-1 # skip ahead
            continue

          # terminator
          if c is CHAR.SEMICOLON
            double_space = false
            symbol_array.push new Symbol c, [SYMBOL.STATEMENT_END], line: line, char: char, byte: byte
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
                when 'BLOCK' then symbol.pushUniqueType SYMBOL.BLOCK
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
    next_matching_pair = (n, open_test, close_test) ->
      ii = n
      open_count = 0
      while ++ii < len and (symbol = symbol_array[ii])
        if open_test.call symbol
          open_count++
        else if close_test.call symbol
          open_count--
          if open_count is 0
            return ii
      return false # missing pair!

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
          symbol.chars[0].match(/A-Z/) and
          ((p = peek(-1)) and p.chars is CHAR.OPEN_PARENTHESIS) and
          ((n = peek(1)) and n.chars is CHAR.CLOSE_PARENTHESIS)
        symbol.pushUniqueType SYMBOL.TYPE
        symbol.pushUniqueType SYMBOL.CAST
        [symbol, delta] = symbol.merge symbol_array, i-1, 3
        symbol.chars = symbol.chars.substr 1, symbol.chars.length-2
        symbol.types = [SYMBOL.ID, SYMBOL.TYPE, SYMBOL.CAST]
        len += delta
        return

      if symbol.hasType(SYMBOL.ID) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_PARENTHESIS) and
          (e = next_matching_pair(i, (-> @chars is CHAR.OPEN_PARENTHESIS), -> @chars is CHAR.CLOSE_PARENTHESIS))

        # param
        if (symbol_array[e+1].chars is CHAR.OPEN_BRACE)
          n.pushUniqueType SYMBOL.PARAM
          symbol_array[e].pushUniqueType SYMBOL.PARAM
        else if (symbol_array[e+1].chars is 'throws') and
            (symbol_array[e+2].hasType SYMBOL.ID) and
            (symbol_array[e+3].chars is CHAR.OPEN_BRACE)
          # transform the `throws Exception` into end-line comment
          n.pushUniqueType SYMBOL.PARAM
          symbol_array[e].pushUniqueType SYMBOL.PARAM
          chars = symbol_array[e+1].chars+' '+symbol_array[e+2].chars
          [symbol, delta] = symbol.merge symbol_array, e+1, 2
          symbol.chars = chars
          symbol.types = [SYMBOL.COMMENT, SYMBOL.ENDLINE_COMMENT]
          len += delta

        # call
        else
          n.pushUniqueType SYMBOL.CALL
          symbol_array[e].pushUniqueType SYMBOL.CALL
        return

      # index
      if symbol.hasType(SYMBOL.ID) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_BRACKET) and
          (e = find_next(i+1, -> @chars is CHAR.CLOSE_BRACKET))
        n.pushUniqueType SYMBOL.INDEX
        symbol_array[e].pushUniqueType SYMBOL.INDEX
        return

      # implicit block
      if symbol.hasType(SYMBOL.BLOCK) and
          ((n = peek(1)) and n.chars is CHAR.OPEN_PARENTHESIS) and
          (e = next_matching_pair(i, (-> @chars is CHAR.OPEN_PARENTHESIS), -> @chars is CHAR.CLOSE_PARENTHESIS)) and
          (((symbol_array[e+1].hasType SYMBOL.ENDLINE_COMMENT) and e++) or 1) and
          (symbol_array[e+1].chars isnt CHAR.OPEN_BRACE) and
          (f = find_next(e+1, -> @hasType SYMBOL.STATEMENT_END))
        symbol_array.splice e+1, 0, new Symbol CHAR.OPEN_BRACE, [SYMBOL.BRACE, SYMBOL.PAIR, SYMBOL.OPEN, SYMBOL.LEVEL_INC]
        symbol_array.splice f+2, 0, new Symbol CHAR.CLOSE_BRACE, [SYMBOL.BRACE, SYMBOL.PAIR, SYMBOL.CLOSE, SYMBOL.LEVEL_DEC]
        len+=2
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
    # group tokens into array of statements
    i = -1
    statement = []
    last_level = 0
    statements = []
    len = symbol_array.length
    while ++i < len
      symbol = symbol_array[i]
      slice_statement_buf = (level) ->
        last_level = statement.level = level
        statements.push statement
        statement = []
      # symbols that both divide and get their own lines afterward
      if symbol.hasType SYMBOL.LEVEL_DEC, SYMBOL.TERMINATOR, SYMBOL.DOUBLE_SPACE, SYMBOL.SUPPORT
        statement.push symbol
        slice_statement_buf symbol.level
      # remaining symbols group to form a statement
      else statement.push symbol
    if statement.length
      slice_statement_buf last_level+1 # TODO: this last level may not always work

    out =
      req: ''
      mod: ''
      classes: ''
    repeat = (s, n) -> r=''; r+=s while --n >= 0; r

    i = -1
    len = symbol_array.length
    in_class_scope = 0
    in_fn_scope = 0
    in_param_scope = false
    global_ids = {}
    class_ids = []
    last_class_id = []
    fn_ids = []
    last_fn_type_void = true

    for statement, y in statements
      # transform some
      # but output all
      indent = -> repeat '  ', statement.level
      cursor = 0
      pluckFromStatement = (tokens) ->
        for ii in [tokens.length-1..0] # starting at farthest end
          statement.splice tokens[ii].statement_pos, 1 # remove token from statement array
        return
      joinTokens = (tokens, sep) ->
        r = []
        for token in tokens
          r.push token.chars
        return r.join sep
      match = (type, test_fn) ->
        index = cursor - 1
        result =
          pos: cursor # beginning index of matches
          end: cursor # ending index of matches
          matches: [] # matching tokens
        while s = statement[++index]
          continue if s.hasType SYMBOL.COMMENT, SYMBOL.SUPPORT # ignore comments
          if matches = test_fn.call s
            result.end = s.statement_pos = index
            result.matches.push s
            cursor = index + 1 # increments cursor to position of element after last match
          switch type
            when 'zeroOrOne' then return result # always true but cursor is also incremented if one was found
            when 'zeroOrMore' then return result unless matches # always true but cursor is also incremented once for each find
            when 'exactlyOne' then return (if result.matches.length then result else null) # true of one was found
            when 'oneOrMore' then return (if result.matches.length then result else null) unless matches # true if any were found
            #when 'between' then # WIP
      toString = (start=0, end) ->
        end = statement.length-1 if end is undefined
        return '' if end < 0
        o = []
        beginning = true
        last_had_space = false
        for ii in [start..end]
          s = statement[ii]

          # comments
          if s.hasType SYMBOL.COMMENT, SYMBOL.SUPPORT
            # multi-line
            if s.hasType SYMBOL.MULTILINE_COMMENT
              comment = s.chars
                .replace(/^[\t ]*\*\//m, '') # bottom
                .replace(/^[\t ]*\*[\t ]*/mg, '') # middle
                .replace(/\/\*\*?/, '') # top
                .replace(/^/mg, indent()) # indent
                .replace(/[\r\n]+$/, '\n') # end-line space
              o.push "####{comment}###\n#{indent()}"
              continue
            # single-line
            else if s.hasType SYMBOL.ENDLINE_COMMENT, SYMBOL.SUPPORT
              comment = s.chars.replace(/^\s*\/\/\s*/mg, '')
              space = if ii is statement.length-1 then '' else "\n#{indent()}"
              o.push "# #{comment}#{space}"
              continue

          # everything else
          if s.hasType(SYMBOL.KEYWORD, SYMBOL.ACCESS, SYMBOL.TYPE) or
              s.hasType(SYMBOL.OP) and s.chars isnt CHAR.EXCLAIMATION
            if beginning or last_had_space
              o.push s.chars+' '
            else
              o.push ' '+s.chars+' '
            last_had_space = true
          else if s.hasType SYMBOL.TERMINATOR, SYMBOL.CAST, SYMBOL.BRACE
          else if s.hasType SYMBOL.DOUBLE_SPACE
            o.push ''
          else
            last_had_space = false
            o.push s.chars
          beginning = false
        return o.join ''
      hasAccessor = (start, end, accessor) ->
        for ii in [start..end]
          if statement[ii].hasType(SYMBOL.ACCESS) and
              statement[ii].chars is accessor
            return true
        return false
      isLocal = (v) -> fn_ids[v] <= in_fn_scope
      isGlobal = (v) -> global_ids[v] is 1
      symbol = statement[0]

      # package = module.exports
      # ^package
      cursor = 0 # reset
      if (match 'exactlyOne', -> @chars is 'package')
        out.mod += "module.exports = # #{toString 1}"
        continue

      # import = require
      # ^import
      cursor = 0 # reset
      if (match 'exactlyOne', -> @chars is 'import')
        file = toString(1).split '.'
        name = file[file.length-1]
        out.req += "#{name} = require '#{file.join '/'}'\n"
        global_ids[name] = 1
        continue

      # scope
      # ^level_dec
      cursor = 0 # reset
      if (match 'exactlyOne', -> @isA 'level_dec')
        if in_fn_scope
          if last_fn_type_void # explicit return
            out.classes += "#{indent()}return\n"
          in_fn_scope--
          for id, lvl of fn_ids
            if lvl > in_fn_scope
              delete fn_ids[id]
          fn_ids = {}
        else if in_class_scope
          in_class_scope--
          for id, lvl of class_ids
            if lvl > in_class_scope
              delete class_ids[id]
          last_class_id.pop()
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
        prev = statement[ii-1]
        if s.isA 'param'
          in_param_scope = s.isA 'open'
        if s.isA 'id'
          # map id definitions in scope registry
          if prev and prev.isA 'type'
            if in_fn_scope
              fn_ids[s.chars] = in_fn_scope
            else if in_class_scope
              class_ids[s.chars] = in_class_scope
          # top-level id references
          # may need a @ prefix if not in local scope
          if in_class_scope and
              not in_param_scope and
              ((prev is undefined) or
              prev.chars isnt CHAR.PERIOD)
            unless isLocal(s.chars) or
                isGlobal(s.chars)
              s.chars = '@'+s.chars

      # class
      #'^access+ class id'
      cursor = 0 # reset
      if (a = match 'oneOrMore', -> @isA 'access') and
          (match 'exactlyOne', -> @chars is 'class') and
          (i = match 'exactlyOne', -> @isA 'id')
        # remove access modifiers from the statement
        name = i.matches[0].chars
        last_class_id.push name
        global_ids[name] = 1
        pluckFromStatement removed = a.matches
        for token, ii in statement
          if token.chars is 'implements'
            removed = removed.concat statement.splice ii, 2 # pluck
            break
        out.classes += "#{indent()}#{toString()} # #{joinTokens removed, ' '}\n"
        in_class_scope = true
        continue

      # function definition
      # ^access+ type? id param_open
      cursor = 0 # reset
      if (a = match 'oneOrMore', -> @isA 'access') and # optional access modifiers
          (t = match 'zeroOrOne', -> @isA 'type') and # optional type
          (i = match 'exactlyOne', -> @isA 'id') and
          (p = match 'exactlyOne', -> @isA('param') and @isA('open'))
        fn_id = ''
        fn_type = 'void'
        fn_params = []
        fn_comment = ''
        in_fn_scope = true
        fn_params_open = false
        fn_param_types = []
        fn_access_mods = []
        for ii in [0...statement.length]
          s = statement[ii]
          if s.hasType SYMBOL.ACCESS
            unless fn_params_open
              fn_access_mods.push s.chars
          else if s.hasType SYMBOL.TYPE
            unless fn_params_open
              fn_type = s.chars
            else
              fn_param_types.push s.chars
          else if s.hasType(SYMBOL.PARAM) and s.hasType(SYMBOL.OPEN)
            fn_params_open = true
          else if s.hasType SYMBOL.ID
            unless fn_params_open
              fn_id = s.chars
            else
              fn_params.push s.chars
              fn_ids[s.chars] = in_fn_scope

        # remove everything from the statement except comments
        if fn_params.length then fn_params
        fn_params = if fn_params.length then "(#{fn_params.join ', '}) " else ''
        fn_param_types = unless fn_param_types.length then ['void'] else fn_param_types
        fn_id = 'constructor' if fn_id.replace(/^@/,'') is last_class_id[last_class_id.length-1]
        if fn_id[0] is '@' and not hasAccessor a.pos, a.end, 'static' # unless static access modifier used
          fn_id = fn_id.substr 1, fn_id.length-1 # remove @ prefix; its only for static
        last_fn_type_void = fn_type is 'void'
        for ii in [statement.length-1..0]
          s = statement[ii]
          unless statement[ii].types[0] is SYMBOL.COMMENT
            statement.splice ii, 1 # remove
        out.classes += "#{indent()}#{toString()}#{fn_id}: #{fn_params}-> # #{fn_access_mods.reverse().join ' '} (#{fn_param_types.join ', '}): #{fn_type} #{fn_comment}\n"
        continue

      #'^access+ type id'
      cursor = 0 # reset
      if (a = match 'oneOrMore', -> @isA 'access') and # optional access modifiers
          (t = match 'zeroOrOne', -> @isA 'type') and # optional type
          (i = match 'exactlyOne', -> @isA 'id')
        id = i.matches[0].chars
        if in_class_scope and not in_fn_scope
          if id[0] is '@' and not hasAccessor a.pos, a.end, 'static' # unless static access modifier used
            i.matches[0].chars = id.substr 1, id.length-1 # remove @ prefix; its only for static
        # remove access modifiers and types from the statement
        pluckFromStatement removed = a.matches.concat(t.matches)
        out.classes += "#{indent()}#{toString()} # #{joinTokens removed, ' '}\n"
        continue

      # pass-through everything else
      out.classes += "#{indent()}#{toString()}\n"

    #@pretty_print_symbol_array symbol_array
    out = "#{out.req}#{out.mod}#{out.classes}"
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

if 'function' is typeof require and typeof exports is typeof module
  module.exports = Ast

fs = require 'fs'

class Enum
  constructor: (h) ->
    for own k, v of h
      @[k] = name: k, id: v

module.exports =
class Ast
  constructor: ->
    @lines = []

  @node_types: new Enum
    DEF: 1
    ID: 2
    OPERATOR: 3
    LITERAL: 4
    WRAPPER: 5
  @literal_types: new Enum
    NUMBER: 1
    STRING: 2
    REGEX: 3
  @number_types: new Enum
    INTEGER: 1
    DECIMAL: 2
    HEX: 3
  @definitions: new Enum
    DEF_TYPE: 1
    DEF_ID: 2
  @operators: new Enum
    COMPARE_EQUAL: 1
    SET_VALUE: 2
    SET_ADDRESS: 3
    SET_ADDRESS_OF: 4
  @operator_types: new Enum
    UNARY_LEFT: 1
    UNARY_RIGHT: 2
    BINARY_LEFT_RIGHT: 3
    #BINARY_LEFT_LEFT: ?
    BINARY_RIGHT_RIGHT: 4
    TERNARY_RIGHT_RIGHT_RIGHT: 5
  @wrapper_types: new Enum
    PAREN: 1 # ()
    BRACK: 2 # []
    SQUO: 3  # ''
    DQUO: 4  # ""
    TSQUO: 5 # '''
    TDQUO: 6 # """
    TANG: 7  # <<<'HEREDOC'
    PUPW: 8  # %W()
    PLOW: 9  # %w()
  @wrapper_ends: new Enum
    HEAD: 1
    TAIL: 2

  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return
  compile: (file, b) ->
    line = 1
    level = 0
    first_indent =
      actual: ''
      spaces: 0
      tabs: 0
    buffered_indent = ''
    l = b.length
    new_level = false
    scope = null
    char = 0
    start_char = null
    spaces = 0
    tabs = 0
    bt = []
    new_scope = false # on new scope, append to backtrace
    node_zero = null
    node = null
    left_node = null
    buffered_word = ''
    in_string = false
    remainder_of_line_is_comment = false
    push_word_node = ->
      return unless buffered_word

      node =
        token: buffered_word
        line: line
        char: start_char
        length: char - (start_char-1)
        left: left_node
        right: null
        node_type: null

      if null isnt (m = buffered_word.match /^(\d+)(\w)?$/)
        node.node_type = Ast.node_types.LITERAL
        node.literal_type = Ast.literal_types.NUMBER
        node.number_type = Ast.number_types.INTEGER
        if m[3] then node.number_unit_symbol = m[3]
      else if null isnt (m = buffered_word.match /^(\d*).(\d+)(\w)?$/)
        node.node_type = Ast.node_types.LITERAL
        node.literal_type = Ast.literal_types.NUMBER
        node.number_type = Ast.number_types.DECIMAL
        if m[4] then node.number_unit_symbol = m[3]
      else if null isnt buffered_word.match /^0x[0-9a-fA-F]+$/
        node.node_type = Ast.node_types.LITERAL
        node.literal_type = Ast.literal_types.NUMBER
        node.number_type = Ast.number_types.HEX
      else switch buffered_word
        when 'defType'
          node.node_type = Ast.node_types.DEF
          node.definition = Ast.definitions.DEF_TYPE
        when 'setUnitEquivalentOf'
          node.node_type = Ast.node_types.OPERATOR
          node.operator_type = Ast.operator_types.BINARY_LEFT_RIGHT
        when 'defId'
          node.node_type = Ast.node_types.DEF
          node.definition = Ast.definitions.DEF_ID
        when 'setLiteral'
          node.node_type = Ast.node_types.OPERATOR
          node.operator_type = Ast.operator_types.BINARY_LEFT_RIGHT
        else
          node.node_type = Ast.node_types.ID

      if left_node
        left_node.right = node
      if node_zero is null
        node_zero = node
        left_node = node_zero
      left_node = node
      buffered_word = ''
      start_char = null

    throw_compile_error = (error) ->
      process.stdout.write "Error: #{error}\n  at #{scope} (#{file}:#{line}:#{char})\n\n"
      process.exit 1

    for i in [0...l]
      c = b[i]
      if (i<l-1 and c is "\r" and b[i+1] is "\n") or
         c is "\r" or
         c is "\n" # line-break
        push_word_node()
        if node_zero isnt null
          @lines.push node_zero
          left_node = null
          node_zero = null
        remainder_of_line_is_comment = false
        line++
        char = spaces = tabs = 0
      else if (c is ' ' and ++spaces) or (c is "\t" and ++tabs) # spacing
        if char is 0
          new_level = true
          buffered_indent += c
        else
          push_word_node()
      else if c is '#' and not in_string
        remainder_of_line_is_comment = true
      else
        char++
        continue if remainder_of_line_is_comment
        if start_char is null
          start_char = char
        if new_level
          level++
          new_level = false
          if first_indent.actual
            unless first_indent.actual is buffered_indent
              throw_compile_error 'inconsistent indentation; '+
                'expected '+ (if first_indent.spaces then "#{first_indent.spaces} spaces" else "#{first_indent.tabs} tabs") +
                ', but found '+ (if spaces then "#{spaces} spaces" else "#{tabs} tabs") + '.'
          else
            first_indent =
              actual: buffered_indent
              spaces: spaces
              tabs: tabs
            buffered_indent = ''
        else
          if null isnt c.match /\w/
            buffered_word += c
          else # non-word char
            # TODO: buffer non-word chars until EOL or another word char is encountered
            # TODO: support wrapper symbols like () [] "" '' %W() %w() <<< """ '''
            # TODO: support finding regex between // on the same line
            push_word_node()

    return

  pretty_print: ->
    process.stdout.write "\n"
    for line in @lines
      n = line
      process.stdout.write '( '
      toString = (n) -> "(#{n.node_type.name} #{n.token}) "
      process.stdout.write toString n
      while n = n.right
        process.stdout.write toString n
      process.stdout.write " )\n"

    #console.log JSON.stringify @node_zero, null, 2

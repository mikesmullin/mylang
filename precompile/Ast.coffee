fs = require 'fs'

module.exports =
class Ast
  constructor: ->
    @node_zero = null
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
    prev_node = null
    buffered_word = ''
    push_word_node = ->
      if buffered_word
        node =
          token: buffered_word
          line: line
          char: start_char
          length: char - (start_char-1)
          prev: prev_node
          next: null
          type: null
        if prev_node
          prev_node.next = node
        if node_zero is null
          node_zero = node
          prev_node = node_zero
        prev_node = node
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
        line++
        char = spaces = tabs = 0
      else if (c is ' ' and ++spaces) or (c is "\t" and ++tabs) # spacing
        if char is 0
          new_level = true
          buffered_indent += c
        else
          push_word_node()
      else
        char++
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
            push_word_node()

    @node_zero = node_zero
    return

  pretty_print: ->
    n = @node_zero
    toString = (n) -> "(#{n.type} #{n.token}) "
    process.stdout.write toString n
    while n = n.next
      process.stdout.write toString n

    #console.log JSON.stringify @node_zero, null, 2

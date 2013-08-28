fs = require 'fs'

module.exports =
class Ast
  constructor: ->
    @tokens = []
    @nodes = []
  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return
  compile: (file, b) ->
    line = 0
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
    spaces = 0
    tabs = 0
    bt = []

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
        char++
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

    return

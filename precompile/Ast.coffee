fs = require 'fs'

module.exports =
class Ast
  constructor: ->
  open: (file, cb) ->
    fs.readFile file, encoding: 'utf8', flag: 'r', (err, data) =>
      throw err if err
      @compile file, data
      cb()
    return
  compile: (file, buf) -> # public (String, String): void
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
    while ++zchar < len # iterate every character in buffer
      c = buf[zchar]
      char = zchar + 1
      # split by win/mac/unix line-breaks
      if c is "\r" and buf[zchar+1] is "\n" # windows
        slice_line_buf 1
      else if c is "\r" or c is "\n" # mac or linux
        slice_line_buf 0
      else
        line_buf += c



    console.log lines
    console.log line















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

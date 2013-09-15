fs = require 'fs'

class Enum
  constructor: (h) ->
    for own k, v of h
      @[k] = name: k, id: v

TOKEN = new Enum
  WORD: 1
  SPACE: 2

class Token
  constructor: (@token, @types, options={}) -> # (String, TOKEN[], Object?): void
    @[k] = v for own k, v of options
    return

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
    space_buf = ''
    word_buf = ''
    tokens = []
    push_token = (token, type) -> # (String, Int): void
      tokens.push new Token token, [type], line: line, char: char
      return
    slice_word_buf = => # (void): void
      if word_buf.length
        push_token word_buf, TOKEN.WORD
        word_buf = ''
      return
    slice_space_buf = => # (void): void
      if space_buf.length
        push_token space_buf, TOKEN.SPACE
        word_buf = ''
      return

    while ++zchar < len # iterate every character in buffer
      c = buf[zchar]
      char = zchar + 1
      # split by win/mac/unix line-breaks
      if c is "\r" and buf[zchar+1] is "\n" # windows
        slice_line_buf 1
        continue
      else if c is "\r" or c is "\n" # mac or linux
        slice_line_buf 0
        continue
      else
        line_buf += c

      # split by token boundaries
      if c is ' ' or c is "\t" # spacing
        slice_word_buf()
        space_buf += c
        continue
      else # word
        slice_space_buf()
        word_buf += c
        continue

    console.log tokens[0]















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

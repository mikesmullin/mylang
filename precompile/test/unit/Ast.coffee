assert = require('chai').assert
Ast = require '../../Ast'
path = require 'path'

describe 'Ast', ->
  ast = undefined
  fake_file = path.join __dirname, '..', 'fixtures', 'test.java'

  before ->
    ast = new Ast

  it 'can be instantiated'#, ->
  #  assert.isObject ast

  #it 'can parse a string', ->
  #  assert.isObject ast
  #  assert.isFunction ast.parse
  #  ast.parse '1'

  it 'can find the end of a string', ->
    buf = '''
      a = "hello world!";
    '''

    #i=4; while ++i < buf.length
    #  process.stdout.write buf[i]
    #  if buf[i] is '"' and (i>0 and buf[i-1] isnt "\\")
    #    console.log "found end at #{i}"

    a = 5
    console.log e = buf.indexOf '"', a
    console.log buf.substr a, e-a

  it 'can find the end of an escaped string', ->
    buf = '''
      a = "hello \\"cruel\\" world!"; b = "how are you?";
    '''

    #i=4; while ++i < buf.length
    #  process.stdout.write buf[i]
    #  if buf[i] is '"' and (i>0 and buf[i-1] isnt "\\")
    #    console.log "found end at #{i}"

    console.log buf
    console.log '---'

    # finds end of pairs where nothing inbetween is allowed but the ending can be escaped; e.g., strings
    find_end_of_escaped_pair = (buf, start, match, escape) ->
      i = start
      while -1 isnt (i = buf.indexOf match, i+match.length)
        unless escape and buf[i-escape.length] is escape
          return i

    console.log e = find_end_of_escaped_pair buf, 4, '"', '\\'
    console.log buf.substr e-2, 4

  it 'can find the end of a single-line comment'
  it 'can find the end of a multi-line comment', ->
    # for this one we just need to find the first token that represents whitespace. can probably be done in lexer
    # other pairs like ( [ { } ] ) will need to use the LIFO<->FIFO approach
    buf = '''
    hello /** blah
    blah
    * blah
     */
    '''

    console.log buf
    console.log '---'

    # finds end of pairs where nothing inbetween is allowed and the end cannot be escaped e.g., comments
    find_end_of_pair = (buf, start, match) ->
      return buf.indexOf match, start+match.length

    console.log e = find_end_of_pair buf, 4, '*/'
    console.log buf.substr e-2, 4

  it.only 'can build level hierearchy from pairs like ( [ { } ] )', ->
    buf = '''
    hello ( a ( b
      [ c
      { d e } f ] g ) h ) i
    '''

    console.log buf
    console.log '---'

    # allocates pairs into block levels
    pairs = [
      ['{','}'],
      ['(',')'],
      ['[',']']
    ]
    # TODO: ensure comments and strings are matched first so all that is left are these type of pairs
    # find pairs that cannot be escaped but can recurse
    # return an array or object representing their hierarchy w/ data inbetween
    match_pairs = (buf, start, pairs) ->
      matches = {}
      i = start-1
      # TODO: use regex replace here instead? so starts and ends can be dynamically sized from the start?
      # TODO: build new RegExp from string array keys join '|'
      while ++i < buf.length
        # TODO: later we can add multi-char support for other languages like %q( but for now we can rely on single-char pairs


        return buf.indexOf match, start+match.length

    console.log e = find_end_of_pair buf, 4, '*/'
    console.log buf.substr e-2, 4


  it 'can open and compile a file', (done) ->
    assert.isObject ast
    assert.isFunction ast.open
    ast.open fake_file, ->
      done()

  it 'can pretty print parsed string'#, ->
  #  ast.pretty_print()

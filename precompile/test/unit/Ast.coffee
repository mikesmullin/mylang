assert = require('chai').assert
Ast = require '../../Ast'
path = require 'path'

describe 'Ast', ->
  ast = undefined
  fake_file = path.join __dirname, '..', 'fixtures', 'main.m'

  before ->
    ast = new Ast

  it 'can be instantiated', ->
    assert.isObject ast

  #it 'can parse a string', ->
  #  assert.isObject ast
  #  assert.isFunction ast.parse
  #  ast.parse '1'

  it 'can open and compile a file', (done) ->
    assert.isObject ast
    assert.isFunction ast.open
    ast.open fake_file, ->
      done()

  it 'can pretty print parsed string', ->
    ast.pretty_print()

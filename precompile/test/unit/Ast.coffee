assert = require('chai').assert
Ast = require '../../Ast'
path = require 'path'

describe 'Ast', ->
  it 'can compile a file', (done) ->
    sample_file = path.join __dirname, '..', 'fixtures', 'test.java'
    ast = new Ast
    assert.isObject ast
    assert.isFunction ast.open
    ast.open sample_file, (code) ->
      console.log "--- OUTPUT:------\n#{code}"
      done()

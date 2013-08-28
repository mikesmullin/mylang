fs = require 'fs'
path = require 'path'
Ast = require './Ast'
parsed = new Ast fs.readFileSync path.join __dirname, '..', 'main.m'

#examples:
#
#coffee precompile/main.coffee /workspace/game/SmartFox/src/Server/javaExtensions/ /workspace/game/NodeDev/aj/server/game/precompile/socket/
#coffee precompile/main.coffee /workspace/game/SmartFox/src/Server/webserver/webapps/root/WEB-INF/classes /workspace/game/NodeDev/aj/server/game/precompile/http/

fs = require 'fs'
path = require 'path'
glob = require 'glob'
async = require 'async2'
[bin, script, indir, outdir] = process.argv

Ast = require './Ast'

require('glob') "#{indir}/**/*.java", (err, files) ->
  throw err if err
  flow = new async
  for file in files
    relfile = path.relative indir, file
    outfile = path.join outdir, relfile
    outfile = path.join outdir, (path.relative indir, path.dirname(file)), path.basename(file, '.java') + '.coffee'
    ((infile, outfile) ->
      flow.serial (next) ->
        ast = new Ast
        console.log "reading #{infile}..."
        ast.open infile, (code) ->
          require('child_process').exec "mkdir -p #{path.dirname outfile}", (err) ->
            throw err if err
            fs.writeFile outfile, code.toString(), encoding: 'utf8', (err) ->
              throw err if err
              console.log "wrote #{outfile}."
              next()
    )(file, outfile)
  flow.go (err) ->
    throw err if err
    console.log 'done'

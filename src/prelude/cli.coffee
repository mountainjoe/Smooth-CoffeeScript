coffeecup = require './coffeecup'
fs = require 'fs'
path = require 'path'
log = console.log
{OptionParser} = require 'coffee-script/lib/coffee-script/optparse'

argv = process.argv[2..]
options = null

handle_error = (err) -> console.log err.stack if err

compile = (input_path, output_directory, js, namespace = 'templates') ->
  fs.readFile input_path, 'utf-8', (err, contents) ->
    handle_error err

    name = path.basename input_path, path.extname(input_path)

    if not js
      output = coffeecup.render contents, options
      ext = '.html'
    else
      func = coffeecup.compile contents, options
      output = """
        (function(){ 
          this.#{namespace} || (this.#{namespace} = {});
          this.#{namespace}[#{JSON.stringify name}] = #{func};
        }).call(this);
      """
      ext = '.js'

    write input_path, name, output, output_directory, ext

write = (input_path, name, contents, output_directory, ext) ->
  filename = name + ext
  dir = output_directory or path.dirname input_path
  path.exists dir, (exists) ->
    unless exists then fs.mkdirSync dir, 0777
    
    output_path = path.join dir, filename
    contents = ' ' if contents.length <= 0
    fs.writeFile output_path, contents, (err) ->
      handle_error err
      log contents if options.print
      log "Compiled #{input_path}" if options.watch

usage = '''
  Usage:
    coffeecup [options] path/to/template.coffee
'''

switches = [
  ['-j', '--js', 'compile template to js function (template + embedded renderer)']
  ['-b', '--bare', 'use with -j to compile template to js (template only)' ]
  ['-c', '--core', 'use with -j to compile renderer to js (renderer only)' ]
  ['-n', '--namespace [name]', 'global object holding the templates (default: "templates")']
  ['-w', '--watch', 'watch templates for changes, and recompile']
  ['-o', '--output [dir]', 'set the directory for compiled html']
  ['-p', '--print', 'print the compiled html to stdout']
  ['-f', '--format', 'apply line breaks and indentation to html output']
  ['-u', '--utils', 'add helper locals (currently only "render")']
  ['-z', '--optimize', 'optimize resulting JS']
  ['-v', '--version', 'display coffeecup version']
  ['-h', '--help', 'display this help message']
]

@run = ->
  parser = new OptionParser switches, usage
  options = parser.parse argv
  args = options.arguments
  delete options.arguments

  log parser.help() if options.help or argv.length is 0
  log coffeecup.version if options.version
  if options.utils
    options.locals ?= {}
    options.locals.render = (file) ->
      contents = fs.readFileSync file, 'utf-8'
      coffeecup.render contents, options

  if args.length > 0
    file = args[0]

    if options.watch
      fs.watchFile file, {persistent: true, interval: 500}, (curr, prev) ->
        return if curr.size is prev.size and curr.mtime.getTime() is prev.mtime.getTime()
        compile file, options.output, options.js, options.namespace

    compile file, options.output, options.js, options.namespace


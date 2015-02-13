Docco
=====

**Docco** is a quick-and-dirty documentation generator, written in
[Literate CoffeeScript](http://coffeescript.org/#literate).
It produces an HTML document that displays your comments intermingled with your
code. All prose is passed through
[Markdown](http://daringfireball.net/projects/markdown/syntax), and code is
passed through [Highlight.js](http://highlightjs.org/) syntax highlighting.
This page is the result of running Docco against its own
[source file](https://github.com/jashkenas/docco/blob/master/docco.litcoffee).

1. Install Docco with **npm**: `sudo npm install -g docco`

2. Run it against your code: `docco src/*.coffee`

There is no "Step 3". This will generate an HTML page for each of the named
source files, with a menu linking to the other pages, saving the whole mess
into a `docs` folder (configurable).

The [Docco source](http://github.com/jashkenas/docco) is available on GitHub,
and is released under the [MIT license](http://opensource.org/licenses/MIT).

Docco can be used to process code written in any programming language. If it
doesn't handle your favorite yet, feel free to
[add it to the list](https://github.com/jashkenas/docco/blob/master/resources/languages.json).
Finally, the ["literate" style](http://coffeescript.org/#literate) of *any*
language is also supported — just tack an `.md` extension on the end:
`.coffee.md`, `.py.md`, and so on.


Partners in Crime:
------------------

* If Node.js doesn't run on your platform, or you'd prefer a more
convenient package, get [Ryan Tomayko](http://github.com/rtomayko)'s
[Rocco](http://rtomayko.github.io/rocco/rocco.html), the **Ruby** port that's
available as a gem.

* If you're writing shell scripts, try
[Shocco](http://rtomayko.github.io/shocco/), a port for the **POSIX shell**,
also by Mr. Tomayko.

* If **Python** is more your speed, take a look at
[Nick Fitzgerald](http://github.com/fitzgen)'s [Pycco](http://fitzgen.github.io/pycco/).

* For **Clojure** fans, [Fogus](http://blog.fogus.me/)'s
[Marginalia](http://fogus.me/fun/marginalia/) is a bit of a departure from
"quick-and-dirty", but it'll get the job done.

* There's a **Go** port called [Gocco](http://nikhilm.github.io/gocco/),
written by [Nikhil Marathe](https://github.com/nikhilm).

* For all you **PHP** buffs out there, Fredi Bach's
[sourceMakeup](http://jquery-jkit.com/sourcemakeup/) (we'll let the faux pas
with respect to our naming scheme slide), should do the trick nicely.

* **Lua** enthusiasts can get their fix with
[Robert Gieseke](https://github.com/rgieseke)'s [Locco](http://rgieseke.github.io/locco/).

* And if you happen to be a **.NET**
aficionado, check out [Don Wilson](https://github.com/dontangg)'s
[Nocco](http://dontangg.github.io/nocco/).

* Going further afield from the quick-and-dirty, [Groc](http://nevir.github.io/groc/)
is a **CoffeeScript** fork of Docco that adds a searchable table of contents,
and aims to gracefully handle large projects with complex hierarchies of code.

Note that not all ports will support all Docco features ... yet.


Main Documentation Generation Functions
---------------------------------------

Generate the documentation for our configured source file by copying over static
assets, reading all the source files in, splitting them up into prose+code
sections, highlighting each file in the appropriate language, and printing them
out in an HTML template.

    document = (options = {}, callback) ->
      config = configure options

      fs.mkdirs config.output, ->

        callback or= (error) -> throw error if error
        copyAsset  = (file, callback) ->
          return callback() unless fs.existsSync file
          fs.copy file, path.join(config.output, path.basename(file)), callback
        complete   = ->
          copyAsset config.css, (error) ->
            return callback error if error
            return copyAsset config.public, callback if fs.existsSync config.public
            callback()

        files = config.sources.slice()

        nextFile = ->
          source = files.shift()
          fs.readFile source, (error, buffer) ->
            return callback error if error

            code = buffer.toString()
            sections = parse source, code, config
            format source, sections, config
            write source, sections, config
            if files.length then nextFile() else complete()

        nextFile()

Given a string of source code, **parse** out each block of prose and the code that
follows it — by detecting which is which, line by line — and then create an
individual **section** for it. Each section is an object with `docsText` and
`codeText` properties, and eventually `docsHtml` and `codeHtml` as well.

    parse = (source, code, config = {}) ->
      lines    = code.split '\n'
      sections = []
      lang     = getLanguage source, config
      hasCode  = docsText = codeText = ''

      save = ->
        sections.push {docsText, codeText}
        hasCode = docsText = codeText = ''

Our quick-and-dirty implementation of the literate programming style. Simply
invert the prose and code relationship on a per-line basis, and then continue as
normal below.

      if lang.literate
        isText = maybeCode = yes
        for line, i in lines
          lines[i] = if maybeCode and match = /^([ ]{4}|[ ]{0,3}\t)/.exec line
            isText = no
            line[match[0].length..]
          else if maybeCode = /^\s*$/.test line
            if isText then lang.symbol else ''
          else
            isText = yes
            lang.symbol + ' ' + line

      for line in lines
        continue if line.match lang.discardLineFilter
        if lang.name is 'markdown' or (line.match(lang.commentMatcher) and not line.match(lang.commentFilter))
          save() if hasCode
          if lang.name isnt 'markdown'
            line = line.replace(lang.commentMatcher, '')
          docsText += line + '\n'
          save() if /^(---+|===+)$/.test line
        else
          hasCode = yes
          codeText += line + '\n'
      save()

      sections

To **format** and highlight the now-parsed sections of code, we use **Highlight.js**
over stdio, and run the text of their corresponding comments through
**Markdown**, using [Marked](https://github.com/chjj/marked).

    format = (source, sections, config) ->
      language = getLanguage source, config

Pass any user defined options to Marked if specified via command line option

      markedOptions =
        smartypants: true

      if config.marked
        markedOptions = config.marked

      marked.setOptions markedOptions

Tell Marked how to highlight code blocks within comments, treating that code
as either the language specified in the code block or the language of the file
if not specified.

      marked.setOptions {
        highlight: (code, lang) ->
          lang or= language.name

          if highlightjs.getLanguage(lang)
            highlightjs.highlight(lang, code).value
          else
            console.warn "docco: couldn't highlight code block with unknown language '#{lang}' in #{source}"
            code
      }

      for section, i in sections
        code = highlightjs.highlight(language.name, section.codeText).value
        code = code.replace(/\s+$/, '')
        section.codeHtml = "<div class='highlight'><pre>#{code}</pre></div>"
        section.docsHtml = marked(section.docsText)
        firstComment = marked.lexer(section.docsText)[0]
        if firstComment?.type is 'heading'
          section.heading = firstComment.text
          section.headingDepth = firstComment.depth

Once all of the code has finished highlighting, we can **write** the resulting
documentation file by passing the completed HTML sections into the template,
and rendering it to the specified output path.

    write = (source, sections, config) ->

      destination = (file, options = {}) ->
        if (options.fKeepExtension ? false)
          filename = path.basename file
        else
          filename = path.basename(file, path.extname(file)) + '.html'
        path.join(config.output, path.dirname(file), filename)

      htmlPath = (file, options = {}) ->
        goOut = path.relative path.dirname(destination(source)), config.output
        goIn  = path.relative config.output, destination(file, options)
        return slash(path.join goOut, goIn)

      assetPath = (file) -> htmlPath file, fKeepExtension: true

The **title** of the file is either the first heading in the prose, or the
name of the source file.

      firstSection = _.find sections, (section) ->
        section.docsText.length > 0
      first = marked.lexer(firstSection.docsText)[0] if firstSection
      hasTitle = first and first.type is 'heading' and first.depth is 1
      title = if hasTitle then first.text else path.basename source

      destinationFile = destination(source)
      destinationDir  = path.dirname destinationFile

      lang = getLanguage source, config
      template = if lang.name is 'markdown' then config.mdTemplate else config.template

      html = template 
        sources:      config.sources
        css:          path.join(path.relative(destinationDir, config.output), path.basename(config.css))
        destination:  htmlPath
        htmlPath:     htmlPath
        assetPath:    assetPath
        path:         path
        title:        title
        hasTitle:     hasTitle
        sections:     sections

      console.log "docco: #{source} -> #{destination source}"
      fs.mkdirsSync destinationDir
      fs.writeFileSync destinationFile, html


Configuration
-------------

Default configuration **options**. All of these may be extended by
user-specified options.

    defaults =
      layout:     'parallel'
      output:     'docs'
      template:   null
      mdTemplate: null
      css:        null
      extension:  null
      languages:  {}
      marked:     null

**Configure** this particular run of Docco. We might use a passed-in external
template, or one of the built-in **layouts**. We only attempt to process
source files for languages for which we have definitions.

    configure = (options) ->
      config = _.extend {}, defaults, _.pick(options, _.keys(defaults)...)

      config.languages = buildMatchers config.languages

The user is able to override the layout file used with the `--template` parameter.
In this case, it is also neccessary to explicitly specify a stylesheet file.
These custom templates are compiled exactly like the predefined ones, but the `public` folder
is only copied for the latter.

      dir = config.layout = path.join __dirname, 'resources', config.layout
      config.public       = path.join dir, 'public' if fs.existsSync path.join dir, 'public'
      config.css          = path.join dir, 'docco.css'
      config.template     = _.template fs.readFileSync(path.join dir, 'docco.jst').toString()
      config.mdTemplate   = _.template fs.readFileSync(path.join dir, 'markdown.jst').toString()

      if options.marked
        config.marked = JSON.parse fs.readFileSync(options.marked)

      allSources = []
      for fileOrDir in options.args
        console.log fileOrDir
        stats = fs.lstatSync fileOrDir
        if stats.isDirectory()
          console.log '...is a dir'
          diveSync fileOrDir, (err, file) -> allSources.push file unless err
        else if stats.isFile()
          console.log '...is a file'
          allSources.push fileOrDir

      config.sources = allSources.filter((source) ->
        lang = getLanguage source, config
        console.warn "docco: skipped unknown type (#{source})" unless lang
        lang
      ).sort()

      config


Helpers & Initial Setup
-----------------------

Require our external dependencies.

    _           = require 'underscore'
    fs          = require 'fs-extra'
    path        = require 'path'
    marked      = require 'marked'
    commander   = require 'commander'
    highlightjs = require 'highlight.js'
    diveSync    = require 'diveSync'
    slash       = require 'slash'

Languages are stored in JSON in the file `resources/languages.json`.
Each item maps the file extension to the name of the language and the
`symbol` that indicates a line comment. To add support for a new programming
language to Docco, just add it to the file.

    languages = JSON.parse fs.readFileSync(path.join(__dirname, 'resources', 'languages.json'))

Build out the appropriate matchers and delimiters for each language.

    buildMatchers = (languages) ->
      for ext, l of languages

Does the line begin with a comment?

        l.commentMatcher = ///^\s*#{l.symbol}\s?///

Ignore [hashbangs](http://en.wikipedia.org/wiki/Shebang_%28Unix%29) and interpolations...

        if l.name is 'coffeescript'
          l.commentFilter = /(^#![/]|^\s*#\{|^\s*## )/
        else
          l.commentFilter = /(^#![/]|^\s*#\{)/

Ignore these lines altogether

        l.discardLineFilter = /^\s*#-/
      languages
    languages = buildMatchers languages

A function to get the current language we're documenting, based on the
file extension. Detect and tag "literate" `.ext.md` variants.

    getLanguage = (source, config) ->
      ext  = config.extension or path.extname(source) or path.basename(source)
      lang = config.languages?[ext] or languages[ext]
      if lang and lang.name is 'markdown'
        codeExt = path.extname(path.basename(source, ext))
        if codeExt and codeLang = languages[codeExt]
          lang = _.extend {}, codeLang, {literate: yes}
      lang

Keep it DRY. Extract the docco **version** from `package.json`

    version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'))).version


Command Line Interface
----------------------

Finally, let's define the interface to run Docco from the command line.
Parse options using [Commander](https://github.com/visionmedia/commander.js).

    run = (args = process.argv) ->
      c = defaults
      commander.version(version)
        .usage('[options] directories')
        .option('-L, --languages [file]', 'use a custom languages.json', _.compose JSON.parse, fs.readFileSync)
        .option('-l, --layout [name]',    'choose a layout (parallel, linear or classic)', c.layout)
        .option('-o, --output [path]',    'output to a given folder', c.output)
        .option('-e, --extension [ext]',  'assume a file extension for all inputs', c.extension)
        .option('-m, --marked [file]',    'use custom marked options', c.marked)
        .parse(args)
        .name = "docco"
      if commander.args.length
        document commander
      else
        console.log commander.helpInformation()


Public API
----------

    Docco = module.exports = {run, document, parse, format, version}

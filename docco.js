// Generated by CoffeeScript 1.3.3
(function() {
  var Docco, commander, configure, defaults, document, ext, format, fs, getLanguage, highlight, l, languages, marked, parse, path, run, version, write, _,
    __slice = [].slice;

  document = function(options, callback) {
    var config;
    if (options == null) {
      options = {};
    }
    config = configure(options);
    return fs.mkdirs(config.output, function() {
      var complete, copyAsset, files, nextFile;
      callback || (callback = function(error) {
        if (error) {
          throw error;
        }
      });
      copyAsset = function(file, callback) {
        return fs.copy(file, path.join(config.output, path.basename(file)), callback);
      };
      complete = function() {
        return copyAsset(config.css, function(error) {
          if (error) {
            return callback(error);
          } else if (fs.existsSync(config["public"])) {
            return copyAsset(config["public"], callback);
          } else {
            return callback();
          }
        });
      };
      files = config.sources.slice();
      nextFile = function() {
        var source;
        source = files.shift();
        return fs.readFile(source, function(error, buffer) {
          var code, sections;
          if (error) {
            return callback(error);
          }
          code = buffer.toString();
          sections = parse(source, code, config);
          format(source, sections, config);
          write(source, sections, config);
          if (files.length) {
            return nextFile();
          } else {
            return complete();
          }
        });
      };
      return nextFile();
    });
  };

  parse = function(source, code, config) {
    var codeText, docsText, hasCode, i, in_block, isText, lang, line, lines, match, maybeCode, param, save, sections, single, _i, _j, _len, _len1;
    if (config == null) {
      config = {};
    }
    lines = code.split('\n');
    sections = [];
    lang = getLanguage(source, config);
    hasCode = docsText = codeText = '';
    param = '';
    in_block = 0;
    save = function() {
      sections.push({
        docsText: docsText,
        codeText: codeText
      });
      return hasCode = docsText = codeText = '';
    };
    if (lang.literate) {
      isText = maybeCode = true;
      for (i = _i = 0, _len = lines.length; _i < _len; i = ++_i) {
        line = lines[i];
        lines[i] = maybeCode && (match = /^([ ]{4}|[ ]{0,3}\t)/.exec(line)) ? (isText = false, line.slice(match[0].length)) : (maybeCode = /^\s*$/.test(line)) ? isText ? lang.symbol : '' : (isText = true, lang.symbol + ' ' + line);
      }
    }
    for (_j = 0, _len1 = lines.length; _j < _len1; _j++) {
      line = lines[_j];
      if (in_block) {
        ++in_block;
      }
      if (!in_block && config.blocks && lang.blocks && line.match(lang.commentEnter)) {
        line = line.replace(lang.commentEnter, '');
        in_block = 1;
      }
      single = lang.commentMatcher && line.match(lang.commentMatcher) && !line.match(lang.commentFilter);
      if (in_block || single) {
        if (hasCode) {
          save();
        }
        if (!in_block) {
          line = line.replace(lang.commentMatcher, '');
        }
        if (in_block > 1 && lang.commentNext) {
          line = line.replace(lang.commentNext, '');
        }
        if (lang.commentParam) {
          param = line.match(lang.commentParam);
          if (param) {
            line = line.replace(param[0], '\n' + '<b>' + param[1] + '</b>');
          }
        }
        if (in_block && line.match(lang.commentExit)) {
          line = line.replace(lang.commentExit, '');
          in_block = false;
        }
        docsText += line + '\n';
        if (/^(---+|===+)$/.test(line)) {
          save();
        }
      } else {
        hasCode = true;
        codeText += line + '\n';
      }
    }
    save();
    return sections;
  };

  format = function(source, sections, config) {
    var code, i, language, section, _i, _len, _results;
    language = getLanguage(source, config);
    _results = [];
    for (i = _i = 0, _len = sections.length; _i < _len; i = ++_i) {
      section = sections[i];
      code = highlight(language.name, section.codeText).value;
      code = code.replace(/\s+$/, '');
      section.codeHtml = "<div class='highlight'><pre>" + code + "</pre></div>";
      _results.push(section.docsHtml = marked(section.docsText));
    }
    return _results;
  };

  write = function(source, sections, config) {
    var destination, first, hasTitle, html, title;
    destination = function(file) {
      return path.join(config.output, path.basename(file, path.extname(file)) + '.html');
    };
    first = marked.lexer(sections[0].docsText)[0];
    hasTitle = first && first.type === 'heading' && first.depth === 1;
    title = hasTitle ? first.text : path.basename(source);
    html = config.template({
      sources: config.sources,
      css: path.basename(config.css),
      title: title,
      hasTitle: hasTitle,
      sections: sections,
      path: path,
      destination: destination
    });
    console.log("docco: " + source + " -> " + (destination(source)));
    return fs.writeFileSync(destination(source), html);
  };

  defaults = {
    layout: 'parallel',
    output: 'docs',
    template: null,
    css: null,
    extension: null,
    blocks: false,
    markdown: false
  };

  configure = function(options) {
    var config, dir;
    config = _.extend({}, defaults, _.pick.apply(_, [options].concat(__slice.call(_.keys(defaults)))));
    if (options.template) {
      config.layout = null;
    } else {
      dir = config.layout = path.join(__dirname, 'resources', config.layout);
      if (fs.existsSync(path.join(dir, 'public'))) {
        config["public"] = path.join(dir, 'public');
      }
      config.template = path.join(dir, 'docco.jst');
      config.css = options.css || path.join(dir, 'docco.css');
    }
    config.template = _.template(fs.readFileSync(config.template).toString());
    config.sources = options.args.filter(function(source) {
      var lang;
      lang = getLanguage(source, config);
      if (!lang) {
        console.warn("docco: skipped unknown type (" + (path.basename(source)) + ")");
      }
      return lang;
    }).sort();
    return config;
  };

  _ = require('underscore');

  fs = require('fs-extra');

  path = require('path');

  marked = require('marked');

  commander = require('commander');

  highlight = require('highlight.js').highlight;

  languages = JSON.parse(fs.readFileSync(path.join(__dirname, 'resources', 'languages.json')));

  for (ext in languages) {
    l = languages[ext] || 'text';
    if (l.symbol) {
      l.commentMatcher = RegExp("^\\s*" + l.symbol + "\\s?");
    }
    if (l.enter && l.exit) {
      l.blocks = true;
      l.commentEnter = new RegExp(l.enter);
      l.commentExit = new RegExp(l.exit);
      if (l.next) {
        l.commentNext = new RegExp(l.next);
      }
    }
    if (l.param) {
      l.commentParam = new RegExp(l.param);
    }
    l.commentFilter = /(^#![/]|^\s*#\{)/;
  }

  getLanguage = function(source, config) {
    var codeExt, codeLang, lang;
    ext = config.extension || path.extname(source) || path.basename(source);
    lang = languages[ext];
    if (lang && lang.name === 'markdown') {
      codeExt = path.extname(path.basename(source, ext));
      if (codeExt && (codeLang = languages[codeExt])) {
        lang = _.extend({}, codeLang, {
          literate: true
        });
      }
    }
    return lang;
  };

  version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'))).version;

  run = function(args) {
    var c;
    if (args == null) {
      args = process.argv;
    }
    c = defaults;
    commander.version(version).usage('[options] files').option('-l, --layout [name]', 'choose a layout (parallel, linear or classic)', c.layout).option('-o, --output [path]', 'output to a given folder', c.output).option('-c, --css [file]', 'use a custom css file', c.css).option('-t, --template [file]', 'use a custom .jst template', c.template).option('-b, --blocks', 'parse block comments where available', c.blocks).option('-m, --markdown', 'output markdown', c.markdown).option('-e, --extension [ext]', 'assume a file extension for all inputs', c.extension).parse(args).name = "docco";
    if (commander.args.length) {
      return document(commander);
    } else {
      return console.log(commander.helpInformation());
    }
  };

  Docco = module.exports = {
    run: run,
    document: document,
    parse: parse,
    version: version
  };

}).call(this);

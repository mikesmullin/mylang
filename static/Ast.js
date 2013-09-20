// Generated by CoffeeScript 1.6.3
var Ast, CHAR, Enum, INDENT, OPERATOR, SYMBOL, SYNTAX, Symbol, deepCopy,
  __hasProp = {}.hasOwnProperty,
  __slice = [].slice;

deepCopy = function(obj) {
  var i, len, out;
  if (Object.prototype.toString.call(obj) === "[object Array]") {
    out = [];
    i = 0;
    len = obj.length;
    while (i < len) {
      out[i] = arguments.callee(obj[i]);
      i++;
    }
    return out;
  }
  if (typeof obj === "object") {
    out = {};
    i = void 0;
    for (i in obj) {
      out[i] = arguments.callee(obj[i]);
    }
    return out;
  }
  return obj;
};

Enum = (function() {
  function Enum(a) {
    var i, v, _i, _len;
    for (i = _i = 0, _len = a.length; _i < _len; i = ++_i) {
      v = a[i];
      this[v] = {
        "enum": v
      };
    }
  }

  return Enum;

})();

CHAR = {
  SPACE: ' ',
  TAB: "\t",
  CR: "\r",
  LF: "\n",
  EXCLAIMATION: '!',
  DOUBLE_QUOTE: '"',
  SINGLE_QUOTE: "'",
  POUND: '#',
  DOLLAR: '$',
  PERCENT: '%',
  AMPERSAND: '&',
  OPEN_PARENTHESIS: '(',
  CLOSE_PARENTHESIS: ')',
  ASTERISK: '*',
  PLUS: '+',
  COMMA: ',',
  HYPHEN: '-',
  PERIOD: '.',
  SLASH: '/',
  COLON: ':',
  SEMICOLON: ';',
  LESS: '<',
  EQUAL: '=',
  GREATER: '>',
  QUESTION: '?',
  AT: '@',
  OPEN_BRACKET: '[',
  CLOSE_BRACKET: ']',
  BACKSLASH: "\\",
  CARET: '^',
  UNDERSCORE: '_',
  GRAVE: '`',
  OPEN_BRACE: '{',
  CLOSE_BRACE: '}',
  BAR: '|',
  TILDE: '~'
};

INDENT = new Enum(['SPACE', 'TAB', 'MIXED']);

Symbol = (function() {
  function Symbol(chars, types, meta) {
    var k, v;
    this.chars = chars;
    this.types = types;
    if (meta == null) {
      meta = {};
    }
    for (k in meta) {
      if (!__hasProp.call(meta, k)) continue;
      v = meta[k];
      this[k] = v;
    }
    return;
  }

  Symbol.prototype.pushUniqueType = function(v) {
    if (-1 === this.types.indexOf(v)) {
      this.types.push(v);
    }
  };

  Symbol.prototype.hasType = function() {
    var types, __type, _i, _j, _len, _len1, _ref, _type;
    types = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    _ref = this.types;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _type = _ref[_i];
      for (_j = 0, _len1 = types.length; _j < _len1; _j++) {
        __type = types[_j];
        if (_type === void 0 || __type === void 0) {
          console.log("called hasType with ", {
            at: this,
            _type: _type,
            __type: __type,
            types: types
          });
          console.trace();
        }
        if (_type["enum"] === __type["enum"]) {
          return true;
        }
      }
    }
    return false;
  };

  Symbol.prototype.isA = function(str_type) {
    return this.hasType(SYMBOL[str_type.toUpperCase()]);
  };

  Symbol.prototype.removeType = function(type) {
    var i, _i, _len, _ref, _type;
    _ref = this.types;
    for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
      _type = _ref[i];
      if (!(_type["enum"] === type["enum"])) {
        continue;
      }
      this.types.splice(i, 1);
      return;
    }
  };

  Symbol.prototype.clone = function(char_delta, new_chars) {
    var symbol;
    symbol = deepCopy(this);
    if (new_chars) {
      symbol.chars = new_chars;
    }
    symbol.char += char_delta;
    return symbol;
  };

  Symbol.prototype.split = function(index, len, arr, i) {
    var args, l, ll;
    l = this.chars.length;
    args = [i, 1];
    if (index > 0) {
      args.push(this.clone(0, this.chars.substr(0, index)));
    }
    args.push(this.clone(index, this.chars.substr(index, len)));
    if ((ll = l - index - len) > 0) {
      args.push(this.clone(index + len, this.chars.substr(index + len, ll)));
    }
    Array.prototype.splice.apply(arr, args);
    return [arr[i + 1], args.length - 3];
  };

  Symbol.prototype.merge = function(arr, i, len) {
    var ii, k, kk, symbol, v, vv, _i, _j, _k, _len, _len1, _ref, _ref1, _ref2;
    symbol = arr[i];
    for (ii = _i = _ref = i + 1, _ref1 = i + len; _ref <= _ref1 ? _i < _ref1 : _i > _ref1; ii = _ref <= _ref1 ? ++_i : --_i) {
      _ref2 = arr[ii];
      for (k in _ref2) {
        if (!__hasProp.call(_ref2, k)) continue;
        v = _ref2[k];
        if (k === 'chars') {
          symbol[k] += v;
        } else if (k === 'types') {
          symbol[k] || (symbol[k] = []);
          for (_j = 0, _len = v.length; _j < _len; _j++) {
            vv = v[_j];
            symbol.pushUniqueType(vv);
          }
        } else if (k === 'line' || k === 'char') {
          symbol[k] = Math.min(symbol[k], v);
        } else {
          if (Object.prototype.toString.call(v) === "[object Array]") {
            for (_k = 0, _len1 = v.length; _k < _len1; _k++) {
              vv = v[_k];
              symbol[k] || (symbol[k] = []);
              symbol[k].push(vv);
            }
          } else if (typeof v === 'object') {
            for (kk in v) {
              if (!__hasProp.call(v, kk)) continue;
              vv = v[kk];
              symbol[k] || (symbol[k] = {});
              symbol[k][kk] = vv;
            }
          } else {
            symbol[k] = v;
          }
        }
      }
    }
    arr.splice(i, len, symbol);
    return [arr[i], len * -1];
  };

  return Symbol;

})();

SYMBOL = new Enum(['LINEBREAK', 'INDENT', 'WORD', 'TEXT', 'KEYWORD', 'LETTER', 'ID', 'OP', 'STATEMENT_END', 'LITERAL', 'STRING', 'NUMBER', 'INTEGER', 'DECIMAL', 'HEX', 'REGEX', 'PUNCTUATION', 'PARENTHESIS', 'SQUARE_BRACKET', 'ANGLE_BRACKET', 'BRACE', 'PAIR', 'OPEN', 'CLOSE', 'COMMENT', 'ENDLINE_COMMENT', 'MULTILINE_COMMENT', 'CALL', 'INDEX', 'PARAM', 'TERMINATOR', 'LEVEL_INC', 'LEVEL_DEC', 'ACCESS', 'TYPE', 'CAST', 'GENERIC_TYPE', 'SUPPORT', 'DOUBLE_SPACE', 'BLOCK']);

OPERATOR = new Enum(['UNARY_LEFT', 'UNARY_RIGHT', 'BINARY_LEFT_RIGHT', 'BINARY_LEFT_LEFT', 'BINARY_RIGHT_RIGHT', 'TERNARY_RIGHT_RIGHT_RIGHT']);

SYNTAX = {
  JAVA: {
    KEYWORDS: {
      STATEMENTS: ['case', 'catch', 'continue', 'default', 'finally', 'goto', 'return', 'switch', 'try', 'throw'],
      BLOCK: ['if', 'else', 'for', 'while', 'do'],
      ACCESS_MODIFIERS: ['abstract', 'const', 'private', 'protected', 'public', 'static', 'synchronized', 'transient', 'volatile', 'final'],
      TYPES: ['boolean', 'double', 'char', 'float', 'int', 'long', 'short', 'void'],
      OTHER: ['class', 'new', 'import', 'package', 'super', 'this', 'enum', 'implements', 'extends', 'instanceof', 'interface', 'native', 'strictfp', 'throws']
    },
    LITERALS: ['false', 'null', 'true'],
    OPERATORS: [
      {
        type: OPERATOR.UNARY_LEFT,
        name: 'postfix',
        symbols: ['++', '--']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'equality',
        symbols: ['==', '!=']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'assignment',
        symbols: ['+=', '-=', '*=', '/=', '%=', '&=', '^=', '|=', '<<=', '>>=', '>>>=']
      }, {
        type: OPERATOR.UNARY_RIGHT,
        name: 'unary',
        symbols: ['++', '--', '+', '-', '~', '!']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'multiplicative',
        symbols: ['*', '/', '%']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'additive',
        symbols: ['+', '-']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'shift',
        symbols: ['<<', '>>', '>>>']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'relational',
        symbols: ['<=', '>=', '<', '>', 'instanceof', '=']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'logical AND',
        symbols: ['&&']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'bitwise AND',
        symbols: ['&']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'bitwise exclusive OR',
        symbols: ['^']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'logical OR',
        symbols: ['||']
      }, {
        type: OPERATOR.BINARY_LEFT_RIGHT,
        name: 'bitwise inclusive OR',
        symbols: ['|']
      }, {
        type: OPERATOR.TERNARY_RIGHT_RIGHT_RIGHT,
        name: 'ternary',
        symbols: [['?', ':']]
      }
    ],
    PAIRS: [
      {
        name: 'multi-line comment',
        types: [SYMBOL.COMMENT, SYMBOL.MULTILINE_COMMENT],
        symbols: ['/*', '*/']
      }, {
        name: 'single-line comment',
        types: [SYMBOL.COMMENT, SYMBOL.ENDLINE_COMMENT],
        symbols: ['//']
      }, {
        name: 'string',
        types: [SYMBOL.STRING],
        symbols: ['"', '"'],
        escaped_by: '\\'
      }, {
        name: 'character',
        types: [SYMBOL.STRING],
        symbols: ["'", "'"],
        escaped_by: '\\'
      }, {
        name: 'block',
        types: [SYMBOL.BRACE],
        symbols: ['{', '}']
      }, {
        name: 'arguments',
        types: [SYMBOL.PARENTHESIS],
        symbols: ['(', ')']
      }, {
        name: 'generic',
        types: [SYMBOL.ANGLE_BRACKET],
        symbols: ['<', '>']
      }, {
        name: 'index',
        types: [SYMBOL.SQUARE_BRACKET],
        symbols: ['[', ']']
      }
    ]
  }
};

Ast = (function() {
  function Ast() {}

  Ast.prototype.open = function(file, cb) {
    var fs,
      _this = this;
    if (!(require && (fs = require('fs')))) {
      return;
    }
    fs.readFile(file, {
      encoding: 'utf8',
      flag: 'r'
    }, function(err, data) {
      var code;
      if (err) {
        throw err;
      }
      code = _this.compile(file, data);
      return cb(code);
    });
  };

  Ast.prototype.compile = function(file, buf) {
    var code, symbol_array;
    symbol_array = this.lexer(file, buf);
    symbol_array = this.symbolizer(symbol_array);
    symbol_array = this.java_syntaxer(symbol_array);
    code = this.translate_to_coffee(symbol_array);
    return code;
  };

  Ast.prototype.lexer = function(file, buf) {
    var byte, c, char, double_space, indent_buf, indent_type_this_line, is_eol, is_operator, is_pair, len, level, line, nonword_buf, peek, push_symbol, r, slice_line_buf, slice_nonword_buf, slice_space_buf, slice_word_buf, space_buf, symbol, symbol_array, throwError, word_buf, word_on_this_line, x, zbyte;
    c = '';
    len = buf.length;
    byte = 1;
    char = 0;
    line = 1;
    level = 0;
    zbyte = -1;
    word_buf = '';
    space_buf = '';
    indent_buf = '';
    nonword_buf = '';
    symbol_array = [];
    double_space = true;
    word_on_this_line = false;
    indent_type_this_line = void 0;
    throwError = function(msg) {
      throw new Error("" + file + ":" + line + ":" + char + ": " + msg);
    };
    peek = function(n, l) {
      if (l == null) {
        l = 1;
      }
      return buf.substr(zbyte + n, l);
    };
    is_eol = function(i) {
      if (buf[i] === CHAR.CR && buf[i + 1] === CHAR.LF) {
        return 2;
      } else if (buf[i] === CHAR.CR || buf[i] === CHAR.LF) {
        return 1;
      } else {
        return false;
      }
    };
    push_symbol = function(chars, symbol, meta) {
      if (meta == null) {
        meta = {};
      }
      meta.line = line;
      meta.char = char - chars.length;
      meta.byte = byte - chars.length;
      symbol_array.push(new Symbol(chars, [symbol], meta));
    };
    slice_word_buf = function() {
      if (word_buf.length) {
        push_symbol(word_buf, SYMBOL.WORD);
        word_on_this_line || (word_on_this_line = true);
        word_buf = '';
        double_space = false;
      }
    };
    slice_nonword_buf = function() {
      if (nonword_buf.length) {
        push_symbol(nonword_buf, SYMBOL.TEXT);
        word_on_this_line || (word_on_this_line = true);
        nonword_buf = '';
        double_space = false;
      }
    };
    slice_space_buf = function() {
      if (indent_buf.length) {
        indent_buf = '';
      } else if (space_buf.length) {
        space_buf = '';
      }
    };
    slice_line_buf = function(num_chars) {
      slice_space_buf();
      slice_nonword_buf();
      slice_word_buf();
      if (zbyte < len) {
        if (double_space) {
          push_symbol(buf.substr(zbyte, num_chars), SYMBOL.DOUBLE_SPACE);
        }
        line++;
        char = 0;
        zbyte += num_chars - 1;
        word_on_this_line = false;
        indent_type_this_line = void 0;
        double_space = true;
      }
    };
    is_pair = function(high_precedence) {
      var find_end_of_escaped_pair, k, pair, search, symbol, type, x, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;
      if (high_precedence == null) {
        high_precedence = false;
      }
      _ref = SYNTAX.JAVA.PAIRS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        pair = _ref[_i];
        _ref1 = pair.symbols;
        for (k = _j = 0, _len1 = _ref1.length; _j < _len1; k = ++_j) {
          search = _ref1[k];
          if (search === peek(0, search.length)) {
            double_space = false;
            symbol = new Symbol(search, [], {
              line: line,
              char: char,
              byte: byte,
              pair: {
                name: pair.name
              }
            });
            _ref2 = pair.types;
            for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
              type = _ref2[_k];
              symbol.pushUniqueType(type);
            }
            if (high_precedence) {
              if (symbol.hasType(SYMBOL.COMMENT)) {
                if (pair.symbols.length === 1) {
                  x = zbyte;
                  while (++x < len && false === is_eol(x)) {}
                  symbol.chars = buf.substr(zbyte, x - zbyte);
                  return [symbol, x - zbyte];
                } else {
                  if (-1 !== (x = buf.indexOf(pair.symbols[1], zbyte + search.length + pair.symbols[1].length))) {
                    symbol.chars = buf.substr(zbyte, x - zbyte + pair.symbols[1].length);
                    return [symbol, x - zbyte + pair.symbols[1].length];
                  } else {
                    throwError("unmatched comment pair \"" + search + "\"");
                  }
                }
              }
              if (symbol.hasType(SYMBOL.STRING)) {
                find_end_of_escaped_pair = function(buf, start, match, escape) {
                  var i;
                  i = start;
                  while (-1 !== (i = buf.indexOf(match, i + match.length - 1))) {
                    if (!(escape && buf.substr(i - escape.length, escape.length) === escape && buf.substr(i - (escape.length * 2), escape.length) !== escape)) {
                      return i;
                    }
                  }
                  return -1;
                };
                if (-1 !== (x = find_end_of_escaped_pair(buf, zbyte + 1, pair.symbols[1], pair.escaped_by))) {
                  symbol.chars = buf.substr(zbyte, x - zbyte + 1);
                  return [symbol, x - zbyte + 1];
                } else {
                  throwError("unmatched string pair \"" + search + "\"");
                }
              }
            } else {
              symbol.pushUniqueType(SYMBOL.PAIR);
              if (k === 0 || pair.symbols[0] === pair.symbols[1]) {
                symbol.pushUniqueType(SYMBOL.OPEN);
              }
              if (k === 1 || pair.symbols[0] === pair.symbols[1]) {
                symbol.pushUniqueType(SYMBOL.CLOSE);
              }
              return [symbol, search.length];
            }
          }
        }
      }
    };
    is_operator = function() {
      var operator, search, symbol, _i, _j, _len, _len1, _ref, _ref1;
      _ref = SYNTAX.JAVA.OPERATORS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        operator = _ref[_i];
        _ref1 = operator.symbols;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          search = _ref1[_j];
          if (search === peek(0, search.length)) {
            double_space = false;
            symbol = new Symbol(search, [SYMBOL.OP], {
              line: line,
              char: char,
              byte: byte,
              operator: {
                type: operator.type,
                name: operator.name
              }
            });
            return [symbol, search.length];
          }
        }
      }
      return false;
    };
    while (++zbyte < len) {
      c = buf[zbyte];
      byte = zbyte + 1;
      ++char;
      if (x = is_eol(zbyte)) {
        slice_line_buf(x);
      } else if (c === CHAR.SPACE || c === CHAR.TAB) {
        slice_nonword_buf();
        slice_word_buf();
        if (word_on_this_line) {
          space_buf += c;
        } else {
          if (c === CHAR.SPACE) {
            indent_type_this_line || (indent_type_this_line = indent_type_this_line === INDENT.TAB ? INDENT.MIXED : INDENT.SPACE);
          } else if (c === CHAR.TAB) {
            indent_type_this_line || (indent_type_this_line = indent_type_this_line === INDENT.SPACE ? INDENT.MIXED : INDENT.TAB);
          }
          indent_buf += c;
        }
      } else {
        slice_space_buf();
        if (c.match(/[a-zA-Z0-9_]/)) {
          slice_nonword_buf();
          word_buf += c;
        } else {
          slice_word_buf();
          if (r = is_pair(true)) {
            symbol = r[0], x = r[1];
            symbol_array.push(symbol);
            zbyte += x - 1;
            continue;
          }
          if (r = is_operator()) {
            symbol = r[0], x = r[1];
            symbol_array.push(symbol);
            zbyte += x - 1;
            continue;
          }
          if (r = is_pair(false)) {
            symbol = r[0], x = r[1];
            symbol_array.push(symbol);
            zbyte += x - 1;
            continue;
          }
          if (c === CHAR.SEMICOLON) {
            double_space = false;
            symbol_array.push(new Symbol(c, [SYMBOL.STATEMENT_END], {
              line: line,
              char: char,
              byte: byte
            }));
            continue;
          }
          nonword_buf += c;
        }
      }
    }
    slice_line_buf();
    return symbol_array;
  };

  Ast.prototype.symbolizer = function(symbol_array) {
    var i, len, next_symbol, peek,
      _this = this;
    i = -1;
    len = symbol_array.length;
    peek = function(n) {
      var old_i, symbol, target_i;
      old_i = i;
      if (n > 0) {
        target_i = i + n;
        while (++i < target_i) {
          next_symbol();
        }
      } else {
        i += n;
      }
      symbol = symbol_array[i];
      i = old_i;
      return symbol;
    };
    next_symbol = function() {
      var delta, group, keyword, keywords, literal, symbol, _i, _j, _len, _len1, _ref, _ref1, _ref2;
      symbol = symbol_array[i];
      if (symbol.hasType(SYMBOL.WORD)) {
        if ((i === 0 || !peek(-1).hasType(SYMBOL.TEXT)) && (i === len || !peek(1).hasType(SYMBOL.TEXT))) {
          _ref = SYNTAX.JAVA.KEYWORDS;
          for (group in _ref) {
            keywords = _ref[group];
            for (_i = 0, _len = keywords.length; _i < _len; _i++) {
              keyword = keywords[_i];
              if (!(symbol.chars === keyword)) {
                continue;
              }
              symbol.pushUniqueType(SYMBOL.KEYWORD);
              switch (group) {
                case 'ACCESS_MODIFIERS':
                  symbol.types = [SYMBOL.ACCESS];
                  break;
                case 'TYPES':
                  symbol.types = [SYMBOL.TYPE];
                  break;
                case 'BLOCK':
                  symbol.pushUniqueType(SYMBOL.BLOCK);
              }
              return;
            }
          }
          _ref1 = SYNTAX.JAVA.LITERALS;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            literal = _ref1[_j];
            if (symbol.chars === literal) {
              symbol.types = [SYMBOL.LITERAL];
              return;
            }
          }
        }
        if (symbol.chars.match(/^-?\d+$/)) {
          symbol.types = [SYMBOL.NUMBER];
          if (peek(1).chars === '.' && peek(2).hasType(SYMBOL.NUMBER)) {
            _ref2 = symbol.merge(symbol_array, i, 3), symbol = _ref2[0], delta = _ref2[1];
            len += delta;
            symbol.pushUniqueType(SYMBOL.DECIMAL);
            symbol.removeType(SYMBOL.TEXT);
            symbol.removeType(SYMBOL.INTEGER);
          } else {
            symbol.pushUniqueType(SYMBOL.INTEGER);
          }
          return;
        }
        if (symbol.chars.match(/^0x[0-9a-fA-F]+$/)) {
          symbol.pushUniqueType(SYMBOL.NUMBER);
          symbol.pushUniqueType(SYMBOL.HEX);
          return;
        }
        return symbol.types = [SYMBOL.ID];
      } else if (symbol.hasType(SYMBOL.TEXT)) {
        return 1;
      }
    };
    while (++i < len) {
      next_symbol();
    }
    return symbol_array;
  };

  Ast.prototype.java_syntaxer = function(symbol_array) {
    var find_next, i, len, level, next_matching_pair, next_non_space, next_symbol, open_pairs, peek,
      _this = this;
    i = -1;
    len = symbol_array.length;
    open_pairs = [];
    level = 0;
    peek = function(n) {
      var old_i, symbol, target_i;
      old_i = i;
      if (n > 0) {
        target_i = i + n;
        while (++i < target_i) {
          next_symbol();
        }
      } else {
        i += n;
      }
      symbol = symbol_array[i];
      i = old_i;
      return symbol;
    };
    find_next = function(n, test) {
      var ii, symbol;
      ii = n;
      while (++ii < len) {
        symbol = symbol_array[ii];
        if (test.call(symbol)) {
          return ii;
        }
      }
      return false;
    };
    next_non_space = function(n, test) {
      var ii, symbol;
      ii = n;
      while (++ii < len && (symbol = symbol_array[ii]) && (symbol.hasType(SYMBOL.LINEBREAK, SYMBOL.INDENT))) {}
      if (test.call(symbol)) {
        return ii;
      } else {
        return false;
      }
    };
    next_matching_pair = function(n, open_test, close_test) {
      var ii, open_count, symbol;
      ii = n;
      open_count = 0;
      while (++ii < len && (symbol = symbol_array[ii])) {
        if (open_test.call(symbol)) {
          open_count++;
        } else if (close_test.call(symbol)) {
          open_count--;
          if (open_count === 0) {
            return ii;
          }
        }
      }
      return false;
    };
    next_symbol = function() {
      var chars, delta, e, f, ii, n, p, symbol, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      symbol = symbol_array[i];
      if (symbol === void 0) {
        return;
      }
      symbol.level = level;
      if (symbol.hasType(SYMBOL.ID) && (!symbol.hasType(SYMBOL.ACCESS)) && ((n = peek(1)) && n.hasType(SYMBOL.ID))) {
        symbol.types = [SYMBOL.TYPE];
      }
      if (symbol.hasType(SYMBOL.ID) && (!symbol.hasType(SYMBOL.ACCESS)) && ((n = peek(1)) && n.chars === CHAR.OPEN_BRACKET) && ((n = peek(2)) && n.chars === CHAR.CLOSE_BRACKET) && ((n = peek(3)) && n.hasType(SYMBOL.ID))) {
        _ref = symbol.merge(symbol_array, i, 3), symbol = _ref[0], delta = _ref[1];
        symbol.types = [SYMBOL.TYPE];
        len += delta;
      }
      if (symbol.hasType(SYMBOL.ID) && ((p = peek(-1)) && p.chars === CHAR.LESS)) {
        if (peek(1).chars === CHAR.GREATER) {
          peek(-2).pushUniqueType(SYMBOL.TYPE);
          _ref1 = symbol.merge(symbol_array, i - 2, 4), symbol = _ref1[0], delta = _ref1[1];
          symbol.types = [SYMBOL.TYPE, SYMBOL.GENERIC_TYPE];
          len += delta;
          return;
        } else {
          ii = i + 1;
          while (symbol_array[ii].chars === CHAR.COMMA && symbol_array[ii + 1].hasType(SYMBOL.ID)) {
            ii += 2;
          }
          if (symbol_array[ii].chars === CHAR.GREATER) {
            _ref2 = symbol.merge(symbol_array, i - 2, ii - i + 3), symbol = _ref2[0], delta = _ref2[1];
            symbol.types = [SYMBOL.TYPE, SYMBOL.GENERIC_TYPE];
            len += delta;
            return;
          }
        }
      }
      if (symbol.hasType(SYMBOL.ID) && symbol.chars[0].match(/A-Z/) && ((p = peek(-1)) && p.chars === CHAR.OPEN_PARENTHESIS) && ((n = peek(1)) && n.chars === CHAR.CLOSE_PARENTHESIS)) {
        symbol.pushUniqueType(SYMBOL.TYPE);
        symbol.pushUniqueType(SYMBOL.CAST);
        _ref3 = symbol.merge(symbol_array, i - 1, 3), symbol = _ref3[0], delta = _ref3[1];
        symbol.chars = symbol.chars.substr(1, symbol.chars.length - 2);
        symbol.types = [SYMBOL.ID, SYMBOL.TYPE, SYMBOL.CAST];
        len += delta;
        return;
      }
      if (symbol.hasType(SYMBOL.ID) && ((n = peek(1)) && n.chars === CHAR.OPEN_PARENTHESIS) && (e = next_matching_pair(i, (function() {
        return this.chars === CHAR.OPEN_PARENTHESIS;
      }), function() {
        return this.chars === CHAR.CLOSE_PARENTHESIS;
      }))) {
        if (symbol_array[e + 1].chars === CHAR.OPEN_BRACE) {
          n.pushUniqueType(SYMBOL.PARAM);
          symbol_array[e].pushUniqueType(SYMBOL.PARAM);
        } else if ((symbol_array[e + 1].chars === 'throws') && (symbol_array[e + 2].hasType(SYMBOL.ID)) && (symbol_array[e + 3].chars === CHAR.OPEN_BRACE)) {
          n.pushUniqueType(SYMBOL.PARAM);
          symbol_array[e].pushUniqueType(SYMBOL.PARAM);
          chars = symbol_array[e + 1].chars + ' ' + symbol_array[e + 2].chars;
          _ref4 = symbol.merge(symbol_array, e + 1, 2), symbol = _ref4[0], delta = _ref4[1];
          symbol.chars = chars;
          symbol.types = [SYMBOL.COMMENT, SYMBOL.ENDLINE_COMMENT];
          len += delta;
        } else {
          n.pushUniqueType(SYMBOL.CALL);
          symbol_array[e].pushUniqueType(SYMBOL.CALL);
        }
        return;
      }
      if (symbol.hasType(SYMBOL.ID) && ((n = peek(1)) && n.chars === CHAR.OPEN_BRACKET) && (e = find_next(i + 1, function() {
        return this.chars === CHAR.CLOSE_BRACKET;
      }))) {
        n.pushUniqueType(SYMBOL.INDEX);
        symbol_array[e].pushUniqueType(SYMBOL.INDEX);
        return;
      }
      if (symbol.hasType(SYMBOL.BLOCK) && ((n = peek(1)) && n.chars === CHAR.OPEN_PARENTHESIS) && (e = next_matching_pair(i, (function() {
        return this.chars === CHAR.OPEN_PARENTHESIS;
      }), function() {
        return this.chars === CHAR.CLOSE_PARENTHESIS;
      })) && (((symbol_array[e + 1].hasType(SYMBOL.ENDLINE_COMMENT)) && e++) || 1) && (symbol_array[e + 1].chars !== CHAR.OPEN_BRACE) && (f = find_next(e + 1, function() {
        return this.hasType(SYMBOL.STATEMENT_END);
      }))) {
        symbol_array.splice(e + 1, 0, new Symbol(CHAR.OPEN_BRACE, [SYMBOL.BRACE, SYMBOL.PAIR, SYMBOL.OPEN, SYMBOL.LEVEL_INC]));
        symbol_array.splice(f + 2, 0, new Symbol(CHAR.CLOSE_BRACE, [SYMBOL.BRACE, SYMBOL.PAIR, SYMBOL.CLOSE, SYMBOL.LEVEL_DEC]));
        len += 2;
        return;
      }
      if (symbol.chars === CHAR.OPEN_BRACE) {
        ++level;
        symbol.pushUniqueType(SYMBOL.LEVEL_INC);
        symbol.pushUniqueType(SYMBOL.TERMINATOR);
        return;
      }
      if (symbol.chars === CHAR.CLOSE_BRACE) {
        --level;
        symbol.pushUniqueType(SYMBOL.LEVEL_DEC);
        return;
      }
      if (symbol.chars === CHAR.SEMICOLON) {
        symbol.pushUniqueType(SYMBOL.TERMINATOR);
        return;
      }
      if (symbol.chars === 'Override' && ((p = peek(-1)) && p.chars === CHAR.AT)) {
        _ref5 = symbol.merge(symbol_array, i - 1, 2), symbol = _ref5[0], delta = _ref5[1];
        symbol.types = [SYMBOL.SUPPORT];
        len += delta;
      }
    };
    while (++i < len) {
      next_symbol();
    }
    return symbol_array;
  };

  Ast.prototype.translate_to_coffee = function(symbol_array) {
    var a, class_ids, cursor, file, fn_access_mods, fn_comment, fn_id, fn_ids, fn_param_types, fn_params, fn_params_open, fn_type, global_ids, hasAccessor, i, id, ii, in_class_scope, in_fn_scope, in_param_scope, indent, isGlobal, isLocal, joinTokens, last_class_id, last_level, len, lvl, match, out, p, pluckFromStatement, prev, removed, repeat, s, slice_statement_buf, statement, statements, symbol, t, toString, token, y, _i, _j, _k, _l, _len, _len1, _len2, _m, _ref, _ref1;
    i = -1;
    statement = [];
    last_level = 0;
    statements = [];
    len = symbol_array.length;
    while (++i < len) {
      symbol = symbol_array[i];
      slice_statement_buf = function(level) {
        last_level = statement.level = level;
        statements.push(statement);
        return statement = [];
      };
      if (symbol.hasType(SYMBOL.LEVEL_DEC, SYMBOL.TERMINATOR, SYMBOL.DOUBLE_SPACE)) {
        statement.push(symbol);
        slice_statement_buf(symbol.level);
      } else {
        statement.push(symbol);
      }
    }
    if (statement.length) {
      slice_statement_buf(last_level + 1);
    }
    out = {
      req: '',
      mod: '',
      classes: ''
    };
    repeat = function(s, n) {
      var r;
      r = '';
      while (--n >= 0) {
        r += s;
      }
      return r;
    };
    i = -1;
    len = symbol_array.length;
    in_class_scope = 0;
    in_fn_scope = 0;
    in_param_scope = false;
    global_ids = {};
    class_ids = [];
    last_class_id = [];
    fn_ids = [];
    for (y = _i = 0, _len = statements.length; _i < _len; y = ++_i) {
      statement = statements[y];
      indent = function() {
        return repeat('  ', statement.level);
      };
      cursor = 0;
      pluckFromStatement = function(tokens) {
        var ii, _j, _ref;
        for (ii = _j = _ref = tokens.length - 1; _ref <= 0 ? _j <= 0 : _j >= 0; ii = _ref <= 0 ? ++_j : --_j) {
          statement.splice(tokens[ii].statement_pos, 1);
        }
      };
      joinTokens = function(tokens, sep) {
        var r, token, _j, _len1;
        r = [];
        for (_j = 0, _len1 = tokens.length; _j < _len1; _j++) {
          token = tokens[_j];
          r.push(token.chars);
        }
        return r.join(sep);
      };
      match = function(type, test_fn) {
        var index, matches, result, s;
        index = cursor - 1;
        result = {
          pos: cursor,
          end: cursor,
          matches: []
        };
        while (s = statement[++index]) {
          if (s.isA('comment')) {
            continue;
          }
          if (matches = test_fn.call(s)) {
            result.end = s.statement_pos = index;
            result.matches.push(s);
            cursor = index + 1;
          }
          switch (type) {
            case 'zeroOrOne':
              return result;
            case 'zeroOrMore':
              if (!matches) {
                return result;
              }
              break;
            case 'exactlyOne':
              return (result.matches.length ? result : null);
            case 'oneOrMore':
              if (!matches) {
                return (result.matches.length ? result : null);
              }
          }
        }
      };
      toString = function(start, end) {
        var beginning, comment, ii, last_had_space, o, s, _j;
        if (start == null) {
          start = 0;
        }
        if (end === void 0) {
          end = statement.length - 1;
        }
        if (end < 0) {
          return '';
        }
        o = [];
        beginning = true;
        last_had_space = false;
        for (ii = _j = start; start <= end ? _j <= end : _j >= end; ii = start <= end ? ++_j : --_j) {
          s = statement[ii];
          if (s.hasType(SYMBOL.COMMENT, SYMBOL.SUPPORT)) {
            if (s.hasType(SYMBOL.MULTILINE_COMMENT)) {
              comment = s.chars.replace(/^[\t ]*\*\//m, '').replace(/^[\t ]*\*[\t ]*/mg, '').replace(/\/\*\*?/, '').replace(/^/mg, indent());
              o.push("###" + comment + "### ");
              continue;
            } else if (s.hasType(SYMBOL.ENDLINE_COMMENT, SYMBOL.SUPPORT)) {
              comment = s.chars.replace(/^\s*\/\/\s*/mg, '');
              o.push("# " + comment + "\n" + (indent()));
              continue;
            }
          }
          if (s.hasType(SYMBOL.KEYWORD, SYMBOL.ACCESS, SYMBOL.TYPE) || s.hasType(SYMBOL.OP) && s.chars !== CHAR.EXCLAIMATION) {
            if (beginning || last_had_space) {
              o.push(s.chars + ' ');
            } else {
              o.push(' ' + s.chars + ' ');
            }
            last_had_space = true;
          } else if (s.hasType(SYMBOL.TERMINATOR, SYMBOL.CAST, SYMBOL.BRACE)) {

          } else if (s.hasType(SYMBOL.DOUBLE_SPACE)) {
            o.push('');
          } else {
            last_had_space = false;
            o.push(s.chars);
          }
          beginning = false;
        }
        return o.join('');
      };
      hasAccessor = function(start, end, accessor) {
        var ii, _j;
        for (ii = _j = start; start <= end ? _j <= end : _j >= end; ii = start <= end ? ++_j : --_j) {
          if (statement[ii].hasType(SYMBOL.ACCESS) && statement[ii].chars === accessor) {
            return true;
          }
        }
        return false;
      };
      isLocal = function(v) {
        return fn_ids[v] <= in_fn_scope;
      };
      isGlobal = function(v) {
        return global_ids[v] === 1;
      };
      symbol = statement[0];
      cursor = 0;
      if (match('exactlyOne', function() {
        return this.chars === 'package';
      })) {
        out.mod += "module.exports = # " + (toString(1));
        continue;
      }
      cursor = 0;
      if (match('exactlyOne', function() {
        return this.chars === 'import';
      })) {
        file = toString(1).split('.');
        out.req += "" + file[file.length] + " = require '" + (file.replace('.', '/')) + "'\n";
        global_ids[name] = 1;
        continue;
      }
      cursor = 0;
      if (match('exactlyOne', function() {
        return this.isA('level_dec');
      })) {
        if (in_fn_scope) {
          in_fn_scope--;
          for (id in fn_ids) {
            lvl = fn_ids[id];
            if (lvl > in_fn_scope) {
              delete fn_ids[id];
            }
          }
          fn_ids = {};
        } else if (in_class_scope) {
          in_class_scope--;
          for (id in class_ids) {
            lvl = class_ids[id];
            if (lvl > in_class_scope) {
              delete class_ids[id];
            }
          }
          last_class_id.pop();
        }
        continue;
      }
      for (ii = _j = 0, _len1 = statement.length; _j < _len1; ii = ++_j) {
        s = statement[ii];
        prev = statement[ii - 1];
        if (s.isA('param')) {
          in_param_scope = s.isA('open');
        }
        if (s.isA('id')) {
          if (prev && prev.isA('type')) {
            if (in_fn_scope) {
              fn_ids[s.chars] = in_fn_scope;
            } else if (in_class_scope) {
              class_ids[s.chars] = in_class_scope;
            }
          }
          if (in_class_scope && !in_param_scope && ((prev === void 0) || prev.chars !== CHAR.PERIOD)) {
            if (!(isLocal(s.chars) || isGlobal(s.chars))) {
              s.chars = '@' + s.chars;
            }
          }
        }
      }
      cursor = 0;
      if ((a = match('oneOrMore', function() {
        return this.isA('access');
      })) && (match('exactlyOne', function() {
        return this.chars === 'class';
      })) && (i = match('exactlyOne', function() {
        return this.isA('id');
      }))) {
        last_class_id.push(i.matches[0].chars);
        pluckFromStatement(removed = a.matches);
        for (ii = _k = 0, _len2 = statement.length; _k < _len2; ii = ++_k) {
          token = statement[ii];
          if (token.chars === 'implements') {
            removed = removed.concat(statement.splice(ii, 2));
            break;
          }
        }
        out.classes += "" + (indent()) + (toString()) + " # " + (joinTokens(removed, ' ')) + "\n";
        in_class_scope = true;
        continue;
      }
      cursor = 0;
      if ((a = match('oneOrMore', function() {
        return this.isA('access');
      })) && (t = match('zeroOrOne', function() {
        return this.isA('type');
      })) && (i = match('exactlyOne', function() {
        return this.isA('id');
      })) && (p = match('exactlyOne', function() {
        return this.isA('param') && this.isA('open');
      }))) {
        fn_id = '';
        fn_type = 'void';
        fn_params = [];
        fn_comment = '';
        in_fn_scope = true;
        fn_params_open = false;
        fn_param_types = [];
        fn_access_mods = [];
        for (ii = _l = 0, _ref = statement.length; 0 <= _ref ? _l < _ref : _l > _ref; ii = 0 <= _ref ? ++_l : --_l) {
          s = statement[ii];
          if (s.hasType(SYMBOL.ACCESS)) {
            if (!fn_params_open) {
              fn_access_mods.push(s.chars);
            }
          } else if (s.hasType(SYMBOL.TYPE)) {
            if (!fn_params_open) {
              fn_type = s.chars;
            } else {
              fn_param_types.push(s.chars);
            }
          } else if (s.hasType(SYMBOL.PARAM) && s.hasType(SYMBOL.OPEN)) {
            fn_params_open = true;
          } else if (s.hasType(SYMBOL.ID)) {
            if (!fn_params_open) {
              fn_id = s.chars;
            } else {
              fn_params.push(s.chars);
              fn_ids[s.chars] = in_fn_scope;
            }
          }
        }
        if (fn_params.length) {
          fn_params;
        }
        fn_params = fn_params.length ? "(" + (fn_params.join(', ')) + ") " : '';
        fn_param_types = !fn_param_types.length ? ['void'] : fn_param_types;
        if (fn_id.replace(/^@/, '') === last_class_id[last_class_id.length - 1]) {
          fn_id = 'constructor';
        }
        if (fn_id[0] === '@' && hasAccessor(a.pos, a.end, 'static')) {
          fn_id = fn_id.substr(1, fn_id.length - 1);
        }
        for (ii = _m = _ref1 = statement.length - 1; _ref1 <= 0 ? _m <= 0 : _m >= 0; ii = _ref1 <= 0 ? ++_m : --_m) {
          s = statement[ii];
          if (statement[ii].types[0] !== SYMBOL.COMMENT) {
            statement.splice(ii, 1);
          }
        }
        out.classes += "" + (indent()) + (toString()) + fn_id + ": " + fn_params + "-> # " + (fn_access_mods.reverse().join(' ')) + " (" + (fn_param_types.join(', ')) + "): " + fn_type + " " + fn_comment + "\n";
        continue;
      }
      cursor = 0;
      if ((a = match('oneOrMore', function() {
        return this.isA('access');
      })) && (t = match('zeroOrOne', function() {
        return this.isA('type');
      })) && (i = match('exactlyOne', function() {
        return this.isA('id');
      }))) {
        id = i.matches[0].chars;
        if (in_class_scope && !in_fn_scope) {
          if (id[0] === '@' && hasAccessor(a.pos, a.end, 'static')) {
            i.matches[0].chars = id.substr(1, id.length - 1);
          }
        }
        pluckFromStatement(removed = a.matches.concat(t.matches));
        out.classes += "" + (indent()) + (toString()) + " # " + (joinTokens(removed, ' ')) + "\n";
        continue;
      }
      out.classes += "" + (indent()) + (toString()) + "\n";
    }
    out = "" + out.req + out.mod + out.classes;
    return out;
  };

  Ast.prototype.pretty_print_symbol_array = function(symbol_array) {
    var i, last_line, symbol, toString, type, types, _i, _j, _len, _len1, _ref;
    process.stdout.write("\n");
    last_line = 1;
    for (i = _i = 0, _len = symbol_array.length; _i < _len; i = ++_i) {
      symbol = symbol_array[i];
      types = [];
      _ref = symbol.types;
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        type = _ref[_j];
        types.push(type["enum"]);
      }
      types = types.join(', ');
      toString = function() {
        return "(" + symbol.level + " " + types + " " + (JSON.stringify(symbol.chars)) + ") ";
      };
      if (last_line !== symbol.line) {
        last_line = symbol.line;
        process.stdout.write("\n");
      }
      process.stdout.write(toString(symbol));
    }
    return process.stdout.write("\n");
  };

  return Ast;

})();

if ('function' === typeof require && typeof exports === typeof module) {
  module.exports = Ast;
}

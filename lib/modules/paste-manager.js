var Document, PasteManager, Quill, Tandem, dom, _;

Quill = require('../quill');

Document = require('../core/document');

_ = Quill.require('lodash');

dom = Quill.require('dom');

Tandem = Quill.require('tandem-core');

PasteManager = (function() {
  function PasteManager(quill, options) {
    this.quill = quill;
    this.options = options;
    this.container = this.quill.addContainer('paste-container');
    this.container.setAttribute('contenteditable', true);
    this.quill.addStyles({
      '.paste-container': {
        'left': '-10000px',
        'position': 'absolute',
        'top': '50%'
      }
    });
    dom(this.quill.root).on('paste', _.bind(this._paste, this));
  }

  PasteManager.prototype._paste = function() {
    var iframe, oldDocLength, range, scrollY;
    oldDocLength = this.quill.getLength();
    range = this.quill.getSelection();
    if (range == null) {
      return;
    }
    this.container.innerHTML = "";
    iframe = dom(this.quill.root).window();
    scrollY = iframe.scrollY;
    this.container.focus();
    return _.defer((function(_this) {
      return function() {
        var delta, doc, lengthAdded, line, lineBottom, offset, _ref;
        doc = new Document(_this.container, _this.quill.options);
        delta = doc.toDelta();
        delta = delta.compose(Tandem.Delta.makeDeleteDelta(delta.endLength, delta.endLength - 1, 1));
        lengthAdded = delta.endLength;
        if (range.start > 0) {
          delta.ops.unshift(new Tandem.RetainOp(0, range.start));
        }
        if (range.end < oldDocLength) {
          delta.ops.push(new Tandem.RetainOp(range.end, oldDocLength));
        }
        delta.endLength += _this.quill.getLength() - (range.end - range.start);
        delta.startLength = oldDocLength;
        _this.quill.updateContents(delta, 'user');
        _this.quill.setSelection(range.start + lengthAdded, range.start + lengthAdded);
        _ref = _this.quill.editor.doc.findLineAt(range.start + lengthAdded), line = _ref[0], offset = _ref[1];
        lineBottom = line.node.offsetTop + line.node.offsetHeight;
        if (lineBottom > scrollY + _this.quill.root.offsetHeight) {
          scrollY = line.node.offsetTop - _this.quill.root.offsetHeight / 2;
        }
        return iframe.scrollTo(0, scrollY);
      };
    })(this));
  };

  return PasteManager;

})();

Quill.registerModule('paste-manager', PasteManager);

module.exports = PasteManager;

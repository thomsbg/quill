Quill  = require('../quill')
_      = Quill.require('lodash')
dom    = Quill.require('dom')
Delta  = Quill.require('delta')


class Keyboard
  @hotkeys:
    BOLD:       { key: 'B',          metaKey: true }
    INDENT:     { key: dom.KEYS.TAB }
    ITALIC:     { key: 'I',          metaKey: true }
    OUTDENT:    { key: dom.KEYS.TAB, shiftKey: true }
    UNDERLINE:  { key: 'U',          metaKey: true }

  constructor: (@quill, options) ->
    @hotkeys = {}
    this._initListeners()
    this._initHotkeys()
    this._initDeletes()

  addHotkey: (hotkey, callback) ->
    hotkey = if _.isObject(hotkey) then _.clone(hotkey) else { key: hotkey }
    hotkey.callback = callback
    which = if _.isNumber(hotkey.key) then hotkey.key else hotkey.key.toUpperCase().charCodeAt(0)
    @hotkeys[which] ?= []
    @hotkeys[which].push(hotkey)

  toggleFormat: (range, format) ->
    if range.isCollapsed()
      delta = @quill.getContents(Math.max(0, range.start-1), range.end)
    else
      delta = @quill.getContents(range)
    value = delta.ops.length == 0 or !_.all(delta.ops, (op) ->
      return op.attributes?[format]
    )
    if range.isCollapsed()
      @quill.prepareFormat(format, value)
    else
      @quill.formatText(range, format, value, 'user')
    toolbar = @quill.getModule('toolbar')
    toolbar.setActive(format, value) if toolbar?

  _initDeletes: ->
    _.each([dom.KEYS.DELETE, dom.KEYS.BACKSPACE], (key) =>
      this.addHotkey(key, =>
        # Prevent deleting if editor is already blank (or just empty newline)
        return @quill.getLength() > 1
      )
    )

  _initHotkeys: ->
    this.addHotkey(Keyboard.hotkeys.INDENT, (range) =>
      this._onTab(range, false)
      return false
    )
    this.addHotkey(Keyboard.hotkeys.OUTDENT, (range) =>
      # TODO implement when we implement multiline tabs
      return false
    )
    _.each(['bold', 'italic', 'underline'], (format) =>
      this.addHotkey(Keyboard.hotkeys[format.toUpperCase()], (range) =>
        this.toggleFormat(range, format)
        return false
      )
    )

  _initListeners: ->
    dom(@quill.root).on('keydown', (event) =>
      prevent = false
      _.each(@hotkeys[event.which], (hotkey) =>
        metaKey = if dom.isMac() then event.metaKey else event.metaKey or event.ctrlKey
        return if !!hotkey.metaKey != !!metaKey
        return if !!hotkey.shiftKey != !!event.shiftKey
        return if !!hotkey.altKey != !!event.altKey
        prevent = hotkey.callback(@quill.getSelection()) == false or prevent
      )
      return !prevent
    )

  _onTab: (range, shift = false) ->
    # TODO implement multiline tab behavior
    # Behavior according to Google Docs + Word
    # When tab on one line, regardless if shift is down, delete selection and insert a tab
    # When tab on multiple lines, indent each line if possible, outdent if shift is down
    delta = new Delta().retain(range.start)
                       .insert("\t")
                       .delete(range.end - range.start)
                       .retain(@quill.getLength() - range.end)
    @quill.updateContents(delta)
    @quill.setSelection(range.start + 1, range.start + 1)


Quill.registerModule('keyboard', Keyboard)
module.exports = Keyboard

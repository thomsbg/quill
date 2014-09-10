Quill = require('../quill')
_     = Quill.require('lodash')
dom   = Quill.require('dom')


class Toolbar
  @DEFAULTS:
    container: null

  @formats:
    LINE    : { 'align', 'bullet', 'list', 'firstheader', 'secondheader', 'thirdheader' }
    SELECT  : { 'align', 'background', 'color', 'font', 'size', }
    TOGGLE  : { 'firstheader', 'secondheader', 'thirdheader', 'bold', 'bullet', 'image', 'italic', 'link', 'list', 'strike', 'underline' }
    TOOLTIP : { 'image', 'link' }

  constructor: (@quill, @options) ->
    throw new Error('container required for toolbar', @options) unless @options.container?
    @container = if _.isString(@options.container) then document.querySelector(@options.container) else @options.container
    @inputs = {}
    @preventUpdate = false
    @triggering = false
    _.each(@quill.options.formats, (format) =>
      return if Toolbar.formats.TOOLTIP[format]?
      this.initFormat(format, (range, value) =>
        return if @triggering
        if range.isCollapsed()
          @quill.prepareFormat(format, value)
        else if Toolbar.formats.LINE[format]?
          @quill.formatLine(range, format, value, 'user')
        else
          @quill.formatText(range, format, value, 'user')
        _.defer( =>
          this.updateActive(range)  # Clear exclusive formats
          this.setActive(format, value)
        )
      )
    )
    @quill.on(@quill.constructor.events.SELECTION_CHANGE, _.bind(this.updateActive, this))
    dom(@container).addClass('ql-toolbar-container')
    dom(@container).addClass('ios') if dom.isIOS()  # Fix for iOS not losing hover state after click
    if dom.isIE(11) or dom.isIOS()
      dom(@container).on('mousedown', =>
        # IE destroys selection by default when we click away
        # Also fixes bug in iOS where preformating prevents subsequent typing
        return false
      )

  initFormat: (format, callback) ->
    selector = ".ql-#{format}"
    if Toolbar.formats.SELECT[format]?
      selector = "select#{selector}"    # Avoid selecting the picker container
      eventName = 'change'
    else
      eventName = 'click'
    input = @container.querySelector(selector)
    return unless input?
    @inputs[format] = input
    dom(input).on(eventName, =>
      value = if eventName == 'change' then dom(input).value() else !dom(input).hasClass('ql-active')
      @preventUpdate = true
      @quill.focus()
      range = @quill.getSelection()
      callback(range, value) if range?
      @preventUpdate = false
      return true
    )

  setActive: (format, value) ->
    input = @inputs[format]
    return unless input?
    $input = dom(input)
    if input.tagName == 'SELECT'
      @triggering = true
      selectValue = $input.value(input)
      value = '' if _.isArray(value)
      if value != selectValue
        if value?
          $input.option(value)
        else
          $input.reset()
      @triggering = false
    else
      $input.toggleClass('ql-active', value or false)

  updateActive: (range) ->
    return unless range? and !@preventUpdate
    activeFormats = this._getActive(range)
    _.each(@inputs, (input, format) =>
      this.setActive(format, activeFormats[format])
      return true
    )

  _getActive: (range) ->
    leafFormats = this._getLeafActive(range)
    lineFormats = this._getLineActive(range)
    return _.defaults({}, leafFormats, lineFormats)

  _getLeafActive: (range) ->
    if range.isCollapsed()
      [line, offset] = @quill.editor.doc.findLineAt(range.start)
      if offset == 0
        contents = @quill.getContents(range.start, range.end + 1)
      else
        contents = @quill.getContents(range.start - 1, range.end)
    else
      contents = @quill.getContents(range)
    formatsArr = _.map(contents.ops, 'attributes')
    return this._intersectFormats(formatsArr)

  _getLineActive: (range) ->
    formatsArr = []
    [firstLine, offset] = @quill.editor.doc.findLineAt(range.start)
    [lastLine, offset] = @quill.editor.doc.findLineAt(range.end)
    lastLine = lastLine.next if lastLine? and lastLine == firstLine
    while firstLine? and firstLine != lastLine
      formatsArr.push(_.clone(firstLine.formats))
      firstLine = firstLine.next
    return this._intersectFormats(formatsArr)

  _intersectFormats: (formatsArr) ->
    return _.reduce(formatsArr.slice(1), (activeFormats, formats) ->
      activeKeys = _.keys(activeFormats)
      formatKeys = _.keys(formats)
      intersection = _.intersection(activeKeys, formatKeys)
      missing = _.difference(activeKeys, formatKeys)
      added = _.difference(formatKeys, activeKeys)
      _.each(intersection, (name) ->
        if Toolbar.formats.SELECT[name]?
          if _.isArray(activeFormats[name])
            activeFormats[name].push(formats[name]) if _.indexOf(activeFormats[name], formats[name]) < 0
          else if activeFormats[name] != formats[name]
            activeFormats[name] = [activeFormats[name], formats[name]]
      )
      _.each(missing, (name) ->
        if Toolbar.formats.TOGGLE[name]?
          delete activeFormats[name]
        else if Toolbar.formats.SELECT[name]? and !_.isArray(activeFormats[name])
          activeFormats[name] = [activeFormats[name]]
      )
      _.each(added, (name) ->
        activeFormats[name] = [formats[name]] if Toolbar.formats.SELECT[name]?
      )
      return activeFormats
    , formatsArr[0] or {})


Quill.registerModule('toolbar', Toolbar)
module.exports = Toolbar

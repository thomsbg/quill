cleanLines = (html) ->
  html = html.replace(/\ class\="line"/g, '')
  html = html.replace(/\ id\="line-\d+"/g, '')
  return html


describe('Editing text', ->
  browser.get('/test/fixtures/e2e.html')
  startRange = element(By.id('start-range'))
  endRange = element(By.id('end-range'))
  deltaOutput = element(By.id('delta'))

  browser.switchTo().frame('quill-1')
  editor = element(By.className('editor-container'))
  updateEditor = (switchBack = true) ->
    browser.switchTo().defaultContent()
    browser.executeScript('quill.editor.checkUpdate()')
    browser.switchTo().frame('quill-1') if switchBack

  beforeEach( ->
    browser.switchTo().defaultContent()
    browser.switchTo().frame('quill-1')
  )

  it('initial focus', ->
    editor.click()
    updateEditor(false)
    expect(startRange.getText()).toEqual('0')
    expect(endRange.getText()).toEqual('0')
  )

  it('simple characters', ->
    text = 'The Whale'
    editor.sendKeys(text)
    updateEditor()
    expect(editor.getInnerHtml().then(cleanLines)).toEqual("<div>#{text}</div>")
    expectedDelta = {
      ops: [{ insert: text }]
    }
    browser.switchTo().defaultContent()
    expect(deltaOutput.getText()).toEqual(JSON.stringify(expectedDelta))
    # Selection should not change due to typing
    expect(startRange.getText()).toEqual('0')
    expect(endRange.getText()).toEqual('0')
  )

  it('enter', ->
    text = 'Chapter 1. Loomings.'
    editor.sendKeys(protractor.Key.RETURN, protractor.Key.RETURN, text, protractor.Key.RETURN)
    updateEditor()
    expect(editor.getInnerHtml().then(cleanLines)).toEqual([
      '<div>The Whale</div>'
      '<div><br></div>'
      "<div>#{text}</div>"
      '<div><br></div>'
    ].join(''))
    browser.switchTo().defaultContent()
    expectedDelta = {
      ops: [
        { retain: 10 }
        { insert: "\n#{text}\n\n" }
      ]
    }
    expect(deltaOutput.getText()).toEqual(JSON.stringify(expectedDelta))
  )

  it('tab', ->
    text1 = 'Call me Ishmael. Some years ago—never mind how long precisely-having little or no money in my purse, and nothing particular to interest me on shore, I thought I would sail about a little and see the watery part of the world. It is a way I have of driving off the spleen and regulating the circulation. Whenever I find myself growing grim about the mouth; whenever it is a damp, drizzly November in my soul; whenever I find myself involuntarily pausing before coffin warehouses, and bringing up the rear of every funeral I meet; and especially whenever my hypos get such an upper hand of me, that it requires a strong moral principle to prevent me from deliberately stepping into the street, and methodically knocking people’s hats off—then, I account it high time to get to sea as soon as I can. This is my substitute for pistol and ball. With a philosophical flourish Cato throws himself upon his sword; I quietly take to the ship. There is nothing surprising in this. If they but knew it, almost all men in their degree, some time or other, cherish very nearly the same feelings towards the ocean with me.'
    text2 = 'There now is your insular city of the Manhattoes, belted round by wharves as Indian isles by coral reefs—commerce surrounds it with her surf. Right and left, the streets take you waterward. Its extreme downtown is the battery, where that noble mole is washed by waves, and cooled by breezes, which a few hours previous were out of sight of land. Look at the crowds of water-gazers there.'
    editor.sendKeys(protractor.Key.RETURN, protractor.Key.TAB, text1)
    editor.sendKeys(protractor.Key.RETURN, protractor.Key.RETURN, text2)
    updateEditor()
    expect(editor.getInnerHtml().then(cleanLines)).toEqual([
      '<div>The Whale</div>'
      '<div><br></div>'
      '<div>Chapter 1. Loomings.</div>'
      '<div><br></div>'
      "<div>\t#{text1}</div>"
      '<div><br></div>'
      "<div>#{text2}</div>"
    ].join(''))
  )

  it('move cursor', ->
    editor.sendKeys(protractor.Key.ARROW_LEFT)
    updateEditor(false)
    expect(startRange.getText()).toEqual('1529')
    expect(endRange.getText()).toEqual('1529')
    browser.switchTo().frame('quill-1')
    [0..15].forEach( ->   # More than enough times to get back to the top
      editor.sendKeys(protractor.Key.ARROW_UP)
    )
    updateEditor(false)
    expect(startRange.getText()).toEqual('0')
    expect(endRange.getText()).toEqual('0')
    browser.switchTo().frame('quill-1')
    [0..3].forEach( ->
      editor.sendKeys(protractor.Key.ARROW_RIGHT)
    )
    updateEditor(false)
    expect(startRange.getText()).toEqual('4')
    expect(endRange.getText()).toEqual('4')
  )

  it('backspace', ->
    [1..4].forEach( ->
      editor.sendKeys(protractor.Key.BACK_SPACE)
    )
    updateEditor()
    firstLine = element.all(By.css('.editor-container div')).first()
    expect(firstLine.getOuterHtml().then(cleanLines)).toEqual('<div>Whale</div>')
  )

  it('delete', ->
    [1..5].forEach( ->
      editor.sendKeys(protractor.Key.DELETE)
    )
    updateEditor()
    lines = element.all(By.css('.editor-container div'))
    expect(lines.get(0).getOuterHtml().then(cleanLines)).toEqual('<div><br></div>')
    expect(lines.get(1).getOuterHtml().then(cleanLines)).toEqual('<div><br></div>')
  )

  it('delete newline', ->
    editor.sendKeys(protractor.Key.DELETE)
    updateEditor()
    lines = element.all(By.css('.editor-container div'))
    expect(lines.get(0).getOuterHtml().then(cleanLines)).toEqual('<div><br></div>')
    expect(lines.get(1).getOuterHtml().then(cleanLines)).toEqual('<div>Chapter 1. Loomings.</div>')
  )

  it('preformat', ->
    browser.switchTo().defaultContent()
    element(By.css('.ql-size')).click()
    element(By.cssContainingText('.ql-size option', 'Huge')).click()
    browser.switchTo().frame('quill-1')
    text = 'Moby Dick'
    editor.sendKeys(text)
    updateEditor()
    firstLine = element.all(By.css('.editor-container div')).first()
    expect(firstLine.getOuterHtml().then(cleanLines)).toEqual(
      "<div><span style=\"font-size: 32px;\">#{text}</span></div>"
    )
    browser.switchTo().defaultContent()
    expectedDelta = {
      ops: [{ attributes: { size: '32px' }, insert: text }]
    }
    expect(deltaOutput.getText()).toEqual(JSON.stringify(expectedDelta))
  )

  it('hotkey format', ->
    editor.sendKeys(protractor.Key.ARROW_RIGHT)
    keys = [1..20].map( ->
      return protractor.Key.ARROW_RIGHT
    )
    keys.unshift(protractor.Key.SHIFT)
    keys.push(protractor.Key.NULL)
    editor.sendKeys(keys...)
    editor.sendKeys(protractor.Key.chord(protractor.Key.META, 'b'))
    updateEditor()
    lines = element.all(By.css('.editor-container div'))
    expect(lines.get(1).getOuterHtml().then(cleanLines)).toEqual(
      '<div><b>Chapter 1. Loomings.</b></div>'
    )
    browser.switchTo().defaultContent()
    expectedDelta = {
      ops: [
        { retain: 10 }
        { retain: 20, attributes: { bold: true } }
      ]
    }
    expect(deltaOutput.getText()).toEqual(JSON.stringify(expectedDelta))
  )

  it('line format', ->
    editor.sendKeys(protractor.Key.chord(protractor.Key.SHIFT, protractor.Key.ARROW_UP))
    browser.switchTo().defaultContent()
    element(By.css('.ql-align')).click()
    element(By.cssContainingText('.ql-align option', 'Center')).click()
    updateEditor()
    lines = element.all(By.css('.editor-container div'))
    expect(lines.get(0).getOuterHtml().then(cleanLines)).toEqual(
      '<div style="text-align: center;"><span style="font-size: 32px;">Moby Dick</span></div>'
    )
    expect(lines.get(1).getOuterHtml().then(cleanLines)).toEqual(
      '<div style="text-align: center;"><b>Chapter 1. Loomings.</b></div>'
    )
    browser.switchTo().defaultContent()
    expectedDelta = {
      ops: [
        { retain: 9 }
        { retain: 1, attributes: { align: 'center' } }
        { retain: 20 }
        { retain: 1, attributes: { align: 'center' } }
      ]
    }
    expect(deltaOutput.getText()).toEqual(JSON.stringify(expectedDelta))
  )

  it('blur', ->
    browser.switchTo().defaultContent()
    startRange.click()    # Any element outside editor to lose focus
    updateEditor()        # Blur currently requires two update cycles to trigger
    updateEditor(false)
    expect(startRange.getText()).toEqual('')
    expect(endRange.getText()).toEqual('')
  )
)

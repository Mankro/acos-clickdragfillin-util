###
Parser for point-and-click and drag-and-drop exercise XML files.

Authors: Tapio Auvinen, Markku Riekkinen
###
xml2js = require('xml2js')
_ = require('underscore')

class ExerciseNode
    
  addChildren: (children) ->
    return unless children
    @children ||= []
    
    if children instanceof Array
      @children = @children.concat(children)
    else
      @children.push children
  
  # Renders the inner text of all child nodes recursively into a string.
  innerText: () ->
    return '' unless @children
    @children.map((child) -> child.innerText()).join(' ')


# A plain text node. This node never has children.
class ExerciseTextNode extends ExerciseNode
  constructor: (text) ->
    super()
    @text = text
  
  html: ->
    @text

  innerText: ->
    @text


# A generic HTML node, which may have children
class ExerciseHtmlNode extends ExerciseNode
  constructor: (name, attributes) ->
    super()
    @nodeName = name
    @attributes = attributes || {}
    
  # Renders the node and its children as HTML and returns a String
  # options:
  # {omitRoot: true} renders only the children without this tag itself
  html: (options = {}) ->
    # Render attributes into a string, e.g. " class='warning'"
    attributesHtml = if @attributes
      ' ' + (Object.keys(@attributes).map (attribute) =>
        # The only characters that must be escaped within attributes are amp and quot
        "#{attribute}='#{@attributes[attribute].replace(/[&]/g, '&amp;').replace(/["]/g, '&quot;')}'").join(' ')
    else
      ''

    if options['omitRoot'] || !@nodeName
      @children.map((child) -> child.html()).join('')
    else
      if @isVoidElement()
        return "<#{@nodeName}" + attributesHtml + "/>"
      else if @children
        content = @children.map((child) -> child.html()).join('')
      else
        content = ''
      return "\n<#{@nodeName}" + attributesHtml + '>' +
          content +
          "</#{@nodeName}>"

  isVoidElement: ->
    @nodeName in ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
                  'link', 'meta', 'param', 'source', 'track', 'wbr']


class ExerciseClickableNode extends ExerciseNode
  constructor: (text, id) ->
    super()
    @text = if not text? || text.length < 1 then ' ' else text
    @id = if not id? || id.length < 1 then @text else id # Use text as id if no id is given
    
  html: ->
    "<span data-label='#{@id}' class='clickable'>#{@text}</span>"
    #"<span data-label='#{@id}' #{this.feedbackHtml()} class='clickable'>#{@text}</span>"
    
  jsonPayload: () ->
    {correct: @correct, feedback: @feedback, reveal: @reveal}
    

class ExerciseFillinNode extends ExerciseNode
  constructor: (text, id) ->
    super()
    @text = text ? ''
    @id = id
    
  html: ->
    "<input data-label='#{id}' type='text' />"

  jsonPayload: () ->
    {correct: @correct, feedback: @feedback}
    

class ExerciseDraggableNode extends ExerciseNode
  constructor: (text, id) ->
    super()
    @text = if not text? || text.length < 1 then '&empty;' else text # use the symbol for empty set for empty text
    @id = id
    
  html: ->
    "<span data-label=\"#{@id}\" class=\"draggable\">#{@text}</span>"

class ExerciseDroppableNode extends ExerciseNode
  constructor: (text, id) ->
    super()
    @text = text.trim()
    @text = '&nbsp;&nbsp;&nbsp;&nbsp;' if @text.length < 1
    @id = id

  html: ->
    "<span data-label=\"#{@id}\" class=\"droppable\"><span>#{@text}</span></span>"
    # extra nested <span> is needed for hacking around the HTML5 drag-and-drop API


class Exercise
  
  # Parses an XML string and converts it into a tree of ExerciseNodes
  # Calls callback(error, tree, head) with the resulting ExerciseNode tree.
  # error: Error message in a String, or undefined
  # tree: an ExerciseNode, root of the tree
  # head: a ExerciseHtmlNode with nodeType='head', contains stylesheets and javascript to include
  # xml: A String containing XML markup
  parseXml: (xml, callback) ->
    # Initialize XML parser
    parser = new xml2js.Parser(
        normalizeTags: true
        explicitChildren: true
        preserveChildrenOrder: true
        charsAsChildren: true
      )
    
    # Parse string into an XML DOM
    parser.parseString xml, (err, dom) =>
      if err
        callback(err)
      else 
        @_parseDom(dom, callback)


  # contentType: type of the exercise, either "pointandclick" or "draganddrop"
  constructor: (@contentType) ->


  # Parses the XML DOM into a tree of Exercise Nodes
  # Calls callback(error, tree, head) with the resulting ExerciseNode tree
  _parseDom: (dom, callback) ->
    # A function that gives uniqued IDs for elements
    idCounter = (->
      current = 0
      return -> current++
    )()

    
    # If root is <html>
    if dom['html']
      head = dom['html']['head']
      if head
        head = @_parseDomNode(head[0], idCounter, {disableMarkup: true})
    
      body = dom['html']['body']
      if body && body.length > 0
        tree = @_parseDomNode(body[0], idCounter)
      else
        callback("&lt;html&gt; tag must contain a &lt;body&gt; tag")
        return
    
    # If root is not <html>
    else
      # Content is not wrapped in <html>, dom looks like { div: {...} }
      tree = @_parseDomNode(dom[Object.keys(dom)[0]], idCounter)
      
    callback(null, tree, head)
  
  
  # Parses a node of the XML DOM
  # returns: ExerciseNode or array of ExerciseNodes
  _parseDomNode: (xmlNode, idCounter, options = {}) ->
    nodeName = xmlNode['#name']
    attributes = xmlNode['$']

    if nodeName == '__text__'
      return @_parseTextNode(xmlNode, options)
    
    else if nodeName == 'clickable' || nodeName == 'fillin'
      # XML <clickable> and <fillin> nodes
      return @_parseInteractiveNode(xmlNode, idCounter)
      
    else
      exerciseNode = new ExerciseHtmlNode(nodeName, attributes)
    
      childNodes = xmlNode['$$']
      if childNodes
        exerciseNode.addChildren _.flatten childNodes.map (child) =>
          @_parseDomNode(child, idCounter, options)
  
    return exerciseNode
  
  
  # Parses a text node of the XML DOM
  # If the text node contains markup (e.g. {}), an array of various ExerciseNodes is returned.
  # Otherwise, a plain ExerciseTextNode is returned.
  _parseTextNode: (xmlNode, options) ->
    nodes = []
    
    # Get original text
    remainingText = xmlNode['_']
    
    while remainingText.length > 0 && !options['disableMarkup']?
      # Find curly brackets { }
      match = remainingText.match(/(\{[^\}]*\})/)
      break if !match?
      
      # Text before brackets is treated as normal text
      before = remainingText.substring(0, match.index)
      nodes.push new ExerciseTextNode(before) if before.length > 0
      
      # Text inside brackets is treated as a 'clickable'. Remove brackets.
      innerText = match[0].substring(1, match[0].length - 1)
      
      # Separate id (id:text)
      parts = innerText.split(':')
      if parts.length > 1
        id = parts[0]
        text = parts[1]
      else
        id = innerText
        text = innerText
      
      if @contentType == 'pointandclick'
        clickableNode = new ExerciseClickableNode(text, id)
        nodes.push clickableNode
      else if @contentType == 'draganddrop'
        droppableNode = new ExerciseDroppableNode(text, id)
        nodes.push droppableNode
      else
        throw new TypeError "Exercise.contentType has an unsupported value: #{@contentType}"
      
      # Continue searching after the closing bracket
      remainingText = remainingText.substring(match.index + innerText.length + 2, remainingText.length)
      
    # Store any remaining text after no more matches are found
    nodes.push new ExerciseTextNode(remainingText) if remainingText.length > 0
    
    return nodes

  
  _parseInteractiveNode: (xmlNode, idCounter) ->
    nodeName = xmlNode['#name']
    attributes = xmlNode['$'] || {}
    manualId = attributes['id']
    
    if nodeName == 'clickable'
      exerciseNode = new ExerciseClickableNode(xmlNode['_'], manualId || idCounter())
      exerciseNode.correct = attributes['correct']
    
    else if nodeName == 'fillin'
      exerciseNode = new ExerciseFillinNode(xmlNode['_'], manualId || idCounter())

    # no XML notation implemented for drag-and-drop

    # Parse attributes

    # Parse <feedback> child nodes
    if xmlNode['feedback']
      for child in xmlNode['feedback']
        exerciseNode.feedback = child['_']
#         feedbackAttributes = child['$']
#         if feedbackAttributes? && feedbackAttributes['correct'] == 'true'
#           exerciseNode.correctFeedback = child['_']
#         else
#           exerciseNode.incorrectFeedback = child['_']

    # Parse <reveal> child nodes
    if xmlNode['reveal']
      exerciseNode.reveal = xmlNode['reveal'][0]['_']
          
    return exerciseNode


  # Collects JSON payload recursively from the given tree of ExerciseNodes.
  # The result is something like {'id1': {payload...}, 'id2': {payload...}}
  # hash: existing payload on which to build
  # tree: the root ExerciseNode
  jsonPayload: (hash, tree) ->
  
    if @contentType == 'draganddrop'
      # no operation for drag-and-drop exercises:
      # the JSON payload does not have the droppable IDs in the top level as they are nested deeper
      # and the XML notation for defining payload (feedback, correct, etc.) has not been implemented
      return hash
    
    # Collect payload recursively
    dfs = (node) ->
      payload = hash[node.id]
      
      # Add autogenerated payload to existing
      if node.id? && node.jsonPayload?
        payload = Object.assign(node.jsonPayload(), payload || {})  # User-provided properties have precedence
      
      hash[node.id] = payload
      
      return unless node.children?
      for child in node.children
        dfs(child)
    
    dfs(tree)
    
    hash
  

module.exports = Exercise

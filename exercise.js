/*
Parser for point-and-click and drag-and-drop exercise XML files.

Authors: Tapio Auvinen, Markku Riekkinen
*/
var Exercise, ExerciseClickableNode, ExerciseDraggableNode, ExerciseDroppableNode, ExerciseFillinNode, ExerciseHtmlNode, ExerciseNode, ExerciseTextNode, _, xml2js;

xml2js = require('xml2js');

_ = require('underscore');

ExerciseNode = class ExerciseNode {
  addChildren(children) {
    if (!children) {
      return;
    }
    this.children || (this.children = []);
    if (children instanceof Array) {
      return this.children = this.children.concat(children);
    } else {
      return this.children.push(children);
    }
  }

  
  // Renders the inner text of all child nodes recursively into a string.
  innerText() {
    if (!this.children) {
      return '';
    }
    return this.children.map(function(child) {
      return child.innerText();
    }).join(' ');
  }

};

// A plain text node. This node never has children.
ExerciseTextNode = class ExerciseTextNode extends ExerciseNode {
  constructor(text) {
    super();
    this.text = text;
  }

  html() {
    return this.text;
  }

  innerText() {
    return this.text;
  }

};

// A generic HTML node, which may have children
ExerciseHtmlNode = class ExerciseHtmlNode extends ExerciseNode {
  constructor(name, attributes) {
    super();
    this.nodeName = name;
    this.attributes = attributes || {};
  }

  
  // Renders the node and its children as HTML and returns a String
  // options:
  // {omitRoot: true} renders only the children without this tag itself
  html(options = {}) {
    var attributesHtml, html;
    // Render attributes into a string, e.g. " class='warning'"
    attributesHtml = this.attributes ? ' ' + (Object.keys(this.attributes).map((attribute) => {
      // The only characters that must be escaped within attributes are amp and quot
      return `${attribute}='${this.attributes[attribute].replace(/[&]/g, '&amp;').replace(/["]/g, '&quot;')}'`;
    })).join(' ') : '';
    if (options['omitRoot'] || !this.nodeName) {
      return this.children.map(function(child) {
        return child.html();
      }).join('');
    } else {
      if (this.children) {
        return html = `\n<${this.nodeName}` + attributesHtml + ">" + this.children.map(function(child) {
          return child.html();
        }).join('') + `</${this.nodeName}>`;
      } else {
        return html = `<${this.nodeName}` + attributesHtml + " />";
      }
    }
  }

};

ExerciseClickableNode = class ExerciseClickableNode extends ExerciseNode {
  constructor(text, id) {
    super();
    this.text = (text == null) || text.length < 1 ? ' ' : text;
    this.id = (id == null) || id.length < 1 ? this.text : id; // Use text as id if no id is given
  }

  html() {
    return `<span data-label='${this.id}' class='clickable'>${this.text}</span>`;
  }

  //"<span data-label='#{@id}' #{this.feedbackHtml()} class='clickable'>#{@text}</span>"
  jsonPayload() {
    return {
      correct: this.correct,
      feedback: this.feedback,
      reveal: this.reveal
    };
  }

};

ExerciseFillinNode = class ExerciseFillinNode extends ExerciseNode {
  constructor(text, id) {
    super();
    this.text = text != null ? text : '';
    this.id = id;
  }

  html() {
    return `<input data-label='${id}' type='text' />`;
  }

  jsonPayload() {
    return {
      correct: this.correct,
      feedback: this.feedback
    };
  }

};

ExerciseDraggableNode = class ExerciseDraggableNode extends ExerciseNode {
  constructor(text, id) {
    super();
    this.text = (text == null) || text.length < 1 ? '&empty;' : text; // use the symbol for empty set for empty text
    this.id = id;
  }

  html() {
    return `<span data-label="${this.id}" class="draggable">${this.text}</span>`;
  }

};

ExerciseDroppableNode = class ExerciseDroppableNode extends ExerciseNode {
  constructor(text, id) {
    super();
    this.text = text.trim();
    if (this.text.length < 1) {
      this.text = '&nbsp;&nbsp;&nbsp;&nbsp;';
    }
    this.id = id;
  }

  html() {
    return `<span data-label="${this.id}" class="droppable"><span>${this.text}</span></span>`;
  }

};

// extra nested <span> is needed for hacking around the HTML5 drag-and-drop API
Exercise = class Exercise {
  
  // Parses an XML string and converts it into a tree of ExerciseNodes
  // Calls callback(error, tree, head) with the resulting ExerciseNode tree.
  // error: Error message in a String, or undefined
  // tree: an ExerciseNode, root of the tree
  // head: a ExerciseHtmlNode with nodeType='head', contains stylesheets and javascript to include
  // xml: A String containing XML markup
  parseXml(xml, callback) {
    var parser;
    // Initialize XML parser
    parser = new xml2js.Parser({
      normalizeTags: true,
      explicitChildren: true,
      preserveChildrenOrder: true,
      charsAsChildren: true
    });
    
    // Parse string into an XML DOM
    return parser.parseString(xml, (err, dom) => {
      if (err) {
        return callback(err);
      } else {
        return this._parseDom(dom, callback);
      }
    });
  }

  // contentType: type of the exercise, either "pointandclick" or "draganddrop"
  constructor(contentType) {
    this.contentType = contentType;
  }

  // Parses the XML DOM into a tree of Exercise Nodes
  // Calls callback(error, tree, head) with the resulting ExerciseNode tree
  _parseDom(dom, callback) {
    var body, head, idCounter, tree;
    // A function that gives uniqued IDs for elements
    idCounter = (function() {
      var current;
      current = 0;
      return function() {
        return current++;
      };
    })();
    
    // If root is <html>
    if (dom['html']) {
      head = dom['html']['head'];
      if (head) {
        head = this._parseDomNode(head[0], idCounter, {
          disableMarkup: true
        });
      }
      body = dom['html']['body'];
      if (body && body.length > 0) {
        tree = this._parseDomNode(body[0], idCounter);
      } else {
        callback("&lt;html&gt; tag must contain a &lt;body&gt; tag");
        return;
      }
    } else {
      // Content is not wrapped in <html>, dom looks like { div: {...} }

      // If root is not <html>
      tree = this._parseDomNode(dom[Object.keys(dom)[0]], idCounter);
    }
    return callback(null, tree, head);
  }

  
  // Parses a node of the XML DOM
  // returns: ExerciseNode or array of ExerciseNodes
  _parseDomNode(xmlNode, idCounter, options = {}) {
    var attributes, childNodes, exerciseNode, nodeName;
    nodeName = xmlNode['#name'];
    attributes = xmlNode['$'];
    if (nodeName === '__text__') {
      return this._parseTextNode(xmlNode, options);
    } else if (nodeName === 'clickable' || nodeName === 'fillin') {
      // XML <clickable> and <fillin> nodes
      return this._parseInteractiveNode(xmlNode, idCounter);
    } else {
      exerciseNode = new ExerciseHtmlNode(nodeName, attributes);
      childNodes = xmlNode['$$'];
      if (childNodes) {
        exerciseNode.addChildren(_.flatten(childNodes.map((child) => {
          return this._parseDomNode(child, idCounter, options);
        })));
      }
    }
    return exerciseNode;
  }

  
  // Parses a text node of the XML DOM
  // If the text node contains markup (e.g. {}), an array of various ExerciseNodes is returned.
  // Otherwise, a plain ExerciseTextNode is returned.
  _parseTextNode(xmlNode, options) {
    var before, clickableNode, droppableNode, id, innerText, match, nodes, parts, remainingText, text;
    nodes = [];
    
    // Get original text
    remainingText = xmlNode['_'];
    while (remainingText.length > 0 && (options['disableMarkup'] == null)) {
      // Find curly brackets { }
      match = remainingText.match(/(\{[^\}]*\})/);
      if (match == null) {
        break;
      }
      
      // Text before brackets is treated as normal text
      before = remainingText.substring(0, match.index);
      if (before.length > 0) {
        nodes.push(new ExerciseTextNode(before));
      }
      
      // Text inside brackets is treated as a 'clickable'. Remove brackets.
      innerText = match[0].substring(1, match[0].length - 1);
      
      // Separate id (id:text)
      parts = innerText.split(':');
      if (parts.length > 1) {
        id = parts[0];
        text = parts[1];
      } else {
        id = innerText;
        text = innerText;
      }
      if (this.contentType === 'pointandclick') {
        clickableNode = new ExerciseClickableNode(text, id);
        nodes.push(clickableNode);
      } else if (this.contentType === 'draganddrop') {
        droppableNode = new ExerciseDroppableNode(text, id);
        nodes.push(droppableNode);
      } else {
        throw new TypeError(`Exercise.contentType has an unsupported value: ${this.contentType}`);
      }
      
      // Continue searching after the closing bracket
      remainingText = remainingText.substring(match.index + innerText.length + 2, remainingText.length);
    }
    if (remainingText.length > 0) {
      
      // Store any remaining text after no more matches are found
      nodes.push(new ExerciseTextNode(remainingText));
    }
    return nodes;
  }

  _parseInteractiveNode(xmlNode, idCounter) {
    var attributes, child, exerciseNode, i, len, manualId, nodeName, ref;
    nodeName = xmlNode['#name'];
    attributes = xmlNode['$'] || {};
    manualId = attributes['id'];
    if (nodeName === 'clickable') {
      exerciseNode = new ExerciseClickableNode(xmlNode['_'], manualId || idCounter());
      exerciseNode.correct = attributes['correct'];
    } else if (nodeName === 'fillin') {
      exerciseNode = new ExerciseFillinNode(xmlNode['_'], manualId || idCounter());
    }
    // no XML notation implemented for drag-and-drop

    // Parse attributes

    // Parse <feedback> child nodes
    if (xmlNode['feedback']) {
      ref = xmlNode['feedback'];
      for (i = 0, len = ref.length; i < len; i++) {
        child = ref[i];
        exerciseNode.feedback = child['_'];
      }
    }
    //         feedbackAttributes = child['$']
    //         if feedbackAttributes? && feedbackAttributes['correct'] == 'true'
    //           exerciseNode.correctFeedback = child['_']
    //         else
    //           exerciseNode.incorrectFeedback = child['_']

    // Parse <reveal> child nodes
    if (xmlNode['reveal']) {
      exerciseNode.reveal = xmlNode['reveal'][0]['_'];
    }
    return exerciseNode;
  }

  // Collects JSON payload recursively from the given tree of ExerciseNodes.
  // The result is something like {'id1': {payload...}, 'id2': {payload...}}
  // hash: existing payload on which to build
  // tree: the root ExerciseNode
  jsonPayload(hash, tree) {
    var dfs;
    if (this.contentType === 'draganddrop') {
      // no operation for drag-and-drop exercises:
      // the JSON payload does not have the droppable IDs in the top level as they are nested deeper
      // and the XML notation for defining payload (feedback, correct, etc.) has not been implemented
      return hash;
    }
    
    // Collect payload recursively
    dfs = function(node) {
      var child, i, len, payload, ref, results;
      payload = hash[node.id];
      
      // Add autogenerated payload to existing
      if ((node.id != null) && (node.jsonPayload != null)) {
        payload = Object.assign(node.jsonPayload(), payload || {});
      }
      hash[node.id] = payload;
      if (node.children == null) {
        return;
      }
      ref = node.children;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        child = ref[i];
        results.push(dfs(child));
      }
      return results;
    };
    dfs(tree);
    return hash;
  }

};

module.exports = Exercise;

# Utility functions for point-and-click and drag-and-drop exercises

This module provides utility functions for the ACOS server content types
[point-and-click](https://github.com/acos-server/acos-pointandclick) and
[drag-and-drop](https://github.com/acos-server/acos-draganddrop).
This module registers itself to the ACOS server as a library so that
its static directory may be served to the web.
The content types that want to use these utility functions should simply require
this module and use its functions to implement the relevant parts in the functions
of the content type.

## Files

* `exercise.coffee`: parser for the exercise XML files (compiled to `exercise.js`)
* `index.coffee`: functions that content types may use when implementing their
  own functionality (compiled to `index.js`)
* `static/resize-feedback-iframe.js`: script that is included in the final feedback page
  in order to resize the feedback iframe so that it may better use the available space in the page
  (minimized from `static-src/resize-feedback-iframe.js`)
* `views/feedback-iframe.html`: template for the final feedback page. It defines the iframe
  that embeds the actual feedback defined by the content type.


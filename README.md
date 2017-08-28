# Utility functions for point-and-click, drag-and-drop, and text fill-in exercises

This module provides utility functions for the ACOS server content types point-and-click,
drag-and-drop, and the text fill-in exercises. This module registers itself to
to the ACOS server as a library so that its static directory may be served to the web.
The content types that want to use these utility functions should simply require
this module and use its functions to implement the relevant parts in the functions
of the content type.

## Files

* `exercise.coffee`: parser for the exercise XML files
* `index.coffee`: functions that content types may use when implementing their own functionality


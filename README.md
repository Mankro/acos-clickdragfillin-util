# Utility functions for point-and-click, drag-and-drop, and text fill-in exercises

This module provides utility functions for the ACOS server content types point-and-click,
drag-and-drop, and the text fill-in exercises. This module does not directly attach itself
to the ACOS server, i.e., it does not define any callback functions that the ACOS server
would call to register this module as a library or some other package type known to ACOS.
The content types that want to use these utility functions should simply require
this module and use its functions to implement the relevant parts in the functions
of the content type.

## Files

* `exercise.coffee`: parser for the exercise XML files
* `index.coffee`: functions that content types may use when implementing their own functionality


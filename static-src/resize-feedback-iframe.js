;(function(document, window, undefined) {
// This script resizes final feedback iframes when the window is resized so that the iframes
// may use most of the available height of the browser viewport.
// The iframes have style "width 100%" so that the width scales automatically and
// only the height needs to be set separately.
  "use strict";
  
  var acosResizeFeedbackIframes = function() {
    var iframes = document.getElementsByClassName('acos-feedback-iframe');
    var len = iframes.length;
    var newHeight = Math.max(window.innerHeight * 0.8, 500).toString(); // 80% of viewport height
    for (var i = 0; i < len; ++i) {
      iframes[i].setAttribute('height', newHeight);
    }
  };
  
  acosResizeFeedbackIframes();
  window.addEventListener('resize', acosResizeFeedbackIframes, false);
})(document, window);

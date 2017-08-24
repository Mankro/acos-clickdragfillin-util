document.addEventListener("DOMContentLoaded", function() {
  "use strict";
  
  var acosResizeIframe = function(iframe, wrapper) {
    var newWidth = Math.max(wrapper.offsetWidth, 700);
    var newHeight = Math.max(window.innerHeight * 0.8, 600); // 80% of viewport height
    iframe.style.width = newWidth + 'px';
    iframe.style.height = newHeight + 'px';
  };
  
  var iframe = document.getElementById('acos-feedback-iframe');
  if (!iframe)
    return;
  var parent = iframe.parentElement;
  if (!parent) {
    parent = document.getElementById('exercise') || document.getElementById('feedback');
    if (!parent)
      return;
  }
  
  acosResizeIframe(iframe, parent);
  window.addEventListener('resize', function() {
    acosResizeIframe(iframe, parent);
  }, true);
});

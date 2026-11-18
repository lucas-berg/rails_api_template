import jquery from 'jquery';
// ActiveAdmin 3.x uses this legacy jQuery helper in its batch-action dialog.
jquery.isArray = Array.isArray;

window.jquery = jquery;
window.jQuery = jquery;
window.$ = jquery;

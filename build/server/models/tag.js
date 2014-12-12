// Generated by CoffeeScript 1.8.0
var Tag, americano, log;

americano = require('americano-cozy');

log = require('printit')({
  prefix: 'tag:model'
});

module.exports = Tag = americano.getModel('Tag', {
  name: {
    type: String
  },
  color: {
    type: String
  }
});

Tag.byName = function(name, callback) {
  return Tag.request('all', {
    key: name
  }, callback);
};
// Generated by CoffeeScript 1.8.0
var User, americano;

americano = require('americano-cozy');

module.exports = User = americano.getModel('User', {
  email: {
    type: String
  },
  timezone: {
    type: String,
    "default": "Europe/Paris"
  }
});

User.all = function(callback) {
  return User.request("all", callback);
};

User.destroyAll = function(callback) {
  return User.requestDestroy("all", callback);
};

User.getUser = function(callback) {
  return User.all(function(err, users) {
    if (err) {
      return callback(err);
    } else if (users.length === 0) {
      return callback(new Error('no user'));
    } else {
      return callback(null, users[0]);
    }
  });
};

User.updateUser = function(callback) {
  return User.getUser(function(err, user) {
    if (err) {
      console.log(err);
      User.timezone = 'Europe/Paris';
      User.email = '';
    } else {
      User.timezone = user.timezone || "Europe/Paris";
      User.email = user.email;
    }
    return typeof callback === "function" ? callback() : void 0;
  });
};

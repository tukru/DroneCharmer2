// drone_pwn.js

var arDrone = require('ar-drone');
var client = arDrone.createClient();
client.disableEmergency();

console.log('Taking control of the drone...');
client.takeoff();

client
  .after(5000, function() {
    this.clockwise(0.5);
  })
  .after(5000, function() {
    this.stop();
    this.land();
  });

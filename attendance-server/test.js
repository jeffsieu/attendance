var express = require('express');
var ParseServer = require('parse-server').ParseServer;

const app = express();
const parseDatabaseServer = new ParseServer({
    serverURL: 'http://localhost:1337/parse',
    databaseURI: 'postgres://postgres:password@localhost:5432',
    appId: 'attendance',
    fileKey: 'myFileKey',
    masterKey: 'mySecretMasterKey',
    apiKey: 'c0a7edd1-4481-4e16-b152-5e8db698543a',
  });

// Serve the Parse API at /parse URL prefix
app.use('/parse', parseDatabaseServer);

var port = 1337;
var server = app.listen(port, function() {
  console.log('parse-server-example running on port ' + port + '.');
});
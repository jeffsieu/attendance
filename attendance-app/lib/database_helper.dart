import 'dart:convert';

import 'package:attendance/user.dart';
import 'package:http/http.dart' as http;

const String _databaseRootUrl = 'http://192.168.1.236:1337/parse/';
const Map<String, String> _headers = <String, String>{'X-Parse-Application-Id': 'attendance'};

Future<http.Response> _post(String url, {Map<String, String> headers = const <String, String>{}, dynamic body, Encoding encoding}) {
  return http.post(_databaseRootUrl + url, headers: _headers..addAll(headers), body: body, encoding: encoding);
}

Future<http.Response> _put(String url, {Map<String, String> headers = const <String, String>{}, dynamic body, Encoding encoding}) {
  return http.put(_databaseRootUrl + url, headers: _headers..addAll(headers), body: body, encoding: encoding);
}

Future<http.Response> _get(String url, {Map<String, String> headers = const <String, String>{}}) {
  return http.get(_databaseRootUrl + url, headers: _headers..addAll(headers));
}

Future<http.Response> _delete(String url, {Map<String, String> headers = const <String, String>{}}) {
  return http.delete(_databaseRootUrl + url, headers: _headers..addAll(headers));
}

Future<http.Response> createUser(String username, String password, String name, String group) async {
  const String url = 'users';
  final http.Response response = await _post(url, body: {'username': username, 'password': password, 'name': name, 'group': group});
  return response;
}

Future<http.Response> login(String username, String password) async {
  const String url = 'login';
  final http.Response response = await _post(url,
      body: {'username': username, 'password': password},
  );
  return response;
}

Future<void> markAttendance(User user) async {
  const String attendanceUrl = 'classes/AttendanceRecord';
  await _post(attendanceUrl,
      body: {
        'reportingTime': DateTime.now().toIso8601String(),
        'user': user.id,
      },
  );
}

Future<List<Map<String, dynamic>>> retrieveAttendanceRecords(String myId, bool showAllRecords) async {
  final List<User> subordinates = await getSubordinates(myId);
  final List<String> subordinateIds = subordinates.map((User subordinate) => subordinate.id).toList()..add(myId);

  const String url = 'classes/AttendanceRecord';
  final http.Response response = await _get(url);

  final List<User> users = await getUsers();
  final Map<String, User> userMap = Map<String, User>.fromIterable(users,
      key: (dynamic user) => user.id,
      value: (dynamic user) => user,
  );

  final List<dynamic> records = decodeResponse(response);
  final List<Map<String, dynamic>> attendance = records
    .where((dynamic item) => showAllRecords || subordinateIds.contains(item['user']))
    .map((dynamic item) => {'user': userMap[item['user']], 'reportingTime': item['reportingTime']}).toList();
  attendance.sort((Map<String, dynamic> record, Map<String, dynamic> record1) => record1['reportingTime'].compareTo(record['reportingTime']));

  return attendance;
}

Future<List<User>> getUsers() async {
  const String url = 'users';
  final http.Response response = await _get(url);
  final List<dynamic> userObjects = decodeResponse(response);

  return userObjects.map(User.fromMap).toList();
}

Future<String> getMyId(String sessionToken) async {
  const String meUrl = 'users/me';
  final http.Response response = await _get(meUrl, headers: <String, String>{'X-Parse-Session-Token': sessionToken});
  return jsonDecode(response.body)['objectId'];
}

Future<List<String>> getRoles(String sessionToken) async {
  final String myId = await getMyId(sessionToken);
  final Map<String, dynamic> where = {
    'users': {
      '__type': 'Pointer',
      'className': '_User',
      'objectId': myId,
    },
  };

  final String url = 'roles?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response rolesResponse = await _get(url);

  final List<String> roles = decodeResponse(rolesResponse).map((dynamic r) => r['name'].toString()).toList();
  return roles;
}

Future<String> getRoleId(String roleName) async {
  final Map<String, dynamic> rolesWhere = {
    'name': roleName,
  };

  final String rolesUrl = 'roles?where=${Uri.encodeComponent(jsonEncode(rolesWhere).toString())}';
  final http.Response rolesResponse = await _get(rolesUrl);
  return decodeResponse(rolesResponse)[0]['objectId'];
}

Future<List<User>> getMasterAdmins() async {
  final String masterAdminId = await getRoleId('Master Admins');

  final Map<String, dynamic> where = {
    r'$relatedTo': {
      'object': {
        '__type': 'Pointer',
        'className': '_Role',
        'objectId': masterAdminId,
      },
      'key': 'users',
    }
  };

  final String url = 'users?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);

  final List<User> masterAdmins = decodeResponse(response).map(User.fromMap).toList();
  return masterAdmins;
}

Future<List<User>> getAdmins() async {
  final String adminId = await getRoleId('Admins');

  final Map<String, dynamic> where = {
    r'$relatedTo': {
      'object': {
        '__type': 'Pointer',
        'className': '_Role',
        'objectId': adminId,
      },
      'key': 'users',
    }
  };

  final String url = 'users?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);

  final List<User> admins = decodeResponse(response).map(User.fromMap).toList();
  return admins;
}

Future<List<User>> getSubordinates(String myId) async {
  final Map<String, dynamic> where = {
    'superior_id': myId,
  };

  final String url = 'classes/Subordinate?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);
  final List<String> subordinateIds = decodeResponse(response)
      .map((dynamic user) => user['subordinate_id'].toString()).toList();

  final List<User> users = await getUsers();
  final Map<String, User> userMap = Map<String, User>.fromIterable(users,
      key: (dynamic user) => user.id,
      value: (dynamic user) => user,
  );

  final List<User> subordinates = subordinateIds.map((String id) => userMap[id]).toList();

  return subordinates;
}

Future<User> getUserFromUsername(String username) async {
  final Map<String, dynamic> where = {
    'username': username,
  };

  final String url = 'users?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);

  final List<dynamic> result = decodeResponse(response);
  if (result.isEmpty)
    return null;

  return User.fromMap(result[0]);
}

Future<String> addAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final String url = 'roles/' + await getRoleId('Admins');

  await _put(url, body: jsonEncode({
    'users': {
      '__op': 'AddRelation',
      'objects': [
        {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': user.id,
        }
      ]
    }
  }));
  return null;
}

Future<String> removeAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final String url = 'roles/' + await getRoleId('Admins');

  await _put(url, body: jsonEncode({
    'users': {
      '__op': 'RemoveRelation',
      'objects': [
        {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': user.id,
        }
      ]
    }
  }));
  return null;
}

Future<String> removeMasterAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  if ((await getMasterAdmins()).length == 1)
    return 'Cannot remove the only master admin';

  final String url = 'roles/' + await getRoleId('Master Admins');

  await _put(url, body: jsonEncode({
    'users': {
      '__op': 'RemoveRelation',
      'objects': [
        {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': user.id,
        }
      ]
    }
  }));
  return null;
}


Future<String> addSubordinate(String myId, String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final Map<String, dynamic> where = {
    'subordinate_id': user.id,
    'superior_id': myId,
  };

  final String url = 'classes/Subordinate?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);
  if (decodeResponse(response).isNotEmpty)
    return 'User is already a subordinate';

  const String addUrl = 'classes/Subordinate';

  await _post(addUrl, body: jsonEncode({
    'subordinate_id': user.id,
    'superior_id': myId,
  }));
  return null;
}

Future<String> removeSubordinate(String myId, String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final Map<String, dynamic> where = {
    'subordinate_id': user.id,
    'superior_id': myId,
  };

  final String url = 'classes/Subordinate?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);
  final String subordinateObjectId = decodeResponse(response).first['objectId'];

  await _delete('classes/Subordinate/$subordinateObjectId');

  return null;
}

Future<String> addMasterAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final String url = 'roles/' + await getRoleId('Master Admins');

  await _put(url, body: jsonEncode({
    'users': {
      '__op': 'AddRelation',
      'objects': [
        {
          '__type': 'Pointer',
          'className': '_User',
          'objectId': user.id,
        }
      ]
    }
  }));

  return null;
}

List<dynamic> decodeResponse(http.Response response) => jsonDecode(response.body)['results'];
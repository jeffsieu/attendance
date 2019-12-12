import 'dart:convert';

import 'package:attendance/user.dart';
import 'package:http/http.dart' as http;

final String _databaseRootUrl = 'http://192.168.1.236:1337/parse/';
final Map<String, String> _headers = {'X-Parse-Application-Id': 'attendance'};

Future<http.Response> _post(String url, {Map<String, String> headers, dynamic body, Encoding encoding}) {
  return http.post(_databaseRootUrl + url, headers: _headers..addAll(headers ?? {}), body: body, encoding: encoding);
}

Future<http.Response> _put(String url, {Map<String, String> headers, dynamic body, Encoding encoding}) {
  return http.put(_databaseRootUrl + url, headers: _headers..addAll(headers ?? {}), body: body, encoding: encoding);
}

Future<http.Response> _get(String url, {Map<String, String> headers}) {
  return http.get(_databaseRootUrl + url, headers: _headers..addAll(headers ?? {}));
}

Future<http.Response> _delete(String url, {Map<String, String> headers}) {
  return http.delete(_databaseRootUrl + url, headers: _headers..addAll(headers ?? {}));
}

Future<http.Response> createUser(String username, String password, String name) async {
  final String url = 'users';
  final http.Response response = await _post(url, body: {'username': username, 'password': password, 'name': name});
  return response;
}

Future<http.Response> login(String username, String password) async {
  final String url = 'login';
  final http.Response response = await _post(url, body: {'username': username, 'password': password});
  return response;
}

Future<http.Response> markAttendance(String sessionToken) async {
  final String meUrl = 'users/me';
  final http.Response response = await _get(meUrl, headers: {'X-Parse-Session-Token': sessionToken});
  final String userObjectId = jsonDecode(response.body)['objectId'];

  final String attendanceUrl = 'classes/AttendanceRecord';
  final http.Response response1 = await _post(attendanceUrl, body: {
    'reportingTime': DateTime.now().toIso8601String(),
    'user': userObjectId,
  });

  return response1;
}

Future<List<Map<String, dynamic>>> retrieveAttendanceRecords(String myId, bool allRecords) async {
  final List<User> subordinates = await getSubordinates(myId);
  final List<String> subordinateIds = subordinates.map((s) => s.id).toList()..add(myId);

  final String url = 'classes/AttendanceRecord';
  final http.Response response = await _get(url);

  final List<User> users = await getUsers();
  final Map<String, User> userMap = Map<String, User>.fromIterable(users, key: (user)=>user.id, value: (user)=>user);

  final List records = jsonDecode(response.body)['results'];
  final List<Map<String, dynamic>> attendance = records
    .where((item) => allRecords || subordinateIds.contains(item['user']))
    .map((item) => {'user': userMap[item['user']], 'reportingTime': item['reportingTime']}).toList();
  attendance.sort((record, record1) => record1['reportingTime'].compareTo(record['reportingTime']));

  return attendance;
}

Future<List<User>> getUsers() async {
  final String url = 'users';
  final http.Response response = await _get(url);
  final List<dynamic> userObjects = decodeResponse(response);

  return userObjects.map(User.fromMap).toList();
}

Future<List<String>> getRoles(String sessionToken) async {
  final String meUrl = 'users/me';
  final http.Response response = await _get(meUrl, headers: {'X-Parse-Session-Token': sessionToken});
  final String userObjectId = jsonDecode(response.body)['objectId'];

  final Map<String, dynamic> where = {
    'users': {
      '__type': 'Pointer',
      'className': '_User',
      'objectId': userObjectId,
    },
  };

  final String url = 'roles?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response rolesResponse = await _get(url);

  final List<String> roles = decodeResponse(rolesResponse).map((r) => r['name'].toString()).toList();
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
  final List<String> subordinateIds = decodeResponse(response).map((user) => user['subordinate_id'].toString()).toList();

  final List<User> users = await getUsers();
  final Map<String, User> userMap = Map<String, User>.fromIterable(users, key: (user)=>user.id, value: (user)=>user);

  final List<User> subordinates = subordinateIds.map((id) => userMap[id]).toList();

  return subordinates;
}

Future<User> getUserFromUsername(String username) async {
  final Map<String, dynamic> where = {
    'username': username,
  };

  final String url = 'users?where=${Uri.encodeComponent(jsonEncode(where).toString())}';
  final http.Response response = await _get(url);

  List<dynamic> result = decodeResponse(response);
  if (result.isEmpty)
    return null;

  return User.fromMap(result[0]);
}

Future<String> addAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final String url = 'roles/' + await getRoleId('Admins');

  final http.Response response = await _put(url, body: jsonEncode({
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

  final http.Response response = await _put(url, body: jsonEncode({
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

  final http.Response response = await _put(url, body: jsonEncode({
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

  final String addUrl = 'classes/Subordinate';

  final http.Response addResponse = await _post(addUrl, body: jsonEncode({
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
  String objectId = decodeResponse(response).first['objectId'];

  final http.Response response1 = await _delete('classes/Subordinate/$objectId');

  return null;
}

Future<String> addMasterAdmin(String username) async {
  final User user = await getUserFromUsername(username);

  if (user == null)
    return 'No such user';

  final String url = 'roles/' + await getRoleId('Master Admins');

  final http.Response response = await _put(url, body: jsonEncode({
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
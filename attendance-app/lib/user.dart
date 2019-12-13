class User {
  User({this.id, this.name, this.username, this.group});

  final String id;
  final String name;
  final String username;
  final String group;

  static User fromMap(dynamic map) {
    return User(
      id: map['objectId'],
      name: map['name'],
      username: map['username'],
      group: map['group']
    );
  }
}
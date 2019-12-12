class User {
  User({this.id, this.name, this.username});

  final String id;
  final String name;
  final String username;

  static User fromMap(dynamic map) {
    return User(
      id: map['objectId'],
      name: map['name'],
      username: map['username'],
    );
  }
}
import 'dart:convert';

import 'package:attendance/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'database_helper.dart';
import 'homepage.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Attendance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: LoginPage(title: 'Attendance Home Page'),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  LoginPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _usernameTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  final TextEditingController _nameTextController = TextEditingController();
  final TextEditingController _groupTextController = TextEditingController();

  bool _isLoading = false;

  String _passwordValidator(String value) {
    if (value.isEmpty)
      return 'Enter your password';
    return null;
  }

  String _usernameValidator(String value) {
    if (value.isEmpty)
      return 'Enter your phone number';
    return null;
  }

  String _nameValidator(String value) {
    if (value.isEmpty)
      return 'Enter your name';
    return null;
  }

  String _groupValidator(String value) {
    if (value.isEmpty)
      return 'Enter your group';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _usernameTextController.text = '12345678';
    _passwordTextController.text = 'adminpassword123';
  }

  @override
  void dispose() {
    _usernameTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Card(
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TabBar(
                  labelColor: Theme.of(context).accentColor,
                  tabs: <Widget>[
                    Tab(text: 'Login'),
                    Tab(text: 'Register'),
                  ],
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height*0.5,
                  ),
                  child: TabBarView(
                    children: <Widget>[
                      _buildLoginForm(),
                      _buildRegisterForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _nameTextController,
              validator: _nameValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Full name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _usernameTextController,
              validator: _usernameValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Phone number',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _passwordTextController,
              obscureText: true,
              validator: _passwordValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _groupTextController,
              validator: _groupValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Group',
              ),
            ),
          ),
          if (_isLoading)
            const CircularProgressIndicator(),
          RaisedButton(
            color: Theme.of(context).accentColor,
            textColor: Colors.white,
            child: const Text('Create account'),
            onPressed: _createAccount,
          )
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _usernameTextController,
              validator: _usernameValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Phone number',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _passwordTextController,
              obscureText: true,
              validator: _passwordValidator,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Password',
              ),
            ),
          ),
          if (_isLoading)
            const CircularProgressIndicator(),
          RaisedButton(
            color: Theme.of(context).accentColor,
            textColor: Colors.white,
            child: const Text('Login'),
            onPressed: _login,
          ),
        ],
      ),
    );
  }

  void _login() {
    if (_loginFormKey.currentState.validate()) {
      final String username = _usernameTextController.text;
      final String password = _passwordTextController.text;

      setState(() {
        _isLoading = true;
      });

      String message;
      login(username, password).then((response) {
        setState(() {
          _isLoading = false;
        });
        final dynamic body = jsonDecode(response.body);
        if (body['code'] == 101) {
          message = 'Incorrect username/password';
          _displayMessage(message);
        }
        else {
          final User user = User.fromMap(body);
          _pushHomePageRoute(body['sessionToken'], user);
        }
      });
    }
  }

  void _createAccount() {
    if (_registerFormKey.currentState.validate()) {
      final String username = _usernameTextController.text;
      final String password = _passwordTextController.text;
      final String name = _nameTextController.text;
      final String group = _groupTextController.text;

      setState(() {
        _isLoading = true;
      });

      createUser(username, password, name, group).then((response) {
        setState(() {
          _isLoading = false;
        });
        final dynamic body = jsonDecode(response.body);
        String message;
        if (body['code'] == 202)
          message = 'Account already exists, please login';
        else
          message = 'Account created successfully';
        _displayMessage(message);
      });
    }
  }

  void _displayMessage(String message) {
    Scaffold.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _pushHomePageRoute(String sessionToken, User user) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage(sessionToken, user)));
  }
}

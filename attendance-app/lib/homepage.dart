import 'package:attendance/user.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as time_ago;
import 'package:intl/intl.dart';

import 'database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage(this.sessionToken, this.user);

  final String sessionToken;
  final User user;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _masterAdminTextController = TextEditingController();
  final TextEditingController _adminTextController = TextEditingController();
  final TextEditingController _subordinateTextController = TextEditingController();
  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: getRoles(widget.sessionToken),
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        final bool isAdmin = snapshot.hasData && (snapshot.data.contains('Admins') || snapshot.data.contains('Master Admins'));
        final bool isMasterAdmin = snapshot.hasData  && snapshot.data.contains('Master Admins');

        return Scaffold(
          appBar: AppBar(
            title: Text('Hello, ${widget.user.name}'),
            actions: <Widget>[
              FutureBuilder<List<User>>(
                future: getSubordinates(widget.user.id),
                builder: (BuildContext context, AsyncSnapshot<List<User>> snapshot) => PopupMenuButton<User>(
                  icon: Icon(Icons.filter_list),
                  onSelected: (User user) {
                    print(user.name);
                  },
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<User>>[
                      for (User user in snapshot.data)
                        PopupMenuItem<User>(
                          child: Text(user.name),
                          value: user,
                        ),
                    ];
                  },
                ),
              ),
            ],
            bottom: isAdmin ? TabBar(
              controller: _tabController,
              tabs: <Widget>[
                Tab(icon: Icon(Icons.assignment), text: 'Attendance list'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
            ) : PreferredSize(preferredSize: Size.zero, child: Container()),
          ),
          body: _buildBody(isAdmin, isMasterAdmin),
          floatingActionButton: Builder(
            builder: (BuildContext context) => FloatingActionButton.extended(
              icon: Icon(Icons.check),
              onPressed: () => _markAttendance(context),
              label: const Text('Mark attendance'),
            ),
          ),
        );
      }
    );
  }

  Widget _buildBody(bool isAdmin, bool isMasterAdmin) {
    final Widget mainWidget = buildAttendanceList(isMasterAdmin);

    if (!isAdmin)
      return mainWidget;
    return TabBarView(
      controller: _tabController,
      children: [
        mainWidget,
        _buildAdminWidgets(isAdmin, isMasterAdmin),
      ]
    );
  }

  Widget buildAttendanceList(bool isMasterAdmin) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: retrieveAttendanceRecords(widget.user.id, isMasterAdmin),
      builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data.isEmpty)
          return const Center(child: Text('No attendance records found'));

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: kFloatingActionButtonMargin + 48),
          itemBuilder: (BuildContext context, int position) {
            final User user = snapshot.data[position]['user'] as User;
            final String username = user.username == widget.user.username ? 'Me': user.name;
            final DateTime reportingTime = DateTime.parse(snapshot.data[position]['reportingTime']);
            final String timeReadable = time_ago.format(reportingTime);
            final String timeFull = DateFormat('dd MMM yy, HH:mm').format(reportingTime);

            return ListTile(
              title: Text('$username (${user.group})'),
              subtitle: Text('$timeReadable · $timeFull'),
            );
          },
          separatorBuilder: (BuildContext context, int position) => const Divider(height: 1),
          itemCount: snapshot.data.length,
        );
      },
    );
  }

  Widget _buildAdminWidgets(bool isAdmin, bool isMasterAdmin) {
    return Builder(
      builder: (BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: kFloatingActionButtonMargin + 48),
        children: <Widget>[
          if (isMasterAdmin) ... <Widget>{
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Manage master admins', style: Theme
                                .of(context)
                                .textTheme
                                .title),
                            Text(
                              'Master admins can add/remove admins and master admins. Only add trusted personnel.',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .subtitle
                                  .copyWith(color: Theme
                                  .of(context)
                                  .hintColor),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _masterAdminTextController,
                                decoration: const InputDecoration(
                                  hintText: 'Phone number',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add user as master admin',
                              onPressed: () => _addMasterAdmin(context),
                            ),
                          ],
                        ),
                      ),
                      _buildMasterAdminList(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Manage admins', style: Theme
                                .of(context)
                                .textTheme
                                .title),
                            Text(
                              'Admins can add/remove subordinates. The attendance records of subordinates will be visible to them.',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .subtitle
                                  .copyWith(color: Theme
                                  .of(context)
                                  .hintColor),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _adminTextController,
                                decoration: const InputDecoration(
                                  hintText: 'Phone number',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add user as admin',
                              onPressed: () => _addAdmin(context),
                            ),
                          ],
                        ),
                      ),
                      _buildAdminList(),
                    ],
                  ),
                ),
              ),
            ),
          },
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: Container(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Manage your subordinates', style: Theme
                                .of(context)
                                .textTheme
                                .title),
                            Text(
                              'You\'re an admin. Add subordinates to track their attendance records.',
                              style: Theme
                                  .of(context)
                                  .textTheme
                                  .subtitle
                                  .copyWith(color: Theme
                                  .of(context)
                                  .hintColor),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _subordinateTextController,
                                decoration: const InputDecoration(
                                  hintText: 'Phone number',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              tooltip: 'Add subordinate',
                              onPressed: () => _addSubordinate(context),
                            ),
                          ],
                        ),
                      ),
                      _buildSubordinateList(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMasterAdminList() {
    return FutureBuilder<List<User>>(
      future: getMasterAdmins(),
      builder: (BuildContext context, AsyncSnapshot<List<User>> snapshot) {
        if (!snapshot.hasData)
          return Container();

        if (snapshot.data.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('No master admins', style: Theme.of(context).textTheme.body1.copyWith(color: Theme.of(context).hintColor))),
          );
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int position) {
            return ListTile(
              title: Text(snapshot.data[position].name),
              subtitle: Text(snapshot.data[position].username),
              trailing: IconButton(
                icon: Icon(Icons.remove),
                onPressed: snapshot.data.length > 1 ? () => _removeMasterAdmin(context, snapshot.data[position].username) : null,
              ),
            );
          },
          itemCount: snapshot.data.length,
        );
      },
    );
  }

  Widget _buildAdminList() {
    return FutureBuilder<List<User>>(
      future: getAdmins(),
      builder: (BuildContext context, AsyncSnapshot<List<User>> snapshot) {
        if (!snapshot.hasData)
          return Container();

        if (snapshot.data.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('No admins', style: Theme.of(context).textTheme.body1.copyWith(color: Theme.of(context).hintColor))),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int position) {
            return ListTile(
              title: Text(snapshot.data[position].name),
              subtitle: Text(snapshot.data[position].username),
              trailing: IconButton(icon: Icon(Icons.remove), onPressed: () => _removeAdmin(context, snapshot.data[position].username)),
            );
          },
          itemCount: snapshot.data.length,
        );
      },
    );
  }

  Widget _buildSubordinateList() {
    return FutureBuilder<List<User>>(
      future: getSubordinates(widget.user.id),
      builder: (BuildContext context, AsyncSnapshot<List<User>> snapshot) {
        if (!snapshot.hasData)
          return Container();

        if (snapshot.data.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('No subordinates', style: Theme.of(context).textTheme.body1.copyWith(color: Theme.of(context).hintColor))),
          );

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int position) {
            return ListTile(
              title: Text(snapshot.data[position].name),
              subtitle: Text(snapshot.data[position].username),
              trailing: IconButton(icon: Icon(Icons.remove), onPressed: () => _removeSubordinate(context, snapshot.data[position].username)),
            );
          },
          itemCount: snapshot.data.length,
        );
      },
    );
  }

  Future<void> _markAttendance(BuildContext context) async {
    await markAttendance(widget.user);
    _showSnackBar('Marked attendance');
    setState(() {});
  }

  void _showSnackBar(String message) {
    Scaffold.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleFuture(Future<String> future, {@required String onSuccess}) async {
    final String errorMessage = await future;
    if (errorMessage != null)
      _showSnackBar(errorMessage);
    else {
      _showSnackBar(onSuccess);
      setState(() {});
    }
  }

  Future<void> _addAdmin(BuildContext context) async {
    final String usernameToAdd = _adminTextController.text;
    if (usernameToAdd == widget.user.username) {
      _showSnackBar('You are already an admin');
      return;
    }

    _handleFuture(addAdmin(usernameToAdd), onSuccess: 'Added $usernameToAdd as admin');
  }

  Future<void> _removeAdmin(BuildContext context, String username) async {
    final Function removeFunction = () async {
      await _handleFuture(removeAdmin(username), onSuccess: 'Removed $username as admin');
    };

    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text('Remove $username as an admin?'),
      action: SnackBarAction(onPressed: removeFunction, label: 'Yes'),
    ));
  }

  Future<void> _addMasterAdmin(BuildContext context) async {
    final String usernameToAdd = _masterAdminTextController.text;
    if (usernameToAdd == widget.user.username) {
      _showSnackBar('You are already a master admin');
      return;
    }

    _handleFuture(addMasterAdmin(usernameToAdd), onSuccess: 'Added $usernameToAdd as master admin');
  }

  Future<void> _removeMasterAdmin(BuildContext context, String username) async {
    final Function removeFunction = () async {
      await _handleFuture(removeMasterAdmin(username), onSuccess: 'Removed $username as master admin');
    };

    Scaffold.of(context).showSnackBar(SnackBar(
      content: Text('Remove $username as a master admin?'),
      action: SnackBarAction(onPressed: removeFunction, label: 'Yes'),
    ));
  }

  Future<void> _addSubordinate(BuildContext context) async {
    final String usernameToAdd = _subordinateTextController.text;
    if (usernameToAdd == widget.user.username) {
      _showSnackBar('Cannot add yourself as a subordinate');
      return;
    }

    await _handleFuture(addSubordinate(widget.user.id, usernameToAdd), onSuccess: 'Added $usernameToAdd as subordinate');
  }

  Future<void> _removeSubordinate(BuildContext context, String username) async {
    await _handleFuture(removeSubordinate(widget.user.id, username), onSuccess: 'Removed $username as subordinate');
  }
}
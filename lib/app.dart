import 'package:flutter/material.dart';
import 'features/admin/admin_page.dart';
import 'features/user/search_page.dart';
import 'models/user_role.dart';

class MyApp extends StatelessWidget {
  final UserRole userRole;
  const MyApp({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Find Product Prize',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: userRole == UserRole.admin ? const AdminPage() : const SearchPage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'upload_excel_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Upload Product Excel'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadExcelPage()),
            );
          },
        ),
      ),
    );
  }
}

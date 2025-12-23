import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/excel_service.dart';
import '../../core/firebase_service.dart';

class UploadExcelPage extends StatefulWidget {
  const UploadExcelPage({super.key});

  @override
  State<UploadExcelPage> createState() => _UploadExcelPageState();
}

class _UploadExcelPageState extends State<UploadExcelPage> {
  bool _loading = false;
  String? _message;

  Future<void> _pickAndUpload() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result != null && result.files.single.bytes != null) {
        final firebaseService = FirebaseService();
        final excelService = ExcelService(firebaseService);
        await excelService.processAndUploadExcel(result.files.single.bytes!);
        setState(() => _message = 'Upload successful!');
      } else {
        setState(() => _message = 'No file selected.');
      }
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Excel')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickAndUpload,
                    child: const Text('Pick Excel File'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!),
                  ],
                ],
              ),
      ),
    );
  }
}

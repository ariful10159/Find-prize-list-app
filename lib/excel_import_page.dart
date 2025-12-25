import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:io';

class ExcelImportPage extends StatefulWidget {
  @override
  _ExcelImportPageState createState() => _ExcelImportPageState();
}

class _ExcelImportPageState extends State<ExcelImportPage> {
  bool _isUploading = false;
  late Future<List<DocumentSnapshot>> _filesFuture;

  @override
  void initState() {
    super.initState();
    _filesFuture = _getUploadedFiles();
  }

  Future<List<DocumentSnapshot>> _getUploadedFiles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('excel_files')
        .orderBy('uploadedAt', descending: true)
        .get();
    return snapshot.docs;
  }

  void _refreshFiles() {
    setState(() {
      _filesFuture = _getUploadedFiles();
    });
  }

  Future<void> _pickAndUploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isUploading = true;
        });

        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        File file = File(filePath);
        String fileExtension = fileName.split('.').last.toLowerCase();

        print('Processing file: $fileName');

        // Save file reference to Firestore
        await FirebaseFirestore.instance.collection('excel_files').add({
          'fileName': fileName,
          'filePath': filePath,
          'fileExtension': fileExtension,
          'uploadedAt': FieldValue.serverTimestamp(),
          'status': 'uploaded',
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _refreshFiles();
      }
    } catch (e) {
      print('Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing file: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _processExcelFile(String filePath) async {
    try {
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table]!;

        // Skip header row
        for (var i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];

          if (row.isEmpty || row[0]?.value == null) continue;

          // Parse Excel data
          String code = row[0]?.value?.toString() ?? '';
          String itemName = row[1]?.value?.toString() ?? '';
          String thickness = row[2]?.value?.toString() ?? '';
          double dp = double.tryParse(row[3]?.value?.toString() ?? '0') ?? 0.0;
          double tp = double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0;
          double mrp = double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0.0;

          // Upload to excel_products collection (separate from manual uploads)
          await FirebaseFirestore.instance.collection('excel_products').add({
            'code': code,
            'itemName': itemName,
            'thickness': thickness,
            'dp': dp,
            'tp': tp,
            'mrp': mrp,
            'uploadedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      throw Exception('Error processing Excel: $e');
    }
  }

  Future<void> _deleteFile(String docId, String filePath) async {
    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('excel_files')
          .doc(docId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File record deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Files'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.teal.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.upload_file, size: 50, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'File Manager',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Upload and manage all types of files',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Upload Button
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUploadExcel,
              icon: _isUploading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.upload_file),
              label: Text(
                _isUploading ? 'Uploading...' : 'Upload File',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Files List
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No files uploaded yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data![index];
                    var data = doc.data() as Map<String, dynamic>;

                    return _buildFileCard(
                      doc.id,
                      data['fileName'] ?? 'Unknown',
                      data['filePath'] ?? '',
                      data['uploadedAt']?.toDate() ?? DateTime.now(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(
    String docId,
    String fileName,
    String filePath,
    DateTime uploadedAt,
  ) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.insert_drive_file, color: Colors.teal, size: 30),
        ),
        title: Text(
          fileName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 5),
            Text(
              'Uploaded: ${uploadedAt.day}/${uploadedAt.month}/${uploadedAt.year} ${uploadedAt.hour}:${uploadedAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
              onTap: () {
                Future.delayed(Duration.zero, () {
                  _showDeleteConfirmation(docId, filePath, fileName);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String docId, String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete File?'),
        content: Text('Are you sure you want to delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFile(docId, filePath);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

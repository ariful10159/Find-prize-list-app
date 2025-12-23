import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class PrizeUploadPage extends StatefulWidget {
  @override
  _PrizeUploadPageState createState() => _PrizeUploadPageState();
}

class _PrizeUploadPageState extends State<PrizeUploadPage> {
  bool _isUploading = false;
  String? _fileName;
  List<Map<String, dynamic>> _parsedData = [];

  Future<void> _pickAndUploadExcel() async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        setState(() {
          _isUploading = true;
          _fileName = result.files.single.name;
        });

        // Read the Excel file
        var bytes = result.files.single.bytes;
        var excel = Excel.decodeBytes(bytes!);

        List<Map<String, dynamic>> products = [];

        // Parse Excel data
        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table];
          if (sheet != null) {
            // Skip header row (index 0)
            for (var i = 1; i < sheet.maxRows; i++) {
              var row = sheet.rows[i];

              // Assuming columns: Product Name, Price, Category, Description
              if (row.length >= 2) {
                String? productName = row[0]?.value?.toString();
                String? priceStr = row[1]?.value?.toString();
                String? category = row.length > 2
                    ? row[2]?.value?.toString()
                    : '';
                String? description = row.length > 3
                    ? row[3]?.value?.toString()
                    : '';

                if (productName != null && priceStr != null) {
                  double? price = double.tryParse(priceStr);
                  if (price != null) {
                    products.add({
                      'name': productName.trim(),
                      'price': price,
                      'category': category?.trim() ?? '',
                      'description': description?.trim() ?? '',
                      'uploadedAt': FieldValue.serverTimestamp(),
                    });
                  }
                }
              }
            }
          }
        }

        setState(() {
          _parsedData = products;
        });

        // Upload to Firebase
        if (products.isNotEmpty) {
          await _uploadToFirebase(products);
        } else {
          _showMessage('No valid data found in Excel file', isError: true);
        }

        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showMessage('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _uploadToFirebase(List<Map<String, dynamic>> products) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      int uploadCount = 0;
      for (var product in products) {
        final docRef = firestore.collection('products').doc();
        batch.set(docRef, product);
        uploadCount++;
      }

      await batch.commit();

      _showMessage(
        'Successfully uploaded $uploadCount products!',
        isError: false,
      );
    } catch (e) {
      _showMessage('Firebase upload error: ${e.toString()}', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prize Upload'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.upload_file, size: 60, color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        'Upload Product Prizes',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Upload Excel file with product information',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Instructions Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            'Excel File Format',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Your Excel file should have the following columns:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      _buildFormatItem('Column 1:', 'Product Name (Required)'),
                      _buildFormatItem('Column 2:', 'Price (Required, Number)'),
                      _buildFormatItem('Column 3:', 'Category (Optional)'),
                      _buildFormatItem('Column 4:', 'Description (Optional)'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.amber,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The first row should be the header row',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Upload Button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadExcel,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload, size: 28),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Select & Upload Excel File',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              if (_fileName != null) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.green.withOpacity(0.1),
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: Text('File: $_fileName'),
                    subtitle: Text('${_parsedData.length} products found'),
                  ),
                ),
              ],

              // Recent Uploads (Optional - can be expanded later)
              if (_parsedData.isNotEmpty) ...[
                const SizedBox(height: 30),
                const Text(
                  'Parsed Data Preview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _parsedData.length > 5 ? 5 : _parsedData.length,
                    itemBuilder: (context, index) {
                      final product = _parsedData[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(product['name'] ?? ''),
                        subtitle: Text('Price: ₹${product['price']}'),
                        trailing: Text(product['category'] ?? ''),
                      );
                    },
                  ),
                ),
                if (_parsedData.length > 5)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '... and ${_parsedData.length - 5} more',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

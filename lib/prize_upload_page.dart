import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
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
      print('===== Starting file picker =====');
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsb'],
      );

      print(
        'File picker result: ${result != null ? "File selected" : "No file selected"}',
      );

      if (result != null) {
        print('Selected file: ${result.files.single.name}');

        // Check if file is .xlsb format
        String fileName = result.files.single.name;
        if (fileName.toLowerCase().endsWith('.xlsb')) {
          setState(() {
            _isUploading = false;
          });
          _showMessage(
            '⚠️ XLSB format not supported!\n\nPlease convert your file to XLSX format:\n1. Open file in Excel\n2. File → Save As\n3. Choose "Excel Workbook (.xlsx)"\n4. Upload the new file',
            isError: true,
          );
          return;
        }

        setState(() {
          _isUploading = true;
          _fileName = result.files.single.name;
        });

        print('Starting to read Excel file...');
        // Read the Excel file
        // On mobile, bytes might be null, so we need to read from path
        var bytes = result.files.single.bytes;

        if (bytes == null || bytes.isEmpty) {
          print('Bytes is null or empty, reading from file path...');
          String? filePath = result.files.single.path;

          if (filePath != null) {
            print('File path: $filePath');
            final file = File(filePath);
            bytes = await file.readAsBytes();
            print('Bytes read from file: ${bytes.length}');
          } else {
            throw Exception(
              'Unable to read file: both bytes and path are unavailable',
            );
          }
        } else {
          print('Bytes read directly: ${bytes.length}');
        }

        // Decode Excel file with error handling
        late excel.Excel excelFile;
        try {
          excelFile = excel.Excel.decodeBytes(bytes);
          print('Excel file decoded successfully');
        } catch (e) {
          print('Excel decode error: $e');
          setState(() {
            _isUploading = false;
          });
          _showMessage(
            '❌ Excel file format not supported!\n\n'
            'Please try:\n'
            '1. Open the file in Excel\n'
            '2. Save As → Excel Workbook (.xlsx)\n'
            '3. Remove any:\n'
            '   • Macros or VBA code\n'
            '   • Complex formatting\n'
            '   • Password protection\n'
            '   • Pivot tables\n'
            '4. Save only the data sheet\n'
            '5. Try uploading again',
            isError: true,
          );
          return;
        }
        print('Excel file decoded successfully');
        print('Available sheets: ${excelFile.tables.keys.toList()}');

        List<Map<String, dynamic>> products = [];
        int totalRows = 0;
        int skippedRows = 0;

        // Parse Excel data
        for (var table in excelFile.tables.keys) {
          var sheet = excelFile.tables[table];
          if (sheet != null) {
            print('Sheet: $table, Total rows: ${sheet.maxRows}');

            // Skip header row (index 0)
            for (var i = 1; i < sheet.maxRows; i++) {
              totalRows++;
              var row = sheet.rows[i];

              print('Row $i length: ${row.length}');

              // Check if row has enough columns
              if (row.length >= 2) {
                // Excel columns: Code, Item name, Thickness, DP, TP, Picture, MRP
                // Get values with null safety matching actual Excel structure
                var codeCell = row.length > 0 ? row[0] : null;
                var itemNameCell = row.length > 1 ? row[1] : null;
                var thicknessCell = row.length > 2 ? row[2] : null;
                var dpCell = row.length > 3 ? row[3] : null;
                var tpCell = row.length > 4 ? row[4] : null;
                var pictureCell = row.length > 5 ? row[5] : null;
                var mrpCell = row.length > 6 ? row[6] : null;

                String? code = codeCell?.value?.toString()?.trim();
                String? itemName = itemNameCell?.value?.toString()?.trim();
                String? thickness = thicknessCell?.value?.toString()?.trim();
                String? dpStr = dpCell?.value?.toString()?.trim();
                String? tpStr = tpCell?.value?.toString()?.trim();
                String? picture = pictureCell?.value?.toString()?.trim();
                String? mrpStr = mrpCell?.value?.toString()?.trim();

                print(
                  'Row $i - Code: $code, Item: $itemName, Thickness: $thickness, DP: $dpStr, TP: $tpStr, MRP: $mrpStr',
                );

                // Only skip if both code AND itemName are empty
                if (code != null &&
                    code.isNotEmpty &&
                    itemName != null &&
                    itemName.isNotEmpty) {
                  double? dp = double.tryParse(dpStr ?? '0');
                  double? tp = double.tryParse(tpStr ?? '0');
                  double? mrp = double.tryParse(mrpStr ?? '0');

                  products.add({
                    'code': code,
                    'itemName': itemName,
                    'picture': picture ?? '',
                    'thickness': thickness ?? '',
                    'dp': dp ?? 0.0,
                    'tp': tp ?? 0.0,
                    'mrp': mrp ?? 0.0,
                    'uploadedAt': FieldValue.serverTimestamp(),
                  });
                  print('Added product: $code - $itemName');
                } else {
                  skippedRows++;
                  print('Skipped row $i - Code: $code, Item: $itemName');
                }
              } else {
                skippedRows++;
                print('Skipped row $i - insufficient columns');
              }
            }
          }
        }

        print('Total rows processed: $totalRows');
        print('Products found: ${products.length}');
        print('Skipped rows: $skippedRows');

        setState(() {
          _parsedData = products;
        });

        // Upload to Firebase
        if (products.isNotEmpty) {
          await _uploadToFirebase(products);
        } else {
          _showMessage(
            'No valid data found in Excel file.\nTotal rows: $totalRows, Skipped: $skippedRows\nMake sure Code and Item name columns have data.',
            isError: true,
          );
        }

        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      print('===== ERROR CAUGHT =====');
      print('Error type: ${e.runtimeType}');
      print('Error message: ${e.toString()}');
      print('Stack trace: ${StackTrace.current}');

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
                      _buildFormatItem('Column 1:', 'Code (Required)'),
                      _buildFormatItem('Column 2:', 'Item name (Required)'),
                      _buildFormatItem('Column 3:', 'Picture (Optional)'),
                      _buildFormatItem(
                        'Column 4:',
                        'Thickness (mm) (Optional)',
                      ),
                      _buildFormatItem('Column 5:', 'DP (Number)'),
                      _buildFormatItem('Column 6:', 'TP (Number)'),
                      _buildFormatItem('Column 7:', 'MRP (Number)'),
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
                        title: Text(product['itemName'] ?? ''),
                        subtitle: Text(
                          'Code: ${product['code']} | DP: ₹${product['dp']}',
                        ),
                        trailing: Text('MRP: ₹${product['mrp']}'),
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

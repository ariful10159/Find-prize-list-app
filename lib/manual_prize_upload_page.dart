import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'dart:typed_data';

class ManualPrizeUploadPage extends StatefulWidget {
  @override
  _ManualPrizeUploadPageState createState() => _ManualPrizeUploadPageState();
}

class _ManualPrizeUploadPageState extends State<ManualPrizeUploadPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isUploading = false;

  // Required fields
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _dpController = TextEditingController();
  Uint8List? _displayPictureBytes;
  String? _displayPictureName;

  // Optional fields
  final TextEditingController _thicknessController = TextEditingController();
  final TextEditingController _tpController = TextEditingController();
  final TextEditingController _mrpController = TextEditingController();

  // Additional photos
  List<Map<String, dynamic>> _additionalPhotos = [];

  @override
  void dispose() {
    _itemNameController.dispose();
    _dpController.dispose();
    _thicknessController.dispose();
    _tpController.dispose();
    _mrpController.dispose();
    super.dispose();
  }

  Future<void> _pickDisplayPicture() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _displayPictureBytes = result.files.first.bytes;
          _displayPictureName = result.files.first.name;
        });
        _showMessage('Display picture selected successfully!', isError: false);
      }
    } catch (e) {
      _showMessage('Error picking display picture: $e', isError: true);
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.bytes != null) {
              _additionalPhotos.add({'bytes': file.bytes, 'name': file.name});
            }
          }
        });
        _showMessage(
          '${result.files.length} photo(s) added successfully!',
          isError: false,
        );
      }
    } catch (e) {
      _showMessage('Error picking additional photos: $e', isError: true);
    }
  }

  void _removeAdditionalPhoto(int index) {
    setState(() {
      _additionalPhotos.removeAt(index);
    });
  }

  Future<void> _uploadPrize() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_displayPictureBytes == null) {
      _showMessage('Please select a display picture!', isError: true);
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Prepare prize data
      Map<String, dynamic> prizeData = {
        'itemName': _itemNameController.text.trim(),
        'dp': double.tryParse(_dpController.text) ?? 0.0,
        'displayPictureName': _displayPictureName,
        'displayPictureData': _displayPictureBytes,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
      };

      // Add optional fields if filled
      if (_thicknessController.text.isNotEmpty) {
        prizeData['thickness'] = _thicknessController.text.trim();
      }
      if (_tpController.text.isNotEmpty) {
        prizeData['tp'] = double.tryParse(_tpController.text) ?? 0.0;
      }
      if (_mrpController.text.isNotEmpty) {
        prizeData['mrp'] = double.tryParse(_mrpController.text) ?? 0.0;
      }

      // Add additional photos if any
      if (_additionalPhotos.isNotEmpty) {
        List<Map<String, dynamic>> photos = [];
        for (var photo in _additionalPhotos) {
          photos.add({'name': photo['name'], 'data': photo['bytes']});
        }
        prizeData['additionalPhotos'] = photos;
      }

      // Upload to Firestore
      await FirebaseFirestore.instance.collection('prizes').add(prizeData);

      _showMessage('Prize uploaded successfully!', isError: false);

      // Clear form
      _clearForm();
    } catch (e) {
      _showMessage('Error uploading prize: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _itemNameController.clear();
    _dpController.clear();
    _thicknessController.clear();
    _tpController.clear();
    _mrpController.clear();
    setState(() {
      _displayPictureBytes = null;
      _displayPictureName = null;
      _additionalPhotos.clear();
    });
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Prize Upload'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pop(context);
            },
            tooltip: 'Back to Dashboard',
          ),
        ],
      ),
      body: _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Uploading prize...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Add New Product Prize',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Fields marked with * are required',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 30),

                    // Required Fields Section
                    _buildSectionHeader('Required Information'),
                    SizedBox(height: 15),

                    // Item Name (Required)
                    TextFormField(
                      controller: _itemNameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'Enter prize item name',
                        prefixIcon: Icon(Icons.card_giftcard),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Item name is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // DP (Required)
                    TextFormField(
                      controller: _dpController,
                      decoration: InputDecoration(
                        labelText: 'DP (Display Price) *',
                        hintText: 'Enter display price',
                        prefixIcon: Icon(FontAwesomeIcons.bangladeshiTakaSign),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'DP is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Display Picture (Required)
                    Text(
                      'Display Picture *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    _buildDisplayPictureSection(),
                    SizedBox(height: 30),

                    // Optional Fields Section
                    _buildSectionHeader('Optional Information'),
                    SizedBox(height: 15),

                    // Thickness
                    TextFormField(
                      controller: _thicknessController,
                      decoration: InputDecoration(
                        labelText: 'Thickness',
                        hintText: 'Enter product thickness',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),

                    // TP (Trade Price)
                    TextFormField(
                      controller: _tpController,
                      decoration: InputDecoration(
                        labelText: 'TP (Trade Price)',
                        hintText: 'Enter trade price',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 15),

                    // MRP (Maximum Retail Price)
                    TextFormField(
                      controller: _mrpController,
                      decoration: InputDecoration(
                        labelText: 'MRP (Maximum Retail Price)',
                        hintText: 'Enter maximum retail price',
                        prefixIcon: Icon(Icons.sell),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 30),

                    // Additional Photos Section
                    _buildSectionHeader('Photos (Optional)'),
                    SizedBox(height: 15),
                    _buildAdditionalPhotosSection(),
                    SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _uploadPrize,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Upload Prize',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),

                    // Clear Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton(
                        onPressed: _clearForm,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Clear Form',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayPictureSection() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          if (_displayPictureBytes != null)
            Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _displayPictureBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  _displayPictureName ?? 'Unknown',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 10),
              ],
            ),
          ElevatedButton.icon(
            onPressed: _pickDisplayPicture,
            icon: Icon(Icons.image),
            label: Text(
              _displayPictureBytes == null
                  ? 'Select Display Picture'
                  : 'Change Display Picture',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalPhotosSection() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          if (_additionalPhotos.isNotEmpty)
            Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _additionalPhotos.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _additionalPhotos[index]['bytes'],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _removeAdditionalPhoto(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: 15),
              ],
            ),
          ElevatedButton.icon(
            onPressed: _pickAdditionalPhoto,
            icon: Icon(Icons.add_photo_alternate),
            label: Text('Add Photos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_additionalPhotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${_additionalPhotos.length} photo(s) added',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

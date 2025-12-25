import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

class ManageProductsPage extends StatefulWidget {
  @override
  _ManageProductsPageState createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<DocumentSnapshot>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _getAllProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _getAllProducts();
    });
  }

  Future<void> _deleteProduct(String docId, String itemName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Try deleting from both collections
        await _firestore
            .collection('prizes')
            .doc(docId)
            .delete()
            .catchError((_) {});
        await _firestore
            .collection('products')
            .doc(docId)
            .delete()
            .catchError((_) {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshProducts(); // Refresh the list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editProduct(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductPage(
          docId: doc.id,
          productData: data,
          collectionName: doc.reference.parent.id, // Pass the collection name
        ),
      ),
    );

    // Refresh products if editing was successful
    if (result == true) {
      _refreshProducts();
    }
  }

  Future<List<DocumentSnapshot>> _getAllProducts() async {
    try {
      final prizesSnapshot = await _firestore.collection('prizes').get();
      final productsSnapshot = await _firestore.collection('products').get();

      List<DocumentSnapshot> allDocs = [];
      allDocs.addAll(prizesSnapshot.docs);
      allDocs.addAll(productsSnapshot.docs);

      return allDocs;
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Products'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          // Filter products based on search query
          List<DocumentSnapshot> filteredProducts = [];
          if (snapshot.hasData) {
            filteredProducts = snapshot.data!.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final itemName = (data['itemName'] ?? '')
                  .toString()
                  .toLowerCase();
              final code = (data['code'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return itemName.contains(query) || code.contains(query);
            }).toList();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No products found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.add),
                    label: Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refreshProducts();
            },
            child: Column(
              children: [
                // Total Count Card
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Products',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${snapshot.data!.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.inventory_2,
                        size: 50,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by product name or code...',
                      prefixIcon: Icon(Icons.search, color: Colors.blue),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                SizedBox(height: 12),

                // Results Count
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Found ${filteredProducts.length} result(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Product List
                Expanded(
                  child: filteredProducts.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No products found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final doc = filteredProducts[index];
                            final data = doc.data() as Map<String, dynamic>;

                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Serial Number
                                    Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),

                                    // Product Image
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child:
                                            data['displayPictureData'] != null
                                            ? Image.memory(
                                                Uint8List.fromList(
                                                  List<int>.from(
                                                    data['displayPictureData'],
                                                  ),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : Icon(
                                                Icons.image_not_supported,
                                                size: 35,
                                                color: Colors.grey,
                                              ),
                                      ),
                                    ),
                                    SizedBox(width: 12),

                                    // Product Details in Table Format
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Item Name
                                          Text(
                                            data['itemName'] ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 8),

                                          // Table-like layout
                                          _buildInfoRow(
                                            'DP',
                                            '৳${data['dp'] ?? 0}',
                                            Colors.green[700]!,
                                          ),
                                          if (data['tp'] != null)
                                            _buildInfoRow(
                                              'TP',
                                              '৳${data['tp']}',
                                              Colors.blue[700]!,
                                            ),
                                          if (data['mrp'] != null)
                                            _buildInfoRow(
                                              'MRP',
                                              '৳${data['mrp']}',
                                              Colors.orange[700]!,
                                            ),
                                          if (data['thickness'] != null)
                                            _buildInfoRow(
                                              'Thickness',
                                              '${data['thickness']}',
                                              Colors.grey[700]!,
                                            ),
                                          if (data['code'] != null)
                                            _buildInfoRow(
                                              'Code',
                                              '${data['code']}',
                                              Colors.grey[600]!,
                                            ),

                                          SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Edit Button
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _editProduct(doc),
                                                icon: Icon(
                                                  Icons.edit,
                                                  size: 16,
                                                ),
                                                label: Text('Edit'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size(0, 32),
                                                ),
                                              ),
                                              SizedBox(width: 8),

                                              // Delete Button
                                              ElevatedButton.icon(
                                                onPressed: () => _deleteProduct(
                                                  doc.id,
                                                  data['itemName'] ?? 'Unknown',
                                                ),
                                                icon: Icon(
                                                  Icons.delete,
                                                  size: 16,
                                                ),
                                                label: Text('Delete'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  minimumSize: Size(0, 32),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper widget to build table-like info rows
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Product Page
class EditProductPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> productData;
  final String collectionName; // Add collection name

  EditProductPage({
    required this.docId,
    required this.productData,
    required this.collectionName,
  });

  @override
  _EditProductPageState createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isUpdating = false;

  late TextEditingController _itemNameController;
  late TextEditingController _dpController;
  late TextEditingController _thicknessController;
  late TextEditingController _tpController;
  late TextEditingController _mrpController;

  @override
  void initState() {
    super.initState();
    _itemNameController = TextEditingController(
      text: widget.productData['itemName'] ?? '',
    );
    _dpController = TextEditingController(
      text: widget.productData['dp']?.toString() ?? '',
    );
    _thicknessController = TextEditingController(
      text: widget.productData['thickness'] ?? '',
    );
    _tpController = TextEditingController(
      text: widget.productData['tp']?.toString() ?? '',
    );
    _mrpController = TextEditingController(
      text: widget.productData['mrp']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _dpController.dispose();
    _thicknessController.dispose();
    _tpController.dispose();
    _mrpController.dispose();
    super.dispose();
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      Map<String, dynamic> updateData = {
        'itemName': _itemNameController.text.trim(),
        'dp': double.tryParse(_dpController.text) ?? 0.0,
      };

      if (_thicknessController.text.isNotEmpty) {
        updateData['thickness'] = _thicknessController.text.trim();
      }
      if (_tpController.text.isNotEmpty) {
        updateData['tp'] = double.tryParse(_tpController.text) ?? 0.0;
      }
      if (_mrpController.text.isNotEmpty) {
        updateData['mrp'] = double.tryParse(_mrpController.text) ?? 0.0;
      }

      await FirebaseFirestore.instance
          .collection(widget.collectionName) // Use the correct collection
          .doc(widget.docId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Product'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: _isUpdating
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display existing image
                    if (widget.productData['displayPictureData'] != null)
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              Uint8List.fromList(
                                List<int>.from(
                                  widget.productData['displayPictureData'],
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 30),

                    // Item Name
                    TextFormField(
                      controller: _itemNameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
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

                    // DP
                    TextFormField(
                      controller: _dpController,
                      decoration: InputDecoration(
                        labelText: 'DP (Display Price) *',
                        prefixIcon: Icon(Icons.currency_rupee),
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

                    // Thickness
                    TextFormField(
                      controller: _thicknessController,
                      decoration: InputDecoration(
                        labelText: 'Thickness',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // TP
                    TextFormField(
                      controller: _tpController,
                      decoration: InputDecoration(
                        labelText: 'TP (Trade Price)',
                        prefixIcon: Icon(Icons.money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 20),

                    // MRP
                    TextFormField(
                      controller: _mrpController,
                      decoration: InputDecoration(
                        labelText: 'MRP (Maximum Retail Price)',
                        prefixIcon: Icon(Icons.sell),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 40),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _updateProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Update Product',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryManagementPage extends StatefulWidget {
  @override
  _CategoryManagementPageState createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  final TextEditingController _categoryController = TextEditingController();
  bool _isAdding = false;
  String? _editingCategoryId;
  final TextEditingController _editController = TextEditingController();

  Future<void> _addCategory() async {
    final categoryName = _categoryController.text.trim();
    if (categoryName.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      await FirebaseFirestore.instance.collection('categories').add({
        'name': categoryName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _categoryController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category added!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _updateCategory(String docId) async {
    final newName = _editController.text.trim();
    if (newName.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('categories')
          .doc(docId)
          .update({'name': newName});
      setState(() {
        _editingCategoryId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Categories'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: InputDecoration(hintText: 'Category name'),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isAdding ? null : _addCategory,
                  child: _isAdding
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            Text(
              'Existing Categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('categories')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Text('No categories added yet'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isEditing = _editingCategoryId == doc.id;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: isEditing
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _editController,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          hintText: 'Category name',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _updateCategory(doc.id),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _editingCategoryId = null;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: Text(data['name'] ?? '')),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.deepPurple,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _editingCategoryId = doc.id;
                                          _editController.text =
                                              data['name'] ?? '';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                          subtitle: data['createdAt'] != null
                              ? Text('Created: ${data['createdAt'].toDate()}')
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

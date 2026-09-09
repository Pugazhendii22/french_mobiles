import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/catalog_firebase.dart';
import '../widgets/app_back_button.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String _name = '';
  String? _photoUrl;
  bool _loading = false;
  bool _saving = false;
  File? _pickedFile;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = catalogAuth.currentUser;
    if (user != null) {
      _name = user.displayName ?? '';
      _photoUrl = user.photoURL;
      _nameCtrl.text = _name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
    if (picked == null) return;
    setState(() {
      _pickedFile = File(picked.path);
      _loading = true;
    });

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/djvjsrva/image/upload');
      final req = http.MultipartRequest('POST', uri);
      req.fields['upload_preset'] = 'lalalala';
      req.files.add(await http.MultipartFile.fromPath('file', _pickedFile!.path));
      final streamed = await req.send();
      final respStr = await streamed.stream.bytesToString();
      final json = jsonDecode(respStr) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String?;
      if (secureUrl != null) {
        setState(() {
          _photoUrl = secureUrl;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final user = catalogAuth.currentUser;
    if (user == null) return;
    final docRef = catalogFirestore.collection('users').doc(user.uid);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{'name': name};
      if (_photoUrl != null && _photoUrl!.isNotEmpty) updates['photoUrl'] = _photoUrl;
      await docRef.set(updates, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B69B),
        elevation: 0,
        leading: const AppBackButton.dark(),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFFF3F4F6),
                    child: _loading
                        ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator())
                        : (_photoUrl != null && _photoUrl!.isNotEmpty
                            ? ClipOval(child: Image.network(_photoUrl!, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48)))
                            : const Icon(Icons.person, size: 48)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Color(0xFF00B69B), size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B69B), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

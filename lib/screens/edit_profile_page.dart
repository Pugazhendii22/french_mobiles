import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/catalog_firebase.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

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
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.xxl,
              ),
              children: [
                const AppScreenHeader(title: 'Edit profile'),
                const SizedBox(height: AppSpacing.xxl),
                Center(child: _buildAvatar()),
                const SizedBox(height: AppSpacing.xxl),
                Text('Name', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _nameCtrl,
                  style: AppTextStyles.body,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: AppBottomBar(
          child: AppPrimaryButton(
            label: 'Save changes',
            loading: _saving,
            onPressed: _saving || _loading ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: InkWell(
        onTap: _loading ? null : _pickImage,
        customBorder: const CircleBorder(),
        child: Stack(
          children: [
            Container(
              height: 104,
              width: 104,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : hasPhoto
                      ? AppNetworkImage(
                          url: _photoUrl!,
                          height: 104,
                          width: 104,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.zero,
                          placeholderIcon: Icons.person_outline_rounded,
                        )
                      : const Icon(
                          Icons.person_outline_rounded,
                          size: 44,
                          color: AppColors.textTertiary,
                        ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 15,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_sizes.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/providers.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_text_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  File? _pickedPhoto;
  String? _uploadedPhotoUrl;
  bool _uploadingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _uploadedPhotoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() {
      _pickedPhoto = File(picked.path);
      _uploadingPhoto = true;
    });

    final result = await ref.read(authRepositoryProvider).uploadProfilePhoto(
      uid: widget.user.uid,
      file: _pickedPhoto!,
    );

    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    result.map(
      onSuccess: (url) => setState(() => _uploadedPhotoUrl = url),
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await ref.read(authRepositoryProvider).updateProfile(
      uid: widget.user.uid,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    result.map(
      onSuccess: (_) {
        Helpers.showToast(message: 'Profile updated');
        AppRouter.pop();
      },
      onError: (error) => context.showSnack(error.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Edit profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              children: [
                Center(
                  child: Stack(
                    children: [
                      _AvatarPreview(
                        photoFile: _pickedPhoto,
                        photoUrl: _uploadedPhotoUrl,
                        loading: _uploadingPhoto,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.accent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.grey900,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacing32),
                CustomTextField(
                  label: 'Full name',
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                  validator: (v) => Validators.required(v, fieldName: 'Name'),
                  prefix: const Icon(Icons.badge_outlined, size: 20),
                ),
                const SizedBox(height: AppSizes.spacing16),
                CustomTextField(
                  label: 'Phone number',
                  hint: 'e.g. 024 123 4567',
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // optional
                    final digits = v.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 9) return 'Enter a valid phone number';
                    return null;
                  },
                  prefix: const Icon(Icons.call_outlined, size: 20),
                ),
                const SizedBox(height: AppSizes.spacing32),
                CustomButton(
                  text: 'Save changes',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final File? photoFile;
  final String? photoUrl;
  final bool loading;

  const _AvatarPreview({
    required this.photoFile,
    required this.photoUrl,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(color: AppColors.grey50, shape: BoxShape.circle),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoFile != null)
              Image.file(photoFile!, fit: BoxFit.cover)
            else if (photoUrl != null)
              Image.network(photoUrl!, fit: BoxFit.cover)
            else
              const Icon(Icons.person_outline_rounded, color: AppColors.grey300, size: 40),
            if (loading)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
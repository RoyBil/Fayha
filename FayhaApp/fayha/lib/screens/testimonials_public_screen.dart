import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/mock_data.dart';
import '../services/testimonials_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';

class TestimonialsPublicScreen extends StatefulWidget {
  const TestimonialsPublicScreen({super.key});

  @override
  State<TestimonialsPublicScreen> createState() =>
      _TestimonialsPublicScreenState();
}

class _TestimonialsPublicScreenState extends State<TestimonialsPublicScreen> {
  late Future<List<Testimonial>> _public;

  @override
  void initState() {
    super.initState();
    _public = TestimonialsService.fetchPublic();
  }

  void _reload() {
    setState(() => _public = TestimonialsService.fetchPublic());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Testimonials')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SectionHeader(
              eyebrow: 'From the Choir',
              title: 'Voices of Fayha',
              subtitle:
                  'Stories shared by our members and audience about the choir.',
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<Testimonial>>(
              future: _public,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data ?? const <Testimonial>[];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No testimonials yet — be the first to share!',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return Column(
                  children: list
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TestimonialCard(t: t),
                          ))
                      .toList(),
                );
              },
            ),
            if (!AppState.instance.isSignedIn) ...[
              const SizedBox(height: 28),
              const SectionHeader(
                eyebrow: 'From You',
                title: 'Share Your Story',
                subtitle:
                    'Tell us about your experience with the choir. Add a photo if you like.',
              ),
              const SizedBox(height: 16),
              _AudienceSubmitForm(onSubmitted: _reload),
            ],
          ],
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final Testimonial t;
  const _TestimonialCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(t.photoUrl!),
                  backgroundColor: AppColors.offWhite,
                )
              else
                Avatar(name: t.author, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.author, style: theme.textTheme.titleMedium),
                    if (t.voiceSection.isNotEmpty)
                      Text(
                        t.voiceSection,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.accent, width: 3),
              ),
            ),
            child: Text(
              t.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudienceSubmitForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _AudienceSubmitForm({required this.onSubmitted});

  @override
  State<_AudienceSubmitForm> createState() => _AudienceSubmitFormState();
}

class _AudienceSubmitFormState extends State<_AudienceSubmitForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final ext = f.name.contains('.')
        ? f.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoExt = ext;
    });
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final msg = _message.text.trim();
    if (name.isEmpty || email.isEmpty || msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill in name, email, and message')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await TestimonialsService.uploadPhoto(
          bytes: _photoBytes!,
          fileExtension: _photoExt,
        );
      }
      await TestimonialsService.submit(
        author: name,
        email: email,
        body: msg,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() => _done = true);
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return ElegantCard(
        background: AppColors.secondary.withValues(alpha: 0.08),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Thank you! Your testimonial has been shared.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    final hasPhoto = _photoBytes != null;
    return AbsorbPointer(
      absorbing: _saving,
      child: ElegantCard(
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _message,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Your message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (hasPhoto)
                  ClipOval(
                    child: Image.memory(
                      _photoBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.offWhite,
                    child: Icon(Icons.person, color: AppColors.gray),
                  ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: Icon(
                      hasPhoto ? Icons.swap_horiz : Icons.add_photo_alternate_outlined,
                      size: 18),
                  label: Text(hasPhoto ? 'Change photo' : 'Add photo (optional)'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cream),
                        )
                      : const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

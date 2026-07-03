import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _showAll = false;

  static const _initialCount = 10;

  @override
  void initState() {
    super.initState();
    _public = TestimonialsService.fetchPublic();
  }

  void _reload() {
    setState(() {
      _public = TestimonialsService.fetchPublic();
    });
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
                final visible = _showAll
                    ? list
                    : list.take(_initialCount).toList();
                final hasMore = !_showAll && list.length > _initialCount;
                return Column(
                  children: [
                    ...visible.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TestimonialCard(t: t),
                      ),
                    ),
                    if (hasMore) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showAll = true),
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text(
                          'Read more (${list.length - _initialCount} more)',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_showAll && list.length > _initialCount) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _showAll = false),
                        icon: const Icon(Icons.expand_less, size: 18),
                        label: const Text('Show less'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
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

class _TestimonialCard extends StatefulWidget {
  final Testimonial t;
  const _TestimonialCard({required this.t});

  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard> {
  static const _truncateAt = 75;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.t;
    final isLong = t.body.length > _truncateAt;
    final displayText = isLong && !_expanded
        ? '${t.body.substring(0, _truncateAt)}…'
        : t.body;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (isLong) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Read Less' : 'Read More',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
  final _captchaCtrl = TextEditingController();
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';
  bool _saving = false;
  bool _done = false;

  // Bot protection: simple math challenge + minimum visible-time gate.
  late final int _captchaA;
  late final int _captchaB;
  bool _captchaSolved = false;
  late final DateTime _formShownAt;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _captchaA = rng.nextInt(9) + 1;
    _captchaB = rng.nextInt(9) + 1;
    _formShownAt = DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  static const _maxPhotoBytes = 5 * 1024 * 1024; // 5 MB

  Future<void> _pickPhoto() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (f == null) return;
    var bytes = await f.readAsBytes();

    // If still above 5 MB, re-pick with lower quality is not possible
    // (image_picker runs native compression); show a friendly error instead.
    if (bytes.lengthInBytes > _maxPhotoBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Photo is too large (max 5 MB). Please choose a smaller image.',
          ),
        ),
      );
      return;
    }

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
          content: Text('Please fill in name, email, and message'),
        ),
      );
      return;
    }
    if (!_captchaSolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please answer the security question: $_captchaA + $_captchaB = ?',
          ),
        ),
      );
      return;
    }
    // Time-gate: if the form was filled in under 3 seconds it's almost
    // certainly a bot. Silently pretend success to avoid revealing the check.
    if (DateTime.now().difference(_formShownAt).inSeconds < 3) {
      setState(() => _done = true);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
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
            const SizedBox(height: 10),
            TextField(
              controller: _captchaCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Security check: what is $_captchaA + $_captchaB?',
                prefixIcon: const Icon(Icons.security_outlined, size: 18),
                suffixIcon: _captchaSolved
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.secondary,
                        size: 20,
                      )
                    : null,
              ),
              onChanged: (v) {
                final answer = int.tryParse(v.trim());
                final solved = answer == _captchaA + _captchaB;
                if (solved != _captchaSolved) {
                  setState(() => _captchaSolved = solved);
                }
              },
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
                    child: Icon(Icons.account_circle, color: AppColors.gray),
                  ),
                const SizedBox(width: 10),
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: Icon(
                      hasPhoto
                          ? Icons.swap_horiz
                          : Icons.account_circle_outlined,
                      size: 18,
                    ),
                    label: Text(
                      hasPhoto ? 'Change picture' : 'Profile picture',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cream,
                          ),
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

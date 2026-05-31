import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../services/audience_data.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';

class TestimonialsPublicScreen extends StatefulWidget {
  const TestimonialsPublicScreen({super.key});

  @override
  State<TestimonialsPublicScreen> createState() => _TestimonialsPublicScreenState();
}

class _TestimonialsPublicScreenState extends State<TestimonialsPublicScreen> {
  late Future<List<Testimonial>> _approved;

  @override
  void initState() {
    super.initState();
    _approved = AudienceData.fetchApprovedTestimonials();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Testimonials')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const SectionHeader(
            eyebrow: 'From the Choir',
            title: 'Voices of Fayha',
            subtitle:
                'Stories shared by our members about life inside the choir.',
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Testimonial>>(
            future: _approved,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final approved = snap.data ?? const <Testimonial>[];
              return Column(
                children: approved.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElegantCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(name: t.author, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.author,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(t.voiceSection,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.primary,
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
                    ),
                    child: Text(
                      t.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )).toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          const SectionHeader(
            eyebrow: 'From You',
            title: 'Share Your Story',
            subtitle:
                'Are you in the audience? Tell us about your experience with the choir.',
          ),
          const SizedBox(height: 16),
          _AudienceSubmitForm(),
        ],
      ),
    );
  }
}

class _AudienceSubmitForm extends StatefulWidget {
  @override
  State<_AudienceSubmitForm> createState() => _AudienceSubmitFormState();
}

class _AudienceSubmitFormState extends State<_AudienceSubmitForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _photo = false;
  bool _done = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name, email, and message')),
      );
      return;
    }
    try {
      await AudienceData.submitTestimonial(
        author: _name.text.trim(),
        voiceSection: 'Audience',
        body: _message.text.trim(),
      );
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!context.mounted) return;
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
                'Thank you! Your testimonial is pending admin approval.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return ElegantCard(
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
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _photo = !_photo),
                icon: Icon(_photo ? Icons.image : Icons.add_photo_alternate_outlined, size: 18),
                label: Text(_photo ? 'Photo attached' : 'Attach photo'),
              ),
              const Spacer(),
              FilledButton(onPressed: _submit, child: const Text('Submit')),
            ],
          ),
        ],
      ),
    );
  }
}

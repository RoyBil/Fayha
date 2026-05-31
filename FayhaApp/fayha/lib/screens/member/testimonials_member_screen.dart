import 'package:flutter/material.dart';
import '../../data/mock_data.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../widgets/elegant_card.dart';

class TestimonialsMemberScreen extends StatefulWidget {
  const TestimonialsMemberScreen({super.key});

  @override
  State<TestimonialsMemberScreen> createState() => _TestimonialsMemberScreenState();
}

class _TestimonialsMemberScreenState extends State<TestimonialsMemberScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testimonials'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Submit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _feed(),
          _submit(),
        ],
      ),
    );
  }

  Widget _feed() {
    final approved = MockData.testimonials
        .where((t) => t.status == TestimonialStatus.approved)
        .toList();
    if (approved.isEmpty) {
      return const Center(child: Text('No testimonials yet.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: approved.map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _TestimonialCard(t: t),
      )).toList(),
    );
  }

  Widget _submit() => _SubmitForm(onSubmitted: () {
    setState(() {});
    _tabs.animateTo(0);
  });
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
              Avatar(name: t.author, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.author, style: theme.textTheme.titleMedium),
                    Text(t.voiceSection,
                        style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
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

class _SubmitForm extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _SubmitForm({required this.onSubmitted});

  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  final _ctrl = TextEditingController();
  bool _attachedPhoto = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim().isEmpty) return;
    final m = AppState.instance.currentMember!;
    MockData.testimonials.insert(
      0,
      Testimonial(
        author: m.name,
        voiceSection: m.voiceSection,
        body: _ctrl.text.trim(),
        submittedAt: DateTime.now(),
      ),
    );
    _ctrl.clear();
    setState(() => _attachedPhoto = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitted — pending admin approval')),
    );
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myPending = MockData.testimonials
        .where((t) =>
            t.author == AppState.instance.currentMember?.name &&
            t.status != TestimonialStatus.approved)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Share your experience', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Your testimonial will be reviewed by an admin. Once approved it appears both here and on the public app.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Write your testimonial…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _attachedPhoto = !_attachedPhoto),
              icon: Icon(_attachedPhoto ? Icons.image : Icons.add_photo_alternate_outlined, size: 18),
              label: Text(_attachedPhoto ? 'Photo attached' : 'Attach photo'),
            ),
            const Spacer(),
            FilledButton(onPressed: _submit, child: const Text('Submit')),
          ],
        ),
        if (myPending.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('My submissions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          ...myPending.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElegantCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(_statusIcon(t.status), size: 18, color: _statusColor(t.status)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_statusLabel(t.status),
                            style: theme.textTheme.titleSmall?.copyWith(color: _statusColor(t.status))),
                        const SizedBox(height: 4),
                        Text(
                          t.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  IconData _statusIcon(TestimonialStatus s) {
    switch (s) {
      case TestimonialStatus.pending: return Icons.hourglass_empty;
      case TestimonialStatus.approved: return Icons.check_circle;
      case TestimonialStatus.rejected: return Icons.cancel;
    }
  }

  Color _statusColor(TestimonialStatus s) {
    switch (s) {
      case TestimonialStatus.pending: return AppColors.accentDark;
      case TestimonialStatus.approved: return AppColors.secondary;
      case TestimonialStatus.rejected: return const Color(0xFFB23A48);
    }
  }

  String _statusLabel(TestimonialStatus s) {
    switch (s) {
      case TestimonialStatus.pending: return 'Pending approval';
      case TestimonialStatus.approved: return 'Approved';
      case TestimonialStatus.rejected: return 'Rejected';
    }
  }
}

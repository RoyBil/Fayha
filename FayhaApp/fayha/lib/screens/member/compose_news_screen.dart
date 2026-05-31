import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class ComposeNewsScreen extends StatefulWidget {
  const ComposeNewsScreen({super.key});

  @override
  State<ComposeNewsScreen> createState() => _ComposeNewsScreenState();
}

class _ComposeNewsScreenState extends State<ComposeNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dateLabel = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _dateLabel.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AdminService.addNews(
        dateLabel: _dateLabel.text.trim(),
        title: _title.text.trim(),
        body: _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post news: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post News')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                controller: _dateLabel,
                decoration: const InputDecoration(
                  labelText: 'Date label (e.g. "May 2026")',
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Headline',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _body,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Article',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Icon(Icons.publish, size: 18),
                label: const Text('Publish News'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

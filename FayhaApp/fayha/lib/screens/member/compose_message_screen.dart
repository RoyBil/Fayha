import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/messages_service.dart';
import '../../theme/app_theme.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});

  @override
  State<ComposeMessageScreen> createState() => _ComposeMessageScreenState();
}

class _ComposeMessageScreenState extends State<ComposeMessageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'members';
  String? _branch;
  String? _voice;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audience == 'branch' && _branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a branch')),
      );
      return;
    }
    if (_audience == 'voice' && _voice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a voice section')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await MessagesService.send(
        title: _title.text.trim(),
        body: _body.text.trim(),
        audience: _audience,
        branch: _audience == 'branch' ? _branch : null,
        voiceSection: _audience == 'voice' ? _voice : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Message')),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _body,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              Text('Send to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _audience,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: MessagesService.audiences
                    .map((a) => DropdownMenuItem(value: a.$1, child: Text(a.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _audience = v ?? 'members'),
              ),
              if (_audience == 'branch') ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _branch,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: ChoirData.branches
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _branch = v),
                ),
              ],
              if (_audience == 'voice') ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _voice,
                  decoration: const InputDecoration(
                    labelText: 'Voice section or group',
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  items: ChoirData.messageVoiceTargets
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() => _voice = v),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Icon(Icons.send, size: 18),
                label: const Text('Send Message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

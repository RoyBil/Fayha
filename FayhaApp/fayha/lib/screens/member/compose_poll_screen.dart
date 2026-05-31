import 'package:flutter/material.dart';
import '../../data/choir_data.dart';
import '../../services/messages_service.dart';
import '../../services/polls_service.dart';
import '../../theme/app_theme.dart';

class ComposePollScreen extends StatefulWidget {
  const ComposePollScreen({super.key});

  @override
  State<ComposePollScreen> createState() => _ComposePollScreenState();
}

class _ComposePollScreenState extends State<ComposePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiChoice = false;
  String _audience = 'members';
  String? _branch;
  DateTime? _closesAt;
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    _description.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length >= 8) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_options.length <= 2) return;
    setState(() {
      _options[i].dispose();
      _options.removeAt(i);
    });
  }

  Future<void> _pickCloseDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _closesAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    setState(() {
      _closesAt = DateTime(
        d.year, d.month, d.day, t?.hour ?? 23, t?.minute ?? 59,
      );
    });
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final opts = _options
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (opts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 non-empty options')),
      );
      return;
    }
    if (_audience == 'branch' && _branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a branch')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PollsService.createPoll(
        question: _question.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        options: opts,
        multiChoice: _multiChoice,
        audience: _audience,
        branch: _audience == 'branch' ? _branch : null,
        closesAt: _closesAt,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish: $e')),
      );
    }
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Poll')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              TextFormField(
                controller: _question,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  prefixIcon: Icon(Icons.help_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 22),
              Text('Options', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _options[i],
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            prefixIcon: const Icon(Icons.tag),
                          ),
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.gray),
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                ),
              if (_options.length < 8)
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add option'),
                ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow multiple selections'),
                subtitle: const Text(
                    'Members can vote for more than one option'),
                value: _multiChoice,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _multiChoice = v),
              ),
              const SizedBox(height: 14),
              Text('Send to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _audience,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                items: MessagesService.audiences
                    .where((a) => a.$1 != 'audience' && a.$1 != 'everyone')
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
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickCloseDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.offWhite),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_busy,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _closesAt == null
                              ? 'Closes: never (optional)'
                              : 'Closes: ${_fmt(_closesAt!)}',
                        ),
                      ),
                      if (_closesAt != null)
                        IconButton(
                          icon:
                              const Icon(Icons.clear, color: AppColors.gray),
                          onPressed: () => setState(() => _closesAt = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _publish,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cream),
                      )
                    : const Icon(Icons.publish, size: 18),
                label: const Text('Publish Poll'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

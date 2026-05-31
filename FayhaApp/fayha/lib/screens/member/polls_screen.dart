import 'package:flutter/material.dart';
import '../../services/polls_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/branded_background.dart';
import '../../widgets/elegant_card.dart';
import '../../widgets/empty_state.dart';
import 'compose_poll_screen.dart';
import 'member_detail_screen.dart';
import '../../services/admin_service.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  List<Poll>? _polls;
  String? _loadError;
  bool _loading = true;
  final Set<String> _voting = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await PollsService.fetchAll();
      if (!mounted) return;
      setState(() {
        _polls = list;
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _openCompose() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ComposePollScreen()),
    );
    // Tiny delay so Supabase has finished the insert before refetching.
    await Future.delayed(const Duration(milliseconds: 250));
    await _load();
  }

  /// Builds a new Poll with the local vote applied (or removed).
  Poll _applyLocalVote(Poll p, PollOption o, {required bool remove}) {
    final newMy = Set<String>.from(p.myVotes);
    final newOpts = <PollOption>[];
    var newTotal = p.totalVotes;

    if (remove) {
      newMy.remove(o.id);
      for (final opt in p.options) {
        if (opt.id == o.id) {
          newOpts.add(PollOption(
            id: opt.id,
            text: opt.text,
            sortOrder: opt.sortOrder,
            voteCount: (opt.voteCount - 1).clamp(0, 1 << 31),
            voters: opt.voters,
          ));
          newTotal = (newTotal - 1).clamp(0, 1 << 31);
        } else {
          newOpts.add(opt);
        }
      }
    } else {
      // Single-choice: remove old votes first (locally).
      if (!p.multiChoice) {
        final oldId = p.myVotes.isNotEmpty ? p.myVotes.first : null;
        for (final opt in p.options) {
          if (opt.id == oldId) {
            newOpts.add(PollOption(
              id: opt.id,
              text: opt.text,
              sortOrder: opt.sortOrder,
              voteCount: (opt.voteCount - 1).clamp(0, 1 << 31),
            ));
            newTotal = (newTotal - 1).clamp(0, 1 << 31);
          } else {
            newOpts.add(opt);
          }
        }
        newMy.clear();
      } else {
        newOpts.addAll(p.options);
      }
      // Now add the new vote.
      final idx = newOpts.indexWhere((opt) => opt.id == o.id);
      if (idx >= 0) {
        newOpts[idx] = PollOption(
          id: newOpts[idx].id,
          text: newOpts[idx].text,
          sortOrder: newOpts[idx].sortOrder,
          voteCount: newOpts[idx].voteCount + 1,
          voters: newOpts[idx].voters,
        );
        newTotal += 1;
        newMy.add(o.id);
      }
    }

    return Poll(
      id: p.id,
      question: p.question,
      description: p.description,
      multiChoice: p.multiChoice,
      audience: p.audience,
      branch: p.branch,
      createdByName: p.createdByName,
      createdAt: p.createdAt,
      closesAt: p.closesAt,
      options: newOpts,
      myVotes: newMy,
      totalVotes: newTotal,
    );
  }

  void _replacePoll(Poll updated) {
    final idx = _polls!.indexWhere((x) => x.id == updated.id);
    if (idx >= 0) _polls![idx] = updated;
  }

  Future<void> _onTapOption(Poll p, PollOption o) async {
    if (p.isClosed) return;
    if (_voting.contains(p.id)) return;
    _voting.add(p.id);
    final already = p.myVotes.contains(o.id);
    final original = p;

    // Optimistic update.
    setState(() {
      _replacePoll(_applyLocalVote(p, o, remove: already));
    });

    try {
      if (already) {
        await PollsService.unvote(pollId: p.id, optionId: o.id);
      } else {
        await PollsService.vote(
          pollId: p.id,
          optionId: o.id,
          multiChoice: p.multiChoice,
        );
      }
      // Refresh from server to get exact tallies (in case others voted too).
      final fresh = await PollsService.fetchAll();
      if (!mounted) return;
      setState(() => _polls = fresh);
    } catch (e) {
      if (!mounted) return;
      // Roll back.
      setState(() => _replacePoll(original));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save vote: $e')),
      );
    } finally {
      _voting.remove(p.id);
    }
  }

  Future<void> _confirmDelete(Poll p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete poll?'),
        content: Text('"${p.question}" and all its votes will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PollsService.deletePoll(p.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = AppState.instance.isAdmin || AppState.instance.isMaestro;
    return Scaffold(
      appBar: AppBar(title: const Text('Polls')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCompose,
              icon: const Icon(Icons.add),
              label: const Text('New poll'),
            )
          : null,
      body: BrandedBackground(
        child: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (context) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loadError != null) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load polls',
                    message: _loadError,
                  ),
                ],
              );
            }
            final polls = _polls ?? const <Poll>[];
            if (polls.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  EmptyState(
                    icon: Icons.poll_outlined,
                    title: 'No polls yet',
                    message: 'Admins can create polls from this screen.',
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: polls.length,
              itemBuilder: (context, i) {
                final p = polls[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PollCard(
                    poll: p,
                    onTapOption: (o) => _onTapOption(p, o),
                    onDelete: AppState.instance.isMaestro
                        ? () => _confirmDelete(p)
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  final void Function(PollOption) onTapOption;
  final VoidCallback? onDelete;
  const _PollCard({
    required this.poll,
    required this.onTapOption,
    this.onDelete,
  });

  String _date(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _audienceLabel() {
    switch (poll.audience) {
      case 'members':
        return 'All members';
      case 'branch':
        return poll.branch ?? 'Branch';
      case 'admins':
        return 'Admins';
      case 'superAdmins':
        return 'Maestro';
      default:
        return poll.audience;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voted = poll.hasVoted;
    final total = poll.totalVotes == 0 ? 1 : poll.totalVotes;
    return ElegantCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.poll_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${poll.createdByName ?? 'Admin'} · ${_date(poll.createdAt)}',
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Chip(label: _audienceLabel(), color: AppColors.accentDark),
                        if (poll.multiChoice)
                          const _Chip(label: 'Multi-choice', color: AppColors.primary),
                        if (poll.isClosed)
                          const _Chip(label: 'Closed', color: AppColors.gray),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.gray,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(poll.question, style: theme.textTheme.titleLarge),
          if (poll.description != null && poll.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(poll.description!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 14),
          ...poll.options.map((o) {
            final count = o.voteCount;
            final pct = count / total;
            final selected = poll.myVotes.contains(o.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: poll.isClosed ? null : () => onTapOption(o),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.offWhite,
                      width: selected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            poll.multiChoice
                                ? (selected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                                : (selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                            size: 18,
                            color: selected ? AppColors.primary : AppColors.gray,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(o.text, style: theme.textTheme.bodyLarge),
                          ),
                          if (voted)
                            Text('${(pct * 100).round()}%',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.gray,
                                )),
                        ],
                      ),
                      if (voted || poll.isClosed) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 4,
                            backgroundColor: AppColors.offWhite,
                            color: selected
                                ? AppColors.primary
                                : AppColors.accent,
                          ),
                        ),
                      ],
                      if (o.voters.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _VotersRow(voters: o.voters),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          if (poll.isClosed)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gray.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.gray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Poll closed · ${poll.totalVotes} final votes',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: AppColors.gray),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              voted
                  ? '${poll.totalVotes} votes · Tap your choice to remove it'
                  : '${poll.totalVotes} votes · Tap an option to vote',
              style: theme.textTheme.labelMedium,
            ),
        ],
      ),
    );
  }
}

class _VotersRow extends StatelessWidget {
  final List<PollVoter> voters;
  const _VotersRow({required this.voters});

  Future<void> _openMember(BuildContext context, PollVoter v) async {
    final member = await AdminService.fetchMember(v.memberId);
    if (!context.mounted || member == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: voters
          .map((v) => InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openMember(context, v),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
                  decoration: BoxDecoration(
                    color: AppColors.offWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          image: v.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(v.photoUrl!),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: v.photoUrl == null
                            ? Center(
                                child: Text(
                                  v.name.isNotEmpty
                                      ? v.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Text(
                        v.name.split(' ').first,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

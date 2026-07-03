import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';

class NewsDetailScreen extends StatelessWidget {
  final String title;
  final String body;
  final String? dateLabel;
  final String? posterUrl;
  final DateTime? date;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.body,
    this.dateLabel,
    this.posterUrl,
    this.date,
  });

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: posterUrl != null ? 320 : 140,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.cream,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              centerTitle: false,
              background: posterUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          posterUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: AppColors.primary),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x88000000)],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(color: AppColors.primary),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if ((dateLabel ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentDark.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accentDark.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      dateLabel!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accentDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                else if (date != null)
                  Text(_date(date!), style: theme.textTheme.labelMedium),
                const SizedBox(height: 18),
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 14),
                ElegantCard(
                  child: SelectableText(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

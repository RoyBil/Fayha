import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/choir_data.dart';
import '../theme/app_theme.dart';
import '../widgets/elegant_card.dart';
import '../widgets/section_header.dart';
import 'about_screen.dart';
import 'join_screen.dart';
import 'member_signin_screen.dart';
import 'testimonials_public_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        const SectionHeader(
          eyebrow: 'Learn',
          title: 'About the Choir',
        ),
        const SizedBox(height: 20),
        _ActionCard(
          icon: Icons.menu_book_outlined,
          title: 'Our Story',
          subtitle: 'Choir biography, achievements, leadership, social projects.',
          color: AppColors.primaryDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
        const SizedBox(height: 32),

        const SectionHeader(
          eyebrow: 'Get Involved',
          title: 'Connect with Fayha',
        ),
        const SizedBox(height: 20),
        _ActionCard(
          icon: Icons.person_add_alt_1,
          title: 'Join the Choir',
          subtitle: 'Audition and become part of the ensemble.',
          color: AppColors.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const JoinScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.format_quote,
          title: 'Testimonials',
          subtitle: 'Stories from the choir — and share your own.',
          color: AppColors.accentDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TestimonialsPublicScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.lock_outline,
          title: 'Member Sign In',
          subtitle: 'Choir members: access rehearsals, attendance, and parts.',
          color: AppColors.secondary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MemberSignInScreen()),
          ),
        ),
        const SizedBox(height: 32),

        const SectionHeader(
          eyebrow: 'Reach Out',
          title: 'Contact',
        ),
        const SizedBox(height: 16),
        ElegantCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContactRow(
                icon: Icons.person_outline,
                primary: ChoirData.presidentName,
                secondary: ChoirData.presidentTitle,
              ),
              const SizedBox(height: 14),
              _ContactRow(
                icon: Icons.person_outline,
                primary: ChoirData.managerName,
                secondary: ChoirData.managerTitle,
              ),
              const Divider(height: 28),
              _ContactRow(
                icon: Icons.mail_outline,
                primary: ChoirData.managerEmail,
                secondary: 'Manager',
                onTap: () => _launch('mailto:${ChoirData.managerEmail}'),
                isLink: true,
              ),
              const SizedBox(height: 14),
              ...ChoirData.phones.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ContactRow(
                    icon: Icons.phone_outlined,
                    primary: p,
                    secondary: 'Call',
                    onTap: () => _launch('tel:$p'),
                    isLink: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        const SectionHeader(
          eyebrow: 'Online',
          title: 'Follow Us',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Website',
                icon: Icons.language,
                onTap: () => _launch(ChoirData.websiteUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: '@fayhanationalchoir',
                icon: FontAwesomeIcons.instagram,
                onTap: () => _launch(
                    'https://www.instagram.com/fayhanationalchoir/'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Facebook',
                icon: FontAwesomeIcons.facebook,
                onTap: () => _launch('https://www.facebook.com/FayhaChoir'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            '© ${DateTime.now().year} Fayha National Choir',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _launch(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElegantCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.gray),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String primary;
  final String secondary;
  final VoidCallback? onTap;
  final bool isLink;
  const _ContactRow({
    required this.icon,
    required this.primary,
    required this.secondary,
    this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primary,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isLink ? AppColors.primary : AppColors.dark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(secondary, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      ),
      child: Column(
        children: [
          // FaIcon renders both Material and Font Awesome IconData
          // correctly because it picks the font family from the icon.
          icon.fontFamily == 'MaterialIcons'
              ? Icon(icon, size: 20)
              : FaIcon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

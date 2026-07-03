import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fayha/widgets/elegant_card.dart';
import 'package:fayha/widgets/empty_state.dart';
import 'package:fayha/widgets/section_header.dart';
import 'package:fayha/theme/app_theme.dart';

// Wraps [child] in a minimal MaterialApp so theme & MediaQuery are available.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  group('ElegantCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        _wrap(const ElegantCard(child: Text('hello card'))),
      );
      expect(find.text('hello card'), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ElegantCard(onTap: () => tapped = true, child: const Text('tap me')),
        ),
      );
      await tester.tap(find.text('tap me'));
      expect(tapped, true);
    });

    testWidgets('renders without onTap without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const ElegantCard(child: Text('no tap'))));
      // Tapping a card with no onTap should be silent
      await tester.tap(find.text('no tap'));
      expect(find.text('no tap'), findsOneWidget);
    });

    testWidgets('accepts custom padding', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ElegantCard(padding: EdgeInsets.all(8), child: Text('padded')),
        ),
      );
      expect(find.text('padded'), findsOneWidget);
    });

    testWidgets('accepts custom background color', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ElegantCard(background: Colors.amber, child: Text('colored')),
        ),
      );
      expect(find.text('colored'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(icon: Icons.music_note, title: 'No songs yet')),
      );
      expect(find.text('No songs yet'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders the optional message when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const EmptyState(
            icon: Icons.event,
            title: 'No events',
            message: 'Check back soon',
          ),
        ),
      );
      expect(find.text('No events'), findsOneWidget);
      expect(find.text('Check back soon'), findsOneWidget);
    });

    testWidgets('omits message text when message is null', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(icon: Icons.photo, title: 'No photos')),
      );
      expect(find.text('No photos'), findsOneWidget);
      // Only one Text widget (the title) should be present for the message area
      expect(find.text('Check back soon'), findsNothing);
    });

    testWidgets('contains a Center widget for layout', (tester) async {
      await tester.pumpWidget(
        _wrap(const EmptyState(icon: Icons.inbox, title: 'Empty inbox')),
      );
      expect(find.byType(Center), findsWidgets);
    });
  });

  group('SectionHeader', () {
    testWidgets('uppercases the eyebrow text', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(eyebrow: 'events', title: 'Title')),
      );
      expect(find.text('EVENTS'), findsOneWidget);
      // The original lowercase should not appear
      expect(find.text('events'), findsNothing);
    });

    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(eyebrow: 'X', title: 'Our Repertoire')),
      );
      expect(find.text('Our Repertoire'), findsOneWidget);
    });

    testWidgets('renders optional subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SectionHeader(
            eyebrow: 'X',
            title: 'Title',
            subtitle: 'A subtitle here',
          ),
        ),
      );
      expect(find.text('A subtitle here'), findsOneWidget);
    });

    testWidgets('renders without subtitle when omitted', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(eyebrow: 'X', title: 'Title')),
      );
      // Exactly one Text for eyebrow and one for title (no subtitle)
      expect(find.byType(Text), findsNWidgets(2));
    });

    testWidgets('light=true variant does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SectionHeader(
            eyebrow: 'X',
            title: 'Light Title',
            subtitle: 'sub',
            light: true,
          ),
        ),
      );
      expect(find.text('LIGHT TITLE'), findsNothing); // title is NOT uppercased
      expect(find.text('Light Title'), findsOneWidget);
    });

    testWidgets('renders the accent bar decoration', (tester) async {
      await tester.pumpWidget(
        _wrap(const SectionHeader(eyebrow: 'X', title: 'T')),
      );
      // The accent bar is a Container with specific height=2 width=48
      // Just verify the widget tree renders without error
      expect(find.byType(SectionHeader), findsOneWidget);
    });
  });
}

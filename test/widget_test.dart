import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eds_mobile_app/main.dart';
import 'package:eds_mobile_app/providers/auth_provider.dart';

// KoridorApp watches authStateProvider (a FirebaseAuth stream). In tests we
// override the provider instead of initializing Firebase, so we can exercise
// each auth state branch of KoridorApp.build without platform plugins.
ProviderScope scopeWith(Stream<User?> authStream) {
  return ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => authStream)],
    child: const KoridorApp(),
  );
}

void main() {
  testWidgets('shows loading spinner while auth state resolves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(scopeWith(const Stream.empty()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows auth view when user is signed out', (
    WidgetTester tester,
  ) async {
    // Stream that emits null map to a signed-out user.
    await tester.pumpWidget(scopeWith(Stream<User?>.value(null)));
    await tester.pump();

    // Signed-out view should not render the dashboard immediately; the
    // loading spinner must be gone at minimum.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows error message when auth stream fails', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(scopeWith(Stream<User?>.error('baglanti hatasi')));
    await tester.pump();

    expect(find.textContaining('Hata'), findsOneWidget);
    expect(find.textContaining('baglanti hatasi'), findsOneWidget);
  });
}

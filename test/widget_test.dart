import 'package:chatty/services/wallpaper_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChatWallpaper enum has all expected presets', () {
    expect(ChatWallpaper.values.length, 4);
    expect(ChatWallpaper.obsidian.id, 'obsidian');
    expect(ChatWallpaper.titanium.id, 'titanium');
    expect(ChatWallpaper.midnight.id, 'midnight');
    expect(ChatWallpaper.pearl.id, 'pearl');

    for (final w in ChatWallpaper.values) {
      expect(w.title.isNotEmpty, true);
      expect(w.subtitle.isNotEmpty, true);
      expect(w.gradientColors(true).length, greaterThanOrEqualTo(2));
      expect(w.gradientColors(false).length, greaterThanOrEqualTo(2));
    }
  });

  test('WallpaperController updates notifier correctly', () async {
    WallpaperController.wallpaperNotifier.value = ChatWallpaper.obsidian;
    expect(WallpaperController.wallpaperNotifier.value, ChatWallpaper.obsidian);

    await WallpaperController.setWallpaper(ChatWallpaper.titanium);
    expect(WallpaperController.wallpaperNotifier.value, ChatWallpaper.titanium);

    await WallpaperController.setWallpaper(ChatWallpaper.midnight);
    expect(WallpaperController.wallpaperNotifier.value, ChatWallpaper.midnight);
  });

  testWidgets('Message options sheet dismisses when tapping blank space in any direction', (tester) async {
    bool dismissed = false;
    String tappedItem = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showGeneralDialog(
                  context: context,
                  barrierDismissible: true,
                  barrierLabel: 'Dismiss',
                  barrierColor: Colors.transparent,
                  pageBuilder: (dialogContext, anim, secAnim) => const SizedBox.shrink(),
                  transitionBuilder: (dialogContext, anim, secAnim, child) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        dismissed = true;
                        Navigator.pop(dialogContext);
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(color: Colors.black54),
                          ),
                          Positioned(
                            top: 200,
                            right: 16,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 400, maxWidth: 300),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Material(
                                      child: InkWell(
                                        onTap: () {
                                          tappedItem = 'reaction';
                                          Navigator.pop(dialogContext);
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('❤️'),
                                        ),
                                      ),
                                    ),
                                    IgnorePointer(
                                      child: Container(height: 60, width: 200, color: Colors.blue),
                                    ),
                                    Material(
                                      child: InkWell(
                                        onTap: () {
                                          tappedItem = 'reply';
                                          Navigator.pop(dialogContext);
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Reply'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    Future<void> openDialog() async {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      dismissed = false;
      tappedItem = '';
    }

    // 1. Tap above in blank space
    await openDialog();
    await tester.tapAt(const Offset(100, 50));
    await tester.pumpAndSettle();
    expect(dismissed, true);

    // 2. Tap below in blank space
    await openDialog();
    await tester.tapAt(const Offset(100, 550));
    await tester.pumpAndSettle();
    expect(dismissed, true);

    // 3. Tap to the left in blank space
    await openDialog();
    await tester.tapAt(const Offset(50, 250));
    await tester.pumpAndSettle();
    expect(dismissed, true);

    // 4. Tap on message bubble preview
    await openDialog();
    await tester.tapAt(const Offset(700, 250));
    await tester.pumpAndSettle();
    expect(dismissed, true);

    // 5. Tap on reaction emoji (must trigger action, not outer dismiss)
    await openDialog();
    await tester.tap(find.text('❤️'));
    await tester.pumpAndSettle();
    expect(tappedItem, 'reaction');
    expect(dismissed, false);

    // 6. Tap on menu item (must trigger action, not outer dismiss)
    await openDialog();
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(tappedItem, 'reply');
    expect(dismissed, false);
  });
}

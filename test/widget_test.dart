import 'package:chatty/services/wallpaper_controller.dart';
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
}

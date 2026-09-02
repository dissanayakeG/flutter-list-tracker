# List Tracker

A new Flutter project.

DashboardPage
  watches categoriesProvider / listSummariesProvider
    ↓
categoriesProvider / listSummariesProvider
  watch listTrackerRepositoryProvider
    ↓
listTrackerRepositoryProvider
  watches appDatabaseProvider
    ↓
appDatabaseProvider
  creates AppDatabase()

AppDatabase is initialized in repository_providers.dart,
inside appDatabaseProvider,
when the UI first watches/reads a provider that depends on it.

It is lazy, which means Flutter does not create the database at app startup unless some screen actually asks for data.


# Add Icons

1. Current icon setup in `pubspec.yaml`


```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/icons/list_tracker.svg
```

That makes the SVG available inside Flutter, but it does not generate Android launcher icons.

2. Confirm the PNG source icon exists

```text
assets/icons/list_tracker.png
```

That PNG is the source image used by the launcher icon generator.

3. Add/updat the launcher icon dependency

In `pubspec.yaml`, under `dev_dependencies`:

```yaml
flutter_launcher_icons: ^0.14.4
```

This package is a development tool, so it belongs in `dev_dependencies`.

4. Add the launcher icon config

In `pubspec.yaml`, I added:

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icons/list_tracker.png"
  min_sdk_android: 21
```

This tells the package to generate Android launcher icons from PNG.

5. Generated Android launcher icons

I ran:

```bash
dart run flutter_launcher_icons
```

That generated/updated these Android files:

```text
android/app/src/main/res/mipmap-mdpi/ic_launcher.png
android/app/src/main/res/mipmap-hdpi/ic_launcher.png
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
```

6. Update the startup splash background

Edit both Android launch background files:

```text
android/app/src/main/res/drawable/launch_background.xml
android/app/src/main/res/drawable-v21/launch_background.xml
```

Change them to show the generated launcher icon:

```xml
<item>
    <bitmap
        android:gravity="center"
        android:src="@mipmap/ic_launcher" />
</item>
```

So now the same app icon appears while the installed app starts.

7. Verify everything

Run:

```bash
dart format lib test
flutter analyze
flutter test
./gradlew :app:assembleDebug --console=plain
```

The Gradle command needed Java, so has to use Android Studio’s bundled JBR:

```bash
JAVA_HOME=/home/madz/Android/android-studio/jbr ./gradlew :app:assembleDebug --console=plain
```
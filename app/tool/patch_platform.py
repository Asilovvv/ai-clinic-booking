"""One-time tweaks to the generated android/ios/web projects.

Run from the app/ folder after `flutter create .`:
    python3 tool/patch_platform.py
Adds microphone + internet permissions, allows http:// to the local server
and sets the visible app name.
"""
from pathlib import Path

APP_NAME = "Smile AI"


def patch(path: str, edit) -> None:
    file = Path(path)
    if not file.exists():
        print(f"skip {path} (not found)")
        return
    before = file.read_text(encoding="utf-8")
    after = edit(before)
    if after != before:
        file.write_text(after, encoding="utf-8")
        print(f"patched {path}")


def android_manifest(text: str) -> str:
    if "RECORD_AUDIO" not in text:
        text = text.replace(
            "<application",
            '<uses-permission android:name="android.permission.INTERNET"/>\n'
            '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
            "    <application",
            1,
        )
    if "usesCleartextTraffic" not in text:
        text = text.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    text = text.replace('android:label="ai_clinic"', f'android:label="{APP_NAME}"')
    if "android.speech.RecognitionService" not in text:
        text = text.replace(
            "<queries>",
            "<queries>\n        <intent>\n"
            '            <action android:name="android.speech.RecognitionService"/>\n'
            "        </intent>",
            1,
        )
    return text


def ios_plist(text: str) -> str:
    text = text.replace("<string>Ai Clinic</string>", f"<string>{APP_NAME}</string>")
    if "NSMicrophoneUsageDescription" not in text:
        extra = (
            "\t<key>NSMicrophoneUsageDescription</key>\n"
            "\t<string>The microphone is used to dictate booking requests.</string>\n"
            "\t<key>NSSpeechRecognitionUsageDescription</key>\n"
            "\t<string>Speech recognition turns your voice into a booking request.</string>\n"
            "\t<key>NSAppTransportSecurity</key>\n"
            "\t<dict>\n\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n\t</dict>\n"
        )
        head, sep, tail = text.rpartition("</dict>")
        text = head + extra + sep + tail
    return text


def web_name(text: str) -> str:
    return text.replace("ai_clinic", APP_NAME).replace("A new Flutter project.", "AI administrator: book with one sentence.")


patch("android/app/src/main/AndroidManifest.xml", android_manifest)
patch("ios/Runner/Info.plist", ios_plist)
patch("web/manifest.json", web_name)
patch("web/index.html", web_name)

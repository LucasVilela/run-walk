# Running Run-Walk on your iPhone

Native Swift needs no Expo Go or dev-client: Xcode builds the app straight onto your phone.

## One-time setup

1. **Xcode account.** Xcode → Settings → Accounts → sign in with your Apple ID. The project already
   uses your team (`26TW9454CR`, same as Receipt Calc).
2. **Developer Mode on the phone.** iPhone → Settings → Privacy & Security → Developer Mode → On.
   The phone restarts; confirm "Turn On" after it boots.
3. **Connect once by cable.** Plug the iPhone into the Mac, unlock it, tap **Trust**.
4. *(Optional)* **Wireless.** Xcode → Window → Devices and Simulators → select the phone →
   tick **Connect via network**. After this, no cable needed.

## Build and run

```bash
cd ~/Developer/run-walk && xcodegen generate && open RunWalk.xcodeproj
```

In Xcode: scheme **RunWalk**, pick your iPhone in the device menu at the top, press **⌘R**.

If the phone says "Untrusted Developer": Settings → General → VPN & Device Management → your
Apple ID → Trust.

Debug builds show the ×1 / ×10 / ×60 speed button on the Run screen and a "Try any workout (dev)"
menu in Settings. Neither exists in Release builds.

## Things to check

1. **Notifications.** Allow them during onboarding (or Settings → Notifications → Run-Walk). They carry
   your reminders and the locked-screen beeps.
2. **Unlocked, with music.** Play music in another app, start a run, set ×60. Every switch is spoken over
   lowered music, with beeps and a vibration.
3. **Locked.** Start a run and lock the phone: each switch arrives as a notification with a beep. Unlock
   and the voice carries on from where the run is.
4. **Distance.** There's no GPS. If you know your distance (treadmill display, a known route), type it
   on the run summary and the pace is worked out for you.
5. **Lock screen.** During a run a Live Activity shows the time left and a filling bar on the lock
   screen and Dynamic Island. To add the widget: long-press the lock screen → Customise → Lock Screen →
   tap the widget row → Run-Walk. During a run it shows the current segment and its countdown;
   otherwise your next run.
6. **Day by day.** Plan → Day by day shows every day: what you ran, rest days, and what's planned.

## Troubleshooting

- **No beeps when locked:** check notifications are allowed for Run-Walk, and that a Focus mode isn't silencing them.
- **App gone after 7 days:** that only happens with a free Apple ID. Rebuild with ⌘R.

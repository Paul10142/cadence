<p align="center">
  <img src="docs/icon.png" width="128" alt="Cadence icon">
</p>

<h1 align="center">Cadence</h1>

<p align="center">
  A tiny stopwatch, countdown and pomodoro timer that lives in your Mac's menu bar.<br>
  No dock icon, no window, no account. Click the stopwatch, it starts counting.
</p>

<p align="center">
  <a href="https://github.com/Paul10142/cadence/releases/latest"><b>⬇ Download the latest release</b></a>
</p>

---

## Why this exists

[Thyme](https://github.com/joaomoreno/thyme) by João Moreno is a lovely little
menu bar stopwatch that I used for years. It was last updated in 2015 and no
longer runs on Apple Silicon Macs.

This is a fresh reimplementation in Swift: the same idea, running natively on
modern macOS, with a countdown timer and pomodoro cycling added. It is not a
fork — no original source was copied — but it owes the whole concept to Thyme.

## What it does

**Stopwatch.** Click the menu bar icon to start counting up. Click again to
pause and open the menu. Finish saves the elapsed time to your session history
and resets the clock.

**Countdown.** Set hours, minutes and seconds, and choose what happens at zero:
blink in the menu bar, an alert window, a Mac notification, or a spoken
announcement of a phrase you write.

**Pomodoro.** Set a work length, a break length and a number of rounds, and it
alternates automatically until the rounds are done. While it runs, the menu bar
shows a rule **under** the time during work and **over** it during a break, so
you can tell which phase you're in at a glance. Work blocks are recorded in your
history; breaks are not.

**Session history.** The last sessions are listed in the menu with a stopwatch
or hourglass marker showing which timer produced each one, a running total, and
a CSV export for spreadsheets.

**Everything is configurable.** System-wide keyboard shortcuts for every action,
your choice of what a click on the icon does, and automatic pausing while your
Mac sleeps or the screen is locked.

## Install

1. Download `Cadence.dmg` from the
   [latest release](https://github.com/Paul10142/cadence/releases/latest).
2. Open it and drag **Cadence** into your Applications folder.
3. Open it. A stopwatch appears in your menu bar — there is no dock icon and no
   window, which is the point.

### macOS will say the app is damaged. It isn't.

Apple charges developers $99 a year for a certificate that tells macOS an app is
trustworthy. This is a free app, there's no certificate behind it, and so macOS
shows a scary and inaccurate message: *"Cadence is damaged and can't be
opened"*.

**There is no way around this without paying Apple.** Either you tell your Mac to
open it anyway, or you [build it yourself](#building-it-yourself) from this
source — an app you compiled on your own machine carries no warning at all.

You should be sceptical of any download asking you to bypass a security warning.
So don't take my word for it: every line of this app is in this repository, and
you or anyone you trust can read exactly what it does before running it.

To open it anyway, paste this into Terminal once:

```bash
xattr -dr com.apple.quarantine "/Applications/Cadence.app"
```

That removes the "downloaded from the internet" flag macOS attaches to the file.
Then open the app normally. You only need to do this once.

If you'd rather not use Terminal: go to **System Settings → Privacy & Security**,
scroll down, and click **Open Anyway** next to the message about Cadence.

> Only do this for software you actually trust — including this one.

## Using it

| Action | How |
| --- | --- |
| Start / pause the stopwatch | Click the menu bar icon |
| Open the menu | Right-click (or Control-click) the icon |
| Start a countdown | Right-click → **Start General Timer** |
| Start a pomodoro | Right-click → **Start Pomodoro Timer** |
| See your history | Right-click → **Show All Sessions** |
| Change shortcuts and behaviour | Right-click → **Preferences** |

In Preferences you can choose what a plain click does — open the menu, run the
stopwatch, run the countdown, or run the pomodoro — and set system-wide keyboard
shortcuts for each. Shortcuts work from any app. If another app has already
claimed the combination you pick, Cadence tells you rather than silently
doing nothing.

Your sessions live in `~/Library/Application Support/Cadence/sessions.json`.

## Menu bar managers (Ice, Bartender)

If you use a menu bar manager, new icons are usually dropped into its hidden
section, where you'll never find them. Cadence claims a visible position on
first launch to avoid this. If it still hides, drag it into the visible section
in your manager's settings, or ⌘-drag it along the menu bar.

## Building it yourself

You need the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is
not required.

```bash
git clone https://github.com/Paul10142/cadence.git
cd cadence
./Tools/bundle.sh
```

This compiles the Swift sources, assembles `build/Cadence.app`, signs it
ad-hoc, and produces a DMG. Requires macOS 13 or later, Apple Silicon.

## Credits

- [Thyme](https://github.com/joaomoreno/thyme) by
  [João Moreno](https://github.com/joaomoreno) — the original, and the reason
  this exists.
- Countdown and alert options modelled on
  [Menu Bar Countdown](https://github.com/kristopherjohnson/MenuBarCountdown).

MIT licensed. See [LICENSE](LICENSE).

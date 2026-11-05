# Samaa سماع

Learn to play the oud by ear. Samaa plays a note, you play it back on your oud, and it listens
through the microphone: it tells you which note you played and guides you higher or lower until
you find it. Lessons start with single notes and continue as separate routes through the Arabic
maqamat (Rast, Bayati, Hijaz, Nahawand, Kurd, Saba, Sikah), quarter tones included, up to the upper jins,
modulation to sister maqamat, and phrases over the iqa'at (Maqsum, Baladi, Saidi, Malfuf).

## Features

- Pitch detection built for a real oud on a cheap mic: a gate that follows the room, a 42 ms analysis window
  for the low courses, and target-aware matching with a fretless tolerance. It is quick to accept the right
  note, slow to call a note wrong, and it learns how far your oud sits from concert pitch
- Five levels, each a path of 10 mini-levels (play-back lessons, listening rounds and a review), a reward
  chest halfway and a guidebook. 80% first-try to pass a mini-level, 90% on a 15-exercise mastery test to
  finish a level, or jump ahead by passing the test of the level before
- Phrases follow the sayr of each maqam, as heard in taqasim
- Quarter-tone aware matching and note names (Rast, Dukah, Sikah, Jaharkah, Nawa…)
- Levels, daily quests, XP, streaks with streak freezes, pearls and a shop
- Accounts with cloud-saved progress, a weekly league, and guest mode
- Mic check that calibrates to your room, tuner for F-to-F and C-to-C tuning
- Keyboard shortcuts on laptops, installable on phones, works offline

## Switch on accounts and the world leaderboard (about 5 minutes)

The site and app run in guest mode until they are connected to a free Supabase project.

1. Create a project at [supabase.com](https://supabase.com) (free plan).
2. In the project, open **SQL Editor → New query**, paste the contents of [`supabase.sql`](supabase.sql) and press **Run**.
3. Open **Authentication → URL Configuration** and set **Site URL** to `https://osalhaddad1.github.io/samaa/`.
   Add the same address under **Redirect URLs**.
4. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key into [`config.js`](config.js).
5. Commit and push. The site updates, and GitHub builds a new APK.

Before launch, set up custom SMTP under **Authentication → Emails**: Supabase's built-in email sender is limited to a
few messages an hour. To hide a cheater, set `banned` to true on their row in **Table Editor → profiles**.

XP on the leaderboard is written only by the database function `award_xp`, which limits each lesson, hour and day.
A modified app could still claim XP up to those limits, because the listening happens on the player's device.

## Android app

The `native/` folder is a [Capacitor](https://capacitorjs.com) project that packs the site into an Android app.
Every push to `main` that changes the app builds an APK on GitHub Actions and publishes it under
[Releases](https://github.com/osAlhaddad1/samaa/releases/latest).

Without a signing key the APK is signed with a throwaway debug key, so each new build must replace the old one
by uninstalling it, which clears guest progress. For updates that install over the old app, create a keystore
and add it as the repository secrets `SAMAA_KEYSTORE_B64` (base64 of the file) and `SAMAA_KEY_PASSWORD`,
with the key alias `samaa`.

## Run it locally

```bash
python -m http.server 8137
```

Then open <http://localhost:8137>. The microphone needs `localhost` or `https`.

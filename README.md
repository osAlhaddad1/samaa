# Samaa سماع

Learn to play the oud by ear. Samaa plays a note, you play it back on your oud, and it listens
through the microphone: it tells you which note you played and guides you higher or lower until
you find it. Lessons start with single notes and continue as separate routes through the Arabic
maqamat (Rast, Bayati, Hijaz, Nahawand, Kurd, Saba, Sikah), quarter tones included.

## Features

- Pitch detection tuned for the oud: audio-thread capture, band-pass filtering, pluck and decay checks,
  octave guard and hysteresis. A pluck registers in about 140 ms; speech and room noise are ignored
- 30 exercises per level, an 80% first-try pass mark per lesson, and a 90% mastery test to finish each level
- Phrases follow the sayr of each maqam, as heard in taqasim
- Quarter-tone aware matching and note names (Rast, Dukah, Sikah, Jaharkah, Nawa…)
- Levels, daily quests, XP, streaks with streak freezes, pearls and a shop
- Accounts with cloud-saved progress, a weekly league, and guest mode
- Mic check that calibrates to your room, tuner for F-to-F and C-to-C tuning
- Keyboard shortcuts on laptops, installable on phones, works offline

## Switch on accounts (about 5 minutes)

The site runs in guest mode until it is connected to a free Supabase project.

1. Create a project at [supabase.com](https://supabase.com) (free plan).
2. In the project, open **SQL Editor → New query**, paste the contents of [`supabase.sql`](supabase.sql) and press **Run**.
3. Open **Authentication → URL Configuration** and set **Site URL** to the address of your live site
   (for example `https://<your-username>.github.io/samaa/`). Add the same address under **Redirect URLs**.
4. Open **Project Settings → API**. Copy the **Project URL** and the **anon public** key into [`config.js`](config.js).
5. Commit and push. Sign-up, log-in, password reset and the league are now live.

By default Supabase asks new players to confirm their email. You can turn that off under
**Authentication → Providers → Email** if you want people to start right away.

## Run it locally

```bash
python -m http.server 8137
```

Then open <http://localhost:8137>. The microphone needs `localhost` or `https`.

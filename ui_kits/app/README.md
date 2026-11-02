# Mat Mind — mobile app prototype

Interactive first draft of the Mat Mind MVP at 390×844, composed from the design-system bundle (`window.MatMindDesignSystem_8b0f80`).

- `flows.html` — IA sitemap, journeys A–C, MVP guardrails (nodes deep-link into the prototype)
- `index.html` — phone + review panel (journeys, 8 screens, key states). Deep links: `#activity|training|create|complete|friends|qr|scan|profile|notifications|post|empty|invite|active|broken`
- `App.jsx` — state, actions, router, review panel
- `Shell.jsx` — Phone, Screen, Header, Eyebrow, TapeLabel, PairAvatars, PhotoTile
- `Activity.jsx` — Feed, PostCard (double-tap like), PostDetail
- `Training.jsx` — Upcoming, tickets, invites, empty state, SessionDetail
- `Create.jsx` — Plan / log a past session
- `Complete.jsx` — Complete & share → celebration with streak tick-ups
- `Friends.jsx` — Streaks, friend profile, QR + scan + instant connect
- `Me.jsx` — Profile, account sheet, notifications
- `data.js` — sample data (photos: Unsplash, in assets/photos)

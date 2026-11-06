# Participant session photos

Confirmed attendees can contribute one photo to a session once its start time
has passed, including when the host has not completed or published the session.
This implements the participant-photo design reviewed in PR #102 using the
current native `SessionTicket`, metadata card, `MMPhotoTile`, `MMButton`,
`MMScreen` and empty-photo reminder. It adds no captions or reactions to photos.

## Behavior

- Guest session details retain Completed and I didn't attend, with Add photo
  until that guest has a photo. Photos sit after the existing focus outline.
- The separate composer uses the single-image Photos picker. Its JPEG draft
  stays on the device until Post photo; closing discards the draft. Failed
  uploads keep the draft for retry and leave the previous photo intact.
- Each photo card shows its author's name, including while the image downloads.
  Only the current person's card has Replace photo and Remove photo. A stale
  replacement/removal fails rather than overwriting another device's changes.
- Removing a photo keeps training attendance and credits. Correcting attendance,
  declining, or removing a guest detaches that person's session-photo slot.
- The host's existing completion and Activity publishing flow is preserved.
  Replacing/removing a session photo does not rewrite a published Activity image.

## Data and access

Migration `20261106081940_participant_session_photos.sql` adds `session_photo`
to `media_assets`, with a partial unique index on session + owner. Existing ready
photos are retained; the newest per person becomes their current session slot.
Older media referenced by Activity posts remain available to that post's audience.

New commands prepare, post and remove participant photos through the existing
authenticated, rate-limited, idempotent dispatcher. The private handler locks the
session and requires a going RSVP, confirmed attendance, elapsed training,
an active session and no block with its host. Finalization checks the uploaded
object, owner, session and expected previous media ID. The unique index also
enforces the limit independently of the UI.

The current slot uses the existing private `session-photos` bucket. Both media
RLS and object RLS require accepted session access, with blocks respected for
the host and the photo's author. Pending invitations, declined participants,
followers and unrelated people cannot read the new photos. Owners retain access
to their private uploads. Replacement/removal detaches the previous image from
the session; its private media row/object remains for retries, existing Activity
references and account cleanup. This change does not delete storage objects
directly in SQL or make the bucket public.

## Rollout

The PR includes a migration and does not deploy to the hosted project.
Deploy the migration before enabling the new client. The snapshot advertises
`participant_photos_available`; new clients hide participant writes when it is
missing, so app and database releases may be ordered safely. Older caches still
decode and retain the organizer-only fallback. Older clients can continue using
the existing host save/publish commands.

## Regression checks

`sh scripts/test-database.sh` runs all migrations and database suites against the
disposable local PostgreSQL container. `participant_photos.sql` covers:

- Separate host/guest slots, replayed receipts, preparation without publication,
  stale replacement/removal, forged ownership and cross-session media.
- Private metadata/object reads for accepted attendees versus invitations,
  declines, blocks, followers and unrelated users; independent storage access
  with media RLS disabled; no direct helper/anonymous execution.
- Future and unconfirmed attendance rejection, photo-only removal preserving
  attendance, attendance correction clearing a slot, and host Activity images
  surviving session-photo removal.

Native regression tests cover per-person replacement/removal, failed writes,
eligibility and capability gating, author/loading metadata, detachment after
refresh and keeping guest images out of the host's composer selection.

For device review, use two signed-in accounts. Join and confirm attendance on a
past session, add a photo as the guest, refresh the host and verify its author.
Cancel a replacement, then post one; remove it and verify attendance remains.
Confirm a pending invitation cannot upload/read it. Also review the prototype's
Participant photos preset at narrow widths and with larger text. The native
app/prototype builds and XCTest suite run in the existing macOS CI workflow.

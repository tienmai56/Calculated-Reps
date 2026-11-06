'use strict';

// Deliberately isolated from AppModel, authentication, storage and the backend.
// These sample state transitions exist only to review the proposed interaction.
const params = new URLSearchParams(location.search);
const embedded = params.has('embed');
const overview = !embedded && params.get('layout') !== 'single' && !params.has('state');
const $ = selector => document.querySelector(selector);
const icon = name => `<span class="icon" style="--icon: url('../../assets/icons/${name}.svg')" aria-hidden="true"></span>`;
const photos = ['group-class', 'roll-gi', 'coach-help'];
const photoURL = photo => `../../assets/photos/${photo}.jpg`;
const photoAlt = photo => ({
  'group-class': 'Training partners together on the mat',
  'roll-gi': 'Partners practicing a jiu-jitsu pass',
  'coach-help': 'A coach working with training partners'
})[photo];
const knownStates = ['before', 'preview', 'posted', 'empty', 'focus', 'upcoming', 'absent'];
let state;
let returnFocus;
let toastTimer;

document.body.classList.toggle('embedded', embedded);
$('#overview').hidden = !overview;
$('#interactive').hidden = overview;
$('.state-control').hidden = overview || embedded;
if (overview) {
  document.querySelectorAll('#overview iframe').forEach(frame => {
    frame.src = `?embed=1&state=${frame.dataset.state}${frame.dataset.state === 'posted' ? '&focus=photos' : ''}`;
  });
} else {
  // Hidden iframes still load; remove the overview to prevent recursive embeds.
  $('#overview').remove();
}

function initialize(name) {
  const selected = knownStates.includes(name) ? name : 'before';
  state = {
    view: selected === 'preview' ? 'composer' : 'session',
    upcoming: selected === 'upcoming',
    attended: selected !== 'absent',
    hostPhoto: !['empty', 'upcoming'].includes(selected),
    hasFocus: selected === 'focus',
    ownPhoto: selected === 'posted' ? 'group-class' : null,
    draft: selected === 'preview' ? 'group-class' : null
  };
  $('#review-state').value = selected;
  closeSheet(false);
  $('#toast').hidden = true;
  render();
  if (selected === 'posted' && params.get('focus') === 'photos') focusPhotos();
}

function ticket() {
  return `<section class="ticket" aria-label="Night training, Wednesday November 4 at 8 PM, hosted by Sarah">
    <div class="date-stub"><span class="day">WED</span><strong>4</strong><span class="month">Nov</span></div>
    <div class="ticket-tear" aria-hidden="true"></div>
    <div class="ticket-details">
      <h3>Night training</h3>
      <div class="ticket-meta">${icon('clock')}<span class="time">8:00 PM</span>${icon('map-pin').replace('class="icon"', 'class="icon location-icon"')}<span class="venue">Ralph Gracie Jiu-Jitsu</span></div>
      <div class="ticket-people"><div class="avatar-stack" aria-label="Sarah and Tien"><span class="avatar" aria-hidden="true">SL</span><span class="avatar" aria-hidden="true">TM</span></div><span class="host">by Sarah</span></div>
    </div>
  </section>`;
}

function infoRow(name, text) {
  return `<div class="info-row">${icon(name)}<span>${text}</span></div>`;
}

function photoCard(author, photo, own = false) {
  return `<article class="photo-card" aria-label="Photo from ${author}">
    <div class="author-row"><h4>${author}${own ? ' <span class="you">(you)</span>' : ''}</h4>
      ${own ? `<button class="icon-button" data-action="photo-menu" aria-label="Your photo options">${icon('ellipsis')}</button>` : ''}
    </div>
    <img class="photo-tile" src="${photoURL(photo)}" alt="${photoAlt(photo)}">
  </article>`;
}

function sessionContent() {
  const count = Number(state.hostPhoto) + Number(Boolean(state.ownPhoto));
  return `${ticket()}
    <div class="info-card">
      ${infoRow('map-pin', 'Ralph Gracie Jiu-Jitsu')}
      ${infoRow('clock', 'Wed, Nov 4 · 8:00 PM')}
      ${infoRow('lock', 'Friends only')}
    </div>
    ${state.hasFocus ? `<section class="focus-section" aria-labelledby="focus-heading">
      <h3 id="focus-heading">What we're working on</h3>
      <div class="focus-outline"><div>${icon('notebook-pen')}<strong>Guard passing</strong></div><div class="focus-detail">${icon('chevron-right')}<span>Win the underhook</span></div></div>
    </section>` : ''}
    <section class="photos" id="photos" aria-labelledby="photos-heading">
      <div class="section-heading"><h3 id="photos-heading">Photos</h3><span class="photo-count">${count === 0 ? 'None yet' : count === 1 ? '1 photo' : `${count} photos`}</span></div>
      <div class="photo-list">
        ${state.hostPhoto ? photoCard('Sarah Lee', 'roll-gi') : ''}
        ${state.ownPhoto ? photoCard('Tien Mai', state.ownPhoto, true) : ''}
        ${count === 0 ? `<div class="empty-photos">
          <div class="reminder-art" aria-hidden="true"><img class="reminder-monkey" src="../../assets/brand/logo-mark.svg" alt=""><div class="reminder-photo"><div class="reminder-tile">${icon('camera')}</div></div></div>
          <p>Post-roll photos land here.</p>
        </div>` : ''}
      </div>
    </section>
    <h3 class="people-heading">Who's coming</h3>
    <div class="people-card">
      <div class="person"><span class="avatar" aria-hidden="true">SL</span><div><strong>Sarah Lee</strong><small>Organizer</small></div></div>
      <div class="person"><span class="avatar" aria-hidden="true">TM</span><div><strong>You</strong><small>${state.attended ? 'Ralph Gracie Jiu-Jitsu' : 'Did not attend'}</small></div></div>
    </div>`;
}

function sessionFooter() {
  if (state.upcoming) {
    return `<div class="footer-stack"><p class="footer-copy">You’re going</p><p class="footer-copy">You can add a photo after training.</p></div>`;
  }
  if (!state.attended) {
    return '<div class="footer-stack"><span class="completed">Completed</span><p class="footer-copy">You didn’t attend this session.</p></div>';
  }
  return `<div class="footer-stack">
    <span class="completed">Completed</span>
    ${!state.ownPhoto ? '<p class="footer-copy">One photo per person, per session.</p>' : ''}
    <div class="footer-actions">
      ${!state.ownPhoto ? `<button class="button primary" data-action="choose-photo">${icon('camera')}Add photo</button>` : ''}
      <button class="button secondary" data-action="attendance">I didn’t attend</button>
    </div>
  </div>`;
}

function composerContent() {
  return `<section class="compose-summary">
    <h3>Night training</h3>
    ${infoRow('map-pin', 'Ralph Gracie Jiu-Jitsu')}
    ${infoRow('user', 'Hosted by Sarah Lee')}
    ${infoRow('lock', 'Friends only')}
  </section>
  <div class="preview-photo">
    <img class="photo-tile" src="${photoURL(state.draft)}" alt="${photoAlt(state.draft)}">
    <button class="icon-button" data-action="choose-photo" aria-label="Change photo">${icon('repeat-2')}</button>
  </div>
  <span class="preview-name">Tien Mai (you)</span>
  <p class="compose-hint">One photo per person, per session.${state.ownPhoto ? ' Posting replaces your current photo.' : ''}</p>`;
}

function render() {
  const composer = state.view === 'composer';
  $('#header').innerHTML = `<button class="icon-button" data-action="back" aria-label="${composer ? 'Cancel photo' : 'Back'}">${icon(composer ? 'x' : 'chevron-left')}</button>${composer ? `<h2>${state.ownPhoto ? 'Replace your photo' : 'Add your photo'}</h2>` : ''}`;
  $('#screen-body').innerHTML = composer ? composerContent() : sessionContent();
  $('#footer').innerHTML = composer
    ? `<div class="footer-stack"><p class="footer-copy">Shared with the same people as this session.</p><button class="button primary full large" data-action="post-photo">${icon('check')}${state.ownPhoto ? 'Replace photo' : 'Post photo'}</button></div>`
    : sessionFooter();
  $('#screen-body').scrollTop = 0;
}

function focusPhotos() {
  $('#screen-body').scrollTop = $('#photos').offsetTop - $('#screen-body').offsetTop;
}

function openSheet(title, content) {
  if ($('#sheet-overlay').hidden) returnFocus = document.activeElement;
  $('#sheet-title').textContent = title;
  $('#sheet-content').innerHTML = content;
  $('[data-action="close-sheet"]').innerHTML = icon('x');
  $('#sheet-overlay').hidden = false;
  $('#header').inert = true;
  $('#screen-body').inert = true;
  $('#footer').inert = true;
  $('.sheet').focus();
}

function closeSheet(restoreFocus = true) {
  $('#sheet-overlay').hidden = true;
  $('#header').inert = false;
  $('#screen-body').inert = false;
  $('#footer').inert = false;
  if (restoreFocus && returnFocus?.isConnected) returnFocus.focus();
}

function choosePhoto() {
  openSheet('Recent photos', `<div class="photo-choices">${photos.map((photo, index) => `
    <button class="sample-choice" data-action="pick-photo" data-photo="${photo}" aria-label="Choose sample photo ${index + 1}">
      <img src="${photoURL(photo)}" alt="${photoAlt(photo)}">
    </button>`).join('')}</div><p class="sample-hint">Sample photos for this mockup. Pick one to preview.</p>`);
}

function toast(message) {
  clearTimeout(toastTimer);
  $('#toast').textContent = message;
  $('#toast').hidden = false;
  toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 2600);
}

document.addEventListener('click', event => {
  if (event.target === $('#sheet-overlay')) { closeSheet(); return; }
  const button = event.target.closest('[data-action]');
  if (!button) return;
  switch (button.dataset.action) {
    case 'back':
      if (state.view === 'composer') {
        state.draft = null;
        state.view = 'session';
        render();
      } else {
        // Navigation beyond this session is outside this design review.
        toast('Session detail mockup');
      }
      break;
    case 'choose-photo': choosePhoto(); break;
    case 'close-sheet': closeSheet(); break;
    case 'pick-photo':
      if (!photos.includes(button.dataset.photo) || !state.attended || state.upcoming) break;
      state.draft = button.dataset.photo;
      state.view = 'composer';
      closeSheet(false);
      render();
      $('#header button').focus({ preventScroll: true });
      break;
    case 'post-photo':
      if (!state.draft || !state.attended || state.upcoming) break;
      state.ownPhoto = state.draft;
      state.draft = null;
      state.view = 'session';
      render();
      focusPhotos();
      $('[data-action="photo-menu"]').focus({ preventScroll: true });
      toast('Your photo is in the session');
      break;
    case 'photo-menu':
      openSheet('Your photo', `<button class="menu-action" data-action="choose-photo">${icon('repeat-2')}Replace photo</button><button class="menu-action danger" data-action="remove-photo">${icon('trash-2')}Remove photo</button>`);
      break;
    case 'remove-photo':
      openSheet('Remove your photo?', '<p>Your training attendance stays recorded.</p><div class="sheet-actions"><button class="button secondary full" data-action="close-sheet">Keep photo</button><button class="button danger full" data-action="confirm-remove">Remove photo</button></div>');
      break;
    case 'confirm-remove':
      state.ownPhoto = null;
      closeSheet(false);
      render();
      $('[data-action="choose-photo"]').focus({ preventScroll: true });
      toast('Your photo was removed');
      break;
    case 'attendance':
      openSheet('Didn’t train this time?', '<p>This removes your attendance and your photo from this session.</p><div class="sheet-actions"><button class="button secondary full" data-action="close-sheet">Keep my attendance</button><button class="button danger full" data-action="confirm-absence">I didn’t attend</button></div>');
      break;
    case 'confirm-absence':
      state.attended = false;
      state.ownPhoto = null;
      closeSheet(false);
      render();
      $('#screen-body').focus({ preventScroll: true });
      toast('Attendance updated in this mockup');
      break;
  }
});

// Keep keyboard navigation inside the visible sheet, including nested menus.
document.addEventListener('keydown', event => {
  if ($('#sheet-overlay').hidden) return;
  if (event.key === 'Escape') { event.preventDefault(); closeSheet(); }
  if (event.key !== 'Tab') return;
  const buttons = [...$('.sheet').querySelectorAll('button')];
  const first = buttons[0];
  const last = buttons.at(-1);
  if (event.shiftKey && [first, $('.sheet')].includes(document.activeElement)) {
    event.preventDefault(); last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault(); first.focus();
  }
});

$('#review-state').addEventListener('change', event => initialize(event.target.value));
if (!overview) initialize(params.get('state'));

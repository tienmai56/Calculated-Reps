/* @ds-bundle: {"format":4,"namespace":"GripGorillasDesignSystem_8b0f80","components":[{"name":"Button","sourcePath":"design-system/components/core/Button.jsx"},{"name":"ICON_NAMES","sourcePath":"design-system/components/core/Icon.jsx"},{"name":"Icon","sourcePath":"design-system/components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"design-system/components/core/IconButton.jsx"},{"name":"Logo","sourcePath":"design-system/components/core/Logo.jsx"},{"name":"Avatar","sourcePath":"design-system/components/display/Avatar.jsx"},{"name":"AvatarStack","sourcePath":"design-system/components/display/AvatarStack.jsx"},{"name":"Badge","sourcePath":"design-system/components/display/Badge.jsx"},{"name":"BELT_COLORS","sourcePath":"design-system/components/display/Belt.jsx"},{"name":"Belt","sourcePath":"design-system/components/display/Belt.jsx"},{"name":"Card","sourcePath":"design-system/components/display/Card.jsx"},{"name":"StreakBelt","sourcePath":"design-system/components/display/StreakBelt.jsx"},{"name":"Tag","sourcePath":"design-system/components/display/Tag.jsx"},{"name":"Dialog","sourcePath":"design-system/components/feedback/Dialog.jsx"},{"name":"Toast","sourcePath":"design-system/components/feedback/Toast.jsx"},{"name":"Tooltip","sourcePath":"design-system/components/feedback/Tooltip.jsx"},{"name":"Checkbox","sourcePath":"design-system/components/forms/Checkbox.jsx"},{"name":"Input","sourcePath":"design-system/components/forms/Input.jsx"},{"name":"Radio","sourcePath":"design-system/components/forms/Radio.jsx"},{"name":"Select","sourcePath":"design-system/components/forms/Select.jsx"},{"name":"Switch","sourcePath":"design-system/components/forms/Switch.jsx"},{"name":"TabBar","sourcePath":"design-system/components/navigation/TabBar.jsx"},{"name":"Tabs","sourcePath":"design-system/components/navigation/Tabs.jsx"}],"sourceHashes":{"design-system/components/core/Button.jsx":"85da24435512","design-system/components/core/Icon.jsx":"4288e96fdb91","design-system/components/core/IconButton.jsx":"38c7dcea0d97","design-system/components/display/Avatar.jsx":"cf7f4e752245","design-system/components/display/AvatarStack.jsx":"ae4f510a2b9d","design-system/components/display/Badge.jsx":"1cc38787b758","design-system/components/display/Belt.jsx":"cfafa21427c5","design-system/components/display/Card.jsx":"7cba4a816b62","design-system/components/display/StreakBelt.jsx":"8d77adb65f68","design-system/components/display/Tag.jsx":"53081ee7f44a","design-system/components/feedback/Dialog.jsx":"ebcf73d05c5e","design-system/components/feedback/Toast.jsx":"e06c2e2bad15","design-system/components/feedback/Tooltip.jsx":"cfbcbd91618b","design-system/components/forms/Checkbox.jsx":"5f281a9907fa","design-system/components/forms/Input.jsx":"c34d5880eed3","design-system/components/forms/Radio.jsx":"782cb748d5ad","design-system/components/forms/Select.jsx":"2edca2184f22","design-system/components/forms/Switch.jsx":"a0ad53dc3b63","design-system/components/navigation/TabBar.jsx":"e13fc2d0468b","design-system/components/navigation/Tabs.jsx":"50929bab281b","design-system/tailwind.config.js":"9e4180ea9093","ui_kits/app/Activity.jsx":"5e47902808a1","ui_kits/app/App.jsx":"cee17d63321e","ui_kits/app/Complete.jsx":"4274ae7574eb","ui_kits/app/Create.jsx":"25d816994b5d","ui_kits/app/Friends.jsx":"ac7c90f421f4","ui_kits/app/Me.jsx":"6d3cafb4c252","ui_kits/app/Profile.jsx":"1a2bb3f22c26","ui_kits/app/Shell.jsx":"b29b866fdbe2","ui_kits/app/Training.jsx":"4e7933eaba92","ui_kits/app/data.js":"62ce36e0d57c","design-system/components/core/Logo.jsx":"becd710e7dd0"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.GripGorillasDesignSystem_8b0f80 = window.GripGorillasDesignSystem_8b0f80 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// design-system/components/core/Icon.jsx
try { (() => {
// Lucide v0.454.0 (ISC) — inner SVG markup copied verbatim from lucide-static. Source files also in assets/icons/.
const ICONS = {
  "house": "<path d=\"M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8\" /><path d=\"M3 10a2 2 0 0 1 .709-1.528l7-5.999a2 2 0 0 1 2.582 0l7 5.999A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\" />",
  "search": "<circle cx=\"11\" cy=\"11\" r=\"8\" /><path d=\"m21 21-4.3-4.3\" />",
  "plus": "<path d=\"M5 12h14\" /><path d=\"M12 5v14\" />",
  "bell": "<path d=\"M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9\" /><path d=\"M10.3 21a1.94 1.94 0 0 0 3.4 0\" />",
  "user": "<path d=\"M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2\" /><circle cx=\"12\" cy=\"7\" r=\"4\" />",
  "users": "<path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\" /><circle cx=\"9\" cy=\"7\" r=\"4\" /><path d=\"M22 21v-2a4 4 0 0 0-3-3.87\" /><path d=\"M16 3.13a4 4 0 0 1 0 7.75\" />",
  "message-circle": "<path d=\"M7.9 20A9 9 0 1 0 4 16.1L2 22Z\" />",
  "heart": "<path d=\"M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z\" />",
  "share-2": "<circle cx=\"18\" cy=\"5\" r=\"3\" /><circle cx=\"6\" cy=\"12\" r=\"3\" /><circle cx=\"18\" cy=\"19\" r=\"3\" /><line x1=\"8.59\" x2=\"15.42\" y1=\"13.51\" y2=\"17.49\" /><line x1=\"15.41\" x2=\"8.59\" y1=\"6.51\" y2=\"10.49\" />",
  "bookmark": "<path d=\"m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z\" />",
  "ellipsis": "<circle cx=\"12\" cy=\"12\" r=\"1\" /><circle cx=\"19\" cy=\"12\" r=\"1\" /><circle cx=\"5\" cy=\"12\" r=\"1\" />",
  "map-pin": "<path d=\"M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0\" /><circle cx=\"12\" cy=\"10\" r=\"3\" />",
  "calendar": "<path d=\"M8 2v4\" /><path d=\"M16 2v4\" /><rect width=\"18\" height=\"18\" x=\"3\" y=\"4\" rx=\"2\" /><path d=\"M3 10h18\" />",
  "clock": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><polyline points=\"12 6 12 12 16 14\" />",
  "timer": "<line x1=\"10\" x2=\"14\" y1=\"2\" y2=\"2\" /><line x1=\"12\" x2=\"15\" y1=\"14\" y2=\"11\" /><circle cx=\"12\" cy=\"14\" r=\"8\" />",
  "flame": "<path d=\"M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z\" />",
  "trophy": "<path d=\"M6 9H4.5a2.5 2.5 0 0 1 0-5H6\" /><path d=\"M18 9h1.5a2.5 2.5 0 0 0 0-5H18\" /><path d=\"M4 22h16\" /><path d=\"M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22\" /><path d=\"M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22\" /><path d=\"M18 2H6v7a6 6 0 0 0 12 0V2Z\" />",
  "dumbbell": "<path d=\"M14.4 14.4 9.6 9.6\" /><path d=\"M18.657 21.485a2 2 0 1 1-2.829-2.828l-1.767 1.768a2 2 0 1 1-2.829-2.829l6.364-6.364a2 2 0 1 1 2.829 2.829l-1.768 1.767a2 2 0 1 1 2.828 2.829z\" /><path d=\"m21.5 21.5-1.4-1.4\" /><path d=\"M3.9 3.9 2.5 2.5\" /><path d=\"M6.404 12.768a2 2 0 1 1-2.829-2.829l1.768-1.767a2 2 0 1 1-2.828-2.829l2.828-2.828a2 2 0 1 1 2.829 2.828l1.767-1.768a2 2 0 1 1 2.829 2.829z\" />",
  "settings": "<path d=\"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z\" /><circle cx=\"12\" cy=\"12\" r=\"3\" />",
  "chevron-left": "<path d=\"m15 18-6-6 6-6\" />",
  "chevron-right": "<path d=\"m9 18 6-6-6-6\" />",
  "chevron-down": "<path d=\"m6 9 6 6 6-6\" />",
  "x": "<path d=\"M18 6 6 18\" /><path d=\"m6 6 12 12\" />",
  "check": "<path d=\"M20 6 9 17l-5-5\" />",
  "camera": "<path d=\"M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z\" /><circle cx=\"12\" cy=\"13\" r=\"3\" />",
  "image": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" ry=\"2\" /><circle cx=\"9\" cy=\"9\" r=\"2\" /><path d=\"m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21\" />",
  "send": "<path d=\"M14.536 21.686a.5.5 0 0 0 .937-.024l6.5-19a.496.496 0 0 0-.635-.635l-19 6.5a.5.5 0 0 0-.024.937l7.93 3.18a2 2 0 0 1 1.112 1.11z\" /><path d=\"m21.854 2.147-10.94 10.939\" />",
  "play": "<polygon points=\"6 3 20 12 6 21 6 3\" />",
  "star": "<path d=\"M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z\" />",
  "swords": "<polyline points=\"14.5 17.5 3 6 3 3 6 3 17.5 14.5\" /><line x1=\"13\" x2=\"19\" y1=\"19\" y2=\"13\" /><line x1=\"16\" x2=\"20\" y1=\"16\" y2=\"20\" /><line x1=\"19\" x2=\"21\" y1=\"21\" y2=\"19\" /><polyline points=\"14.5 6.5 18 3 21 3 21 6 17.5 9.5\" /><line x1=\"5\" x2=\"9\" y1=\"14\" y2=\"18\" /><line x1=\"7\" x2=\"4\" y1=\"17\" y2=\"20\" /><line x1=\"3\" x2=\"5\" y1=\"19\" y2=\"21\" />",
  "shield": "<path d=\"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z\" />",
  "activity": "<path d=\"M22 12h-2.48a2 2 0 0 0-1.93 1.46l-2.35 8.36a.25.25 0 0 1-.48 0L9.24 2.18a.25.25 0 0 0-.48 0l-2.35 8.36A2 2 0 0 1 4.49 12H2\" />",
  "trending-up": "<polyline points=\"22 7 13.5 15.5 8.5 10.5 2 17\" /><polyline points=\"16 7 22 7 22 13\" />",
  "chart-column": "<path d=\"M3 3v16a2 2 0 0 0 2 2h16\" /><path d=\"M18 17V9\" /><path d=\"M13 17V5\" /><path d=\"M8 17v-3\" />",
  "log-out": "<path d=\"M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4\" /><polyline points=\"16 17 21 12 16 7\" /><line x1=\"21\" x2=\"9\" y1=\"12\" y2=\"12\" />",
  "info": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M12 16v-4\" /><path d=\"M12 8h.01\" />",
  "triangle-alert": "<path d=\"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3\" /><path d=\"M12 9v4\" /><path d=\"M12 17h.01\" />",
  "circle-check": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"m9 12 2 2 4-4\" />",
  "lock": "<rect width=\"18\" height=\"11\" x=\"3\" y=\"11\" rx=\"2\" ry=\"2\" /><path d=\"M7 11V7a5 5 0 0 1 10 0v4\" />",
  "pencil": "<path d=\"M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z\" /><path d=\"m15 5 4 4\" />",
  "video": "<path d=\"m16 13 5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5\" /><rect x=\"2\" y=\"6\" width=\"14\" height=\"12\" rx=\"2\" />",
  "award": "<path d=\"m15.477 12.89 1.515 8.526a.5.5 0 0 1-.81.47l-3.58-2.687a1 1 0 0 0-1.197 0l-3.586 2.686a.5.5 0 0 1-.81-.469l1.514-8.526\" /><circle cx=\"12\" cy=\"8\" r=\"6\" />",
  "zap": "<path d=\"M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z\" />",
  "sliders-horizontal": "<line x1=\"21\" x2=\"14\" y1=\"4\" y2=\"4\" /><line x1=\"10\" x2=\"3\" y1=\"4\" y2=\"4\" /><line x1=\"21\" x2=\"12\" y1=\"12\" y2=\"12\" /><line x1=\"8\" x2=\"3\" y1=\"12\" y2=\"12\" /><line x1=\"21\" x2=\"16\" y1=\"20\" y2=\"20\" /><line x1=\"12\" x2=\"3\" y1=\"20\" y2=\"20\" /><line x1=\"14\" x2=\"14\" y1=\"2\" y2=\"6\" /><line x1=\"8\" x2=\"8\" y1=\"10\" y2=\"14\" /><line x1=\"16\" x2=\"16\" y1=\"18\" y2=\"22\" />",
  "notebook-pen": "<path d=\"M13.4 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7.4\" /><path d=\"M2 6h4\" /><path d=\"M2 10h4\" /><path d=\"M2 14h4\" /><path d=\"M2 18h4\" /><path d=\"M21.378 5.626a1 1 0 1 0-3.004-3.004l-5.01 5.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z\" />",
  "repeat-2": "<path d=\"m2 9 3-3 3 3\" /><path d=\"M13 18H7a2 2 0 0 1-2-2V6\" /><path d=\"m22 15-3 3-3-3\" /><path d=\"M11 6h6a2 2 0 0 1 2 2v10\" />",
  "user-plus": "<path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\" /><circle cx=\"9\" cy=\"7\" r=\"4\" /><line x1=\"19\" x2=\"19\" y1=\"8\" y2=\"14\" /><line x1=\"22\" x2=\"16\" y1=\"11\" y2=\"11\" />",
  "navigation": "<polygon points=\"3 11 22 2 13 21 11 13 3 11\" />",
  "droplet": "<path d=\"M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z\" />",
  "qr-code": "<rect width=\"5\" height=\"5\" x=\"3\" y=\"3\" rx=\"1\" /><rect width=\"5\" height=\"5\" x=\"16\" y=\"3\" rx=\"1\" /><rect width=\"5\" height=\"5\" x=\"3\" y=\"16\" rx=\"1\" /><path d=\"M21 16h-3a2 2 0 0 0-2 2v3\" /><path d=\"M21 21v.01\" /><path d=\"M12 7v3a2 2 0 0 1-2 2H7\" /><path d=\"M3 12h.01\" /><path d=\"M12 3h.01\" /><path d=\"M12 16v.01\" /><path d=\"M16 12h1\" /><path d=\"M21 12v.01\" /><path d=\"M12 21v-1\" />",
  "scan-line": "<path d=\"M3 7V5a2 2 0 0 1 2-2h2\" /><path d=\"M17 3h2a2 2 0 0 1 2 2v2\" /><path d=\"M21 17v2a2 2 0 0 1-2 2h-2\" /><path d=\"M7 21H5a2 2 0 0 1-2-2v-2\" /><path d=\"M7 12h10\" />",
  "link": "<path d=\"M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71\" /><path d=\"M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71\" />",
  "upload": "<path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\" /><polyline points=\"17 8 12 3 7 8\" /><line x1=\"12\" x2=\"12\" y1=\"3\" y2=\"15\" />",
  "image-plus": "<path d=\"M16 5h6\" /><path d=\"M19 2v6\" /><path d=\"M21 11.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7.5\" /><path d=\"m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21\" /><circle cx=\"9\" cy=\"9\" r=\"2\" />",
  "calendar-plus": "<path d=\"M8 2v4\" /><path d=\"M16 2v4\" /><path d=\"M21 13V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h8\" /><path d=\"M3 10h18\" /><path d=\"M16 19h6\" /><path d=\"M19 16v6\" />",
  "calendar-check": "<path d=\"M8 2v4\" /><path d=\"M16 2v4\" /><rect width=\"18\" height=\"18\" x=\"3\" y=\"4\" rx=\"2\" /><path d=\"M3 10h18\" /><path d=\"m9 16 2 2 4-4\" />",
  "user-minus": "<path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\" /><circle cx=\"9\" cy=\"7\" r=\"4\" /><line x1=\"22\" x2=\"16\" y1=\"11\" y2=\"11\" />",
  "trash-2": "<path d=\"M3 6h18\" /><path d=\"M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6\" /><path d=\"M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2\" /><line x1=\"10\" x2=\"10\" y1=\"11\" y2=\"17\" /><line x1=\"14\" x2=\"14\" y1=\"11\" y2=\"17\" />",
  "globe": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20\" /><path d=\"M2 12h20\" />",
  "mail": "<rect width=\"20\" height=\"16\" x=\"2\" y=\"4\" rx=\"2\" /><path d=\"m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7\" />",
  "copy": "<rect width=\"14\" height=\"14\" x=\"8\" y=\"8\" rx=\"2\" ry=\"2\" /><path d=\"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2\" />",
  "arrow-left": "<path d=\"m12 19-7-7 7-7\" /><path d=\"M19 12H5\" />",
  "check-check": "<path d=\"M18 6 7 17l-5-5\" /><path d=\"m22 10-7.5 7.5L13 16\" />",
  "circle-plus": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M8 12h8\" /><path d=\"M12 8v8\" />",
  "handshake": "<path d=\"m11 17 2 2a1 1 0 1 0 3-3\" /><path d=\"m14 14 2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4\" /><path d=\"m21 3 1 11h-2\" /><path d=\"M3 3 2 14l6.5 6.5a1 1 0 1 0 3-3\" /><path d=\"M3 4h8\" />",
  "party-popper": "<path d=\"M5.8 11.3 2 22l10.7-3.79\" /><path d=\"M4 3h.01\" /><path d=\"M22 8h.01\" /><path d=\"M15 2h.01\" /><path d=\"M22 20h.01\" /><path d=\"m22 2-2.24.75a2.9 2.9 0 0 0-1.96 3.12c.1.86-.57 1.63-1.45 1.63h-.38c-.86 0-1.6.6-1.76 1.44L14 10\" /><path d=\"m22 13-.82-.33c-.86-.34-1.82.2-1.98 1.11c-.11.7-.72 1.22-1.43 1.22H17\" /><path d=\"m11 2 .33.82c.34.86-.2 1.82-1.11 1.98C9.52 4.9 9 5.52 9 6.23V7\" /><path d=\"M11 13c1.93 1.93 2.83 4.17 2 5-.83.83-3.07-.07-5-2-1.93-1.93-2.83-4.17-2-5 .83-.83 3.07.07 5 2Z\" />",
  "hand": "<path d=\"M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2\" /><path d=\"M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2\" /><path d=\"M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8\" /><path d=\"M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15\" />",
  "sun": "<circle cx=\"12\" cy=\"12\" r=\"4\" /><path d=\"M12 2v2\" /><path d=\"M12 20v2\" /><path d=\"m4.93 4.93 1.41 1.41\" /><path d=\"m17.66 17.66 1.41 1.41\" /><path d=\"M2 12h2\" /><path d=\"M20 12h2\" /><path d=\"m6.34 17.66-1.41 1.41\" /><path d=\"m19.07 4.93-1.41 1.41\" />",
  "moon": "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\" />",
  "calendar-clock": "<path d=\"M21 7.5V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h3.5\" /><path d=\"M16 2v4\" /><path d=\"M8 2v4\" /><path d=\"M3 10h5\" /><path d=\"M17.5 17.5 16 16.3V14\" /><circle cx=\"16\" cy=\"16\" r=\"6\" />",
  "history": "<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" /><path d=\"M3 3v5h5\" /><path d=\"M12 7v5l4 2\" />",
  "user-check": "<path d=\"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2\" /><circle cx=\"9\" cy=\"7\" r=\"4\" /><polyline points=\"16 11 18 13 22 9\" />",
  "circle-x": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"m15 9-6 6\" /><path d=\"m9 9 6 6\" />",
  "eye": "<path d=\"M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0\" /><circle cx=\"12\" cy=\"12\" r=\"3\" />",
  "images": "<path d=\"M18 22H4a2 2 0 0 1-2-2V6\" /><path d=\"m22 13-1.296-1.296a2.41 2.41 0 0 0-3.408 0L11 18\" /><circle cx=\"12\" cy=\"8\" r=\"2\" /><rect width=\"16\" height=\"16\" x=\"6\" y=\"2\" rx=\"2\" />"
};
const ICON_NAMES = Object.keys(ICONS);
function Icon({
  name,
  size = 20,
  strokeWidth = 2,
  color = 'currentColor',
  filled = false,
  style,
  ...rest
}) {
  const inner = ICONS[name];
  if (!inner) return null;
  return React.createElement('svg', {
    xmlns: 'http://www.w3.org/2000/svg',
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: filled ? color : 'none',
    stroke: color,
    strokeWidth,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    style: {
      display: 'block',
      flexShrink: 0,
      ...style
    },
    'aria-hidden': true,
    dangerouslySetInnerHTML: {
      __html: inner
    },
    ...rest
  });
}
Object.assign(__ds_scope, { ICON_NAMES, Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// design-system/components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const SIZES = {
  sm: {
    h: 36,
    px: 14,
    fs: 14,
    icon: 16
  },
  md: {
    h: 48,
    px: 20,
    fs: 16,
    icon: 18
  },
  lg: {
    h: 56,
    px: 24,
    fs: 17,
    icon: 20
  }
};
const VARIANTS = {
  primary: {
    bg: 'var(--accent)',
    bgH: 'var(--accent-hover)',
    fg: 'var(--text-on-accent)',
    edge: 'var(--accent-shade)'
  },
  secondary: {
    bg: 'var(--white)',
    bgH: 'var(--paper-2)',
    fg: 'var(--text-primary)',
    bd: 'var(--border-default)',
    edge: 'var(--ink-200)'
  },
  soft: {
    bg: 'var(--accent-tint)',
    bgH: '#FFD6C9',
    fg: 'var(--coral-700)'
  },
  ghost: {
    bg: 'transparent',
    bgH: 'var(--surface-hover)',
    fg: 'var(--text-primary)'
  },
  inverse: {
    bg: 'var(--ink-900)',
    bgH: 'var(--ink-800)',
    fg: 'var(--paper)',
    edge: '#000'
  },
  danger: {
    bg: 'var(--danger-tint)',
    bgH: '#FBD0D0',
    fg: 'var(--danger-500)'
  }
};
function Button({
  variant = 'primary',
  size = 'md',
  iconLeft,
  iconRight,
  fullWidth = false,
  disabled = false,
  children,
  style,
  onClick,
  type = 'button',
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const v = VARIANTS[variant] || VARIANTS.primary;
  const edge = v.edge && !disabled ? press ? 1 : 3 : 0;
  const shadows = [v.bd ? `inset 0 0 0 1.5px ${v.bd}` : null, edge ? `0 ${edge}px 0 ${v.edge}` : null].filter(Boolean).join(', ') || 'none';
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled,
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 8,
      height: s.h,
      padding: `0 ${s.px}px`,
      width: fullWidth ? '100%' : undefined,
      boxSizing: 'border-box',
      borderRadius: 'var(--radius-pill)',
      border: 0,
      background: disabled ? 'var(--ink-100)' : hover ? v.bgH : v.bg,
      color: disabled ? 'var(--text-disabled)' : v.fg,
      boxShadow: shadows,
      fontFamily: 'var(--font-display)',
      fontSize: s.fs,
      fontWeight: 700,
      letterSpacing: '-0.01em',
      cursor: disabled ? 'not-allowed' : 'pointer',
      whiteSpace: 'nowrap',
      transform: press && !disabled ? edge ? 'translateY(2px)' : 'scale(.97)' : 'none',
      transition: 'background var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out)',
      ...style
    }
  }, rest), iconLeft && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconLeft,
    size: s.icon,
    strokeWidth: 2.25
  }), children, iconRight && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconRight,
    size: s.icon,
    strokeWidth: 2.25
  }));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/core/Button.jsx", error: String((e && e.message) || e) }); }

// design-system/components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const V = {
  ghost: {
    bg: 'transparent',
    bgH: 'var(--surface-hover)',
    fg: 'var(--text-primary)'
  },
  filled: {
    bg: 'var(--paper-2)',
    bgH: 'var(--paper-3)',
    fg: 'var(--text-primary)'
  },
  accent: {
    bg: 'var(--accent)',
    bgH: 'var(--accent-hover)',
    fg: 'var(--text-on-accent)'
  },
  overlay: {
    bg: 'rgba(255,255,255,.88)',
    bgH: '#fff',
    fg: 'var(--ink-900)'
  },
  inverse: {
    bg: 'var(--ink-900)',
    bgH: 'var(--ink-800)',
    fg: 'var(--paper)'
  }
};
function IconButton({
  icon,
  variant = 'ghost',
  size = 44,
  iconSize,
  active = false,
  filledWhenActive = false,
  activeColor = 'var(--accent)',
  badge,
  label,
  onClick,
  disabled,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const v = V[variant] || V.ghost;
  const color = active && variant !== 'accent' ? activeColor : v.fg;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    title: label,
    onClick: onClick,
    disabled: disabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      position: 'relative',
      width: size,
      height: size,
      borderRadius: 'var(--radius-pill)',
      border: 0,
      padding: 0,
      flexShrink: 0,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: hover ? v.bgH : v.bg,
      color,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .4 : 1,
      transform: press ? 'scale(.86)' : 'none',
      transition: 'transform var(--dur-fast) var(--ease-bounce), background var(--dur-fast) var(--ease-out)',
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: iconSize || Math.round(size * 0.5),
    strokeWidth: 2.25,
    filled: active && filledWhenActive,
    color: color
  }), badge != null && badge !== false && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: size * 0.12,
      right: size * 0.12,
      minWidth: badge === true ? 9 : 18,
      height: badge === true ? 9 : 18,
      padding: badge === true ? 0 : '0 5px',
      borderRadius: 999,
      background: 'var(--accent)',
      color: '#fff',
      boxSizing: 'border-box',
      font: '800 11px/18px var(--font-body)',
      boxShadow: '0 0 0 2px var(--bg-app)'
    }
  }, badge === true ? '' : badge));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// design-system/components/core/Logo.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// The Silverback mark. Geometry matches assets/brand/logo-mark.svg (viewBox 36 22 228 256).
const VIEWBOX = '36 22 228 256';
const RATIO = 228 / 256;
function Mark({
  height,
  brow
}) {
  return /*#__PURE__*/React.createElement("svg", {
    viewBox: VIEWBOX,
    width: Math.round(height * RATIO),
    height: height,
    "aria-hidden": "true",
    style: {
      display: 'block',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M150 28C222 28 258 72 258 132C258 204 226 266 150 272C74 266 42 204 42 132C42 72 78 28 150 28Z",
    style: {
      fill: 'var(--ink-900)'
    }
  }), /*#__PURE__*/React.createElement("path", {
    d: "M150 112C202 108 226 132 222 168C218 222 188 252 150 254C112 252 82 222 78 168C74 132 98 108 150 112Z",
    style: {
      fill: 'var(--paper-3)'
    }
  }), /*#__PURE__*/React.createElement("rect", {
    x: "68",
    y: "98",
    width: "164",
    height: "38",
    rx: "19",
    style: {
      fill: brow
    }
  }), /*#__PURE__*/React.createElement("rect", {
    x: "100",
    y: "148",
    width: "30",
    height: "11",
    rx: "5.5",
    style: {
      fill: 'var(--ink-900)'
    }
  }), /*#__PURE__*/React.createElement("rect", {
    x: "170",
    y: "148",
    width: "30",
    height: "11",
    rx: "5.5",
    style: {
      fill: 'var(--ink-900)'
    }
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "136",
    cy: "200",
    rx: "10",
    ry: "7",
    style: {
      fill: 'var(--ink-900)'
    }
  }), /*#__PURE__*/React.createElement("ellipse", {
    cx: "164",
    cy: "200",
    rx: "10",
    ry: "7",
    style: {
      fill: 'var(--ink-900)'
    }
  }), /*#__PURE__*/React.createElement("path", {
    d: "M124 230H176",
    strokeWidth: "9",
    strokeLinecap: "round",
    style: {
      stroke: 'var(--ink-900)'
    }
  }));
}
function Tile({
  size
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      width: size,
      height: size,
      borderRadius: size * 0.225,
      background: 'var(--sun-400)',
      flexShrink: 0,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      paddingTop: size * 0.03,
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement(Mark, {
    height: Math.round(size * 0.69),
    brow: "var(--accent)"
  }));
}
function Wordmark({
  size,
  color
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      font: `800 ${Math.round(size * 0.6)}px/1 var(--font-display)`,
      letterSpacing: '-0.045em',
      color,
      whiteSpace: 'nowrap'
    }
  }, "grip gorillas", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, "."));
}
function Logo({
  variant = 'mark',
  size = 40,
  label = 'Grip Gorillas',
  style,
  ...rest
}) {
  let content;
  if (variant === 'mono') content = /*#__PURE__*/React.createElement(Mark, {
    height: size,
    brow: "var(--ink-900)"
  });else if (variant === 'appIcon') content = /*#__PURE__*/React.createElement(Tile, {
    size: size
  });else if (variant === 'lockup') content = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Mark, {
    height: size,
    brow: "var(--accent)"
  }), /*#__PURE__*/React.createElement(Wordmark, {
    size: size,
    color: "var(--text-primary)"
  }));else if (variant === 'lockupInverse') content = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Tile, {
    size: size
  }), /*#__PURE__*/React.createElement(Wordmark, {
    size: size,
    color: "var(--text-inverse)"
  }));else content = /*#__PURE__*/React.createElement(Mark, {
    height: size,
    brow: "var(--accent)"
  });
  return /*#__PURE__*/React.createElement("span", _extends({
    role: "img",
    "aria-label": label
  }, rest, {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: Math.round(size * 0.3),
      lineHeight: 0,
      ...style
    }
  }), content);
}
Object.assign(__ds_scope, { Logo });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/core/Logo.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/Badge.jsx
try { (() => {
const V = {
  neutral: {
    bg: 'var(--paper-2)',
    fg: 'var(--text-secondary)'
  },
  accent: {
    bg: 'var(--accent)',
    fg: '#fff'
  },
  soft: {
    bg: 'var(--accent-tint)',
    fg: 'var(--coral-700)'
  },
  success: {
    bg: 'var(--success-tint)',
    fg: 'var(--mint-700)'
  },
  warning: {
    bg: 'var(--warning-tint)',
    fg: '#8A6200'
  },
  danger: {
    bg: 'var(--danger-tint)',
    fg: 'var(--danger-500)'
  },
  info: {
    bg: 'var(--info-tint)',
    fg: 'var(--sky-700)'
  },
  flame: {
    bg: 'var(--flame-100)',
    fg: '#B5520A'
  }
};
function Badge({
  variant = 'neutral',
  children,
  dot = false,
  icon,
  style
}) {
  const v = V[variant] || V.neutral;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      height: 24,
      padding: '0 10px',
      borderRadius: 999,
      background: v.bg,
      color: v.fg,
      font: '700 12px/1 var(--font-body)',
      whiteSpace: 'nowrap',
      ...style
    }
  }, dot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: 999,
      background: 'currentColor'
    }
  }), icon, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/Badge.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/Belt.jsx
try { (() => {
const COLORS = {
  white: 'var(--belt-white)',
  blue: 'var(--belt-blue)',
  purple: 'var(--belt-purple)',
  brown: 'var(--belt-brown)',
  black: 'var(--belt-black)',
  coral: 'var(--belt-coral)',
  red: 'var(--belt-red)',
  grey: 'var(--belt-grey)',
  yellow: 'var(--belt-yellow)',
  orange: 'var(--belt-orange)',
  green: 'var(--belt-green)'
};
const H = {
  xs: 8,
  sm: 12,
  md: 16,
  lg: 24
};
const BELT_COLORS = COLORS;
function Belt({
  rank = 'white',
  stripes = 0,
  size = 'md',
  width,
  label = false,
  style
}) {
  const h = H[size] || H.md;
  const bar = rank === 'black' || rank === 'coral' || rank === 'red' ? 'var(--belt-bar-red)' : 'var(--belt-bar-black)';
  const barW = size === 'xs' ? 14 : Math.max(h * 3.2, 26);
  const stripeW = Math.max(2, Math.round(h * 0.24));
  const n = Math.max(0, Math.min(4, stripes));
  const name = rank.charAt(0).toUpperCase() + rank.slice(1) + ' belt' + (n ? ` · ${n} stripe${n > 1 ? 's' : ''}` : '');
  const strip = /*#__PURE__*/React.createElement("span", {
    role: "img",
    "aria-label": name,
    style: {
      display: 'flex',
      height: h,
      width: width ?? '100%',
      minWidth: barW * 2.5,
      borderRadius: Math.max(3, h * 0.25),
      overflow: 'hidden',
      background: COLORS[rank] || COLORS.white,
      boxShadow: 'inset 0 0 0 1.5px rgba(29,27,24,.16)',
      flexShrink: 0,
      ...(label ? {} : style)
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: barW,
      background: bar,
      display: 'flex',
      justifyContent: 'flex-end',
      gap: Math.max(2, stripeW * 0.8),
      padding: size === 'xs' ? '0 2px' : `0 ${Math.round(h * 0.35)}px`
    }
  }, Array.from({
    length: n
  }).map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      width: stripeW,
      background: 'var(--belt-stripe)'
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      width: Math.round(h * 0.8)
    }
  }));
  if (!label) return strip;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6,
      ...style
    }
  }, strip, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 13px/1.2 var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, name));
}
Object.assign(__ds_scope, { BELT_COLORS, Belt });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/Belt.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/Avatar.jsx
try { (() => {
const HUES = ['var(--sun-100)', 'var(--mint-100)', 'var(--sky-100)', 'var(--plum-100)', 'var(--coral-100)'];
const INK = ['var(--sun-600)', 'var(--mint-700)', 'var(--sky-700)', 'var(--plum-700)', 'var(--coral-700)'];
function Avatar({
  src,
  name = '',
  size = 40,
  belt,
  ring = 'var(--bg-app)',
  online = false,
  style
}) {
  const initials = name.split(' ').filter(Boolean).slice(0, size < 30 ? 1 : 2).map(w => w[0]).join('').toUpperCase();
  const h = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % HUES.length;
  const beltW = belt ? Math.max(2, Math.round(size / 18)) : 0;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'inline-flex',
      width: size,
      height: size,
      flexShrink: 0,
      borderRadius: 999,
      boxSizing: 'border-box',
      padding: beltW ? beltW + 2 : 0,
      background: ring,
      boxShadow: beltW ? `inset 0 0 0 ${beltW}px ${__ds_scope.BELT_COLORS[belt] || belt}${belt === 'white' ? ', inset 0 0 0 ' + (beltW + 1) + 'px rgba(29,27,24,.2)' : ''}` : 'none',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: '100%',
      height: '100%',
      borderRadius: 999,
      overflow: 'hidden',
      background: HUES[h],
      color: INK[h],
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      font: `800 ${Math.round(size * 0.38)}px/1 var(--font-display)`
    }
  }, src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }) : initials), online && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      right: 0,
      bottom: 0,
      width: Math.max(9, size * 0.26),
      height: Math.max(9, size * 0.26),
      borderRadius: 999,
      background: 'var(--mint-500)',
      boxShadow: '0 0 0 2px var(--bg-app)'
    }
  }));
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/Avatar.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/AvatarStack.jsx
try { (() => {
function AvatarStack({
  people = [],
  size = 32,
  max = 4,
  ring = 'var(--surface-card)',
  label,
  style
}) {
  const shown = people.slice(0, max);
  const extra = people.length - shown.length;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex'
    }
  }, shown.map((p, i) => /*#__PURE__*/React.createElement("span", {
    key: p.name + i,
    style: {
      marginLeft: i ? -size * 0.32 : 0,
      borderRadius: 999,
      boxShadow: `0 0 0 2.5px ${ring}`,
      display: 'inline-flex',
      zIndex: shown.length - i
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: p.name,
    src: p.src,
    size: size
  }))), extra > 0 && /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: -size * 0.32,
      width: size,
      height: size,
      borderRadius: 999,
      background: 'var(--paper-2)',
      boxShadow: `0 0 0 2.5px ${ring}`,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      font: `700 ${Math.round(size * 0.34)}px var(--font-body)`,
      color: 'var(--text-secondary)'
    }
  }, "+", extra)), label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 13px/1.3 var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, label));
}
Object.assign(__ds_scope, { AvatarStack });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/AvatarStack.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/Card.jsx
try { (() => {
function Card({
  children,
  padding = 16,
  variant = 'default',
  interactive = false,
  onClick,
  style
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const bg = variant === 'sunken' ? 'var(--paper-2)' : variant === 'outline' ? 'transparent' : 'var(--surface-card)';
  const sh = variant === 'default' ? 'var(--shadow-card)' : variant === 'outline' ? 'inset 0 0 0 1.5px var(--border-default)' : 'none';
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      background: bg,
      borderRadius: 'var(--radius-lg)',
      padding,
      boxShadow: sh,
      boxSizing: 'border-box',
      cursor: interactive ? 'pointer' : undefined,
      transform: interactive && press ? 'scale(.985)' : interactive && hover ? 'translateY(-1px)' : 'none',
      transition: 'transform var(--dur-fast) var(--ease-out)',
      ...style
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/Card.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/StreakBelt.jsx
try { (() => {
const HUE = {
  coral: ['var(--coral-500)', 'var(--coral-100)'],
  sun: ['var(--sun-400)', 'var(--sun-100)'],
  mint: ['var(--mint-500)', 'var(--mint-100)'],
  sky: ['var(--sky-500)', 'var(--sky-100)'],
  plum: ['var(--plum-500)', 'var(--plum-100)']
};
function StreakBelt({
  weeks = [],
  thisWeek = 'pending',
  hue = 'coral',
  size = 'md',
  showFlame = true,
  style
}) {
  const [c, tint] = HUE[hue] || HUE.coral;
  const h = size === 'sm' ? 14 : 22;
  const cells = [...weeks, thisWeek];
  const lastIdx = cells.length - 1;
  const alive = thisWeek === 'done' || thisWeek === 'pending' && weeks[weeks.length - 1];
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      display: 'flex',
      gap: 3,
      height: h
    }
  }, cells.map((w, i) => {
    const isNow = i === lastIdx;
    const done = isNow ? thisWeek === 'done' : !!w;
    const first = i === 0 || !(isNow ? weeks[i - 1] : cells[i - 1]);
    const last = isNow || !cells[i + 1] || i + 1 === lastIdx && thisWeek !== 'done';
    return /*#__PURE__*/React.createElement("span", {
      key: i,
      title: isNow ? 'This week' : '',
      style: {
        flex: 1,
        position: 'relative',
        borderRadius: `${first ? 6 : 2}px ${last ? 6 : 2}px ${last ? 6 : 2}px ${first ? 6 : 2}px`,
        background: done ? c : isNow ? 'transparent' : 'var(--paper-3)',
        boxShadow: isNow && !done ? `inset 0 0 0 2px ${c}` : 'none',
        opacity: isNow && !done ? .7 : 1,
        backgroundImage: isNow && !done ? `repeating-linear-gradient(135deg, ${tint} 0 4px, transparent 4px 8px)` : 'none'
      }
    }, done && size !== 'sm' && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        right: 4,
        top: 4,
        bottom: 4,
        width: 3,
        borderRadius: 1,
        background: 'rgba(255,255,255,.85)'
      }
    }));
  })), showFlame && /*#__PURE__*/React.createElement("span", {
    style: {
      width: h + 6,
      height: h + 6,
      borderRadius: 999,
      flexShrink: 0,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: alive ? 'var(--flame-100)' : 'var(--paper-2)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "flame",
    size: Math.round(h * 0.72),
    filled: alive,
    color: alive ? 'var(--flame-500)' : 'var(--ink-300)'
  })));
}
Object.assign(__ds_scope, { StreakBelt });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/StreakBelt.jsx", error: String((e && e.message) || e) }); }

// design-system/components/display/Tag.jsx
try { (() => {
function Tag({
  children,
  icon,
  selected = false,
  onClick,
  onRemove,
  size = 'md',
  style
}) {
  const [hover, setHover] = React.useState(false);
  const h = size === 'sm' ? 32 : 40;
  return /*#__PURE__*/React.createElement("span", {
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      height: h,
      padding: `0 ${size === 'sm' ? 12 : 16}px`,
      borderRadius: 999,
      boxSizing: 'border-box',
      flexShrink: 0,
      background: selected ? 'var(--ink-900)' : hover && onClick ? 'var(--paper-2)' : 'var(--white)',
      color: selected ? 'var(--paper)' : 'var(--text-primary)',
      boxShadow: selected ? 'none' : 'inset 0 0 0 1.5px var(--border-default)',
      font: `600 ${size === 'sm' ? 13 : 15}px/1 var(--font-body)`,
      cursor: onClick ? 'pointer' : 'default',
      whiteSpace: 'nowrap',
      userSelect: 'none',
      transition: 'background var(--dur-fast) var(--ease-out)',
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === 'sm' ? 14 : 16,
    strokeWidth: 2.25
  }), children, onRemove && /*#__PURE__*/React.createElement("span", {
    onClick: e => {
      e.stopPropagation();
      onRemove();
    },
    style: {
      display: 'flex',
      marginRight: -4,
      opacity: .6,
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 14,
    strokeWidth: 2.5
  })));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/display/Tag.jsx", error: String((e && e.message) || e) }); }

// design-system/components/feedback/Dialog.jsx
try { (() => {
function Dialog({
  open = true,
  onClose,
  title,
  description,
  children,
  actions,
  variant = 'sheet',
  contained = false,
  style
}) {
  if (!open) return null;
  const sheet = variant === 'sheet';
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: contained ? 'absolute' : 'fixed',
      inset: 0,
      zIndex: 50,
      background: 'var(--surface-overlay)',
      display: 'flex',
      alignItems: sheet ? 'flex-end' : 'center',
      justifyContent: 'center',
      padding: sheet ? 0 : 24,
      animation: 'mmFade var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    role: "dialog",
    "aria-modal": "true",
    onClick: e => e.stopPropagation(),
    style: {
      width: '100%',
      maxWidth: sheet ? undefined : 340,
      background: 'var(--white)',
      boxSizing: 'border-box',
      borderRadius: sheet ? 'var(--radius-xl) var(--radius-xl) 0 0' : 'var(--radius-xl)',
      boxShadow: sheet ? 'var(--shadow-sheet)' : 'var(--shadow-float)',
      padding: sheet ? '10px 20px 34px' : 22,
      maxHeight: '88%',
      overflowY: 'auto',
      animation: sheet ? 'mmSheet var(--dur-slow) var(--ease-out)' : 'mmPop var(--dur-base) var(--ease-bounce)',
      ...style
    }
  }, sheet && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 5,
      borderRadius: 999,
      background: 'var(--ink-200)',
      margin: '0 auto 16px'
    }
  }), (title || onClose) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      justifyContent: 'space-between',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, title && /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 22px/1.15 var(--font-display)',
      letterSpacing: '-.02em',
      color: 'var(--text-primary)'
    }
  }, title), description && /*#__PURE__*/React.createElement("div", {
    style: {
      font: '400 15px/1.45 var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, description)), onClose && /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    size: 36,
    variant: "filled",
    label: "Close",
    onClick: onClose
  })), children && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16
    }
  }, children), actions && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginTop: 20
    }
  }, actions)), /*#__PURE__*/React.createElement("style", null, '@keyframes mmFade{from{opacity:0}}@keyframes mmSheet{from{transform:translateY(100%)}}@keyframes mmPop{from{transform:scale(.92);opacity:0}}'));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/feedback/Dialog.jsx", error: String((e && e.message) || e) }); }

// design-system/components/feedback/Toast.jsx
try { (() => {
const ICON = {
  default: null,
  success: 'circle-check',
  danger: 'triangle-alert',
  streak: 'flame',
  friend: 'handshake'
};
const COLOR = {
  default: 'var(--paper)',
  success: 'var(--mint-500)',
  danger: '#FF7B7D',
  streak: 'var(--flame-500)',
  friend: 'var(--sun-400)'
};
function Toast({
  message,
  variant = 'default',
  icon,
  action,
  style
}) {
  const ic = icon || ICON[variant];
  return /*#__PURE__*/React.createElement("div", {
    role: "status",
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      minHeight: 52,
      padding: '10px 10px 10px 16px',
      borderRadius: 999,
      background: 'var(--ink-900)',
      boxShadow: 'var(--shadow-float)',
      color: 'var(--paper)',
      font: '600 15px/1.3 var(--font-body)',
      boxSizing: 'border-box',
      ...style
    }
  }, ic && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: ic,
    size: 20,
    color: COLOR[variant],
    filled: variant === 'streak'
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, message), action && /*#__PURE__*/React.createElement("button", {
    onClick: action.onClick,
    style: {
      border: 0,
      background: 'rgba(255,255,255,.12)',
      color: '#fff',
      font: '700 14px var(--font-display)',
      cursor: 'pointer',
      height: 34,
      padding: '0 14px',
      borderRadius: 999
    }
  }, action.label));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// design-system/components/feedback/Tooltip.jsx
try { (() => {
function Tooltip({
  content,
  children,
  placement = 'top',
  open,
  style
}) {
  const [hover, setHover] = React.useState(false);
  const show = open ?? hover;
  const top = placement === 'top';
  return /*#__PURE__*/React.createElement("span", {
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      position: 'relative',
      display: 'inline-flex',
      ...style
    }
  }, children, /*#__PURE__*/React.createElement("span", {
    role: "tooltip",
    style: {
      position: 'absolute',
      left: '50%',
      [top ? 'bottom' : 'top']: 'calc(100% + 8px)',
      transform: `translateX(-50%) translateY(${show ? 0 : top ? 4 : -4}px)`,
      opacity: show ? 1 : 0,
      pointerEvents: 'none',
      whiteSpace: 'nowrap',
      padding: '7px 11px',
      borderRadius: 10,
      background: 'var(--ink-900)',
      color: 'var(--paper)',
      font: '600 13px/1.2 var(--font-body)',
      transition: 'opacity var(--dur-fast) var(--ease-out), transform var(--dur-fast) var(--ease-out)',
      zIndex: 20
    }
  }, content));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// design-system/components/forms/Checkbox.jsx
try { (() => {
function Checkbox({
  checked,
  defaultChecked = false,
  onChange,
  label,
  description,
  disabled,
  style
}) {
  const [inner, setInner] = React.useState(defaultChecked);
  const on = checked ?? inner;
  const toggle = () => {
    if (disabled) return;
    setInner(!on);
    onChange && onChange(!on);
  };
  return /*#__PURE__*/React.createElement("label", {
    onClick: toggle,
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .45 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    role: "checkbox",
    "aria-checked": on,
    style: {
      width: 24,
      height: 24,
      flexShrink: 0,
      borderRadius: 8,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: on ? 'var(--accent)' : 'var(--white)',
      boxShadow: on ? '0 2px 0 var(--accent-shade)' : 'inset 0 0 0 2px var(--control-border)',
      transform: on ? 'scale(1)' : 'scale(.96)',
      transition: 'all var(--dur-fast) var(--ease-bounce)'
    }
  }, on && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 16,
    strokeWidth: 3.25,
    color: "#fff"
  })), (label || description) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      paddingTop: 2
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 16px/1.3 var(--font-body)',
      color: 'var(--text-primary)'
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '400 13px/1.4 var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, description)));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// design-system/components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Input({
  label,
  hint,
  error,
  iconLeft,
  value,
  defaultValue,
  placeholder,
  onChange,
  multiline = false,
  rows = 3,
  disabled,
  type = 'text',
  style,
  inputStyle,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const Tag = multiline ? 'textarea' : 'input';
  const border = error ? 'var(--danger-500)' : focus ? 'var(--border-focus)' : 'var(--border-default)';
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '700 14px/1.2 var(--font-display)',
      color: 'var(--text-primary)'
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: multiline ? 'flex-start' : 'center',
      gap: 10,
      minHeight: 50,
      padding: multiline ? '14px 16px' : '0 16px',
      boxSizing: 'border-box',
      background: 'var(--surface-input)',
      borderRadius: 'var(--radius-md)',
      boxShadow: `inset 0 0 0 1.5px ${border}${focus && !error ? ', 0 0 0 4px var(--accent-tint)' : ''}`,
      opacity: disabled ? .5 : 1,
      transition: 'box-shadow var(--dur-fast) var(--ease-out)'
    }
  }, iconLeft && /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconLeft,
    size: 18,
    color: "var(--text-tertiary)",
    style: {
      marginTop: multiline ? 2 : 0
    }
  }), /*#__PURE__*/React.createElement(Tag, _extends({
    type: multiline ? undefined : type,
    rows: multiline ? rows : undefined,
    value: value,
    defaultValue: defaultValue,
    placeholder: placeholder,
    onChange: onChange,
    disabled: disabled,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      flex: 1,
      minWidth: 0,
      border: 0,
      outline: 'none',
      background: 'transparent',
      color: 'var(--text-primary)',
      resize: 'none',
      font: '400 16px/1.45 var(--font-body)',
      padding: 0,
      ...inputStyle
    }
  }, rest))), (error || hint) && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 13px/1.3 var(--font-body)',
      color: error ? 'var(--danger-500)' : 'var(--text-tertiary)'
    }
  }, error || hint));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// design-system/components/forms/Radio.jsx
try { (() => {
function Radio({
  checked = false,
  onChange,
  label,
  description,
  disabled,
  name,
  value,
  style
}) {
  return /*#__PURE__*/React.createElement("label", {
    onClick: () => !disabled && onChange && onChange(value),
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .45 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    role: "radio",
    "aria-checked": checked,
    "data-name": name,
    style: {
      width: 24,
      height: 24,
      flexShrink: 0,
      borderRadius: 999,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'var(--white)',
      boxShadow: checked ? 'inset 0 0 0 2px var(--accent)' : 'inset 0 0 0 2px var(--control-border)',
      transition: 'box-shadow var(--dur-fast) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      borderRadius: 999,
      background: 'var(--accent)',
      transform: checked ? 'scale(1)' : 'scale(0)',
      transition: 'transform var(--dur-base) var(--ease-bounce)'
    }
  })), (label || description) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2,
      paddingTop: 2
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 16px/1.3 var(--font-body)',
      color: 'var(--text-primary)'
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '400 13px/1.4 var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, description)));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// design-system/components/forms/Select.jsx
try { (() => {
function Select({
  label,
  options = [],
  value,
  defaultValue,
  onChange,
  placeholder,
  disabled,
  style
}) {
  const [focus, setFocus] = React.useState(false);
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '700 14px/1.2 var(--font-display)',
      color: 'var(--text-primary)'
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("select", {
    value: value,
    defaultValue: defaultValue,
    onChange: onChange,
    disabled: disabled,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      appearance: 'none',
      WebkitAppearance: 'none',
      width: '100%',
      height: 50,
      padding: '0 44px 0 16px',
      border: 0,
      outline: 'none',
      background: 'var(--surface-input)',
      color: 'var(--text-primary)',
      font: '500 16px var(--font-body)',
      borderRadius: 'var(--radius-md)',
      boxShadow: `inset 0 0 0 1.5px ${focus ? 'var(--border-focus)' : 'var(--border-default)'}`,
      cursor: 'pointer',
      opacity: disabled ? .5 : 1
    }
  }, placeholder && /*#__PURE__*/React.createElement("option", {
    value: "",
    disabled: true
  }, placeholder), options.map(o => typeof o === 'string' ? /*#__PURE__*/React.createElement("option", {
    key: o,
    value: o
  }, o) : /*#__PURE__*/React.createElement("option", {
    key: o.value,
    value: o.value
  }, o.label))), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 18,
    color: "var(--text-tertiary)",
    style: {
      position: 'absolute',
      right: 16,
      pointerEvents: 'none'
    }
  })));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// design-system/components/forms/Switch.jsx
try { (() => {
function Switch({
  checked,
  defaultChecked = false,
  onChange,
  label,
  description,
  disabled,
  style
}) {
  const [inner, setInner] = React.useState(defaultChecked);
  const on = checked ?? inner;
  const toggle = () => {
    if (disabled) return;
    setInner(!on);
    onChange && onChange(!on);
  };
  const track = /*#__PURE__*/React.createElement("span", {
    role: "switch",
    "aria-checked": on,
    onClick: label ? undefined : toggle,
    style: {
      width: 52,
      height: 32,
      flexShrink: 0,
      borderRadius: 999,
      position: 'relative',
      cursor: disabled ? 'not-allowed' : 'pointer',
      background: on ? 'var(--accent)' : 'var(--control-off)',
      opacity: disabled ? .45 : 1,
      transition: 'background var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 3,
      left: 3,
      width: 26,
      height: 26,
      borderRadius: 999,
      background: '#fff',
      boxShadow: '0 2px 4px rgba(29,27,24,.18)',
      transform: on ? 'translateX(20px)' : 'none',
      transition: 'transform var(--dur-base) var(--ease-bounce)'
    }
  }));
  if (!label) return track;
  return /*#__PURE__*/React.createElement("label", {
    onClick: toggle,
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 16,
      cursor: 'pointer',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '500 16px/1.3 var(--font-body)',
      color: 'var(--text-primary)'
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      font: '400 13px/1.4 var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, description)), track);
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// design-system/components/navigation/TabBar.jsx
try { (() => {
function TabBar({
  items = [],
  value,
  onChange,
  centerAction,
  style
}) {
  const half = Math.ceil(items.length / 2);
  const render = it => {
    const on = it.id === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.id,
      onClick: () => onChange && onChange(it.id),
      "aria-label": it.label,
      style: {
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 4,
        padding: '10px 0 0',
        border: 0,
        background: 'transparent',
        cursor: 'pointer',
        color: on ? 'var(--text-primary)' : 'var(--ink-400)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'relative',
        transform: on ? 'translateY(-1px)' : 'none',
        transition: 'transform var(--dur-base) var(--ease-bounce)'
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: it.icon,
      size: 24,
      strokeWidth: on ? 2.5 : 2
    }), it.badge && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: -2,
        right: -4,
        width: 9,
        height: 9,
        borderRadius: 999,
        background: 'var(--accent)',
        boxShadow: '0 0 0 2px var(--white)'
      }
    })), /*#__PURE__*/React.createElement("span", {
      style: {
        font: `${on ? 800 : 600} 11px/1 var(--font-display)`
      }
    }, it.label));
  };
  return /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      height: 86,
      padding: '0 6px 26px',
      boxSizing: 'border-box',
      background: 'rgba(255,255,255,.9)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      boxShadow: '0 -1px 0 var(--border-subtle)',
      ...style
    }
  }, items.slice(0, centerAction ? half : items.length).map(render), centerAction && /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      display: 'flex',
      justifyContent: 'center',
      paddingTop: 2
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: centerAction.onClick,
    "aria-label": centerAction.label || 'Create',
    style: {
      width: 56,
      height: 46,
      borderRadius: 999,
      border: 0,
      background: 'var(--accent)',
      color: '#fff',
      boxShadow: '0 3px 0 var(--accent-shade)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: centerAction.icon || 'plus',
    size: 26,
    strokeWidth: 2.75
  }))), centerAction && items.slice(half).map(render));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// design-system/components/navigation/Tabs.jsx
try { (() => {
function Tabs({
  items = [],
  value,
  onChange,
  variant = 'segmented',
  style
}) {
  const seg = variant === 'segmented';
  return /*#__PURE__*/React.createElement("div", {
    role: "tablist",
    style: {
      display: 'flex',
      gap: seg ? 2 : 22,
      padding: seg ? 4 : 0,
      borderRadius: 999,
      background: seg ? 'var(--paper-2)' : 'transparent',
      ...style
    }
  }, items.map(it => {
    const id = it.id ?? it.label ?? it;
    const label = it.label ?? it;
    const on = id === value;
    return /*#__PURE__*/React.createElement("button", {
      key: id,
      role: "tab",
      "aria-selected": on,
      onClick: () => onChange && onChange(id),
      style: {
        flex: seg ? 1 : undefined,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        border: 0,
        cursor: 'pointer',
        height: seg ? 38 : 40,
        padding: seg ? '0 14px' : 0,
        borderRadius: 999,
        background: seg && on ? 'var(--white)' : 'transparent',
        boxShadow: seg && on ? '0 1px 3px rgba(29,27,24,.12)' : 'none',
        color: on ? 'var(--text-primary)' : 'var(--text-tertiary)',
        font: `${on ? 800 : 600} 15px/1 var(--font-display)`,
        position: 'relative',
        transition: 'all var(--dur-fast) var(--ease-out)'
      }
    }, label, it.count != null && /*#__PURE__*/React.createElement("span", {
      style: {
        minWidth: 20,
        height: 20,
        padding: '0 6px',
        boxSizing: 'border-box',
        borderRadius: 999,
        background: 'var(--accent)',
        color: '#fff',
        font: '800 11px/20px var(--font-body)'
      }
    }, it.count), !seg && on && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        left: '20%',
        right: '20%',
        bottom: 0,
        height: 4,
        borderRadius: 4,
        background: 'var(--accent)'
      }
    }));
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// design-system/tailwind.config.js
try { (() => {
/**
 * Grip Gorillas — Tailwind preset. Every value points at a CSS custom property, so
 * load styles.css (or design-system/tokens/*.css) before Tailwind's output.
 * Usage: module.exports = { presets: [require('./design-system/tailwind.config.js')], content: [...] }
 * Generated from design-system/tokens — edit the tokens, not this file.
 */
module.exports = {
  theme: {
    colors: {
      transparent: "transparent",
      current: "currentColor",
      white: "var(--white)",
      paper: {
        "2": "var(--paper-2)",
        "3": "var(--paper-3)",
        DEFAULT: "var(--paper)"
      },
      ink: {
        "100": "var(--ink-100)",
        "200": "var(--ink-200)",
        "300": "var(--ink-300)",
        "400": "var(--ink-400)",
        "500": "var(--ink-500)",
        "700": "var(--ink-700)",
        "800": "var(--ink-800)",
        "900": "var(--ink-900)"
      },
      coral: {
        "100": "var(--coral-100)",
        "300": "var(--coral-300)",
        "500": "var(--coral-500)",
        "600": "var(--coral-600)",
        "700": "var(--coral-700)"
      },
      sun: {
        "100": "var(--sun-100)",
        "400": "var(--sun-400)",
        "600": "var(--sun-600)"
      },
      mint: {
        "100": "var(--mint-100)",
        "500": "var(--mint-500)",
        "700": "var(--mint-700)"
      },
      sky: {
        "100": "var(--sky-100)",
        "500": "var(--sky-500)",
        "700": "var(--sky-700)"
      },
      plum: {
        "100": "var(--plum-100)",
        "500": "var(--plum-500)",
        "700": "var(--plum-700)"
      },
      flame: {
        "100": "var(--flame-100)",
        "500": "var(--flame-500)"
      },
      belt: {
        white: "var(--belt-white)",
        blue: "var(--belt-blue)",
        purple: "var(--belt-purple)",
        brown: "var(--belt-brown)",
        black: "var(--belt-black)",
        coral: "var(--belt-coral)",
        red: "var(--belt-red)",
        grey: "var(--belt-grey)",
        yellow: "var(--belt-yellow)",
        orange: "var(--belt-orange)",
        green: "var(--belt-green)",
        "bar-black": "var(--belt-bar-black)",
        "bar-red": "var(--belt-bar-red)",
        stripe: "var(--belt-stripe)"
      },
      success: {
        DEFAULT: "var(--success-500)",
        tint: "var(--success-tint)"
      },
      warning: {
        DEFAULT: "var(--warning-500)",
        tint: "var(--warning-tint)"
      },
      danger: {
        DEFAULT: "var(--danger-500)",
        tint: "var(--danger-tint)"
      },
      info: {
        DEFAULT: "var(--info-500)",
        tint: "var(--info-tint)"
      },
      accent: {
        DEFAULT: "var(--accent)",
        hover: "var(--accent-hover)",
        press: "var(--accent-press)",
        shade: "var(--accent-shade)",
        tint: "var(--accent-tint)"
      }
    },
    backgroundColor: {
      app: "var(--bg-app)",
      card: "var(--surface-card)",
      sunken: "var(--surface-sunken)",
      input: "var(--surface-input)",
      overlay: "var(--surface-overlay)",
      inverse: "var(--surface-inverse)"
    },
    textColor: {
      primary: "var(--text-primary)",
      secondary: "var(--text-secondary)",
      tertiary: "var(--text-tertiary)",
      disabled: "var(--text-disabled)",
      inverse: "var(--text-inverse)",
      "on-accent": "var(--text-on-accent)",
      accent: "var(--text-accent)",
      link: "var(--text-link)"
    },
    borderColor: {
      subtle: "var(--border-subtle)",
      DEFAULT: "var(--border-default)",
      strong: "var(--border-strong)",
      focus: "var(--border-focus)"
    },
    fontFamily: {
      display: ["var(--font-display)"],
      body: ["var(--font-body)"],
      mono: ["var(--font-mono)"]
    },
    fontSize: {
      "display-xl": ["var(--text-display-xl)", {
        lineHeight: "var(--lh-display-xl)"
      }],
      "display-l": ["var(--text-display-l)", {
        lineHeight: "var(--lh-display-l)"
      }],
      "display-m": ["var(--text-display-m)", {
        lineHeight: "var(--lh-display-m)"
      }],
      "title-l": ["var(--text-title-l)", {
        lineHeight: "var(--lh-title-l)"
      }],
      "title-m": ["var(--text-title-m)", {
        lineHeight: "var(--lh-title-m)"
      }],
      "title-s": ["var(--text-title-s)", {
        lineHeight: "var(--lh-title-s)"
      }],
      "body-l": ["var(--text-body-l)", {
        lineHeight: "var(--lh-body-l)"
      }],
      body: ["var(--text-body)", {
        lineHeight: "var(--lh-body)"
      }],
      "body-s": ["var(--text-body-s)", {
        lineHeight: "var(--lh-body-s)"
      }],
      caption: ["var(--text-caption)", {
        lineHeight: "var(--lh-caption)"
      }],
      overline: ["var(--text-overline)", {
        lineHeight: "var(--lh-overline)"
      }]
    },
    letterSpacing: {
      display: "var(--tracking-display)",
      title: "var(--tracking-title)",
      overline: "var(--tracking-overline)"
    },
    spacing: {
      "0": "var(--space-0)",
      "1": "var(--space-1)",
      "2": "var(--space-2)",
      "3": "var(--space-3)",
      "4": "var(--space-4)",
      "5": "var(--space-5)",
      "6": "var(--space-6)",
      "7": "var(--space-7)",
      "8": "var(--space-8)",
      "9": "var(--space-9)",
      "10": "var(--space-10)",
      "11": "var(--space-11)"
    },
    borderRadius: {
      none: "0",
      xs: "var(--radius-xs)",
      sm: "var(--radius-sm)",
      md: "var(--radius-md)",
      lg: "var(--radius-lg)",
      xl: "var(--radius-xl)",
      full: "var(--radius-pill)"
    },
    boxShadow: {
      none: "none",
      hairline: "var(--shadow-hairline)",
      card: "var(--shadow-card)",
      float: "var(--shadow-float)",
      sheet: "var(--shadow-sheet)",
      press: "var(--shadow-press)",
      focus: "var(--ring-focus)"
    },
    transitionTimingFunction: {
      out: "var(--ease-out)",
      "in-out": "var(--ease-in-out)",
      bounce: "var(--ease-bounce)"
    },
    transitionDuration: {
      fast: "var(--dur-fast)",
      base: "var(--dur-base)",
      slow: "var(--dur-slow)"
    }
  },
  plugins: []
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "design-system/tailwind.config.js", error: String((e && e.message) || e) }); }

// ui_kits/app/Activity.jsx
try { (() => {
const {
  Avatar: AAv,
  AvatarStack: AStack,
  IconButton: AIB,
  Icon: AIcon,
  Button: ABtn,
  Dialog: ADlg,
  Input: AIn,
  Badge: ABadge
} = window.GripGorillasDesignSystem_8b0f80;
const MMCtx = React.createContext(null);
const useMM = () => React.useContext(MMCtx);
function PostCard({
  post,
  highlight
}) {
  const mm = useMM();
  const P = mm.person;
  const org = P(post.organizer);
  const liked = post.likes.includes('me');
  const others = post.participants.filter(x => x !== post.organizer).map(x => x === 'me' ? 'You' : P(x).name);
  const [burst, setBurst] = React.useState(0);
  const dbl = () => {
    if (!liked) mm.like(post.id);
    setBurst(b => b + 1);
  };
  return /*#__PURE__*/React.createElement("article", {
    style: {
      margin: '0 12px 14px',
      padding: 12,
      background: 'var(--white)',
      borderRadius: 28,
      boxShadow: highlight ? '0 0 0 3px var(--coral-300), var(--shadow-card)' : 'var(--shadow-card)',
      animation: highlight ? 'mmPop .5s var(--ease-bounce)' : 'none'
    }
  }, /*#__PURE__*/React.createElement(Row, {
    style: {
      padding: '2px 2px 12px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    onClick: () => post.organizer !== 'me' && mm.go('friend', {
      id: post.organizer
    }),
    style: {
      cursor: 'pointer',
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement(AAv, {
    name: org.name,
    src: org.src,
    size: 42,
    belt: org.belt,
    ring: "var(--white)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '400 14px/1.3 var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, /*#__PURE__*/React.createElement("b", {
    style: {
      font: '700 15px var(--font-body)',
      color: 'var(--ink-900)'
    }
  }, post.organizer === 'me' ? 'You' : org.name), " trained with ", names(others, 2)), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 13px var(--font-body)',
      color: 'var(--text-tertiary)',
      marginTop: 2
    }
  }, post.date, " \xB7 ", post.ago)), /*#__PURE__*/React.createElement(AIB, {
    icon: "ellipsis",
    size: 36,
    label: "Post options",
    onClick: () => mm.go('post', {
      id: post.id,
      menu: true
    })
  })), /*#__PURE__*/React.createElement(PhotoTile, {
    src: post.photo,
    h: 300,
    radius: 20,
    onClick: null,
    style: {
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onDoubleClick: dbl,
    onClick: () => mm.go('post', {
      id: post.id
    }),
    style: {
      position: 'absolute',
      inset: 0
    }
  }), /*#__PURE__*/React.createElement(TapeLabel, {
    style: {
      position: 'absolute',
      left: 12,
      bottom: 14
    }
  }, /*#__PURE__*/React.createElement(AIcon, {
    name: "map-pin",
    size: 13,
    strokeWidth: 2.5
  }), post.gym), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      right: 12,
      bottom: 12
    }
  }, /*#__PURE__*/React.createElement(AStack, {
    people: post.participants.map(P),
    size: 30,
    ring: "#fff",
    max: 4
  })), burst > 0 && /*#__PURE__*/React.createElement("span", {
    key: burst,
    style: {
      position: 'absolute',
      left: '50%',
      top: '50%',
      marginLeft: -44,
      marginTop: -44,
      animation: 'mmHeartBurst .8s var(--ease-out) forwards',
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement(AIcon, {
    name: "heart",
    size: 88,
    filled: true,
    color: "#fff",
    strokeWidth: 1.5
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 4px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 21px/1.15 var(--font-display)',
      letterSpacing: '-.025em',
      color: 'var(--ink-900)'
    }
  }, post.title), post.caption && /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '6px 0 0',
      font: '400 15px/1.45 var(--font-body)',
      color: 'var(--ink-800)',
      textWrap: 'pretty'
    }
  }, post.caption)), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 2,
      marginTop: 8,
      marginLeft: -4
    }
  }, /*#__PURE__*/React.createElement(AIB, {
    icon: "heart",
    label: "Like",
    size: 40,
    active: liked,
    filledWhenActive: true,
    onClick: () => mm.like(post.id),
    style: {
      animation: liked ? 'mmLike .4s var(--ease-bounce)' : 'none'
    }
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    w: 700,
    style: {
      marginRight: 10
    }
  }, post.likes.length + post.extraLikes), /*#__PURE__*/React.createElement(AIB, {
    icon: "message-circle",
    label: "Comment",
    size: 40,
    onClick: () => mm.go('post', {
      id: post.id,
      focus: true
    })
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    w: 700
  }, post.comments.length), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 5,
      paddingRight: 6
    }
  }, /*#__PURE__*/React.createElement(AIcon, {
    name: "users",
    size: 15,
    color: "var(--text-tertiary)"
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 12,
    w: 600,
    c: "var(--text-tertiary)"
  }, "On ", post.participants.length, " profiles"))), post.comments[0] && /*#__PURE__*/React.createElement("div", {
    onClick: () => mm.go('post', {
      id: post.id
    }),
    style: {
      padding: '2px 4px 4px',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 14
  }, /*#__PURE__*/React.createElement("b", null, P(post.comments[0].who).name.split(' ')[0]), " ", post.comments[0].text), post.comments.length > 1 && /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 13px var(--font-body)',
      color: 'var(--text-tertiary)',
      marginTop: 4
    }
  }, "View all ", post.comments.length, " comments")));
}
function StreakNudges() {
  const mm = useMM();
  const list = mm.s.friends.filter(f => f.thisWeek === 'pending' && mm.streakOf(f) > 0);
  if (!list.length) return null;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      overflowX: 'auto',
      padding: '2px 12px 16px',
      ...hideScroll
    }
  }, list.map(f => {
    const p = mm.person(f.id);
    const n = mm.streakOf(f);
    const [c, tint, ink] = HUEV[p.hue];
    return /*#__PURE__*/React.createElement("div", {
      key: f.id,
      onClick: () => mm.go('friend', {
        id: f.id
      }),
      style: {
        flexShrink: 0,
        width: 262,
        padding: 14,
        borderRadius: 24,
        background: tint,
        display: 'flex',
        gap: 12,
        alignItems: 'center',
        cursor: 'pointer'
      }
    }, /*#__PURE__*/React.createElement(PairAvatars, {
      a: mm.s.me,
      b: p,
      size: 38,
      hue: p.hue
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        font: '800 16px/1.15 var(--font-display)',
        letterSpacing: '-.02em',
        color: ink
      }
    }, n, " weeks with ", p.name.split(' ')[0]), /*#__PURE__*/React.createElement("div", {
      style: {
        font: '500 13px/1.3 var(--font-body)',
        color: 'var(--ink-700)',
        marginTop: 3
      }
    }, "Roll together by Sunday to make it ", n + 1)), /*#__PURE__*/React.createElement(AIcon, {
      name: "flame",
      size: 22,
      filled: true,
      color: "var(--flame-500)"
    }));
  }));
}
function ActivityScreen({
  highlight
}) {
  const mm = useMM();
  const unread = mm.s.notifications.filter(n => n.unread).length;
  return /*#__PURE__*/React.createElement(Screen, {
    tabPad: true,
    header: /*#__PURE__*/React.createElement(Header, {
      large: true,
      title: /*#__PURE__*/React.createElement("span", null, "grip gorillas", /*#__PURE__*/React.createElement("span", {
        style: {
          color: 'var(--accent)'
        }
      }, ".")),
      right: /*#__PURE__*/React.createElement(AIB, {
        icon: "bell",
        label: "Notifications",
        badge: unread || false,
        onClick: () => mm.go('notifications')
      })
    })
  }, /*#__PURE__*/React.createElement(StreakNudges, null), mm.s.posts.map(p => /*#__PURE__*/React.createElement(PostCard, {
    key: p.id,
    post: p,
    highlight: p.id === highlight
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      padding: '10px 40px 20px',
      font: '500 13px/1.45 var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, "That's everything from your crew this week.", /*#__PURE__*/React.createElement("br", null), "Go make a new memory."));
}
function PostDetail({
  id,
  menu,
  focus
}) {
  const mm = useMM();
  const P = mm.person;
  const post = mm.s.posts.find(p => p.id === id);
  const [text, setText] = React.useState('');
  const [sheet, setSheet] = React.useState(menu ? 'menu' : null);
  const [editing, setEditing] = React.useState(false);
  const [cap, setCap] = React.useState(post ? post.caption : '');
  if (!post) return null;
  const isOrg = post.organizer === 'me';
  const isIn = post.participants.includes('me');
  const send = () => {
    if (!text.trim()) return;
    mm.comment(post.id, text.trim());
    setText('');
  };
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(AIB, {
        icon: "chevron-left",
        label: "Back",
        onClick: mm.back
      }),
      title: post.title,
      right: isOrg || isIn ? /*#__PURE__*/React.createElement(AIB, {
        icon: "ellipsis",
        label: "Options",
        onClick: () => setSheet('menu')
      }) : null
    }),
    footer: /*#__PURE__*/React.createElement(Row, {
      style: {
        gap: 8
      }
    }, /*#__PURE__*/React.createElement(AAv, {
      name: mm.s.me.name,
      src: mm.s.me.src,
      size: 36
    }), /*#__PURE__*/React.createElement(AIn, {
      placeholder: "Say something nice\u2026",
      value: text,
      onChange: e => setText(e.target.value),
      onKeyDown: e => e.key === 'Enter' && send(),
      autoFocus: !!focus,
      style: {
        flex: 1
      }
    }), /*#__PURE__*/React.createElement(AIB, {
      icon: "send",
      variant: "accent",
      label: "Send",
      onClick: send
    }))
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 12px'
    }
  }, /*#__PURE__*/React.createElement(PhotoTile, {
    src: post.photo,
    h: 340,
    radius: 24
  }, /*#__PURE__*/React.createElement(TapeLabel, {
    style: {
      position: 'absolute',
      left: 12,
      bottom: 14
    }
  }, /*#__PURE__*/React.createElement(AIcon, {
    name: "map-pin",
    size: 13,
    strokeWidth: 2.5
  }), post.gym)), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 6px 0'
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    w: 600,
    c: "var(--text-tertiary)"
  }, post.date, " \xB7 organized by ", isOrg ? 'you' : P(post.organizer).name), editing ? /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 10
    }
  }, /*#__PURE__*/React.createElement(AIn, {
    multiline: true,
    rows: 3,
    value: cap,
    onChange: e => setCap(e.target.value)
  }), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8,
      marginTop: 10
    }
  }, /*#__PURE__*/React.createElement(ABtn, {
    size: "sm",
    onClick: () => {
      mm.editCaption(post.id, cap);
      setEditing(false);
    }
  }, "Save"), /*#__PURE__*/React.createElement(ABtn, {
    size: "sm",
    variant: "ghost",
    onClick: () => setEditing(false)
  }, "Cancel"))) : /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '8px 0 0',
      font: '400 16px/1.5 var(--font-body)',
      color: 'var(--ink-800)'
    }
  }, post.caption), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 18,
      font: '800 16px var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, "On the mat"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      overflowX: 'auto',
      padding: '12px 0 4px',
      ...hideScroll
    }
  }, post.participants.map(x => {
    const p = P(x);
    return /*#__PURE__*/React.createElement("div", {
      key: x,
      style: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 6,
        width: 60,
        flexShrink: 0
      }
    }, /*#__PURE__*/React.createElement(AAv, {
      name: p.name,
      src: p.src,
      size: 52,
      belt: p.belt
    }), /*#__PURE__*/React.createElement(Txt, {
      s: 12,
      w: 600,
      style: {
        textAlign: 'center'
      }
    }, x === 'me' ? 'You' : p.name.split(' ')[0]), x === post.organizer && /*#__PURE__*/React.createElement(ABadge, {
      variant: "soft",
      style: {
        height: 18,
        padding: '0 6px',
        fontSize: 10
      }
    }, "Host"));
  })), /*#__PURE__*/React.createElement(Row, {
    style: {
      marginTop: 14,
      gap: 4,
      marginLeft: -6
    }
  }, /*#__PURE__*/React.createElement(AIB, {
    icon: "heart",
    label: "Like",
    active: post.likes.includes('me'),
    filledWhenActive: true,
    onClick: () => mm.like(post.id)
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    w: 600,
    c: "var(--text-secondary)"
  }, "Liked by ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: 'var(--ink-900)'
    }
  }, names(post.likes.map(l => l === 'me' ? 'You' : P(l).name), 2)), " and ", post.extraLikes, " others")), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 8,
      display: 'flex',
      flexDirection: 'column',
      gap: 14,
      paddingBottom: 16
    }
  }, post.comments.map((c, i) => {
    const p = P(c.who);
    return /*#__PURE__*/React.createElement(Row, {
      key: i,
      style: {
        alignItems: 'flex-start',
        animation: c.fresh ? 'mmFadeUp .35s var(--ease-out)' : 'none'
      }
    }, /*#__PURE__*/React.createElement(AAv, {
      name: p.name,
      src: p.src,
      size: 34
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        background: 'var(--white)',
        borderRadius: '6px 18px 18px 18px',
        padding: '9px 13px',
        boxShadow: 'var(--shadow-hairline)'
      }
    }, /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 700
    }, c.who === 'me' ? 'You' : p.name), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Txt, {
      s: 15
    }, c.text))));
  }), !post.comments.length && /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)"
  }, "No comments yet. Be the first.")))), sheet === 'menu' && /*#__PURE__*/React.createElement(ADlg, {
    contained: true,
    variant: "sheet",
    onClose: () => setSheet(null),
    title: isOrg ? 'Your post' : 'Post options',
    description: isOrg ? 'Only you, the organizer, can edit or delete this post.' : `${P(post.organizer).name} organized this session.`
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8
    }
  }, isOrg && /*#__PURE__*/React.createElement(ABtn, {
    variant: "secondary",
    iconLeft: "pencil",
    fullWidth: true,
    onClick: () => {
      setSheet(null);
      setEditing(true);
    }
  }, "Edit caption"), isOrg && /*#__PURE__*/React.createElement(ABtn, {
    variant: "danger",
    iconLeft: "trash-2",
    fullWidth: true,
    onClick: () => setSheet('delete')
  }, "Delete post"), !isOrg && isIn && /*#__PURE__*/React.createElement(ABtn, {
    variant: "danger",
    iconLeft: "user-minus",
    fullWidth: true,
    onClick: () => {
      mm.removeMe(post.id);
    }
  }, "Remove me from this post"), !isOrg && !isIn && /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)"
  }, "You weren't in this session."))), sheet === 'delete' && /*#__PURE__*/React.createElement(ADlg, {
    contained: true,
    variant: "modal",
    title: "Delete this post?",
    description: `It disappears from all ${post.participants.length} profiles and your friends' feeds.`,
    onClose: () => setSheet(null),
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(ABtn, {
      variant: "secondary",
      fullWidth: true,
      onClick: () => setSheet(null)
    }, "Keep it"), /*#__PURE__*/React.createElement(ABtn, {
      variant: "danger",
      fullWidth: true,
      onClick: () => mm.deletePost(post.id)
    }, "Delete"))
  }));
}
Object.assign(window, {
  MMCtx,
  useMM,
  PostCard,
  ActivityScreen,
  PostDetail
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Activity.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/App.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  TabBar: XTab,
  Toast: XToast,
  Button: XBtn,
  Icon: XIcon
} = window.GripGorillasDesignSystem_8b0f80;
const clone = o => JSON.parse(JSON.stringify(o));
const TABS = [{
  id: 'activity',
  icon: 'house',
  label: 'Activity'
}, {
  id: 'training',
  icon: 'calendar',
  label: 'Training'
}, {
  id: 'friends',
  icon: 'users',
  label: 'Friends'
}, {
  id: 'profile',
  icon: 'user',
  label: 'Profile'
}];
const SCREENS = {
  post: PostDetail,
  session: SessionDetail,
  create: CreateScreen,
  complete: CompleteScreen,
  friend: FriendProfile,
  qr: QRScreen,
  notifications: NotificationsScreen
};
function useApp() {
  const [s, setS] = React.useState(() => ({
    ...clone(window.MM_SEED),
    drafts: [],
    emptyTraining: false
  }));
  const [tab, setTabRaw] = React.useState(() => localStorage.getItem('mm2-tab') || 'activity');
  const [stack, setStack] = React.useState([]);
  const [toastMsg, setToast] = React.useState(null);
  const [highlight, setHighlight] = React.useState(null);
  const [fresh, setFresh] = React.useState(null);
  const timers = React.useRef([]);
  const later = (fn, ms) => timers.current.push(setTimeout(fn, ms));
  React.useEffect(() => {
    localStorage.setItem('mm2-tab', tab);
  }, [tab]);
  const up = fn => setS(prev => {
    const n = clone(prev);
    fn(n);
    return n;
  });
  const person = id => id === 'me' ? s.me : s.people[id];
  const streakOf = f => {
    let n = 0;
    for (let i = f.weeks.length - 1; i >= 0 && f.weeks[i]; i--) n++;
    return n + (f.thisWeek === 'done' ? 1 : 0);
  };
  const toast = (message, variant = 'default') => {
    setToast({
      message,
      variant,
      k: Date.now()
    });
    later(() => setToast(t => t && t.message === message ? null : t), 2600);
  };
  const go = (name, props = {}) => setStack(st => [...st, {
    name,
    props,
    key: Date.now() + Math.random()
  }]);
  const back = () => setStack(st => st.slice(0, -1));
  const replace = (name, props = {}) => setStack(st => [...st.slice(0, -1), {
    name,
    props,
    key: Date.now()
  }]);
  const setTab = t => {
    setStack([]);
    setTabRaw(t);
  };
  const findSession = id => s.upcoming.find(x => x.id === id) || (s.toComplete && s.toComplete.id === id ? s.toComplete : null) || s.drafts.find(x => x.id === id);
  const mm = {
    s,
    person,
    streakOf,
    toast,
    go,
    back,
    setTab,
    findSession,
    fresh,
    like: id => up(n => {
      const p = n.posts.find(x => x.id === id);
      p.likes = p.likes.includes('me') ? p.likes.filter(x => x !== 'me') : ['me', ...p.likes];
    }),
    comment: (id, text) => up(n => {
      n.posts.find(x => x.id === id).comments.push({
        who: 'me',
        text,
        fresh: true
      });
    }),
    editCaption: (id, cap) => {
      up(n => {
        n.posts.find(x => x.id === id).caption = cap;
      });
      toast('Caption updated', 'success');
    },
    deletePost: id => {
      up(n => {
        n.posts = n.posts.filter(x => x.id !== id);
      });
      back();
      toast('Post deleted from every profile');
    },
    removeMe: id => {
      up(n => {
        const p = n.posts.find(x => x.id === id);
        p.participants = p.participants.filter(x => x !== 'me');
      });
      back();
      toast("You're off that post. It's gone from your profile.");
    },
    rsvp: (sid, st) => {
      up(n => {
        n.upcoming.find(x => x.id === sid).people.me = st;
        n.notifications.forEach(x => {
          if (x.session === sid) x.unread = false;
        });
      });
      if (st === 'going') {
        setFresh(sid + 'me');
        toast("You're in. See you on the mat.", 'success');
      } else toast('Declined. No hard feelings.');
    },
    removeParticipant: (sid, pid) => {
      up(n => {
        delete n.upcoming.find(x => x.id === sid).people[pid];
      });
      toast(person(pid).name.split(' ')[0] + ' removed');
    },
    addParticipants: (sid, ids) => {
      up(n => {
        const x = n.upcoming.find(y => y.id === sid);
        ids.forEach(i => x.people[i] = 'going');
      });
      setFresh(sid + ids[0]);
      toast(`Added ${ids.length} to the session`, 'success');
    },
    createSession: d => {
      const id = 'n' + Date.now();
      const people = {
        me: 'going'
      };
      d.invited.forEach(i => people[i] = d.past ? 'going' : 'invited');
      const sess = {
        id,
        title: d.title,
        day: d.day,
        date: d.date,
        month: d.month,
        time: d.time,
        gym: d.gym,
        organizer: 'me',
        privacy: d.privacy,
        note: d.note,
        people
      };
      if (d.past) {
        up(n => {
          n.drafts.push(sess);
        });
        replace('complete', {
          id
        });
        return;
      }
      up(n => {
        n.upcoming.push(sess);
        n.emptyTraining = false;
      });
      replace('session', {
        id
      });
      toast(d.invited.length ? `Invites sent to ${d.invited.length}` : 'Session created', 'success');
      d.invited.slice(0, 2).forEach((pid, i) => later(() => {
        up(n => {
          const x = n.upcoming.find(y => y.id === id);
          if (x) x.people[pid] = 'going';
          n.notifications.unshift({
            id: 'j' + Date.now(),
            kind: 'joined',
            who: pid,
            text: 'joined ' + d.title,
            time: 'now',
            unread: true
          });
        });
        setFresh(id + pid);
        toast(`${person(pid).name.split(' ')[0]} joined ${d.title}`, 'friend');
      }, 2200 + i * 2000));
    },
    publish: (sid, {
      photo,
      caption,
      people
    }) => {
      const sess = findSession(sid);
      const post = {
        id: 'p' + Date.now(),
        organizer: 'me',
        title: sess.title,
        gym: sess.gym,
        date: `${sess.day}, ${sess.month} ${sess.date}`,
        ago: 'now',
        photo,
        participants: people,
        caption,
        likes: [],
        extraLikes: 0,
        comments: []
      };
      const streaks = [];
      s.friends.forEach(f => {
        if (people.includes(f.id) && f.thisWeek !== 'done') {
          const from = streakOf(f);
          streaks.push({
            id: f.id,
            from,
            to: from + 1,
            f: clone(f)
          });
        }
      });
      up(n => {
        n.posts.unshift(post);
        n.upcoming = n.upcoming.filter(x => x.id !== sid);
        n.drafts = n.drafts.filter(x => x.id !== sid);
        if (n.toComplete && n.toComplete.id === sid) n.toComplete = null;
        n.friends.forEach(f => {
          if (people.includes(f.id)) f.thisWeek = 'done';
        });
      });
      return {
        post,
        streaks
      };
    },
    showPost: id => {
      setStack([]);
      setTabRaw('activity');
      setHighlight(id);
      later(() => setHighlight(null), 2500);
      later(() => {
        up(n => {
          const p = n.posts.find(x => x.id === id);
          if (p) {
            p.likes = ['sarah'];
            p.extraLikes = 0;
          }
        });
        toast('Sarah liked your post', 'friend');
      }, 1800);
      later(() => {
        up(n => {
          const p = n.posts.find(x => x.id === id);
          if (p) {
            p.likes.push('alex');
            p.comments.push({
              who: 'alex',
              text: 'Great rounds today. Same time next week?',
              fresh: true
            });
          }
        });
        toast('Alex commented on your post');
      }, 3800);
    },
    addFriend: id => up(n => {
      if (!n.friends.find(f => f.id === id)) n.friends.unshift({
        id,
        weeks: [false, false, false, false, false, false, false, false, false],
        thisWeek: 'pending',
        best: 0,
        together: 0
      });
    }),
    readAll: () => up(n => n.notifications.forEach(x => x.unread = false))
  };
  const reset = () => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
    setS({
      ...clone(window.MM_SEED),
      drafts: [],
      emptyTraining: false
    });
    setStack([]);
    setToast(null);
    setHighlight(null);
  };
  return {
    mm,
    tab,
    setTabRaw,
    stack,
    setStack,
    toastMsg,
    highlight,
    reset,
    up
  };
}
function App() {
  const app = useApp();
  const {
    mm,
    tab,
    stack,
    toastMsg,
    highlight
  } = app;
  window.__mm = app;
  React.useEffect(() => {
    const h = location.hash.slice(1);
    if (h) runPreset(app, h);
  }, []);
  const TabScreen = {
    activity: ActivityScreen,
    training: TrainingScreen,
    friends: FriendsScreen,
    profile: ProfileScreen
  }[tab] || ActivityScreen;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 56,
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      padding: '32px 24px',
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement(ReviewPanel, {
    app: app
  }), /*#__PURE__*/React.createElement(MMCtx.Provider, {
    value: mm
  }, /*#__PURE__*/React.createElement(Phone, null, /*#__PURE__*/React.createElement(TabScreen, {
    key: tab,
    highlight: highlight
  }), stack.map(st => {
    const C = SCREENS[st.name];
    return /*#__PURE__*/React.createElement(C, _extends({
      key: st.key
    }, st.props));
  }), stack.length === 0 && /*#__PURE__*/React.createElement(XTab, {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 0,
      zIndex: 20
    },
    value: tab,
    onChange: mm.setTab,
    items: TABS.map(t => t.id === 'friends' ? {
      ...t,
      badge: mm.s.friends.some(f => mm.streakOf(f) > 0 && f.thisWeek === 'pending')
    } : t),
    centerAction: {
      icon: 'plus',
      label: 'Plan a session',
      onClick: () => mm.go('create')
    }
  }), toastMsg && /*#__PURE__*/React.createElement("div", {
    key: toastMsg.k,
    style: {
      position: 'absolute',
      top: 6,
      left: 12,
      right: 12,
      zIndex: 85,
      animation: 'mmToast .4s var(--ease-bounce)'
    }
  }, /*#__PURE__*/React.createElement(XToast, {
    variant: toastMsg.variant,
    message: toastMsg.message
  })))));
}
const PRESETS = {
  activity: a => a.mm.setTab('activity'),
  training: a => a.mm.setTab('training'),
  friends: a => a.mm.setTab('friends'),
  profile: a => a.mm.setTab('profile'),
  create: a => {
    a.mm.setTab('training');
    setTimeout(() => a.mm.go('create'), 30);
  },
  complete: a => {
    a.mm.setTab('training');
    setTimeout(() => a.mm.go('complete', {
      id: 'c1'
    }), 30);
  },
  qr: a => {
    a.mm.setTab('friends');
    setTimeout(() => a.mm.go('qr'), 30);
  },
  scan: a => {
    a.mm.setTab('friends');
    setTimeout(() => a.mm.go('qr', {
      tab: 'scan'
    }), 30);
  },
  notifications: a => {
    a.mm.setTab('activity');
    setTimeout(() => a.mm.go('notifications'), 30);
  },
  post: a => {
    a.mm.setTab('activity');
    setTimeout(() => a.mm.go('post', {
      id: 'p1'
    }), 30);
  },
  empty: a => {
    a.up(n => {
      n.emptyTraining = true;
    });
    a.mm.setTab('training');
  },
  invite: a => {
    a.mm.setTab('training');
    setTimeout(() => a.mm.go('session', {
      id: 's2'
    }), 30);
  },
  broken: a => {
    a.mm.setTab('friends');
    setTimeout(() => a.mm.go('friend', {
      id: 'jamie'
    }), 30);
  },
  active: a => {
    a.mm.setTab('friends');
    setTimeout(() => a.mm.go('friend', {
      id: 'sarah'
    }), 30);
  }
};
function runPreset(app, key) {
  app.reset();
  setTimeout(() => PRESETS[key] && PRESETS[key](app), 20);
}
const JOURNEYS = [{
  k: 'A',
  title: 'Plan training together',
  start: 'training',
  steps: ['Training tab → Plan a training session', 'Pick a day, time and gym', 'Tap friends to invite → Send', 'Watch Sarah & Alex join live']
}, {
  k: 'B',
  title: 'Share a training memory',
  start: 'training',
  steps: ['"How was Halloween open mat?" → Complete & share', 'Take photo → pick one', 'Toggle Training completed → Publish', 'See it in Activity; friends like & comment']
}, {
  k: 'C',
  title: 'Keep a friendship streak',
  start: 'friends',
  steps: ['Friends → tap You + Sarah', 'Invite Sarah to train → send', 'Training → Complete & share with Sarah in it', 'Streak ticks 8 → 9']
}];
function ReviewPanel({
  app
}) {
  const [j, setJ] = React.useState(null);
  const L = ({
    k,
    children
  }) => /*#__PURE__*/React.createElement("button", {
    onClick: () => runPreset(app, k),
    style: {
      display: 'block',
      width: '100%',
      textAlign: 'left',
      border: 0,
      background: 'transparent',
      padding: '6px 10px',
      borderRadius: 10,
      cursor: 'pointer',
      font: '500 14px var(--font-body)',
      color: 'var(--ink-800)'
    },
    onMouseEnter: e => e.currentTarget.style.background = 'var(--paper-2)',
    onMouseLeave: e => e.currentTarget.style.background = 'transparent'
  }, children);
  const H = ({
    children
  }) => /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 13px var(--font-display)',
      color: 'var(--ink-500)',
      margin: '18px 10px 6px',
      letterSpacing: '-.01em'
    }
  }, children);
  return /*#__PURE__*/React.createElement("aside", {
    className: "mm-panel",
    style: {
      width: 250,
      flexShrink: 0,
      alignSelf: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 26px/1 var(--font-display)',
      letterSpacing: '-.04em',
      padding: '0 10px'
    }
  }, "grip gorillas", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--accent)'
    }
  }, ".")), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 13px var(--font-body)',
      color: 'var(--ink-500)',
      padding: '6px 10px 0'
    }
  }, "First draft \xB7 interactive prototype \xB7 ", /*#__PURE__*/React.createElement("a", {
    href: "flows.html"
  }, "IA & flows")), /*#__PURE__*/React.createElement(H, null, "Journeys"), JOURNEYS.map(x => /*#__PURE__*/React.createElement("div", {
    key: x.k,
    style: {
      margin: '0 0 6px'
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: () => {
      setJ(j === x.k ? null : x.k);
      runPreset(app, x.start);
    },
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'center',
      width: '100%',
      textAlign: 'left',
      border: 0,
      cursor: 'pointer',
      padding: '8px 10px',
      borderRadius: 14,
      background: j === x.k ? 'var(--white)' : 'transparent',
      boxShadow: j === x.k ? 'var(--shadow-card)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 26,
      height: 26,
      borderRadius: 99,
      background: 'var(--accent)',
      color: '#fff',
      font: '800 13px/26px var(--font-display)',
      textAlign: 'center',
      flexShrink: 0
    }
  }, x.k), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '700 14px var(--font-body)',
      color: 'var(--ink-900)'
    }
  }, x.title)), j === x.k && /*#__PURE__*/React.createElement("ol", {
    style: {
      margin: '8px 0 6px',
      paddingLeft: 46,
      font: '400 13px/1.5 var(--font-body)',
      color: 'var(--ink-700)'
    }
  }, x.steps.map(s => /*#__PURE__*/React.createElement("li", {
    key: s
  }, s))))), /*#__PURE__*/React.createElement(H, null, "Screens"), [['activity', 'Activity feed'], ['training', 'Upcoming training'], ['create', 'Create session'], ['complete', 'Complete & share'], ['friends', 'Friends & streaks'], ['qr', 'QR code'], ['profile', 'Profile'], ['notifications', 'Notifications']].map(([k, l], i) => /*#__PURE__*/React.createElement(L, {
    key: k,
    k: k
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--ink-400)',
      font: '600 12px var(--font-mono)',
      marginRight: 8
    }
  }, i + 1), l)), /*#__PURE__*/React.createElement(H, null, "States"), [['empty', 'Empty training schedule'], ['invite', 'Pending invitation'], ['active', 'Active streak'], ['broken', 'Broken streak'], ['scan', 'Scan → instant friends'], ['post', 'Post detail + comments']].map(([k, l]) => /*#__PURE__*/React.createElement(L, {
    key: k,
    k: k
  }, l)), /*#__PURE__*/React.createElement("button", {
    onClick: app.reset,
    style: {
      marginTop: 14,
      marginLeft: 10,
      border: 0,
      background: 'transparent',
      cursor: 'pointer',
      font: '600 13px var(--font-body)',
      color: 'var(--coral-600)',
      padding: 0
    }
  }, "Reset demo"));
}
ReactDOM.createRoot(document.getElementById('root')).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Complete.jsx
try { (() => {
const {
  Avatar: KAv,
  AvatarStack: KStack,
  IconButton: KIB,
  Icon: KIcon,
  Button: KBtn,
  Input: KIn,
  Switch: KSw,
  Dialog: KDlg,
  StreakBelt: KBelt
} = window.GripGorillasDesignSystem_8b0f80;
function CompleteScreen({
  id
}) {
  const mm = useMM();
  const P = mm.person;
  const s = mm.findSession(id);
  const [removed, setRemoved] = React.useState([]);
  const [photo, setPhoto] = React.useState(null);
  const [roll, setRoll] = React.useState(false);
  const [caption, setCaption] = React.useState('');
  const [done, setDone] = React.useState(false);
  const [result, setResult] = React.useState(null);
  if (result) return /*#__PURE__*/React.createElement(Celebrate, {
    result: result
  });
  if (!s) return null;
  const people = Object.keys(s.people).filter(k => s.people[k] === 'going' && !removed.includes(k));
  const publish = () => setResult(mm.publish(s.id, {
    photo,
    caption,
    people
  }));
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(KIB, {
        icon: "x",
        label: "Close",
        onClick: mm.back
      }),
      title: "Share the session",
      sub: `${s.title} · ${s.day} ${s.month} ${s.date}`
    }),
    footer: /*#__PURE__*/React.createElement(KBtn, {
      size: "lg",
      fullWidth: true,
      iconLeft: "send",
      disabled: !done,
      onClick: publish
    }, done ? 'Publish to Activity' : 'Mark as completed to publish')
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px 16px 0'
    }
  }, photo ? /*#__PURE__*/React.createElement(PhotoTile, {
    src: photo,
    h: 330,
    radius: 26,
    style: {
      animation: 'mmPop .4s var(--ease-bounce)'
    }
  }, /*#__PURE__*/React.createElement(TapeLabel, {
    style: {
      position: 'absolute',
      left: 12,
      bottom: 14
    }
  }, /*#__PURE__*/React.createElement(KIcon, {
    name: "map-pin",
    size: 13,
    strokeWidth: 2.5
  }), s.gym), /*#__PURE__*/React.createElement(KIB, {
    icon: "repeat-2",
    variant: "overlay",
    label: "Change photo",
    size: 40,
    onClick: () => setRoll(true),
    style: {
      position: 'absolute',
      top: 12,
      right: 12
    }
  })) : /*#__PURE__*/React.createElement("div", {
    style: {
      height: 300,
      borderRadius: 26,
      background: 'var(--paper-2)',
      boxShadow: 'inset 0 0 0 2px var(--ink-200)',
      backgroundImage: 'repeating-linear-gradient(135deg, transparent 0 14px, rgba(29,27,24,.025) 14px 28px)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 14,
      textAlign: 'center',
      padding: 24
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 22px/1.15 var(--font-display)',
      letterSpacing: '-.03em'
    }
  }, "Grab the post-training photo"), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-secondary)"
  }, "Sweaty, smiling, slightly crooked. That's the one."), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8,
      marginTop: 4
    }
  }, /*#__PURE__*/React.createElement(KBtn, {
    iconLeft: "camera",
    onClick: () => setRoll(true)
  }, "Take photo"), /*#__PURE__*/React.createElement(KBtn, {
    variant: "secondary",
    iconLeft: "image-plus",
    onClick: () => setRoll(true)
  }, "Upload"))), /*#__PURE__*/React.createElement(KIn, {
    multiline: true,
    rows: 2,
    placeholder: "What happened on the mat?",
    value: caption,
    onChange: e => setCaption(e.target.value),
    style: {
      marginTop: 16
    }
  }), /*#__PURE__*/React.createElement(Row, {
    style: {
      justifyContent: 'space-between',
      margin: '22px 2px 10px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 16px var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, "Who trained"), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    w: 600,
    c: "var(--text-tertiary)"
  }, people.length, " people")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, Object.keys(s.people).filter(k => s.people[k] === 'going').map(k => {
    const p = P(k);
    const out = removed.includes(k);
    return /*#__PURE__*/React.createElement("span", {
      key: k,
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        height: 42,
        padding: '0 6px 0 4px',
        borderRadius: 99,
        background: out ? 'transparent' : 'var(--white)',
        boxShadow: out ? 'inset 0 0 0 1.5px var(--ink-200)' : 'var(--shadow-card)',
        opacity: out ? .5 : 1,
        transition: 'all var(--dur-base)'
      }
    }, /*#__PURE__*/React.createElement(KAv, {
      name: p.name,
      src: p.src,
      size: 34
    }), /*#__PURE__*/React.createElement(Txt, {
      s: 14,
      w: 600,
      style: {
        textDecoration: out ? 'line-through' : 'none'
      }
    }, k === 'me' ? 'You' : p.name.split(' ')[0]), k !== 'me' ? /*#__PURE__*/React.createElement(KIB, {
      icon: out ? 'plus' : 'x',
      size: 28,
      label: out ? 'Add back' : 'Remove',
      onClick: () => setRemoved(out ? removed.filter(x => x !== k) : [...removed, k])
    }) : /*#__PURE__*/React.createElement("span", {
      style: {
        width: 6
      }
    }));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 22,
      padding: 16,
      borderRadius: 22,
      background: done ? 'var(--mint-100)' : 'var(--white)',
      boxShadow: done ? 'none' : 'var(--shadow-card)',
      transition: 'background var(--dur-base)'
    }
  }, /*#__PURE__*/React.createElement(KSw, {
    label: "Training completed",
    description: "Counts toward weekly streaks for everyone here.",
    checked: done,
    onChange: setDone
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 20
    }
  })), roll && /*#__PURE__*/React.createElement(KDlg, {
    contained: true,
    variant: "sheet",
    title: "Recent photos",
    onClose: () => setRoll(false)
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      gap: 6
    }
  }, mm.s.cameraRoll.map(src => /*#__PURE__*/React.createElement("div", {
    key: src,
    onClick: () => {
      setPhoto(src);
      setRoll(false);
    },
    style: {
      aspectRatio: '1',
      borderRadius: 12,
      overflow: 'hidden',
      cursor: 'pointer',
      boxShadow: photo === src ? '0 0 0 3px var(--accent)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: src,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }))))));
}
function Counter({
  from,
  to,
  delay = 700
}) {
  const [v, setV] = React.useState(from);
  React.useEffect(() => {
    const t = setTimeout(() => setV(to), delay);
    return () => clearTimeout(t);
  }, []);
  return /*#__PURE__*/React.createElement("span", {
    key: v,
    style: {
      display: 'inline-block',
      animation: v !== from ? 'mmCount .5s var(--ease-bounce)' : 'none'
    }
  }, v);
}
function LiveBelt({
  f,
  hue,
  delay
}) {
  const [d, setD] = React.useState(false);
  React.useEffect(() => {
    const t = setTimeout(() => setD(true), delay);
    return () => clearTimeout(t);
  }, []);
  return /*#__PURE__*/React.createElement(KBelt, {
    weeks: f.weeks,
    thisWeek: d ? 'done' : 'pending',
    hue: hue,
    size: "sm"
  });
}
function Celebrate({
  result
}) {
  const mm = useMM();
  const {
    post,
    streaks
  } = result;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 40,
      background: 'var(--coral-500)',
      color: '#fff',
      display: 'flex',
      flexDirection: 'column',
      animation: 'mmFade .3s var(--ease-out)',
      overflowY: 'auto',
      ...hideScroll
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '24px 24px 0',
      textAlign: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 34px/1 var(--font-display)',
      letterSpacing: '-.04em'
    }
  }, "Shared with the crew"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 15px var(--font-body)',
      opacity: .9,
      marginTop: 8
    }
  }, "Now on ", post.participants.length, " profiles and in your friends' feeds.")), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '22px auto 0',
      width: 250,
      padding: '10px 10px 14px',
      background: '#FFFDF8',
      borderRadius: 8,
      boxShadow: '0 18px 40px rgba(90,20,0,.35)',
      animation: 'mmDrop .8s var(--ease-bounce) both',
      color: 'var(--ink-900)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      height: 200,
      borderRadius: 4,
      overflow: 'hidden',
      background: 'var(--paper-3)'
    }
  }, post.photo && /*#__PURE__*/React.createElement("img", {
    src: post.photo,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  })), /*#__PURE__*/React.createElement(Row, {
    style: {
      justifyContent: 'space-between',
      padding: '10px 4px 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 15px/1.1 var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, post.title), /*#__PURE__*/React.createElement(KStack, {
    people: post.participants.map(mm.person),
    size: 22,
    max: 3,
    ring: "#FFFDF8"
  }))), streaks.length > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '24px 16px 0',
      padding: '14px 16px',
      background: '#fff',
      borderRadius: 24,
      color: 'var(--ink-900)',
      animation: 'mmFadeUp .5s .5s var(--ease-out) both'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 16px var(--font-display)',
      letterSpacing: '-.02em',
      marginBottom: 6
    }
  }, "Streaks this week"), streaks.map((x, i) => {
    const p = mm.person(x.id);
    return /*#__PURE__*/React.createElement("div", {
      key: x.id,
      style: {
        padding: '10px 0',
        boxShadow: i < streaks.length - 1 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none'
      }
    }, /*#__PURE__*/React.createElement(Row, null, /*#__PURE__*/React.createElement(PairAvatars, {
      a: mm.s.me,
      b: p,
      size: 30,
      hue: p.hue
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement(Txt, {
      s: 15,
      w: 700
    }, p.name.split(' ')[0])), /*#__PURE__*/React.createElement("span", {
      style: {
        font: '800 22px var(--font-display)',
        letterSpacing: '-.03em',
        color: 'var(--flame-500)'
      }
    }, /*#__PURE__*/React.createElement(Counter, {
      from: x.from,
      to: x.to,
      delay: 1100 + i * 300
    })), /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 600,
      c: "var(--text-tertiary)"
    }, x.to === 1 ? 'week' : 'weeks')), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 8
      }
    }, /*#__PURE__*/React.createElement(LiveBelt, {
      f: x.f,
      hue: p.hue,
      delay: 1100 + i * 300
    })));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 16px 40px',
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      marginTop: 'auto'
    }
  }, /*#__PURE__*/React.createElement(KBtn, {
    size: "lg",
    variant: "inverse",
    fullWidth: true,
    onClick: () => mm.showPost(post.id)
  }, "See it in Activity")));
}
Object.assign(window, {
  CompleteScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Complete.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Create.jsx
try { (() => {
const {
  Avatar: CAv,
  IconButton: CIB,
  Icon: CIcon,
  Button: CBtn,
  Tag: CTag,
  Input: CIn,
  Tabs: CTabs,
  Switch: CSw,
  Dialog: CDlg,
  Badge: CBadge,
  Belt: CBelt
} = window.GripGorillasDesignSystem_8b0f80;
const FUT = [['Today', 'Mon', 2, 'Nov'], ['Tue', 'Tue', 3, 'Nov'], ['Wed', 'Wed', 4, 'Nov'], ['Thu', 'Thu', 5, 'Nov'], ['Fri', 'Fri', 6, 'Nov'], ['Sat', 'Sat', 7, 'Nov'], ['Sun', 'Sun', 8, 'Nov']];
const PAST = [['Yesterday', 'Sun', 1, 'Nov'], ['Sat', 'Sat', 31, 'Oct'], ['Fri', 'Fri', 30, 'Oct'], ['Thu', 'Thu', 29, 'Oct'], ['Wed', 'Wed', 28, 'Oct']];
const TIMES = ['6:30 AM', '12:15 PM', '6:00 PM', '7:30 PM'];
function Field({
  label,
  children,
  hint
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      marginTop: 22
    }
  }, /*#__PURE__*/React.createElement(Row, {
    style: {
      justifyContent: 'space-between',
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 16px var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, label), hint), children);
}
function CreateScreen({
  past: pastInit,
  friend
}) {
  const mm = useMM();
  const [past, setPast] = React.useState(!!pastInit);
  const days = past ? PAST : FUT;
  const [name, setName] = React.useState('');
  const [day, setDay] = React.useState(past ? 0 : 5);
  const [time, setTime] = React.useState(past ? '6:00 PM' : '10:00 AM');
  const [gym, setGym] = React.useState(mm.s.me.gym);
  const [note, setNote] = React.useState('');
  const [showNote, setShowNote] = React.useState(false);
  const [inv, setInv] = React.useState(friend ? [friend] : []);
  const [privacy, setPrivacy] = React.useState('friends');
  const [link, setLink] = React.useState(null);
  const d = days[Math.min(day, days.length - 1)];
  const autoName = d[1] === 'Sat' || d[1] === 'Sun' ? (d[1] === 'Sat' ? 'Saturday' : 'Sunday') + ' open mat' : time.includes('AM') ? 'Morning rolls' : time.startsWith('12') ? 'Lunch rolls' : 'Evening rolls';
  const toggle = id => setInv(inv.includes(id) ? inv.filter(x => x !== id) : [...inv, id]);
  const submit = () => mm.createSession({
    title: name.trim() || autoName,
    day: d[1],
    date: d[2],
    month: d[3],
    time,
    gym,
    note,
    invited: inv,
    privacy,
    past
  });
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(CIB, {
        icon: "x",
        label: "Close",
        onClick: mm.back
      }),
      title: past ? 'Log a past session' : 'Plan a session'
    }),
    footer: /*#__PURE__*/React.createElement(CBtn, {
      size: "lg",
      fullWidth: true,
      iconLeft: past ? 'camera' : 'send',
      onClick: submit
    }, past ? 'Next: add a photo' : inv.length ? `Send invites to ${inv.length}` : 'Create session')
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px'
    }
  }, /*#__PURE__*/React.createElement(CTabs, {
    items: [{
      id: 'plan',
      label: 'Upcoming'
    }, {
      id: 'past',
      label: 'Already happened'
    }],
    value: past ? 'past' : 'plan',
    onChange: v => {
      setPast(v === 'past');
      setDay(v === 'past' ? 0 : 5);
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '18px 16px 0'
    }
  }, /*#__PURE__*/React.createElement("input", {
    value: name,
    onChange: e => setName(e.target.value),
    placeholder: autoName,
    style: {
      width: '100%',
      border: 0,
      outline: 'none',
      background: 'transparent',
      font: '800 30px/1.1 var(--font-display)',
      letterSpacing: '-.035em',
      color: 'var(--ink-900)',
      padding: 0
    }
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--text-tertiary)"
  }, "Name it, or keep our suggestion.")), /*#__PURE__*/React.createElement(Field, {
    label: "When"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      overflowX: 'auto',
      margin: '0 -16px',
      padding: '0 16px 2px',
      ...hideScroll
    }
  }, days.map((x, i) => {
    const on = i === day;
    return /*#__PURE__*/React.createElement("button", {
      key: i,
      onClick: () => setDay(i),
      style: {
        flexShrink: 0,
        width: 62,
        height: 74,
        border: 0,
        borderRadius: 18,
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        background: on ? 'var(--ink-900)' : 'var(--white)',
        color: on ? 'var(--paper)' : 'var(--ink-900)',
        boxShadow: on ? 'none' : 'inset 0 0 0 1.5px var(--border-default)',
        transition: 'all var(--dur-fast) var(--ease-out)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: '700 12px var(--font-body)',
        opacity: .75
      }
    }, x[0]), /*#__PURE__*/React.createElement("span", {
      style: {
        font: '800 24px/1 var(--font-display)',
        letterSpacing: '-.03em'
      }
    }, x[2]));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap',
      marginTop: 10
    }
  }, [...new Set([time, ...TIMES])].map(t => /*#__PURE__*/React.createElement(CTag, {
    key: t,
    size: "sm",
    selected: time === t,
    onClick: () => setTime(t)
  }, t)), /*#__PURE__*/React.createElement(CTag, {
    size: "sm",
    icon: "clock"
  }, "Other"))), /*#__PURE__*/React.createElement(Field, {
    label: "Where"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, mm.s.gyms.map(g => /*#__PURE__*/React.createElement(CTag, {
    key: g,
    size: "sm",
    icon: g === mm.s.me.gym ? 'house' : 'map-pin',
    selected: gym === g,
    onClick: () => setGym(g)
  }, g))), !showNote ? /*#__PURE__*/React.createElement(CBtn, {
    variant: "ghost",
    size: "sm",
    iconLeft: "plus",
    style: {
      marginTop: 8,
      marginLeft: -8
    },
    onClick: () => setShowNote(true)
  }, "Add a note (optional)") : /*#__PURE__*/React.createElement(CIn, {
    multiline: true,
    rows: 2,
    placeholder: "Gi or no-gi? Bring anything?",
    value: note,
    onChange: e => setNote(e.target.value),
    style: {
      marginTop: 12
    }
  })), /*#__PURE__*/React.createElement(Field, {
    label: past ? 'Who was there' : 'Invite friends',
    hint: /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 600,
      c: "var(--text-tertiary)"
    }, inv.length, " picked")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(4, 1fr)',
      gap: 12
    }
  }, mm.s.friends.map(f => {
    const p = mm.person(f.id);
    const on = inv.includes(f.id);
    const n = mm.streakOf(f);
    return /*#__PURE__*/React.createElement("button", {
      key: f.id,
      onClick: () => toggle(f.id),
      style: {
        border: 0,
        background: 'transparent',
        padding: 0,
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 6
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'relative',
        display: 'inline-flex',
        transform: on ? 'scale(1.04)' : 'scale(1)',
        transition: 'transform var(--dur-base) var(--ease-bounce)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        borderRadius: 999,
        boxShadow: on ? '0 0 0 3px var(--bg-app), 0 0 0 5.5px var(--accent)' : 'none',
        display: 'inline-flex',
        transition: 'box-shadow var(--dur-fast)'
      }
    }, /*#__PURE__*/React.createElement(CAv, {
      name: p.name,
      size: 60
    })), on && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        right: -3,
        bottom: -3,
        width: 24,
        height: 24,
        borderRadius: 99,
        background: 'var(--accent)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: '0 0 0 3px var(--bg-app)',
        animation: 'mmPop .3s var(--ease-bounce)'
      }
    }, /*#__PURE__*/React.createElement(CIcon, {
      name: "check",
      size: 14,
      strokeWidth: 3.5,
      color: "#fff"
    })), !on && n > 0 && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        right: -6,
        top: -4,
        height: 22,
        padding: '0 6px',
        borderRadius: 99,
        background: 'var(--flame-100)',
        display: 'flex',
        alignItems: 'center',
        gap: 2,
        font: '800 11px var(--font-body)',
        color: '#B5520A',
        boxShadow: '0 0 0 2px var(--bg-app)'
      }
    }, /*#__PURE__*/React.createElement(CIcon, {
      name: "flame",
      size: 11,
      filled: true,
      color: "var(--flame-500)"
    }), n)), /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: on ? 700 : 500
    }, p.name.split(' ')[0]));
  }))), !past && /*#__PURE__*/React.createElement(Field, {
    label: "Who can join"
  }, /*#__PURE__*/React.createElement(CTabs, {
    items: [{
      id: 'friends',
      label: 'Friends only'
    }, {
      id: 'link',
      label: 'Anyone with link'
    }],
    value: privacy,
    onChange: setPrivacy
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12,
      padding: 14,
      borderRadius: 18,
      background: 'var(--white)',
      boxShadow: 'inset 0 0 0 1.5px var(--border-default)'
    }
  }, link ? /*#__PURE__*/React.createElement(Row, null, /*#__PURE__*/React.createElement(CIcon, {
    name: "link",
    size: 18,
    color: "var(--accent)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: '600 14px var(--font-mono)',
      color: 'var(--ink-900)'
    }
  }, "gripgorillas.app/s/", link), /*#__PURE__*/React.createElement(CBtn, {
    size: "sm",
    variant: "soft",
    iconLeft: "copy",
    onClick: () => mm.toast('Invite link copied', 'success')
  }, "Copy")) : /*#__PURE__*/React.createElement(Row, null, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-secondary)"
  }, privacy === 'link' ? 'Anyone with a Grip Gorillas account can join from the link.' : 'Only your friends can join from the link.')), /*#__PURE__*/React.createElement(CBtn, {
    size: "sm",
    variant: "secondary",
    iconLeft: "link",
    onClick: () => setLink('k3x9q')
  }, "Get link")))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 24
    }
  }));
}
Object.assign(window, {
  CreateScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Create.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Friends.jsx
try { (() => {
const {
  Avatar: FAv,
  IconButton: FIB,
  Icon: FIcon,
  Button: FBtn,
  Tabs: FTabs,
  StreakBelt: FBelt,
  Belt: FRank,
  Badge: FBadge
} = window.GripGorillasDesignSystem_8b0f80;
function streakCopy(mm, f) {
  const n = mm.streakOf(f);
  const first = mm.person(f.id).name.split(' ')[0];
  if (n === 0 && !f.best) return {
    line: 'New friend. Train together to start a streak',
    cta: 'Invite',
    state: 'broken'
  };
  if (n === 0) return {
    line: `Ended ${f.brokeAgo || 'recently'} · best ${f.best} weeks`,
    cta: 'Start again',
    state: 'broken'
  };
  if (f.thisWeek === 'done') return {
    line: n === 1 ? `New streak with ${first}. Same time next week?` : `This week's locked in. Longest: ${Math.max(f.best, n)} weeks`,
    state: 'done'
  };
  return {
    line: `Roll together by Sunday to make it ${n + 1}`,
    cta: 'Invite',
    state: 'pending'
  };
}
function FriendStreakCard({
  f
}) {
  const mm = useMM();
  const p = mm.person(f.id);
  const n = mm.streakOf(f);
  const c = streakCopy(mm, f);
  const [, tint, ink] = HUEV[p.hue];
  const broken = c.state === 'broken';
  return /*#__PURE__*/React.createElement("div", {
    onClick: () => mm.go('friend', {
      id: f.id
    }),
    style: {
      background: 'var(--white)',
      borderRadius: 24,
      padding: 16,
      boxShadow: 'var(--shadow-card)',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement(Row, null, /*#__PURE__*/React.createElement(PairAvatars, {
    a: mm.s.me,
    b: p,
    size: 40,
    hue: broken ? 'coral' : p.hue,
    knot: !broken
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 17px/1.15 var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, "You + ", p.name.split(' ')[0]), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--text-tertiary)"
  }, c.line)), broken ? /*#__PURE__*/React.createElement(FBtn, {
    size: "sm",
    variant: "secondary",
    onClick: e => {
      e.stopPropagation();
      mm.go('create', {
        friend: f.id
      });
    }
  }, c.cta) : /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'right',
      lineHeight: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 30px/1 var(--font-display)',
      letterSpacing: '-.04em',
      color: ink
    }
  }, n), /*#__PURE__*/React.createElement(Txt, {
    s: 11,
    w: 700,
    c: "var(--text-tertiary)"
  }, n === 1 ? 'WEEK' : 'WEEKS'))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14,
      opacity: broken ? .55 : 1
    }
  }, /*#__PURE__*/React.createElement(FBelt, {
    weeks: f.weeks,
    thisWeek: f.thisWeek,
    hue: p.hue,
    showFlame: !broken
  })), c.state === 'pending' && /*#__PURE__*/React.createElement(Row, {
    style: {
      marginTop: 12,
      padding: '10px 12px',
      borderRadius: 16,
      background: tint,
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    w: 600,
    c: ink
  }, p.name.split(' ')[0], " is free most Thursdays"), /*#__PURE__*/React.createElement(FBtn, {
    size: "sm",
    iconLeft: "calendar-plus",
    onClick: e => {
      e.stopPropagation();
      mm.go('create', {
        friend: f.id
      });
    }
  }, "Invite")));
}
function FriendsScreen() {
  const mm = useMM();
  const fr = mm.s.friends;
  const pending = fr.filter(f => mm.streakOf(f) > 0 && f.thisWeek === 'pending');
  const done = fr.filter(f => f.thisWeek === 'done');
  const fresh = fr.filter(f => mm.streakOf(f) === 0 && !f.best);
  const broken = fr.filter(f => mm.streakOf(f) === 0 && f.best);
  const Sec = ({
    t,
    sub,
    list
  }) => list.length ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Eyebrow, {
    right: sub && /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 600,
      c: "var(--text-tertiary)"
    }, sub)
  }, t), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, list.map(f => /*#__PURE__*/React.createElement(FriendStreakCard, {
    key: f.id,
    f: f
  })))) : null;
  return /*#__PURE__*/React.createElement(Screen, {
    tabPad: true,
    header: /*#__PURE__*/React.createElement(Header, {
      large: true,
      title: "Friends",
      right: /*#__PURE__*/React.createElement(FIB, {
        icon: "qr-code",
        variant: "filled",
        label: "My QR code",
        onClick: () => mm.go('qr')
      })
    })
  }, /*#__PURE__*/React.createElement("div", {
    onClick: () => mm.go('qr', {
      tab: 'scan'
    }),
    style: {
      margin: '4px 16px 0',
      padding: '16px 16px 16px 18px',
      borderRadius: 24,
      background: 'var(--sun-100)',
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 18px/1.15 var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, "At the gym with someone new?"), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--ink-700)"
  }, "Scan their code. You're friends instantly.")), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 52,
      height: 52,
      borderRadius: 16,
      background: 'var(--ink-900)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      transform: 'rotate(6deg)'
    }
  }, /*#__PURE__*/React.createElement(FIcon, {
    name: "scan-line",
    size: 26,
    color: "var(--sun-400)",
    strokeWidth: 2.25
  }))), /*#__PURE__*/React.createElement(Sec, {
    t: "New friends",
    list: fresh
  }), /*#__PURE__*/React.createElement(Sec, {
    t: "Keep it going",
    sub: "Weeks run Mon\u2013Sun",
    list: pending
  }), /*#__PURE__*/React.createElement(Sec, {
    t: "Trained together this week",
    list: done
  }), /*#__PURE__*/React.createElement(Sec, {
    t: "Pick it back up",
    list: broken
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      padding: '24px 40px 8px'
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--text-tertiary)"
  }, "A streak grows each week you and a friend finish at least one session together.")));
}
function FriendProfile({
  id
}) {
  const mm = useMM();
  const p = mm.person(id);
  const f = mm.s.friends.find(x => x.id === id);
  const n = f ? mm.streakOf(f) : 0;
  const [, tint, ink] = HUEV[p.hue || 'coral'];
  const shared = mm.s.posts.filter(x => x.participants.includes('me') && x.participants.includes(id));
  const first = p.name.split(' ')[0];
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(FIB, {
        icon: "chevron-left",
        label: "Back",
        onClick: mm.back
      }),
      title: ""
    }),
    footer: /*#__PURE__*/React.createElement(FBtn, {
      size: "lg",
      fullWidth: true,
      iconLeft: "calendar-plus",
      onClick: () => mm.go('create', {
        friend: id
      })
    }, "Invite ", first, " to train")
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      textAlign: 'center',
      padding: '0 24px'
    }
  }, /*#__PURE__*/React.createElement(FAv, {
    name: p.name,
    src: p.src,
    size: 104,
    belt: p.belt
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 30px/1.05 var(--font-display)',
      letterSpacing: '-.035em',
      marginTop: 14
    }
  }, p.name), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)",
    style: {
      marginTop: 4
    }
  }, p.gym), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 180,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement(FRank, {
    rank: p.belt,
    stripes: p.stripes,
    size: "sm",
    label: true
  }))), f && /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '22px 16px 0',
      padding: 18,
      borderRadius: 26,
      background: tint
    }
  }, /*#__PURE__*/React.createElement(Row, null, /*#__PURE__*/React.createElement(PairAvatars, {
    a: mm.s.me,
    b: p,
    size: 36,
    hue: p.hue
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 20px/1.1 var(--font-display)',
      letterSpacing: '-.03em',
      color: ink
    }
  }, n ? `${n}-week streak` : 'Streak on pause'), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--ink-700)"
  }, n ? f.thisWeek === 'done' ? 'This week is covered.' : 'Train together by Sunday to keep it.' : `Your best was ${f.best} weeks. Start a new one?`))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement(FBelt, {
    weeks: f.weeks,
    thisWeek: f.thisWeek,
    hue: p.hue
  })), /*#__PURE__*/React.createElement(Row, {
    style: {
      marginTop: 14,
      gap: 0
    }
  }, [['Longest streak', Math.max(f.best, n) + ' wks'], ['Sessions together', f.together]].map(([l, v], i) => /*#__PURE__*/React.createElement("div", {
    key: l,
    style: {
      flex: 1,
      paddingLeft: i ? 14 : 0,
      boxShadow: i ? 'inset 1.5px 0 0 rgba(29,27,24,.1)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 22px var(--font-display)',
      letterSpacing: '-.03em'
    }
  }, v), /*#__PURE__*/React.createElement(Txt, {
    s: 12,
    w: 600,
    c: "var(--ink-700)"
  }, l))))), /*#__PURE__*/React.createElement(Eyebrow, null, "Memories together"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px 20px',
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 8
    }
  }, shared.length ? shared.map(x => /*#__PURE__*/React.createElement(PhotoTile, {
    key: x.id,
    src: x.photo,
    h: 150,
    radius: 18,
    onClick: () => mm.go('post', {
      id: x.id
    })
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 8,
      right: 8,
      bottom: 8,
      font: '800 13px/1.1 var(--font-display)',
      color: '#fff',
      textShadow: '0 1px 6px rgba(0,0,0,.6)'
    }
  }, x.title))) : /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)"
  }, "No shared posts yet. Fix that this week.")));
}
function QRGrid({
  seed = 7,
  size = 200
}) {
  const N = 25;
  let x = seed;
  const rnd = () => (x = (x * 9301 + 49297) % 233280) / 233280;
  const finder = (r, c) => {
    for (const [R, C] of [[0, 0], [0, N - 7], [N - 7, 0]]) {
      if (r >= R && r < R + 7 && c >= C && c < C + 7) {
        const rr = r - R,
          cc = c - C;
        return rr === 0 || rr === 6 || cc === 0 || cc === 6 || rr >= 2 && rr <= 4 && cc >= 2 && cc <= 4 ? 1 : 0;
      }
      if (r >= R - 1 && r <= R + 7 && c >= C - 1 && c <= C + 7) return 0;
    }
    return null;
  };
  const cells = [];
  for (let r = 0; r < N; r++) for (let c = 0; c < N; c++) {
    const f = finder(r, c);
    const mid = r > 9 && r < 15 && c > 9 && c < 15;
    cells.push(mid ? 0 : f !== null ? f : rnd() > .52 ? 1 : 0);
  }
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: size,
      height: size,
      display: 'grid',
      gridTemplateColumns: `repeat(${N}, 1fr)`
    }
  }, cells.map((v, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      background: v ? 'var(--ink-900)' : 'transparent',
      borderRadius: 1.5
    }
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: '50%',
      top: '50%',
      transform: 'translate(-50%,-50%)',
      width: size * .18,
      height: size * .18,
      borderRadius: 10,
      background: 'var(--accent)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      font: `800 ${size * .07}px var(--font-display)`,
      color: '#fff'
    }
  }, "mm."));
}
function QRScreen({
  tab: t0
}) {
  const mm = useMM();
  const [tab, setTab] = React.useState(t0 || 'code');
  const [found, setFound] = React.useState(null);
  React.useEffect(() => {
    if (tab !== 'scan' || found) return;
    const t = setTimeout(() => {
      setFound('lena');
      mm.addFriend('lena');
    }, 2200);
    return () => clearTimeout(t);
  }, [tab, found]);
  const me = mm.s.me;
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    bg: tab === 'scan' ? '#141210' : 'var(--bg-app)',
    header: /*#__PURE__*/React.createElement("div", {
      style: {
        color: tab === 'scan' ? '#fff' : undefined
      }
    }, /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(FIB, {
        icon: "x",
        label: "Close",
        variant: tab === 'scan' ? 'overlay' : 'ghost',
        onClick: mm.back
      }),
      title: /*#__PURE__*/React.createElement("span", {
        style: {
          color: tab === 'scan' ? '#fff' : 'var(--ink-900)'
        }
      }, "Add friends")
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '0 16px 4px'
      }
    }, /*#__PURE__*/React.createElement(FTabs, {
      items: [{
        id: 'code',
        label: 'My code'
      }, {
        id: 'scan',
        label: 'Scan'
      }],
      value: tab,
      onChange: v => {
        setTab(v);
        setFound(null);
      }
    })))
  }, tab === 'code' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '28px 24px 0',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: '100%',
      padding: '54px 24px 26px',
      borderRadius: 32,
      background: 'var(--coral-500)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: -40,
      borderRadius: 999,
      boxShadow: '0 0 0 5px var(--bg-app)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(FAv, {
    name: me.name,
    src: me.src,
    size: 80,
    belt: me.belt,
    ring: "var(--coral-500)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 24px/1 var(--font-display)',
      letterSpacing: '-.03em',
      color: '#fff'
    }
  }, me.name), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 120,
      margin: '10px 0 18px'
    }
  }, /*#__PURE__*/React.createElement(FRank, {
    rank: me.belt,
    stripes: me.stripes,
    size: "xs"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 18,
      background: '#fff',
      borderRadius: 24,
      transform: 'rotate(-2deg)',
      boxShadow: '0 10px 30px rgba(120,30,0,.3)'
    }
  }, /*#__PURE__*/React.createElement(QRGrid, {
    size: 196
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 20px/1.2 var(--font-display)',
      letterSpacing: '-.02em',
      marginTop: 26,
      textAlign: 'center'
    }
  }, "Hold this up after class"), /*#__PURE__*/React.createElement(Txt, {
    s: 15,
    c: "var(--text-secondary)",
    style: {
      textAlign: 'center',
      marginTop: 6
    }
  }, "When a training partner scans it, you're friends. No requests, no waiting."), /*#__PURE__*/React.createElement(FBtn, {
    variant: "secondary",
    iconLeft: "scan-line",
    style: {
      marginTop: 18
    },
    onClick: () => setTab('scan')
  }, "Scan someone instead")) : /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      margin: '14px 16px 0',
      height: 560,
      borderRadius: 32,
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: MM_PH('team-lineup'),
    style: {
      position: 'absolute',
      inset: 0,
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      filter: 'brightness(.55) saturate(.8)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      top: '44%',
      width: 220,
      height: 220,
      transform: 'translate(-50%,-50%)'
    }
  }, [[0, 0, '0 0'], [1, 0, '0 0'], [0, 1, '0 0'], [1, 1, '0 0']].map(([r, b], i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      position: 'absolute',
      width: 44,
      height: 44,
      [r ? 'right' : 'left']: 0,
      [b ? 'bottom' : 'top']: 0,
      borderStyle: 'solid',
      borderColor: found ? 'var(--mint-500)' : '#fff',
      borderWidth: `${b ? 0 : 5}px ${r ? 5 : 0}px ${b ? 5 : 0}px ${r ? 0 : 5}px`,
      borderRadius: `${!r && !b ? 18 : 0}px ${r && !b ? 18 : 0}px ${r && b ? 18 : 0}px ${!r && b ? 18 : 0}px`,
      transition: 'border-color .2s'
    }
  })), !found && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 14,
      right: 14,
      height: 3,
      borderRadius: 3,
      background: 'var(--sun-400)',
      boxShadow: '0 0 16px var(--sun-400)',
      animation: 'mmScan 1.6s ease-in-out infinite alternate'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 0,
      right: 0,
      bottom: 28,
      textAlign: 'center',
      color: '#fff',
      font: '700 15px var(--font-body)'
    }
  }, found ? 'Got it!' : 'Point at a friend\'s Grip Gorillas code'), found && /*#__PURE__*/React.createElement(Connected, {
    id: found,
    onDone: () => {
      setFound(null);
      mm.back();
    }
  })));
}
function Connected({
  id,
  onDone
}) {
  const mm = useMM();
  const p = mm.person(id);
  const me = mm.s.me;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--sun-400)',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 24,
      textAlign: 'center',
      animation: 'mmFade .25s var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center',
      height: 120
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      animation: 'mmSlideL .7s var(--ease-bounce) both',
      borderRadius: 999,
      boxShadow: '0 0 0 5px var(--sun-400)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(FAv, {
    name: me.name,
    src: me.src,
    size: 104
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: -26,
      animation: 'mmSlideR .7s var(--ease-bounce) both',
      borderRadius: 999,
      boxShadow: '0 0 0 5px var(--sun-400)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(FAv, {
    name: p.name,
    size: 104
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: -6,
      width: 56,
      height: 56,
      marginLeft: -28,
      borderRadius: 999,
      background: 'var(--ink-900)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      animation: 'mmPop .5s .55s var(--ease-bounce) both',
      boxShadow: '0 0 0 5px var(--sun-400)'
    }
  }, /*#__PURE__*/React.createElement(FIcon, {
    name: "handshake",
    size: 28,
    color: "var(--sun-400)"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 30px/1.05 var(--font-display)',
      letterSpacing: '-.04em',
      marginTop: 28,
      color: 'var(--ink-900)',
      animation: 'mmFadeUp .4s .6s var(--ease-out) both'
    }
  }, "You & ", p.name.split(' ')[0], " are friends"), /*#__PURE__*/React.createElement(Txt, {
    s: 15,
    c: "var(--ink-800)",
    style: {
      marginTop: 8,
      animation: 'mmFadeUp .4s .7s var(--ease-out) both'
    }
  }, "Train together this week to start your first streak."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 8,
      width: '100%',
      marginTop: 26,
      animation: 'mmFadeUp .4s .8s var(--ease-out) both'
    }
  }, /*#__PURE__*/React.createElement(FBtn, {
    size: "lg",
    variant: "inverse",
    fullWidth: true,
    iconLeft: "calendar-plus",
    onClick: () => {
      mm.back();
      mm.go('create', {
        friend: id
      });
    }
  }, "Plan a session with ", p.name.split(' ')[0]), /*#__PURE__*/React.createElement(FBtn, {
    variant: "ghost",
    fullWidth: true,
    onClick: onDone
  }, "Done")));
}
Object.assign(window, {
  FriendsScreen,
  FriendProfile,
  QRScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Friends.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Me.jsx
try { (() => {
const {
  Avatar: MAv,
  IconButton: MIB,
  Icon: MIcon,
  Button: MBtn,
  Belt: MBelt,
  Dialog: MDlg,
  Input: MIn,
  Select: MSel,
  Badge: MBadge,
  StreakBelt: MStreak
} = window.GripGorillasDesignSystem_8b0f80;
function ProfileScreen() {
  const mm = useMM();
  const me = mm.s.me;
  const [settings, setSettings] = React.useState(false);
  const mine = mm.s.posts.filter(p => p.participants.includes('me'));
  const active = mm.s.friends.filter(f => mm.streakOf(f) > 0).sort((a, b) => mm.streakOf(b) - mm.streakOf(a));
  return /*#__PURE__*/React.createElement(Screen, {
    tabPad: true,
    header: /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'flex-end',
        padding: '2px 10px 0',
        flexShrink: 0
      }
    }, /*#__PURE__*/React.createElement(MIB, {
      icon: "settings",
      variant: "filled",
      label: "Settings",
      onClick: () => setSettings(true)
    }))
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      textAlign: 'center',
      paddingTop: 4
    }
  }, /*#__PURE__*/React.createElement(MAv, {
    name: me.name,
    src: me.src,
    size: 108,
    belt: me.belt
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 30px/1.05 var(--font-display)',
      letterSpacing: '-.035em',
      marginTop: 14
    }
  }, me.name), /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)",
    style: {
      marginTop: 4
    }
  }, me.gym), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 190,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement(MBelt, {
    rank: me.belt,
    stripes: me.stripes,
    size: "sm",
    label: true
  })), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 10,
      marginTop: 18
    }
  }, /*#__PURE__*/React.createElement(MBtn, {
    size: "sm",
    variant: "secondary",
    iconLeft: "users",
    onClick: () => mm.setTab('friends')
  }, mm.s.friends.length, " friends"), /*#__PURE__*/React.createElement(MBtn, {
    size: "sm",
    variant: "secondary",
    iconLeft: "qr-code",
    onClick: () => mm.go('qr')
  }, "My code"))), /*#__PURE__*/React.createElement(Eyebrow, null, "Weekly streaks"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      overflowX: 'auto',
      padding: '0 16px 4px',
      ...hideScroll
    }
  }, active.map(f => {
    const p = mm.person(f.id);
    const [, tint, ink] = HUEV[p.hue];
    return /*#__PURE__*/React.createElement("div", {
      key: f.id,
      onClick: () => mm.go('friend', {
        id: f.id
      }),
      style: {
        flexShrink: 0,
        width: 150,
        padding: 14,
        borderRadius: 22,
        background: tint,
        cursor: 'pointer'
      }
    }, /*#__PURE__*/React.createElement(PairAvatars, {
      a: me,
      b: p,
      size: 30,
      hue: p.hue
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        font: '800 22px/1 var(--font-display)',
        letterSpacing: '-.03em',
        color: ink,
        marginTop: 12
      }
    }, mm.streakOf(f), " wk", mm.streakOf(f) > 1 ? 's' : ''), /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 600,
      c: "var(--ink-700)"
    }, "with ", p.name.split(' ')[0]), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 10
      }
    }, /*#__PURE__*/React.createElement(MStreak, {
      weeks: f.weeks.slice(-5),
      thisWeek: f.thisWeek,
      hue: p.hue,
      size: "sm",
      showFlame: false
    })));
  })), /*#__PURE__*/React.createElement(Eyebrow, {
    right: /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      w: 600,
      c: "var(--text-tertiary)"
    }, mine.length, " sessions")
  }, "Activity"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      gap: 4
    }
  }, mine.map((p, i) => /*#__PURE__*/React.createElement(PhotoTile, {
    key: p.id,
    src: p.photo,
    h: 118,
    radius: i === 0 ? '18px 4px 4px 4px' : i === 2 ? '4px 18px 4px 4px' : 4,
    onClick: () => mm.go('post', {
      id: p.id
    })
  }))), settings && /*#__PURE__*/React.createElement(MDlg, {
    contained: true,
    variant: "sheet",
    title: "Account",
    onClose: () => setSettings(false)
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement(MIn, {
    label: "Name",
    defaultValue: me.name
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(MIn, {
    label: "Email",
    defaultValue: me.email,
    iconLeft: "mail"
  }), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 6,
      marginTop: 8
    }
  }, /*#__PURE__*/React.createElement(MIcon, {
    name: "lock",
    size: 14,
    color: "var(--text-tertiary)"
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--text-tertiary)"
  }, "Private. Only you can see this."))), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(MSel, {
    label: "Belt",
    defaultValue: me.belt,
    options: ['white', 'blue', 'purple', 'brown', 'black'],
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(MSel, {
    label: "Stripes",
    defaultValue: String(me.stripes),
    options: ['0', '1', '2', '3', '4'],
    style: {
      width: 110
    }
  })), /*#__PURE__*/React.createElement(MBtn, {
    variant: "ghost",
    iconLeft: "log-out",
    style: {
      alignSelf: 'flex-start',
      marginLeft: -10
    }
  }, "Sign out"))));
}
const NICON = {
  invite: ['calendar', 'var(--accent)'],
  joined: ['user-check', 'var(--mint-500)'],
  comment: ['message-circle', 'var(--sky-500)'],
  published: ['images', 'var(--plum-500)']
};
function NotificationsScreen() {
  const mm = useMM();
  const P = mm.person;
  React.useEffect(() => () => mm.readAll(), []);
  const item = n => {
    const p = P(n.who);
    const [ic, col] = NICON[n.kind];
    const s = n.session && mm.s.upcoming.find(x => x.id === n.session);
    return /*#__PURE__*/React.createElement("div", {
      key: n.id,
      style: {
        display: 'flex',
        gap: 12,
        padding: '14px 16px',
        background: n.unread ? 'rgba(255,92,57,.06)' : 'transparent'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'relative',
        display: 'inline-flex',
        alignSelf: 'flex-start'
      }
    }, /*#__PURE__*/React.createElement(MAv, {
      name: p.name,
      src: p.src,
      size: 46
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        right: -3,
        bottom: -3,
        width: 22,
        height: 22,
        borderRadius: 99,
        background: col,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: '0 0 0 2.5px var(--bg-app)'
      }
    }, /*#__PURE__*/React.createElement(MIcon, {
      name: ic,
      size: 12,
      strokeWidth: 2.5,
      color: "#fff"
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, n.kind === 'invite' && s ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Txt, {
      s: 15
    }, /*#__PURE__*/React.createElement("b", null, p.name.split(' ')[0]), " invited you to ", /*#__PURE__*/React.createElement("b", null, s.title)), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      c: "var(--text-tertiary)"
    }, s.day, ", ", s.month, " ", s.date, " \xB7 ", s.time, " \xB7 ", s.gym)), s.people.me === 'invited' ? /*#__PURE__*/React.createElement(Row, {
      style: {
        gap: 8,
        marginTop: 10
      }
    }, /*#__PURE__*/React.createElement(MBtn, {
      size: "sm",
      variant: "secondary",
      onClick: () => mm.rsvp(s.id, 'declined')
    }, "Decline"), /*#__PURE__*/React.createElement(MBtn, {
      size: "sm",
      iconLeft: "check",
      onClick: () => mm.rsvp(s.id, 'going')
    }, "Join")) : /*#__PURE__*/React.createElement(MBadge, {
      variant: s.people.me === 'going' ? 'success' : 'neutral',
      dot: true,
      style: {
        marginTop: 8
      }
    }, s.people.me === 'going' ? "You're going" : 'Declined')) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Txt, {
      s: 15
    }, /*#__PURE__*/React.createElement("b", null, p.name.split(' ')[0]), " ", n.text), n.quote && /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 4
      }
    }, /*#__PURE__*/React.createElement(Txt, {
      s: 14,
      c: "var(--text-secondary)"
    }, "\u201C", n.quote, "\u201D"))), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Txt, {
      s: 12,
      w: 600,
      c: "var(--text-tertiary)"
    }, n.time))), n.photo && /*#__PURE__*/React.createElement(PhotoTile, {
      src: n.photo,
      h: 48,
      radius: 10,
      style: {
        width: 48,
        flexShrink: 0
      },
      onClick: () => mm.go('post', {
        id: 'p1'
      })
    }));
  };
  const fresh = mm.s.notifications.filter(n => n.unread);
  const old = mm.s.notifications.filter(n => !n.unread);
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(MIB, {
        icon: "chevron-left",
        label: "Back",
        onClick: mm.back
      }),
      title: "Notifications"
    })
  }, fresh.length > 0 && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Eyebrow, {
    style: {
      marginTop: 6
    }
  }, "New"), fresh.map(item)), /*#__PURE__*/React.createElement(Eyebrow, null, "Earlier"), old.map(item), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 30
    }
  }));
}
Object.assign(window, {
  ProfileScreen,
  NotificationsScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Me.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Profile.jsx
try { (() => {
const {
  IconButton: PIB,
  Button: PBtn,
  Avatar: PAv,
  Belt: PBelt,
  Tabs: PTabs,
  Card: PCard,
  Tooltip: PTip,
  Badge: PBadge
} = window.GripGorillasDesignSystem_8b0f80;
function ProfileScreen({
  me,
  week,
  recent,
  sessions
}) {
  const [range, setRange] = React.useState('Week');
  const max = Math.max(...week);
  const total = week.reduce((a, b) => a + b, 0);
  const stats = [['Sessions', range === 'Week' ? 5 : range === 'Month' ? 19 : 214], ['Mat hours', range === 'Week' ? (total / 60).toFixed(1) : range === 'Month' ? '27.5' : '311'], ['Rounds', range === 'Week' ? 31 : range === 'Month' ? 118 : 1342], ['Subs', range === 'Week' ? 6 : range === 'Month' ? 21 : 188]];
  return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(ScreenHeader, {
    title: me.handle,
    right: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(PIB, {
      icon: "share-2",
      label: "Share profile"
    }), /*#__PURE__*/React.createElement(PIB, {
      icon: "settings",
      label: "Settings"
    }))
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px 16px 24px',
      display: 'flex',
      flexDirection: 'column',
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 16,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(PAv, {
    name: me.name,
    size: 88,
    belt: me.belt
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '850 26px/1 var(--font-display)',
      fontStretch: '125%',
      textTransform: 'uppercase',
      letterSpacing: '-.02em',
      color: 'var(--text-primary)'
    }
  }, me.name), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '400 13px/1.4 var(--font-body)',
      color: 'var(--text-tertiary)',
      marginTop: 6
    }
  }, me.gym), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      marginTop: 8,
      font: '500 13px var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("b", {
    style: {
      font: '700 14px var(--font-mono)',
      color: 'var(--text-primary)'
    }
  }, me.followers), " followers"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("b", {
    style: {
      font: '700 14px var(--font-mono)',
      color: 'var(--text-primary)'
    }
  }, me.following), " following")))), /*#__PURE__*/React.createElement(PBelt, {
    rank: me.belt,
    stripes: me.stripes,
    size: "lg",
    label: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(PBtn, {
    variant: "secondary",
    fullWidth: true,
    iconLeft: "pencil"
  }, "Edit profile"), /*#__PURE__*/React.createElement(PBtn, {
    variant: "secondary",
    fullWidth: true,
    iconLeft: "award"
  }, "Promotions")), /*#__PURE__*/React.createElement(PTabs, {
    variant: "segmented",
    items: ['Week', 'Month', 'Year'],
    value: range,
    onChange: setRange
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 10
    }
  }, stats.map(([l, v]) => /*#__PURE__*/React.createElement(PCard, {
    key: l,
    style: {
      padding: 14
    }
  }, /*#__PURE__*/React.createElement(Overline, null, l), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '850 30px/1 var(--font-display)',
      fontStretch: '125%',
      color: 'var(--text-primary)',
      marginTop: 8
    }
  }, v)))), /*#__PURE__*/React.createElement(PCard, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'baseline'
    }
  }, /*#__PURE__*/React.createElement(Overline, null, "Mat time"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 12px var(--font-mono)',
      color: 'var(--text-secondary)'
    }
  }, total, " min")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      gap: 10,
      height: 96,
      marginTop: 14
    }
  }, week.map((m, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 6,
      height: '100%',
      justifyContent: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement(PTip, {
    content: m ? m + ' min' : 'Rest day',
    style: {
      width: '100%',
      flex: 1,
      alignItems: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      height: m ? m / max * 100 + '%' : 4,
      borderRadius: 4,
      background: i === 6 ? 'var(--accent)' : m ? 'var(--mat-600)' : 'var(--mat-800)'
    }
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 10px var(--font-body)',
      color: 'var(--text-tertiary)'
    }
  }, 'MTWTFSS'[i]))))), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Overline, {
    style: {
      marginBottom: 4
    }
  }, "Recent sessions"), [...sessions, ...recent].map((s, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 0',
      boxShadow: 'inset 0 -1px 0 var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 44,
      font: '700 12px var(--font-body)',
      color: 'var(--text-secondary)'
    }
  }, s.day), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement(PBadge, null, s.type), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '600 13px var(--font-mono)',
      color: 'var(--text-primary)'
    }
  }, s.min, "m \xB7 ", s.rounds, "R")), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '400 13px/1.4 var(--font-body)',
      color: 'var(--text-tertiary)',
      marginTop: 4,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, s.note)))))));
}
Object.assign(window, {
  ProfileScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Profile.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Shell.jsx
try { (() => {
const DS = window.GripGorillasDesignSystem_8b0f80;
const {
  Avatar: SAv,
  Icon: SIcon
} = DS;
const HUEV = {
  coral: ['var(--coral-500)', 'var(--coral-100)', 'var(--coral-700)'],
  sun: ['var(--sun-400)', 'var(--sun-100)', '#8A6200'],
  mint: ['var(--mint-500)', 'var(--mint-100)', 'var(--mint-700)'],
  sky: ['var(--sky-500)', 'var(--sky-100)', 'var(--sky-700)'],
  plum: ['var(--plum-500)', 'var(--plum-100)', 'var(--plum-700)']
};
const hideScroll = {
  scrollbarWidth: 'none'
};
function StatusBar() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 50,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '6px 30px 0 38px',
      font: '700 16px var(--font-body)',
      color: 'var(--ink-900)',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      gap: 2,
      alignItems: 'flex-end'
    }
  }, [5, 8, 11, 14].map(h => /*#__PURE__*/React.createElement("span", {
    key: h,
    style: {
      width: 3,
      height: h,
      borderRadius: 1,
      background: 'currentColor'
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 25,
      height: 12,
      borderRadius: 4,
      boxShadow: 'inset 0 0 0 1.5px var(--ink-400)',
      padding: 2,
      boxSizing: 'border-box'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      width: '80%',
      height: '100%',
      background: 'currentColor',
      borderRadius: 1.5
    }
  }))));
}
function Phone({
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: 390,
      height: 844,
      borderRadius: 54,
      background: 'var(--bg-app)',
      position: 'relative',
      overflow: 'hidden',
      display: 'flex',
      flexDirection: 'column',
      flexShrink: 0,
      boxShadow: '0 0 0 10px #1D1B18, 0 0 0 11px #3a3631, 0 40px 80px rgba(29,27,24,.35)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 122,
      height: 34,
      borderRadius: 20,
      background: '#000',
      zIndex: 90
    }
  }), /*#__PURE__*/React.createElement(StatusBar, null), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      position: 'relative',
      minHeight: 0
    }
  }, children), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 8,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 134,
      height: 5,
      borderRadius: 3,
      background: 'var(--ink-900)',
      zIndex: 90
    }
  }));
}
// A screen = fixed header + scroll body + optional footer. push = slides in over tabs.
function Screen({
  header,
  children,
  footer,
  push,
  tabPad,
  bg,
  scrollRef
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      display: 'flex',
      flexDirection: 'column',
      background: bg || 'var(--bg-app)',
      zIndex: push ? 30 : 1,
      animation: push ? 'mmPush var(--dur-slow) var(--ease-out)' : 'none'
    }
  }, header, /*#__PURE__*/React.createElement("div", {
    ref: scrollRef,
    style: {
      flex: 1,
      overflowY: 'auto',
      ...hideScroll,
      paddingBottom: tabPad ? 104 : 0
    }
  }, children), footer && /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 16px 34px',
      background: 'linear-gradient(to bottom, rgba(250,246,239,0), var(--bg-app) 30%)',
      flexShrink: 0
    }
  }, footer));
}
function Header({
  title,
  large,
  left,
  right,
  sub
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      padding: large ? '6px 10px 10px 20px' : '4px 10px 8px 10px',
      minHeight: 54,
      flexShrink: 0
    }
  }, left, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      textAlign: large || left == null ? 'left' : 'center',
      paddingRight: !large && left && !right ? 44 : 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: large ? '800 32px/1 var(--font-display)' : '800 18px/1.2 var(--font-display)',
      letterSpacing: large ? '-.035em' : '-.015em',
      color: 'var(--ink-900)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title), sub && /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 13px var(--font-body)',
      color: 'var(--text-tertiary)',
      marginTop: 3
    }
  }, sub)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4
    }
  }, right));
}
function Eyebrow({
  children,
  right,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      justifyContent: 'space-between',
      padding: '0 20px',
      margin: '22px 0 10px',
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 18px/1.2 var(--font-display)',
      letterSpacing: '-.02em',
      color: 'var(--ink-900)'
    }
  }, children), right);
}
function TapeLabel({
  children,
  rotate = -3,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      padding: '6px 12px 6px 11px',
      background: '#FFFDF8',
      color: 'var(--ink-900)',
      font: '800 13px/1 var(--font-display)',
      letterSpacing: '-.01em',
      transform: `rotate(${rotate}deg)`,
      boxShadow: '0 2px 6px rgba(29,27,24,.2)',
      clipPath: 'polygon(2% 0, 98% 4%, 100% 50%, 97% 100%, 3% 96%, 0 50%)',
      ...style
    }
  }, children);
}
// Two avatars tied together — the friendship mark
function PairAvatars({
  a,
  b,
  size = 44,
  hue = 'coral',
  knot = true,
  style
}) {
  const [c, tint] = HUEV[hue] || HUEV.coral;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'inline-flex',
      alignItems: 'center',
      flexShrink: 0,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      borderRadius: 999,
      boxShadow: '0 0 0 3px var(--surface-card)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(SAv, {
    name: a.name,
    src: a.src,
    size: size
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: -size * 0.3,
      borderRadius: 999,
      boxShadow: '0 0 0 3px var(--surface-card)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(SAv, {
    name: b.name,
    src: b.src,
    size: size
  })), knot && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: -4,
      transform: 'translateX(-50%)',
      width: size * 0.5,
      height: size * 0.22,
      borderRadius: 4,
      background: c,
      boxShadow: '0 0 0 2px var(--surface-card)'
    }
  }));
}
function PhotoTile({
  src,
  h = 280,
  radius = 22,
  children,
  style,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      position: 'relative',
      height: h,
      borderRadius: radius,
      overflow: 'hidden',
      background: 'var(--paper-3)',
      cursor: onClick ? 'pointer' : undefined,
      ...style
    }
  }, src && /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: "",
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover',
      display: 'block'
    }
  }), children);
}
function Row({
  children,
  style,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      cursor: onClick ? 'pointer' : undefined,
      ...style
    }
  }, children);
}
function Txt({
  s = 15,
  w = 400,
  c = 'var(--text-primary)',
  f = 'body',
  lh = 1.4,
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      font: `${w} ${s}px/${lh} var(--font-${f})`,
      color: c,
      letterSpacing: f === 'display' ? '-.02em' : 0,
      ...style
    }
  }, children);
}
function names(list, max = 2) {
  const n = list.map(x => x.split(' ')[0]);
  return n.length <= max ? n.join(' & ') : n.slice(0, max).join(', ') + ' +' + (n.length - max);
}
Object.assign(window, {
  Phone,
  Screen,
  Header,
  Eyebrow,
  TapeLabel,
  PairAvatars,
  PhotoTile,
  Row,
  Txt,
  names,
  HUEV,
  hideScroll
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Shell.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/Training.jsx
try { (() => {
const {
  Avatar: TAv,
  AvatarStack: TStack,
  IconButton: TIB,
  Icon: TIcon,
  Button: TBtn,
  Badge: TBadge,
  Tabs: TTabs,
  Dialog: TDlg,
  Checkbox: TCb
} = window.GripGorillasDesignSystem_8b0f80;
const STATUS = {
  going: ['success', 'Going'],
  invited: ['warning', 'Invited'],
  declined: ['neutral', 'Declined']
};
function SessionTicket({
  s,
  onClick,
  big
}) {
  const mm = useMM();
  const org = mm.person(s.organizer);
  const hue = s.organizer === 'me' ? 'coral' : org.hue;
  const [c, tint, ink] = HUEV[hue];
  const going = Object.entries(s.people).filter(([, v]) => v === 'going').map(([k]) => mm.person(k));
  const mine = s.people.me;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: 'flex',
      background: 'var(--white)',
      borderRadius: 24,
      boxShadow: 'var(--shadow-card)',
      cursor: onClick ? 'pointer' : undefined,
      position: 'relative',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: big ? 96 : 84,
      flexShrink: 0,
      background: tint,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '16px 0',
      color: ink
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 13px/1 var(--font-display)',
      letterSpacing: '.04em',
      textTransform: 'uppercase'
    }
  }, s.day), /*#__PURE__*/React.createElement("span", {
    style: {
      font: `800 ${big ? 48 : 40}px/1 var(--font-display)`,
      letterSpacing: '-.04em',
      margin: '4px 0 2px'
    }
  }, s.date), /*#__PURE__*/React.createElement("span", {
    style: {
      font: '700 12px/1 var(--font-body)'
    }
  }, s.month)), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 0,
      borderLeft: '2px dashed var(--ink-200)',
      margin: '10px 0',
      position: 'relative'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: (big ? 96 : 84) - 9,
      top: -9,
      width: 18,
      height: 18,
      borderRadius: 99,
      background: 'var(--bg-app)'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: (big ? 96 : 84) - 9,
      bottom: -9,
      width: 18,
      height: 18,
      borderRadius: 99,
      background: 'var(--bg-app)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      padding: '14px 14px 14px 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 6,
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: '800 18px/1.15 var(--font-display)',
      letterSpacing: '-.02em',
      color: 'var(--ink-900)'
    }
  }, s.title), mine === 'invited' && /*#__PURE__*/React.createElement(TBadge, {
    variant: "warning",
    dot: true
  }, "Invite")), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(TIcon, {
    name: "clock",
    size: 14,
    color: "var(--text-tertiary)"
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    w: 500,
    c: "var(--text-secondary)"
  }, s.time), /*#__PURE__*/React.createElement(TIcon, {
    name: "map-pin",
    size: 14,
    color: "var(--text-tertiary)",
    style: {
      marginLeft: 4
    }
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    w: 500,
    c: "var(--text-secondary)",
    style: {
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, s.gym)), /*#__PURE__*/React.createElement(Row, {
    style: {
      justifyContent: 'space-between',
      marginTop: 4
    }
  }, /*#__PURE__*/React.createElement(TStack, {
    people: going,
    size: 28,
    max: 4,
    ring: "#fff",
    label: going.length + ' going'
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 12,
    w: 600,
    c: "var(--text-tertiary)"
  }, s.organizer === 'me' ? 'You host' : 'by ' + org.name.split(' ')[0]))));
}
function ReadyToShare({
  s
}) {
  const mm = useMM();
  return /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '4px 16px 0',
      padding: 16,
      borderRadius: 24,
      background: 'var(--ink-900)',
      color: 'var(--paper)',
      display: 'flex',
      gap: 14,
      alignItems: 'center',
      position: 'relative',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 64,
      height: 64,
      borderRadius: 18,
      overflow: 'hidden',
      flexShrink: 0,
      transform: 'rotate(-4deg)',
      boxShadow: '0 0 0 3px #fff'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: MM_PH('floor-drill'),
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 17px/1.2 var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, "How was ", s.title.toLowerCase().replace('no-gi ', ''), "?"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '500 13px/1.35 var(--font-body)',
      color: 'var(--ink-200)',
      marginTop: 4
    }
  }, "Add a photo and share it with the ", Object.keys(s.people).length, " of you."), /*#__PURE__*/React.createElement(TBtn, {
    size: "sm",
    iconLeft: "camera",
    style: {
      marginTop: 10
    },
    onClick: () => mm.go('complete', {
      id: s.id
    })
  }, "Complete & share")));
}
function TrainingScreen() {
  const mm = useMM();
  const [tab, setTab] = React.useState('Upcoming');
  const list = mm.s.emptyTraining ? [] : mm.s.upcoming;
  const invites = list.filter(s => s.people.me === 'invited');
  const rest = list.filter(s => s.people.me !== 'invited' && s.people.me !== 'declined');
  return /*#__PURE__*/React.createElement(Screen, {
    tabPad: true,
    header: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Header, {
      large: true,
      title: "Training",
      right: /*#__PURE__*/React.createElement(TIB, {
        icon: "calendar-plus",
        variant: "filled",
        label: "Plan a session",
        onClick: () => mm.go('create')
      })
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '0 16px 6px'
      }
    }, /*#__PURE__*/React.createElement(TTabs, {
      items: ['Upcoming', 'Past'],
      value: tab,
      onChange: setTab
    })))
  }, tab === 'Past' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 16px 0',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Txt, {
    s: 14,
    c: "var(--text-tertiary)",
    style: {
      padding: '0 4px'
    }
  }, "Missed a session? Log it after the fact and it still counts for your streaks."), /*#__PURE__*/React.createElement(TBtn, {
    variant: "secondary",
    iconLeft: "history",
    onClick: () => mm.go('create', {
      past: true
    })
  }, "Log a past session"), mm.s.posts.filter(p => p.participants.includes('me')).map(p => /*#__PURE__*/React.createElement(Row, {
    key: p.id,
    onClick: () => mm.go('post', {
      id: p.id
    }),
    style: {
      background: 'var(--white)',
      borderRadius: 20,
      padding: 10,
      boxShadow: 'var(--shadow-card)'
    }
  }, /*#__PURE__*/React.createElement(PhotoTile, {
    src: p.photo,
    h: 56,
    radius: 14,
    style: {
      width: 56,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 15px var(--font-display)',
      letterSpacing: '-.02em'
    }
  }, p.title), /*#__PURE__*/React.createElement(Txt, {
    s: 13,
    c: "var(--text-tertiary)"
  }, p.date, " \xB7 ", p.participants.length, " people")), /*#__PURE__*/React.createElement(TBadge, {
    variant: "success"
  }, "Shared")))) : /*#__PURE__*/React.createElement(React.Fragment, null, mm.s.toComplete && !mm.s.emptyTraining && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(ReadyToShare, {
    s: mm.s.toComplete
  })), invites.length > 0 && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Eyebrow, null, "Invites"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, invites.map(s => /*#__PURE__*/React.createElement("div", {
    key: s.id
  }, /*#__PURE__*/React.createElement(SessionTicket, {
    s: s,
    onClick: () => mm.go('session', {
      id: s.id
    })
  }), /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8,
      marginTop: 8
    }
  }, /*#__PURE__*/React.createElement(TBtn, {
    size: "sm",
    variant: "secondary",
    fullWidth: true,
    onClick: () => mm.rsvp(s.id, 'declined')
  }, "Decline"), /*#__PURE__*/React.createElement(TBtn, {
    size: "sm",
    fullWidth: true,
    iconLeft: "check",
    onClick: () => mm.rsvp(s.id, 'going')
  }, "Join")))))), rest.length > 0 && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Eyebrow, null, "Coming up"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      display: 'flex',
      flexDirection: 'column',
      gap: 12
    }
  }, rest.map(s => /*#__PURE__*/React.createElement(SessionTicket, {
    key: s.id,
    s: s,
    onClick: () => mm.go('session', {
      id: s.id
    })
  })))), list.length === 0 ? /*#__PURE__*/React.createElement(EmptyTraining, null) : /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 16px 0'
    }
  }, /*#__PURE__*/React.createElement(TBtn, {
    size: "lg",
    fullWidth: true,
    iconLeft: "plus",
    onClick: () => mm.go('create')
  }, "Plan a training session"))));
}
function EmptyTraining() {
  const mm = useMM();
  const crew = mm.s.friends.slice(0, 5).map(f => mm.person(f.id));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '24px 16px 0',
      padding: '32px 24px 26px',
      borderRadius: 28,
      background: 'var(--white)',
      boxShadow: 'var(--shadow-card)',
      textAlign: 'center',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      marginBottom: 18
    }
  }, crew.map((p, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      marginLeft: i ? -14 : 0,
      transform: `rotate(${[-8, 4, -3, 6, -5][i]}deg) translateY(${[4, -4, 2, -6, 3][i]}px)`,
      borderRadius: 999,
      boxShadow: '0 0 0 3px #fff',
      display: 'inline-flex',
      animation: `mmBob 2.4s ${i * .2}s ease-in-out infinite`
    }
  }, /*#__PURE__*/React.createElement(TAv, {
    name: p.name,
    size: 52
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 24px/1.1 var(--font-display)',
      letterSpacing: '-.03em'
    }
  }, "Nothing on the calendar"), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '8px 0 20px',
      font: '400 15px/1.45 var(--font-body)',
      color: 'var(--text-secondary)',
      textWrap: 'pretty'
    }
  }, "Rolls are better with friends. Pick a day, pick a gym, and bring someone along."), /*#__PURE__*/React.createElement(TBtn, {
    size: "lg",
    fullWidth: true,
    iconLeft: "plus",
    onClick: () => mm.go('create')
  }, "Plan a training session"), /*#__PURE__*/React.createElement(TBtn, {
    variant: "ghost",
    size: "sm",
    style: {
      marginTop: 8
    },
    onClick: () => mm.go('create', {
      past: true
    })
  }, "Already trained? Log it"));
}
function SessionDetail({
  id
}) {
  const mm = useMM();
  const P = mm.person;
  const s = mm.s.upcoming.find(x => x.id === id) || (mm.s.toComplete && mm.s.toComplete.id === id ? mm.s.toComplete : null);
  const [add, setAdd] = React.useState(false);
  const [pick, setPick] = React.useState([]);
  if (!s) return null;
  const isOrg = s.organizer === 'me';
  const mine = s.people.me;
  const rows = Object.entries(s.people).sort((a, b) => a[0] === s.organizer ? -1 : b[0] === s.organizer ? 1 : 0);
  const addable = mm.s.friends.map(f => f.id).filter(fid => !s.people[fid]);
  const footer = isOrg ? /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(TBtn, {
    variant: "secondary",
    iconLeft: "user-plus",
    fullWidth: true,
    onClick: () => {
      setPick([]);
      setAdd(true);
    }
  }, "Add people"), /*#__PURE__*/React.createElement(TBtn, {
    variant: "soft",
    iconLeft: "link",
    fullWidth: true,
    onClick: () => mm.toast('Invite link copied', 'success')
  }, "Copy link")) : mine === 'invited' ? /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(TBtn, {
    variant: "secondary",
    fullWidth: true,
    onClick: () => {
      mm.rsvp(s.id, 'declined');
      mm.back();
    }
  }, "Decline"), /*#__PURE__*/React.createElement(TBtn, {
    fullWidth: true,
    iconLeft: "check",
    onClick: () => mm.rsvp(s.id, 'going')
  }, "Join")) : /*#__PURE__*/React.createElement(Row, {
    style: {
      gap: 8,
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement(TBadge, {
    variant: "success",
    dot: true,
    style: {
      height: 34,
      padding: '0 14px',
      fontSize: 14
    }
  }, "You're going"), /*#__PURE__*/React.createElement(TBtn, {
    variant: "ghost",
    size: "sm",
    onClick: () => {
      mm.rsvp(s.id, 'declined');
      mm.back();
    }
  }, "Can't make it"));
  return /*#__PURE__*/React.createElement(Screen, {
    push: true,
    header: /*#__PURE__*/React.createElement(Header, {
      left: /*#__PURE__*/React.createElement(TIB, {
        icon: "chevron-left",
        label: "Back",
        onClick: mm.back
      }),
      title: "",
      right: isOrg ? /*#__PURE__*/React.createElement(TIB, {
        icon: "share-2",
        label: "Share",
        onClick: () => mm.toast('Invite link copied', 'success')
      }) : null
    }),
    footer: footer
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px'
    }
  }, /*#__PURE__*/React.createElement(SessionTicket, {
    s: s,
    big: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14,
      padding: '6px 16px',
      background: 'var(--white)',
      borderRadius: 22,
      boxShadow: 'var(--shadow-card)'
    }
  }, [['map-pin', s.gym], ['clock', s.day + ', ' + s.month + ' ' + s.date + ' · ' + s.time], [s.privacy === 'link' ? 'globe' : 'lock', s.privacy === 'link' ? 'Anyone with the link (Grip Gorillas account required)' : 'Friends only']].map(([ic, t], i) => /*#__PURE__*/React.createElement(Row, {
    key: i,
    style: {
      padding: '11px 0',
      boxShadow: i < 2 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none'
    }
  }, /*#__PURE__*/React.createElement(TIcon, {
    name: ic,
    size: 18,
    color: "var(--text-tertiary)"
  }), /*#__PURE__*/React.createElement(Txt, {
    s: 15,
    w: 500
  }, t)))), s.note && /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '14px 4px 0',
      font: '400 15px/1.45 var(--font-body)',
      color: 'var(--ink-700)'
    }
  }, "\u201C", s.note, "\u201D"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: '800 18px var(--font-display)',
      letterSpacing: '-.02em',
      margin: '22px 4px 10px'
    }
  }, "Who's coming"), /*#__PURE__*/React.createElement("div", {
    style: {
      background: 'var(--white)',
      borderRadius: 22,
      boxShadow: 'var(--shadow-card)',
      padding: '4px 14px'
    }
  }, rows.map(([pid, st], i) => {
    const p = P(pid);
    const [v, l] = STATUS[st];
    return /*#__PURE__*/React.createElement(Row, {
      key: pid,
      style: {
        padding: '10px 0',
        boxShadow: i < rows.length - 1 ? 'inset 0 -1px 0 var(--border-subtle)' : 'none',
        animation: mm.fresh === s.id + pid ? 'mmJoin .6s var(--ease-bounce)' : 'none'
      }
    }, /*#__PURE__*/React.createElement(TAv, {
      name: p.name,
      src: p.src,
      size: 40,
      belt: p.belt,
      ring: "#fff"
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement(Txt, {
      s: 15,
      w: 700
    }, pid === 'me' ? 'You' : p.name), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Txt, {
      s: 13,
      c: "var(--text-tertiary)"
    }, pid === s.organizer ? 'Organizer' : p.gym))), /*#__PURE__*/React.createElement(TBadge, {
      variant: v
    }, l), isOrg && pid !== 'me' && /*#__PURE__*/React.createElement(TIB, {
      icon: "x",
      size: 32,
      label: 'Remove ' + p.name,
      onClick: () => mm.removeParticipant(s.id, pid)
    }));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 16
    }
  })), add && /*#__PURE__*/React.createElement(TDlg, {
    contained: true,
    variant: "sheet",
    title: "Add people",
    description: "They're added straight to the session.",
    onClose: () => setAdd(false),
    actions: /*#__PURE__*/React.createElement(TBtn, {
      fullWidth: true,
      disabled: !pick.length,
      onClick: () => {
        mm.addParticipants(s.id, pick);
        setAdd(false);
      }
    }, "Add ", pick.length || '')
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, addable.length ? addable.map(fid => {
    const p = P(fid);
    return /*#__PURE__*/React.createElement(Row, {
      key: fid
    }, /*#__PURE__*/React.createElement(TAv, {
      name: p.name,
      size: 36
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement(Txt, {
      w: 600
    }, p.name)), /*#__PURE__*/React.createElement(TCb, {
      checked: pick.includes(fid),
      onChange: on => setPick(on ? [...pick, fid] : pick.filter(x => x !== fid))
    }));
  }) : /*#__PURE__*/React.createElement(Txt, {
    c: "var(--text-tertiary)"
  }, "All your friends are already in."))));
}
Object.assign(window, {
  SessionTicket,
  TrainingScreen,
  SessionDetail
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/Training.jsx", error: String((e && e.message) || e) }); }

// ui_kits/app/data.js
try { (() => {
(() => {
  const ph = n => '../../assets/photos/' + n + '.jpg';
  const T = true,
    F = false;
  window.MM_PH = ph;
  window.MM_SEED = {
    me: {
      id: 'me',
      name: 'Dani Alves',
      belt: 'purple',
      stripes: 2,
      gym: 'Tidewater BJJ',
      email: 'dani.alves@gmail.com',
      src: ph('portrait-gi')
    },
    people: {
      sarah: {
        name: 'Sarah Lee',
        belt: 'blue',
        stripes: 3,
        gym: 'Tidewater BJJ',
        hue: 'sky'
      },
      alex: {
        name: 'Alex Moreno',
        belt: 'white',
        stripes: 3,
        gym: 'Tidewater BJJ',
        hue: 'mint'
      },
      priya: {
        name: 'Priya Nair',
        belt: 'blue',
        stripes: 1,
        gym: 'Tidewater BJJ',
        hue: 'sun'
      },
      kenji: {
        name: 'Kenji Ito',
        belt: 'purple',
        stripes: 0,
        gym: 'Tidewater BJJ',
        hue: 'plum'
      },
      jamie: {
        name: 'Jamie Cole',
        belt: 'brown',
        stripes: 1,
        gym: 'North Shore Grappling',
        hue: 'plum'
      },
      marco: {
        name: 'Marco Silva',
        belt: 'black',
        stripes: 2,
        gym: 'Harbor Jiu-Jitsu',
        hue: 'coral'
      },
      lena: {
        name: 'Lena Park',
        belt: 'white',
        stripes: 1,
        gym: 'Tidewater BJJ',
        hue: 'mint'
      }
    },
    // weeks: last 9 completed calendar weeks oldest→newest; thisWeek: done | pending
    friends: [{
      id: 'sarah',
      weeks: [F, T, T, T, T, T, T, T, T],
      thisWeek: 'pending',
      best: 8,
      together: 31
    }, {
      id: 'kenji',
      weeks: [F, F, T, F, F, F, F, T, T],
      thisWeek: 'pending',
      best: 3,
      together: 9
    }, {
      id: 'alex',
      weeks: [T, F, F, F, F, F, T, T, T],
      thisWeek: 'done',
      best: 5,
      together: 22
    }, {
      id: 'priya',
      weeks: [F, F, F, F, F, F, F, F, F],
      thisWeek: 'done',
      best: 1,
      together: 2
    }, {
      id: 'jamie',
      weeks: [T, T, T, T, T, T, F, F, F],
      thisWeek: 'pending',
      best: 12,
      together: 40,
      brokeAgo: '3 weeks ago'
    }, {
      id: 'marco',
      weeks: [T, T, T, F, F, F, F, F, F],
      thisWeek: 'pending',
      best: 4,
      together: 7,
      brokeAgo: '6 weeks ago'
    }],
    posts: [{
      id: 'p1',
      organizer: 'sarah',
      title: 'Sunday No-Gi open mat',
      gym: 'Tidewater BJJ',
      date: 'Sun, Nov 1',
      ago: '18h',
      photo: ph('roll-gi'),
      participants: ['sarah', 'me', 'alex', 'kenji'],
      caption: 'Six rounds, zero ego. Alex finally hit that knee cut on me and will not stop talking about it.',
      likes: ['alex', 'kenji', 'priya', 'jamie', 'lena'],
      extraLikes: 19,
      comments: [{
        who: 'alex',
        text: 'Took me four months. Worth it.'
      }, {
        who: 'kenji',
        text: 'Rematch Thursday?'
      }]
    }, {
      id: 'p2',
      organizer: 'jamie',
      title: 'Leg drag drilling',
      gym: 'North Shore Grappling',
      date: 'Sat, Oct 31',
      ago: '2d',
      photo: ph('coach-help'),
      participants: ['jamie', 'priya', 'marco'],
      caption: 'Slow reps, then positional rounds from the leg drag. Priya was a menace.',
      likes: ['priya', 'marco'],
      extraLikes: 11,
      comments: [{
        who: 'priya',
        text: 'Hips sore in the best way'
      }]
    }, {
      id: 'p3',
      organizer: 'me',
      title: 'Friday fundamentals + rolls',
      gym: 'Tidewater BJJ',
      date: 'Fri, Oct 30',
      ago: '3d',
      photo: ph('group-class'),
      participants: ['me', 'sarah', 'priya', 'lena'],
      caption: 'Brought Lena to her first open roll. She tapped me with a collar choke. Proud and slightly embarrassed.',
      likes: ['sarah', 'lena', 'alex'],
      extraLikes: 27,
      comments: [{
        who: 'lena',
        text: 'I will be telling everyone about this'
      }]
    }, {
      id: 'p4',
      organizer: 'alex',
      title: 'Early bird gi class',
      gym: 'Tidewater BJJ',
      date: 'Wed, Oct 28',
      ago: '5d',
      photo: ph('gym-throw'),
      participants: ['alex', 'me', 'sarah'],
      caption: '6am crew. Takedown day.',
      likes: ['sarah'],
      extraLikes: 8,
      comments: []
    }],
    upcoming: [{
      id: 's2',
      title: 'Leg-lock study group',
      day: 'Tue',
      date: 3,
      month: 'Nov',
      time: '7:30 PM',
      gym: 'North Shore Grappling',
      organizer: 'jamie',
      privacy: 'friends',
      people: {
        jamie: 'going',
        marco: 'going',
        priya: 'going',
        me: 'invited'
      },
      note: 'Heel hook entries from SLX. Bring a rash guard.'
    }, {
      id: 's3',
      title: 'Lunch rolls',
      day: 'Thu',
      date: 5,
      month: 'Nov',
      time: '12:15 PM',
      gym: 'Tidewater BJJ',
      organizer: 'sarah',
      privacy: 'friends',
      people: {
        sarah: 'going',
        me: 'going',
        priya: 'going',
        kenji: 'invited'
      },
      note: '45 min, rounds only.'
    }, {
      id: 's1',
      title: 'Saturday open mat',
      day: 'Sat',
      date: 7,
      month: 'Nov',
      time: '10:00 AM',
      gym: 'Tidewater BJJ',
      organizer: 'me',
      privacy: 'link',
      people: {
        me: 'going',
        sarah: 'going',
        alex: 'going',
        kenji: 'invited',
        lena: 'declined'
      },
      note: 'All levels. Bring water, the mats get warm.'
    }],
    toComplete: {
      id: 'c1',
      title: 'Halloween no-gi open mat',
      day: 'Sat',
      date: 31,
      month: 'Oct',
      time: '10:00 AM',
      gym: 'Tidewater BJJ',
      organizer: 'me',
      people: {
        me: 'going',
        sarah: 'going',
        alex: 'going',
        priya: 'going',
        kenji: 'going'
      }
    },
    notifications: [{
      id: 'n1',
      kind: 'invite',
      who: 'jamie',
      session: 's2',
      time: '20m',
      unread: true
    }, {
      id: 'n2',
      kind: 'joined',
      who: 'alex',
      text: 'joined Saturday open mat',
      time: '2h',
      unread: true
    }, {
      id: 'n3',
      kind: 'comment',
      who: 'kenji',
      text: 'commented on Sunday No-Gi open mat',
      quote: 'Rematch Thursday?',
      photo: ph('roll-gi'),
      time: '16h',
      unread: true
    }, {
      id: 'n4',
      kind: 'published',
      who: 'sarah',
      text: 'shared Sunday No-Gi open mat. You\'re in it.',
      photo: ph('roll-gi'),
      time: '18h'
    }, {
      id: 'n5',
      kind: 'joined',
      who: 'sarah',
      text: 'joined Saturday open mat',
      time: '1d'
    }],
    gyms: ['Tidewater BJJ', 'North Shore Grappling', 'Harbor Jiu-Jitsu', 'Eastside MMA'],
    cameraRoll: ['roll-gi-2', 'team-lineup', 'floor-drill', 'grapple-match', 'bw-sweep', 'roll-gi'].map(ph)
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/app/data.js", error: String((e && e.message) || e) }); }

__ds_ns.Button = __ds_scope.Button;

__ds_ns.ICON_NAMES = __ds_scope.ICON_NAMES;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Logo = __ds_scope.Logo;

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.AvatarStack = __ds_scope.AvatarStack;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.BELT_COLORS = __ds_scope.BELT_COLORS;

__ds_ns.Belt = __ds_scope.Belt;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.StreakBelt = __ds_scope.StreakBelt;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Tabs = __ds_scope.Tabs;

})();

import assert from "node:assert/strict";

const origin = "https://matmonkey.lovable.app";
const token = process.env.SESSION_SHARE_TOKEN;
if (!token || !/^[a-f0-9]{64}$/i.test(token)) {
  console.error("Set SESSION_SHARE_TOKEN to a real active session invitation token. It will not be printed or redeemed.");
  process.exit(1);
}
const association = await fetch(`${origin}/.well-known/apple-app-site-association`, { redirect: "manual" });
assert.equal(association.status, 200, "Association must return 200 without redirect");
assert(association.headers.get("content-type")?.includes("application/json"), "Association must be JSON");
const data = await association.json();
const app = data.applinks?.details?.find((entry) => entry.appIDs?.includes("9R4A2F8F94.com.tienmai.intentionaltrainingnotes"));
assert(app, "Association must contain the production app identifier");
for (const kind of ["friend", "session", "goal"]) assert(app.components?.some((entry) => entry["/"] === `/${kind}/*`), `Missing ${kind} association`);
const page = await fetch(`${origin}/session/${token.toLowerCase()}`, { redirect: "manual", signal: AbortSignal.timeout(10000) });
assert.equal(page.status, 200, "Active session page must return 200");
assert.equal(page.headers.get("cache-control"), "no-store");
assert.equal(page.headers.get("referrer-policy"), "no-referrer");
const html = await page.text();
assert(html.includes(`matmind://session/${token.toLowerCase()}`), "Native destination must preserve the session token");
assert(html.includes('property="og:title"'), "Server HTML must contain the preview title");
assert(html.includes('name="twitter:card" content="summary_large_image"'), "Missing large-image metadata");
const imagePath = `/share/preview/session/${token.toLowerCase()}.png`;
assert(html.includes(`${origin}${imagePath}`), "Metadata must refer to the session-specific image");
const image = await fetch(origin + imagePath, { redirect: "manual", signal: AbortSignal.timeout(10000) });
assert.equal(image.status, 200, "Session image must return 200");
assert.equal(image.headers.get("content-type"), "image/png");
const png = Buffer.from(await image.arrayBuffer());
assert.equal(png.subarray(0, 8).toString("hex"), "89504e470d0a1a0a", "Response must be a real PNG");
assert.equal(png.readUInt32BE(16), 1200);
assert.equal(png.readUInt32BE(20), 630);
console.log("Live association, session metadata, native destination, and 1200 × 630 PNG passed. Complete signed physical-device checks before shipping the iOS build.");

// Orbit agent — Ground Control in iMessage (Photon Spectrum).
//
// Crew members can live in iMessage instead of the app (e.g. Grandma):
//  • Invites:   the app writes imessage_invites → Ground Control texts a welcome.
//  • Landings:  when a capsule lands for someone reachable by iMessage, Ground
//               Control texts a context-aware line, the page image, voice notes
//               as native iMessage voice notes, and the capsule's question.
//  • Replies:   whatever they text back (words, photos, videos, voice notes) is
//               gathered for a few seconds and launched back as a real capsule —
//               it flies to the sender's app as a rocket. Ambiguous recipient →
//               Ground Control asks with an iMessage poll (human in the loop).
//  • Opened:    iMessage read receipts mark the capsule "Opened by Grandma".
//
// Everything flows through Supabase, so this can run on a laptop with no
// public URL. Run: `bun install && bun start` (see agent/README.md).

import { Spectrum, attachment, voice, poll } from "spectrum-ts";
import { imessage } from "spectrum-ts/providers/imessage";
import {
  db, required, normalizePhone, profileByPhone, profilesByIds, crewOf, latestCapsuleTo,
  downloadMedia, mediaPath, uploadMedia, replyLayout,
  type Capsule, type Profile, type ReplyPart,
} from "./orbit";
import { landingLine } from "./groundControl";
import { allowPhone, assignedLine } from "./photon";

const REPLY_GATHER_MS = 8_000;     // wait for "photo, then a caption" bursts
const REPLY_FLIGHT_SECONDS = 10;   // Warp speed, same as the app's default
const TICK_MS = 4_000;

const app = await Spectrum({
  projectId: required("SPECTRUM_PROJECT_ID"),
  projectSecret: required("SPECTRUM_PROJECT_SECRET"),
  providers: [imessage.config()],
});
const im = imessage(app);
console.log("🛰️  Ground Control is online in iMessage.");

/** Our outbound landing messages → the capsule they announced (for read receipts). */
const sentForCapsule = new Map<string, string>();
/** Replies being gathered, per phone. */
const gathering = new Map<string, { profile: Profile; space: any; parts: ReplyPart[]; timer?: Timer }>();
/** Replies waiting on "who is this for?" poll answers, per phone. */
const awaitingPoll = new Map<string, { profile: Profile; space: any; parts: ReplyPart[]; options: { linkId: string; member: Profile }[] }>();
/** Back-off so a failing send (e.g. number not allowlisted) isn't retried every tick. */
const retryAfter = new Map<string, number>();

async function dm(phone: string, name: string) {
  await allowPhone(phone, name); // Photon Pro allowlist — no manual dashboard step
  return im.space.create(await im.user(phone));
}

function isNotAllowed(error: unknown): boolean {
  return (error instanceof Error ? error.message : String(error)).includes("Target not allowed");
}

async function sendWelcome(space: any, name: string, inviterName: string) {
  await space.responding(async () => {
    await space.send(
      `Hi ${name}! 👋 I'm Ground Control from Orbit. ${inviterName} added you to their crew — ` +
        `when they send you a capsule, it'll land right here in your texts.`,
      `You can reply anytime with words, photos, or a voice note, and I'll fly it back to ${inviterName}. No app needed.`,
    );
  });
}

/**
 * Someone with a waiting invite just texted their line, so we're allowed to
 * message them now. Sends the welcome(s) and returns true, so their "hi"
 * isn't launched as a capsule.
 */
async function welcomeWaiting(phone: string, space: any): Promise<boolean> {
  const { data: waiting } = await db.from("imessage_invites").select("*").eq("phone", phone).eq("status", "waiting");
  if (!waiting?.length) return false;
  const inviters = await profilesByIds(waiting.map((i) => i.inviter_id));
  for (const invite of waiting) {
    const inviterName = inviters.get(invite.inviter_id)?.display_name ?? "Your crew";
    await sendWelcome(space, invite.display_name, inviterName);
    await db.from("imessage_invites").update({ status: "sent" }).eq("id", invite.id);
    console.log(`✉️  ${invite.display_name} (${phone}) texted in — welcomed for ${inviterName}`);
  }
  return true;
}

function allowlistHint(error: unknown, phone: string): string {
  const message = error instanceof Error ? error.message : String(error);
  return isNotAllowed(error)
    ? `Photon wouldn't text ${phone} yet — check the agent log (auto-registration), or add it under Users in the Photon dashboard, then invite again.`
    : message;
}

// MARK: - Invites (app → iMessage)

async function processInvites() {
  const { data: invites } = await db.from("imessage_invites").select("*").eq("status", "pending").limit(10);
  for (const invite of invites ?? []) {
    const phone = normalizePhone(invite.phone);
    try {
      const inviter = (await profilesByIds([invite.inviter_id])).get(invite.inviter_id);
      if (!inviter) throw new Error("Inviter profile not found");

      // Reuse an existing Orbit profile for this number, or create an iMessage-only one.
      let profile = await profileByPhone(phone);
      if (!profile) {
        const { data, error } = await db
          .from("profiles")
          .insert({ display_name: invite.display_name, phone, imessage_only: true })
          .select()
          .single();
        if (error) throw error;
        profile = data as Profile;
      }
      const alreadyCrew = (await crewOf(inviter.id)).some((c) => c.member.id === profile!.id);
      if (!alreadyCrew) {
        const code = `IM${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
        const { error } = await db.from("crew_links").insert({ user_a: inviter.id, user_b: profile.id, invite_code: code });
        if (error) throw error;
      }

      try {
        await sendWelcome(await dm(phone, invite.display_name), invite.display_name, inviter.display_name);
      } catch (error) {
        if (!isNotAllowed(error)) throw error;
        // Shared lines only text people who've texted their line first. Park the
        // invite; the app shows "text hi to <line>", and the welcome goes out
        // when they do (handleInbound → welcomeWaiting).
        const line = await assignedLine(phone);
        if (!line) throw error;
        await db.from("imessage_invites").update({ status: "waiting", line, profile_id: profile.id, error: null }).eq("id", invite.id);
        console.log(`⏳ ${invite.display_name} (${phone}) needs to text ${line} once to join`);
        continue;
      }
      await db.from("imessage_invites").update({ status: "sent", profile_id: profile.id, error: null }).eq("id", invite.id);
      console.log(`✉️  Invited ${invite.display_name} (${phone}) for ${inviter.display_name}`);
    } catch (error) {
      await db.from("imessage_invites").update({ status: "failed", error: allowlistHint(error, phone) }).eq("id", invite.id);
      console.error(`Invite to ${phone} failed:`, error);
    }
  }
}

// MARK: - Landings (capsule → iMessage)

async function deliverLandedCapsules() {
  const { data: reachable } = await db
    .from("profiles")
    .select("*")
    .not("phone", "is", null)
    .or("imessage_only.eq.true,imessage_updates.eq.true");
  const recipients = new Map(((reachable ?? []) as Profile[]).map((p) => [p.id, p]));
  if (recipients.size === 0) return;

  const { data: due } = await db
    .from("capsules")
    .select("*")
    .in("recipient_id", [...recipients.keys()])
    .is("imessage_notified_at", null)
    .in("status", ["launched", "in_transit", "landed"])
    .lte("delivery_at", new Date().toISOString())
    .limit(10);

  for (const capsule of (due ?? []) as Capsule[]) {
    if ((retryAfter.get(capsule.id) ?? 0) > Date.now()) continue;
    const recipient = recipients.get(capsule.recipient_id)!;
    try {
      await deliver(capsule, recipient);
      retryAfter.delete(capsule.id);
    } catch (error) {
      retryAfter.set(capsule.id, Date.now() + 60_000);
      console.error(`Delivering capsule ${capsule.id} failed:`, allowlistHint(error, recipient.phone ?? ""));
    }
  }
}

async function deliver(capsule: Capsule, recipient: Profile) {
  const sender = (await profilesByIds([capsule.sender_id])).get(capsule.sender_id);
  const senderName = sender?.display_name ?? "your crew";
  const items = capsule.layout.items;
  const contents: any[] = [await landingLine(capsule, senderName, recipient.display_name)];

  // The page itself: the snapshot the sender's app rendered at launch, or the first photo.
  const firstPhoto = items.find((i) => i.type === "photo" && i.media);
  const pagePath = capsule.preview_image_path ?? (firstPhoto ? mediaPath(capsule.sender_id, firstPhoto.media!, "photo") : null);
  const pageBytes = pagePath ? await downloadMedia(pagePath) : null;
  if (pageBytes) {
    const isPng = pagePath!.endsWith(".png");
    contents.push(attachment(pageBytes, { name: isPng ? "capsule.png" : "capsule.jpg", mimeType: isPng ? "image/png" : "image/jpeg" }));
  }

  // Voice notes arrive as real iMessage voice notes.
  for (const note of items.filter((i) => i.type === "audio" && i.media)) {
    const bytes = await downloadMedia(mediaPath(capsule.sender_id, note.media!, "audio"));
    if (bytes) contents.push(voice(bytes, { name: "voice-note.m4a", mimeType: "audio/mp4" }));
  }

  const question = items.find((i) => i.type === "question")?.text;
  contents.push(
    question
      ? `${senderName} asked: “${question}” Just reply here and I'll fly your answer back.`
      : `Reply here with words, photos, or a voice note and I'll launch it back to ${senderName}.`,
  );

  const space = await dm(recipient.phone!, recipient.display_name);
  await space.responding(async () => {
    const sent = await space.send(...(contents as [any, any, ...any[]]));
    for (const message of Array.isArray(sent) ? sent : [sent]) {
      if (message?.id) sentForCapsule.set(message.id, capsule.id);
    }
  });

  const update: Record<string, unknown> = { imessage_notified_at: new Date().toISOString() };
  // No app on the other end to mark it landed, so Ground Control does.
  if (recipient.imessage_only && capsule.status !== "landed") update.status = "landed";
  await db.from("capsules").update(update).eq("id", capsule.id);
  console.log(`🚀 Delivered capsule ${capsule.id} from ${senderName} to ${recipient.display_name}`);
}

async function markOpened(capsuleId: string) {
  const { data } = await db.from("capsules").select("recipient_id,status").eq("id", capsuleId).maybeSingle();
  if (!data || data.status === "opened") return;
  const recipient = (await profilesByIds([data.recipient_id])).get(data.recipient_id);
  if (!recipient?.imessage_only) return; // app users open it in the app
  await db.from("capsules").update({ status: "opened", opened_at: new Date().toISOString() }).eq("id", capsuleId);
  console.log(`📬 Capsule ${capsuleId} opened in iMessage by ${recipient.display_name}`);
}

// MARK: - Replies (iMessage → capsule → rocket back)

async function launchReply(profile: Profile, target: { linkId: string; member: Profile }, parts: ReplyPart[], space: any) {
  const now = new Date();
  const { error } = await db.from("capsules").insert({
    sender_id: profile.id,
    recipient_id: target.member.id,
    crew_link_id: target.linkId,
    status: "launched",
    layout: replyLayout(parts),
    launched_at: now.toISOString(),
    delivery_at: new Date(now.getTime() + REPLY_FLIGHT_SECONDS * 1000).toISOString(),
    delivery_delay_seconds: REPLY_FLIGHT_SECONDS,
    source: "imessage",
  });
  if (error) throw error;
  await space.send(`🚀 Launched to ${target.member.display_name}! It lands on their launchpad in ${REPLY_FLIGHT_SECONDS} seconds.`);
  console.log(`↩️  ${profile.display_name} replied from iMessage → capsule to ${target.member.display_name}`);
}

async function flushReply(phone: string) {
  const entry = gathering.get(phone);
  gathering.delete(phone);
  if (!entry || entry.parts.length === 0) return;
  const { profile, space, parts } = entry;

  // Reply to whoever sent them their latest capsule…
  const latest = await latestCapsuleTo(profile.id);
  const crew = await crewOf(profile.id);
  const replyTarget = latest ? crew.find((c) => c.member.id === latest.sender_id) : undefined;
  if (replyTarget) return launchReply(profile, replyTarget, parts, space);

  // …otherwise the only crew member, or ask.
  if (crew.length === 1) return launchReply(profile, crew[0], parts, space);
  if (crew.length === 0) {
    await space.send("You're not in anyone's crew yet — ask someone on Orbit to invite you, and I'll deliver for you.");
    return;
  }
  awaitingPoll.set(phone, { profile, space, parts, options: crew });
  await space.send(poll("Who should I send this to?", crew.map((c) => c.member.display_name)));
}

async function gather(phone: string, profile: Profile, space: any, part: ReplyPart) {
  const entry = gathering.get(phone) ?? { profile, space, parts: [] };
  entry.parts.push(part);
  clearTimeout(entry.timer);
  entry.timer = setTimeout(() => flushReply(phone).catch((e) => console.error("Reply failed:", e)), REPLY_GATHER_MS);
  gathering.set(phone, entry);
}

async function handleInbound(space: any, message: any) {
  const content = message.content;

  // Read receipts: "Opened by Grandma" in the sender's app.
  if (content.type === "read") {
    const capsuleId = sentForCapsule.get(content.target?.id);
    if (capsuleId) await markOpened(capsuleId);
    return;
  }
  if (message.direction === "outbound") return;

  const phone = normalizePhone(message.sender?.id ?? "");
  const profile = await profileByPhone(phone);
  if (!profile) {
    await message.reply("Hi! I'm Ground Control from Orbit. Ask someone in your crew to add you by phone, and capsules will land right here.");
    return;
  }

  // First text from someone who was invited but hadn't opened their line yet.
  if (await welcomeWaiting(phone, space)) return;

  // Replying at all means they've opened what we sent.
  const latest = await latestCapsuleTo(profile.id);
  if (latest) await markOpened(latest.id);

  switch (content.type) {
    case "reaction": {
      const capsuleId = sentForCapsule.get(content.target?.id);
      if (capsuleId) await markOpened(capsuleId);
      return;
    }
    case "poll_option": {
      const pending = awaitingPoll.get(phone);
      const choice = content.option?.title ?? content.title;
      const target = pending?.options.find((o) => o.member.display_name === choice);
      if (pending && target && content.selected) {
        awaitingPoll.delete(phone);
        await launchReply(pending.profile, target, pending.parts, pending.space);
      }
      return;
    }
    case "text": {
      const text: string = content.text.trim();
      if (["help", "?"].includes(text.toLowerCase())) {
        await message.reply("Text me words, photos, videos, or a voice note and I'll launch them to your crew as a capsule. 🚀");
        return;
      }
      await gather(phone, profile, space, { kind: "text", text });
      return;
    }
    case "voice": {
      const bytes = await content.read();
      const mediaId = await uploadMedia(profile.id, "audio", bytes, content.mimeType ?? "audio/mp4");
      await gather(phone, profile, space, { kind: "audio", mediaId });
      return;
    }
    case "attachment": {
      const mime: string = content.mimeType ?? "";
      const kind = mime.startsWith("image/") ? "photo" : mime.startsWith("video/") ? "video" : mime.startsWith("audio/") ? "audio" : null;
      if (!kind) {
        await message.reply("I can carry photos, videos, voice notes, and words — that file type won't fit in a capsule.");
        return;
      }
      const bytes = await content.read();
      const mediaId = await uploadMedia(profile.id, kind, bytes, mime);
      await gather(phone, profile, space, { kind, mediaId });
      return;
    }
    default:
      return; // stickers, contacts, etc. — ignored
  }
}

// MARK: - Run

let ticking = false;
setInterval(async () => {
  if (ticking) return;
  ticking = true;
  try {
    await processInvites();
    await deliverLandedCapsules();
  } catch (error) {
    console.error("Tick failed:", error);
  } finally {
    ticking = false;
  }
}, TICK_MS);

process.on("SIGINT", async () => {
  console.log("\n🛰️  Ground Control signing off.");
  await app.stop();
  process.exit(0);
});

for await (const [space, message] of app.messages) {
  if (message.platform !== "imessage") continue;
  handleInbound(space, message).catch((error) => console.error("Inbound message failed:", error));
}

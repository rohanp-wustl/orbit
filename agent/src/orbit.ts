// Orbit's Supabase data, from the agent's side. Uses the service-role key, so
// it can act for iMessage-only crew members (who have no app session).
// Shapes mirror the iOS models; layout JSON uses the same snake_case keys the
// app writes (JSONEncoder .convertToSnakeCase).

import { createClient } from "@supabase/supabase-js";

export const db = createClient(
  required("SUPABASE_URL"),
  required("SUPABASE_SERVICE_ROLE_KEY"),
  { auth: { persistSession: false, autoRefreshToken: false } },
);

export function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing ${name} — copy agent/.env.example to agent/.env and fill it in.`);
  return value;
}

export type Profile = {
  id: string;
  display_name: string;
  phone: string | null;
  imessage_only: boolean;
  imessage_updates: boolean;
};

export type LayoutItem = {
  id: string;
  type: "photo" | "video" | "audio" | "text" | "letter" | "question" | "song" | "recipe" | "sticker";
  media?: string;
  text?: string;
  font?: string;
  asset?: string;
  title?: string;
  artist?: string;
  lines?: string[];
  x: number;
  y: number;
  w: number;
  rotation?: number;
  z?: number;
  frame?: string;
  ai_drafted?: boolean;
};

export type Capsule = {
  id: string;
  sender_id: string;
  recipient_id: string;
  crew_link_id: string;
  status: "draft" | "launched" | "in_transit" | "landed" | "opened";
  layout: { background: string; template: string; items: LayoutItem[]; package_color?: string };
  created_at: string;
  launched_at: string | null;
  delivery_at: string | null;
  preview_image_path: string | null;
  source: "app" | "imessage";
  imessage_notified_at: string | null;
};

/** E.164-ish normalization so "(314) 555-0199" and "+13145550199" match. */
export function normalizePhone(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.includes("@")) return trimmed.toLowerCase(); // iMessage email handles
  const digits = trimmed.replace(/\D/g, "");
  if (trimmed.startsWith("+")) return `+${digits}`;
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length === 11 && digits.startsWith("1")) return `+${digits}`;
  return `+${digits}`;
}

export async function profileByPhone(phone: string): Promise<Profile | null> {
  const { data } = await db.from("profiles").select("*").eq("phone", normalizePhone(phone)).maybeSingle();
  return data as Profile | null;
}

export async function profilesByIds(ids: string[]): Promise<Map<string, Profile>> {
  if (ids.length === 0) return new Map();
  const { data } = await db.from("profiles").select("*").in("id", ids);
  return new Map(((data ?? []) as Profile[]).map((p) => [p.id, p]));
}

/** Crew members of a profile (the other person on each joined link). */
export async function crewOf(profileId: string): Promise<{ linkId: string; member: Profile }[]> {
  const { data } = await db
    .from("crew_links")
    .select("id,user_a,user_b")
    .or(`user_a.eq.${profileId},user_b.eq.${profileId}`)
    .not("user_b", "is", null);
  const links = (data ?? []) as { id: string; user_a: string; user_b: string }[];
  const others = links.map((l) => (l.user_a === profileId ? l.user_b : l.user_a));
  const profiles = await profilesByIds(others);
  return links.flatMap((l) => {
    const member = profiles.get(l.user_a === profileId ? l.user_b : l.user_a);
    return member ? [{ linkId: l.id, member }] : [];
  });
}

/** The newest capsule sent TO this profile — replies go back to its sender. */
export async function latestCapsuleTo(profileId: string): Promise<Capsule | null> {
  const { data } = await db
    .from("capsules")
    .select("*")
    .eq("recipient_id", profileId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  return data as Capsule | null;
}

export async function downloadMedia(path: string): Promise<Buffer | null> {
  const { data, error } = await db.storage.from("media").download(path);
  if (error || !data) return null;
  return Buffer.from(await data.arrayBuffer());
}

/** Same path convention as the app's MediaRepository.storagePath. */
export function mediaPath(ownerId: string, mediaId: string, type: LayoutItem["type"]): string {
  const ext = type === "audio" ? "m4a" : type === "video" ? "mov" : "jpg";
  return `${ownerId.toLowerCase()}/${mediaId}.${ext}`;
}

export async function uploadMedia(
  ownerId: string,
  type: "photo" | "video" | "audio",
  bytes: Buffer,
  contentType: string,
  transcript?: string,
): Promise<string> {
  const mediaId = crypto.randomUUID().toLowerCase();
  const path = mediaPath(ownerId, mediaId, type);
  const { error } = await db.storage.from("media").upload(path, bytes, { contentType, upsert: true });
  if (error) throw error;
  await db.from("media_assets").insert({ id: mediaId, type, storage_path: path, transcript, uploaded_by: ownerId });
  return mediaId;
}

// polaroid_scatter slots — kept in sync with PageTemplate in AssetCatalog.swift.
const PHOTO_SLOTS = [
  { x: 0.3, y: 0.22, w: 0.44, rotation: -7 },
  { x: 0.7, y: 0.36, w: 0.4, rotation: 6 },
  { x: 0.32, y: 0.55, w: 0.38, rotation: 4 },
  { x: 0.7, y: 0.68, w: 0.36, rotation: -5 },
];
const WORD_SLOT = { x: 0.5, y: 0.84, w: 0.8, rotation: -2 };
const AUDIO_SLOT = { x: 0.24, y: 0.92, w: 0.34, rotation: -4 };

export type ReplyPart =
  | { kind: "text"; text: string }
  | { kind: "photo" | "video" | "audio"; mediaId: string };

/**
 * A reply from iMessage as a capsule page. The sender's words are used
 * verbatim — Ground Control arranges, it doesn't rewrite a person's reply.
 */
export function replyLayout(parts: ReplyPart[]): Capsule["layout"] {
  const items: LayoutItem[] = [];
  let z = 1;
  let photoIndex = 0;
  for (const part of parts) {
    if (part.kind === "photo" || part.kind === "video") {
      const slot = PHOTO_SLOTS[Math.min(photoIndex++, PHOTO_SLOTS.length - 1)];
      items.push({ id: `im_${z}`, type: part.kind, media: part.mediaId, ...slot, z: z++, frame: part.kind === "photo" ? "polaroid" : undefined });
    } else if (part.kind === "audio") {
      items.push({ id: `im_${z}`, type: "audio", media: part.mediaId, ...AUDIO_SLOT, z: z++ });
    }
  }
  const words = parts.filter((p): p is { kind: "text"; text: string } => p.kind === "text").map((p) => p.text).join("\n").trim();
  if (words) {
    const isLetter = words.split(/\s+/).length > 14;
    const slot = photoIndex === 0 ? { x: 0.5, y: isLetter ? 0.34 : 0.4, w: 0.84, rotation: -1 } : WORD_SLOT;
    items.push({ id: `im_${z}`, type: isLetter ? "letter" : "text", text: words, font: "handwritten", ...slot, z: z++ });
  }
  items.push({ id: `im_${z}`, type: "sticker", asset: "heart", x: 0.88, y: 0.1, w: 0.12, rotation: 12, z: z++ });
  return { background: "kraft_paper_02", template: "polaroid_scatter", items, package_color: "seafoam" };
}

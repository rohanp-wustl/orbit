// Ground Control's voice in iMessage: one short, context-aware line announcing
// a landed capsule, grounded only in what's actually inside it. Same rules as
// the app's AI spec (docs/AI_SPEC.md): no invented facts, no stock phrases, no
// mention of AI. Falls back to a fixed line if Gemini is unavailable.

import type { Capsule } from "./orbit";

const BANNED = [
  "i hope this finds you well", "hope this finds you", "cherish", "journey", "just wanted to say",
  "sending you love", "sending love", "thinking of you today", "hope you're doing well", "treasure",
  "near and far", "no matter the distance", "special someone", "embark", "heartfelt", "as an ai",
];

const MODELS = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash-lite"];

export function capsuleSummary(capsule: Capsule): string {
  const items = capsule.layout.items;
  const count = (type: string) => items.filter((i) => i.type === type).length;
  const words = items
    .filter((i) => ["text", "letter", "question", "song", "recipe"].includes(i.type))
    .map((i) => (i.type === "song" ? `song: ${i.title} by ${i.artist}` : i.type === "recipe" ? `recipe: ${i.title}` : i.text))
    .filter(Boolean)
    .join(" | ");
  return `${count("photo")} photos, ${count("video")} videos, ${count("audio")} voice notes. Words on the page: ${words || "(none)"}`;
}

export async function landingLine(capsule: Capsule, senderName: string, recipientName: string): Promise<string> {
  const fallback = `🚀 A capsule from ${senderName} just landed! Here's what's inside:`;
  const key = process.env.GEMINI_API_KEY;
  if (!key) return fallback;

  const prompt = `You are Ground Control, the friendly mission-control voice of Orbit, an app for sending scrapbook care packages.
A capsule from ${senderName} just landed for ${recipientName} in iMessage. Write ONE short text message (max 25 words) announcing it,
teasing what's inside using ONLY these facts: ${capsuleSummary(capsule)}.
Rules: warm and a little playful, start with 🚀, no other emoji, don't quote the whole page, never invent anything,
never mention AI, never use greeting-card phrases. Output only the message text.`;

  for (const model of MODELS) {
    try {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }], generationConfig: { temperature: 0.9 } }),
        signal: AbortSignal.timeout(12_000),
      });
      if (!res.ok) continue; // 429 quota / 503 load → next model
      const json: any = await res.json();
      const parts: any[] = json?.candidates?.[0]?.content?.parts ?? [];
      const text: string = (parts.filter((p) => !p.thought).pop()?.text ?? "").trim();
      const lower = text.toLowerCase();
      if (text && text.split(/\s+/).length <= 30 && !BANNED.some((b) => lower.includes(b))) return text;
    } catch {
      // timeout/network → next model
    }
  }
  return fallback;
}

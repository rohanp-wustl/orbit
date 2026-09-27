// Photon's Free/Pro plans send from a shared line that may only text numbers
// registered as "Users" on the project (an anti-spam allowlist — separate from
// Orbit's own sign-in). Instead of adding every crew member by hand in the
// dashboard, the agent registers a number right before it first texts it.
//
// Uses the same Dashboard API call as `npx @photon-ai/cli spectrum users add`,
// authenticated with your CLI login token (run `npx @photon-ai/cli login` once)
// or PHOTON_TOKEN. If neither is available, this is a no-op and you add numbers
// in the dashboard as before.

import { readdir, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const API_HOST = process.env.PHOTON_API_HOST ?? "https://app.photon.codes";
const allowed = new Set<string>();

async function dashboardToken(): Promise<string | null> {
  if (process.env.PHOTON_TOKEN) return process.env.PHOTON_TOKEN;
  // Where the Photon CLI stores `photon login` credentials.
  const base = process.env.PHOTON_CONFIG_DIR
    ?? join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "photon");
  try {
    const dir = join(base, "credentials");
    for (const file of (await readdir(dir)).filter((f) => f.endsWith(".json"))) {
      const creds = JSON.parse(await readFile(join(dir, file), "utf8"));
      if (typeof creds.accessToken === "string") return creds.accessToken;
    }
  } catch {
    // not logged in
  }
  return null;
}

/** Photon requires an email per user; plus-addressing keeps each one unique and routes to you. */
function placeholderEmail(phone: string): string | null {
  const owner = process.env.PHOTON_USER_EMAIL;
  if (!owner || !owner.includes("@")) return null;
  const [local, domain] = owner.split("@");
  return `${local}+orbit${phone.replace(/\D/g, "")}@${domain}`;
}

/**
 * The shared-pool number Photon assigned to this person. On shared lines they
 * must text this number once before Ground Control can message them.
 */
export async function assignedLine(phone: string): Promise<string | null> {
  const id = process.env.SPECTRUM_PROJECT_ID;
  const secret = process.env.SPECTRUM_PROJECT_SECRET;
  try {
    const res = await fetch(`https://spectrum.photon.codes/projects/${id}/users/`, {
      headers: { Authorization: `Basic ${btoa(`${id}:${secret}`)}` },
      signal: AbortSignal.timeout(10_000),
    });
    const body: any = await res.json();
    const users: any[] = body?.data?.users ?? [];
    return users.find((u) => u.phoneNumber === phone)?.assignedPhoneNumber ?? null;
  } catch {
    return null;
  }
}

/**
 * Make sure Photon's shared line is allowed to text `phone`. Best-effort:
 * failures are logged, and the send is still attempted (the number may
 * already be on the list).
 */
export async function allowPhone(phone: string, name: string): Promise<void> {
  if (allowed.has(phone) || phone.includes("@")) return;
  const token = await dashboardToken();
  const email = placeholderEmail(phone);
  if (!token || !email) return;

  const [firstName, ...rest] = (name.trim() || "Orbit").split(/\s+/);
  try {
    const res = await fetch(`${API_HOST}/api/projects/${process.env.SPECTRUM_PROJECT_ID}/spectrum/users`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ firstName, lastName: rest.join(" ") || "Crew", email, phoneNumber: phone, sendInvite: false }),
      signal: AbortSignal.timeout(10_000),
    });
    const body = await res.text();
    if (res.ok || /already|exist|duplicate/i.test(body)) {
      allowed.add(phone);
      if (res.ok) console.log(`✅ Registered ${phone} with Photon`);
    } else {
      console.warn(`Photon user registration for ${phone} failed (${res.status}): ${body.slice(0, 200)}`);
    }
  } catch (error) {
    console.warn(`Photon user registration for ${phone} failed:`, error);
  }
}

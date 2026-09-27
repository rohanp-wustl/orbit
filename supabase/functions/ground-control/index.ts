// Orbit — Ground Control proxy (Supabase Edge Function).
//
// Keeps the Gemini API key on the server: the app sends the same
// generateContent body it would send to Gemini (plus a "model" field), this
// function checks the caller is a signed-in Orbit user, adds the key, and
// forwards the request. Deploy: see docs/SERVER_SETUP.md.
//
//   supabase secrets set GEMINI_API_KEY=...
//   supabase functions deploy ground-control

import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_MODELS = new Set(["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.5-flash-lite"]);

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  // Only signed-in Orbit users (anonymous accounts included) may call Gemini.
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const body = await req.json();
  const model = ALLOWED_MODELS.has(body.model) ? body.model : "gemini-3.8-flash";
  delete body.model;

  const upstream = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${Deno.env.get("GEMINI_API_KEY")}`,
    { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) },
  );
  // Pass Gemini's status through so the app's 503 → next-model fallback still works.
  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: { "Content-Type": "application/json" },
  });
});

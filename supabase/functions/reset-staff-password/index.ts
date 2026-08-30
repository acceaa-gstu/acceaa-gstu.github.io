// Supabase Edge Function: reset-staff-password
//
// Lets a logged-in Admin set a new password for ANY of the 5 staff
// accounts — this is what the Account Settings panel needs, and it's the
// one piece of the admin panel that can't be done directly from the
// browser (it needs the secret service-role key, which must never be
// shipped in front-end code).
//
// DEPLOY: Supabase Dashboard → Edge Functions → Create a new function,
// name it exactly "reset-staff-password", paste this whole file in, then
// Deploy. SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY
// are provided automatically by Supabase inside every Edge Function — you
// do not need to set any secrets by hand.
//
// CALL IT FROM THE APP (once wired up in a later step) like:
//   const { data, error } = await supabase.functions.invoke('reset-staff-password', {
//     body: { targetUserId, newPassword }
//   });
// supabase-js automatically attaches the logged-in admin's auth token.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Once the site is live on GitHub Pages, tighten this to your real origin,
// e.g. "https://acceaa-gstu.github.io" instead of "*".
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Bound to the CALLER's own token — used only to verify who is asking.
    // This client has no elevated privileges of its own.
    const callerClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user: caller }, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !caller) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: callerProfile, error: profileErr } = await callerClient
      .from("staff_profiles")
      .select("role")
      .eq("id", caller.id)
      .single();

    if (profileErr || callerProfile?.role !== "admin") {
      return new Response(
        JSON.stringify({ error: "Only admins can reset another staff member's password" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { targetUserId, newPassword } = await req.json();
    if (!targetUserId || !newPassword || String(newPassword).length < 6) {
      return new Response(
        JSON.stringify({ error: "targetUserId and a newPassword (min 6 characters) are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Admin client using the SERVICE ROLE key — only ever used here, inside
    // this server-side function. It is never sent to, or reachable from,
    // the browser.
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { error: updateErr } = await adminClient.auth.admin.updateUserById(targetUserId, {
      password: newPassword,
    });

    if (updateErr) {
      return new Response(JSON.stringify({ error: updateErr.message }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

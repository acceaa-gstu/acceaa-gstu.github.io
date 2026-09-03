// Supabase Edge Function: share-preview
//
// Serves a tiny HTML page with real Open Graph / Twitter Card tags for one
// specific event, achievement, or notice - so a WhatsApp/Facebook/etc. link
// preview shows THAT item's own title, description and photo, instead of
// just the generic site branding every page shows. Link-preview crawlers
// (facebookexternalhit, WhatsApp, Twitterbot, Slackbot, TelegramBot, ...)
// read the raw HTML below and stop there - they don't run JavaScript. A
// real person who taps the link gets redirected straight into the actual
// site, instantly.
//
// DEPLOY: Supabase Dashboard -> Edge Functions -> Create a new function,
// name it exactly "share-preview", paste this whole file in.
// IMPORTANT: turn OFF "Verify JWT" for this function (there's a toggle
// shown when creating it, and again under the function's own Settings) -
// link-preview bots don't send an auth header, so with JWT verification on
// they'd get a 401 and no preview would ever show. This function only ever
// reads data that's already public on the site (events/achievements/
// notices - same as any visitor sees), so it's safe to leave open.
//
// URL FORMAT (this is what the site's shareEventById/shareAchievementById/
// shareNotice functions build and share):
//   https://<project-ref>.supabase.co/functions/v1/share-preview?type=event&id=<uuid>
//   https://<project-ref>.supabase.co/functions/v1/share-preview?type=achievement&id=<uuid>
//   https://<project-ref>.supabase.co/functions/v1/share-preview?type=notice&id=<uuid>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SITE_URL = "https://acceaa-gstu.github.io";
const DEFAULT_IMAGE = SITE_URL + "/assets/logo.png";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function escapeHtml(s: unknown): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c] as string));
}

function truncate(s: unknown, n: number): string {
  const str = String(s ?? "");
  return str.length > n ? str.slice(0, n - 1).trimEnd() + "…" : str;
}

function renderPage(opts: { title: string; description: string; image: string; redirectUrl: string }): string {
  const title = escapeHtml(opts.title);
  const description = escapeHtml(truncate(opts.description, 200));
  const image = escapeHtml(opts.image);
  const redirectUrl = escapeHtml(opts.redirectUrl);
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=${redirectUrl}">
<title>${title}</title>
<meta property="og:type" content="article">
<meta property="og:site_name" content="ACCEAA, GSTU — Alumni Association">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:image" content="${image}">
<meta property="og:url" content="${redirectUrl}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${title}">
<meta name="twitter:description" content="${description}">
<meta name="twitter:image" content="${image}">
<link rel="canonical" href="${redirectUrl}">
</head>
<body>
<p>Redirecting to <a href="${redirectUrl}">${title}</a>…</p>
<script>location.replace(${JSON.stringify(opts.redirectUrl)});</script>
</body>
</html>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const htmlHeaders = { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" };
  const url = new URL(req.url);
  const type = url.searchParams.get("type");
  const id = url.searchParams.get("id");

  const fallback = () => renderPage({
    title: "ACCEAA, GSTU — Alumni Association",
    description: "Applied Chemistry and Chemical Engineering Alumni Association, GSTU — connecting graduates, sharing achievements, and staying updated on events and news.",
    image: DEFAULT_IMAGE,
    redirectUrl: SITE_URL + "/",
  });

  if (!type || !id || !["event", "achievement", "notice"].includes(type)) {
    return new Response(fallback(), { status: 200, headers: htmlHeaders });
  }

  try {
    const sbClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
    );

    if (type === "event") {
      const { data } = await sbClient.from("events").select("*").eq("id", id).single();
      if (!data) return new Response(fallback(), { status: 200, headers: htmlHeaders });
      return new Response(renderPage({
        title: data.title,
        description: data.description || "",
        image: data.photo_url || DEFAULT_IMAGE,
        redirectUrl: `${SITE_URL}/#event-${id}`,
      }), { status: 200, headers: htmlHeaders });
    }

    if (type === "achievement") {
      const { data } = await sbClient.from("achievements").select("*").eq("id", id).single();
      if (!data) return new Response(fallback(), { status: 200, headers: htmlHeaders });
      return new Response(renderPage({
        title: `${data.alumni_name} — ${data.tag}`,
        description: data.description || "",
        image: data.photo_url || DEFAULT_IMAGE,
        redirectUrl: `${SITE_URL}/#achievement-${id}`,
      }), { status: 200, headers: htmlHeaders });
    }

    // notice
    const { data } = await sbClient.from("notices").select("*").eq("id", id).single();
    if (!data) return new Response(fallback(), { status: 200, headers: htmlHeaders });
    return new Response(renderPage({
      title: data.title,
      description: data.description || "",
      image: DEFAULT_IMAGE,
      redirectUrl: `${SITE_URL}/#notice-${id}`,
    }), { status: 200, headers: htmlHeaders });
  } catch (_e) {
    return new Response(fallback(), { status: 200, headers: htmlHeaders });
  }
});

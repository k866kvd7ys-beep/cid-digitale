// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = Deno.env.get("RESEND_FROM") ?? "no-reply@cid-digitale.app";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { claimId } = await req.json();
    if (!claimId) {
      return Response.json(
        { error: "Missing claimId", success: false },
        { status: 400 },
      );
    }

    console.log("CLAIM ID:", claimId);

    const { data: claim, error } = await supabase
      .from("claims")
      .select("payload_json")
      .eq("id", claimId)
      .single();

    if (error) {
      console.error("Claim fetch error", error);
      return Response.json(
        { error: "Claim not found", success: false },
        { status: 404 },
      );
    }

    const payload = (claim?.payload_json ?? {}) as Record<string, any>;
    const emails = [
      payload["emailAssicurazione"] ?? payload["assicurazioneEmail"],
      payload["emailA"],
      payload["emailB"],
    ]
      .map((e) => (typeof e === "string" ? e.trim() : ""))
      .filter((e) => e.length > 3 && e.includes("@"));

    console.log("Recipients:", emails);

    if (emails.length === 0) {
      return Response.json(
        { error: "No valid recipients", success: false },
        { status: 400 },
      );
    }

    const damage = Array.isArray(payload["fotoDanni"])
      ? payload["fotoDanni"].filter((u: any) =>
          typeof u === "string" && u.startsWith("http")
        )
      : [];
    const libretto = [
      payload["fotoLibrettoA"],
      payload["fotoLibrettoB"],
    ].filter((u) => typeof u === "string" && u.startsWith("http"));

    const bodyLines = [
      "Buongiorno,",
      "",
      "in allegato trova il PDF del CID digitale.",
      "",
      "Foto danni:",
      ...(damage.length ? damage : ["Nessuna foto disponibile"]),
      "",
      "Foto libretto:",
      ...(libretto.length ? libretto : ["Nessuna foto disponibile"]),
      "",
      "Cordiali saluti",
    ];

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: emails,
        subject: "CID digitale incidente",
        text: bodyLines.join("\n"),
      }),
    });

    if (!res.ok) {
      const txt = await res.text();
      console.error("Resend error", txt);
      return Response.json(
        { error: "Email provider error", details: txt, success: false },
        { status: 500 },
      );
    }

    return Response.json({ success: true });
  } catch (err) {
    console.error("Function error", err);
    return Response.json(
      { error: "Unexpected error", success: false },
      { status: 500 },
    );
  }
});

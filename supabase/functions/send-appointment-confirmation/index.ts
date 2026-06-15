// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL") ?? "onboarding@resend.dev";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type SupportedLang = "de" | "it" | "fr" | "en";

const isValidEmail = (email: string) => {
  const trimmed = email.trim();
  return trimmed.length > 3 && trimmed.includes("@");
};

const normalizeLocale = (value: unknown): SupportedLang => {
  const normalized = String(value ?? "de").trim().toLowerCase();
  if (normalized === "it" || normalized === "fr" || normalized === "en") {
    return normalized;
  }
  return "de";
};

const escapeHtml = (value: unknown) =>
  String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const stringOrDash = (value: unknown) => {
  const trimmed = String(value ?? "").trim();
  return trimmed.length === 0 ? "-" : trimmed;
};

const joinLines = (lines: Array<string | null | undefined>) =>
  lines.map((line) => String(line ?? "").trim()).filter(Boolean).join("\n");

const joinHtmlLines = (lines: Array<string | null | undefined>) =>
  lines.map((line) => String(line ?? "").trim()).filter(Boolean).map(escapeHtml).join("<br/>");

const copyByLocale = (locale: SupportedLang) => {
  switch (locale) {
    case "it":
      return {
        subject: "Conferma richiesta appuntamento",
        title: "Conferma della tua richiesta",
        intro: "La tua richiesta è stata registrata correttamente.",
        customer: "Cliente",
        plate: "Targa",
        service: "Servizio",
        date: "Data",
        time: "Ora",
        workshop: "Officina selezionata",
        requestId: "ID richiesta",
        closing: "Ti contatteremo al più presto per eventuali aggiornamenti.",
      };
    case "fr":
      return {
        subject: "Confirmation de votre demande de rendez-vous",
        title: "Confirmation de votre demande",
        intro: "Votre demande a bien été enregistrée.",
        customer: "Client",
        plate: "Plaque",
        service: "Service",
        date: "Date",
        time: "Heure",
        workshop: "Atelier sélectionné",
        requestId: "ID de demande",
        closing: "Nous vous contacterons rapidement en cas de mise à jour.",
      };
    case "en":
      return {
        subject: "Appointment request confirmation",
        title: "Your request has been received",
        intro: "Your request was successfully recorded.",
        customer: "Customer",
        plate: "License plate",
        service: "Service",
        date: "Date",
        time: "Time",
        workshop: "Selected workshop",
        requestId: "Request ID",
        closing: "We will contact you shortly if an update is needed.",
      };
    case "de":
    default:
      return {
        subject: "Bestaetigung Ihrer Terminanfrage",
        title: "Bestaetigung Ihrer Anfrage",
        intro: "Ihre Anfrage wurde erfolgreich gespeichert.",
        customer: "Kunde",
        plate: "Kennzeichen",
        service: "Service",
        date: "Datum",
        time: "Uhrzeit",
        workshop: "Ausgewaehlte Werkstatt",
        requestId: "Anfrage-ID",
        closing: "Wir melden uns bei Rueckfragen schnellstmoeglich bei Ihnen.",
      };
  }
};

async function handleRequest(req: Request) {
  if (!RESEND_API_KEY) {
    return Response.json(
      {
        success: false,
        error: "Missing RESEND_API_KEY",
      },
      { status: 500 },
    );
  }

  const payload = await req.json().catch(() => ({} as Record<string, any>));
  const recipient = String(payload?.recipient ?? "").trim();
  const locale = normalizeLocale(payload?.locale);
  const copy = copyByLocale(locale);

  if (!isValidEmail(recipient)) {
    return Response.json(
      {
        success: false,
        error: "Missing or invalid recipient",
      },
      { status: 400 },
    );
  }

  const workshopLabel = joinLines([
    payload?.selected_workshop_name,
    payload?.selected_workshop_address,
    payload?.selected_workshop_city,
  ]) || String(payload?.selected_workshop ?? "").trim();

  const serviceText = String(payload?.service ?? "").trim();
  const requestId = String(payload?.request_id ?? "").trim();

  const textBody = [
    copy.title,
    "",
    copy.intro,
    "",
    `${copy.customer}: ${stringOrDash(payload?.name)}`,
    `${copy.plate}: ${stringOrDash(payload?.plate)}`,
    `${copy.service}: ${stringOrDash(serviceText)}`,
    `${copy.date}: ${stringOrDash(payload?.date)}`,
    `${copy.time}: ${stringOrDash(payload?.time)}`,
    workshopLabel ? `${copy.workshop}:\n${workshopLabel}` : null,
    requestId ? `${copy.requestId}: ${requestId}` : null,
    "",
    copy.closing,
  ].filter((line) => line != null).join("\n");

  const htmlBody = `
    <div style="font-family:Arial,sans-serif;line-height:1.55;color:#0f172a;">
      <h2 style="margin-bottom:12px;">${escapeHtml(copy.title)}</h2>
      <p>${escapeHtml(copy.intro)}</p>
      <p>
        <strong>${escapeHtml(copy.customer)}:</strong> ${escapeHtml(stringOrDash(payload?.name))}<br/>
        <strong>${escapeHtml(copy.plate)}:</strong> ${escapeHtml(stringOrDash(payload?.plate))}<br/>
        <strong>${escapeHtml(copy.service)}:</strong><br/>${escapeHtml(stringOrDash(serviceText)).replaceAll("\n", "<br/>")}<br/>
        <strong>${escapeHtml(copy.date)}:</strong> ${escapeHtml(stringOrDash(payload?.date))}<br/>
        <strong>${escapeHtml(copy.time)}:</strong> ${escapeHtml(stringOrDash(payload?.time))}
      </p>
      ${
    workshopLabel
      ? `<p><strong>${escapeHtml(copy.workshop)}:</strong><br/>${joinHtmlLines(workshopLabel.split("\n"))}</p>`
      : ""
  }
      ${
    requestId
      ? `<p><strong>${escapeHtml(copy.requestId)}:</strong> ${escapeHtml(requestId)}</p>`
      : ""
  }
      <p>${escapeHtml(copy.closing)}</p>
    </div>
  `;

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [recipient],
      subject: copy.subject,
      text: textBody,
      html: htmlBody,
    }),
  });

  const resendBody = await resendResponse.json().catch(() => ({} as any));
  if (!resendResponse.ok) {
    console.error("SEND APPOINTMENT CONFIRMATION Resend error", {
      status: resendResponse.status,
      body: resendBody,
      recipient,
    });
    return Response.json(
      {
        success: false,
        error: resendBody?.message ?? "Resend send failed",
        resendStatus: resendResponse.status,
        resendBody,
      },
      { status: 400 },
    );
  }

  return Response.json(
    {
      success: true,
      recipient,
      requestId,
      resendBody,
    },
    { status: 200 },
  );
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const response = await handleRequest(req);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }

  return new Response(response.body, {
    status: response.status,
    headers,
  });
});

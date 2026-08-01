// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const RESEND_FROM_EMAIL =
  Deno.env.get("RESEND_FROM_EMAIL") ??
    "CID Digitale <termine@ciddigital.ch>";
const SUPPORT_EMAIL = Deno.env.get("SUPPORT_EMAIL") ?? "";

const SUPPORT_BUCKET = "support-attachments";
const MAX_ATTACHMENTS = 3;
const MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AttachmentMetadata = {
  bucket: string;
  path: string;
  file_name: string;
  mime_type: string;
  byte_size: number;
};

type ResendAttachment = {
  filename: string;
  content: string;
  contentType: string;
};

const jsonResponse = (body: Record<string, unknown>, status: number) =>
  Response.json(body, { status, headers: corsHeaders });

const escapeHtml = (value: unknown) =>
  String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const isValidEmail = (value: unknown) =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(value ?? "").trim());

const base64EncodeBytes = (bytes: Uint8Array) => {
  const parts: string[] = [];
  const chunkSize = 0x8000;
  for (let index = 0; index < bytes.length; index += chunkSize) {
    parts.push(
      String.fromCharCode(...bytes.subarray(index, index + chunkSize)),
    );
  }
  return btoa(parts.join(""));
};

const safeFileName = (value: unknown, index: number) => {
  const sanitized = String(value ?? "")
    .trim()
    .replaceAll(/[^a-zA-Z0-9._-]/g, "_");
  return sanitized || `support_${index + 1}.jpg`;
};

const supportReference = (requestId: string, createdAt: string) => {
  const compactId = requestId.replaceAll("-", "").toUpperCase();
  const year = new Date(createdAt).getUTCFullYear();
  return `SUP-${year}-${compactId.slice(0, 6)}`;
};

const requestTypeLabel = (value: string) => {
  switch (value) {
    case "problem":
      return "Segnalazione";
    case "question":
      return "Domanda";
    case "suggestion":
      return "Suggerimento";
    default:
      return "Richiesta";
  }
};

const swissDateTime = (value: string) =>
  new Intl.DateTimeFormat("it-CH", {
    timeZone: "Europe/Zurich",
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));

const parseAttachmentMetadata = (
  value: unknown,
  userId: string,
  requestId: string,
): AttachmentMetadata[] => {
  if (!Array.isArray(value) || value.length > MAX_ATTACHMENTS) {
    throw new Error("INVALID_ATTACHMENTS");
  }
  return value.map((item) => {
    if (!item || typeof item !== "object") {
      throw new Error("INVALID_ATTACHMENT");
    }
    const metadata = item as Record<string, unknown>;
    const bucket = String(metadata.bucket ?? "");
    const path = String(metadata.path ?? "");
    const fileName = String(metadata.file_name ?? "");
    const mimeType = String(metadata.mime_type ?? "").toLowerCase();
    const byteSize = Number(metadata.byte_size ?? 0);
    const expectedPrefix = `${userId}/${requestId}/`;
    if (
      bucket !== SUPPORT_BUCKET ||
      !path.startsWith(expectedPrefix) ||
      !ALLOWED_MIME_TYPES.has(mimeType) ||
      !Number.isSafeInteger(byteSize) ||
      byteSize <= 0 ||
      byteSize > MAX_ATTACHMENT_BYTES
    ) {
      throw new Error("INVALID_ATTACHMENT");
    }
    return {
      bucket,
      path,
      file_name: fileName,
      mime_type: mimeType,
      byte_size: byteSize,
    };
  });
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ success: false, error: "METHOD_NOT_ALLOWED" }, 405);
  }
  if (
    !SUPABASE_URL ||
    !SUPABASE_SERVICE_ROLE_KEY ||
    !RESEND_API_KEY ||
    !isValidEmail(SUPPORT_EMAIL)
  ) {
    return jsonResponse({ success: false, error: "SERVER_NOT_CONFIGURED" }, 500);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
  if (!token) {
    return jsonResponse({ success: false, error: "UNAUTHENTICATED" }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } =
    await supabase.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) {
    return jsonResponse({ success: false, error: "UNAUTHENTICATED" }, 401);
  }

  const payload = await req.json().catch(() => ({} as Record<string, unknown>));
  const requestId = String(payload.request_id ?? "").trim();
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) {
    return jsonResponse({ success: false, error: "INVALID_REQUEST_ID" }, 400);
  }

  const { data: supportRequest, error: requestError } = await supabase
    .from("support_requests")
    .select(
      "id, created_by, user_email, request_type, subject, message, attachment_urls, created_at, notified_at",
    )
    .eq("id", requestId)
    .eq("created_by", user.id)
    .maybeSingle();
  if (requestError || !supportRequest) {
    return jsonResponse({ success: false, error: "REQUEST_NOT_FOUND" }, 404);
  }

  const reference = supportReference(
    supportRequest.id,
    supportRequest.created_at,
  );
  if (supportRequest.notified_at) {
    return jsonResponse({ success: true, reference, already_notified: true }, 200);
  }

  const replyEmail = String(supportRequest.user_email ?? "").trim();
  const subject = String(supportRequest.subject ?? "").trim();
  const message = String(supportRequest.message ?? "").trim();
  if (
    !isValidEmail(replyEmail) ||
    subject.length < 3 ||
    subject.length > 120 ||
    message.length < 10 ||
    message.length > 2000
  ) {
    return jsonResponse({ success: false, error: "INVALID_REQUEST" }, 400);
  }

  let attachmentMetadata: AttachmentMetadata[];
  try {
    attachmentMetadata = parseAttachmentMetadata(
      supportRequest.attachment_urls,
      user.id,
      requestId,
    );
  } catch (_) {
    return jsonResponse({ success: false, error: "INVALID_ATTACHMENTS" }, 400);
  }

  const attachments: ResendAttachment[] = [];
  for (let index = 0; index < attachmentMetadata.length; index++) {
    const metadata = attachmentMetadata[index];
    const { data, error } = await supabase.storage
      .from(metadata.bucket)
      .download(metadata.path);
    if (error || !data) {
      console.error("support notification attachment unavailable", {
        attachmentIndex: index,
      });
      return jsonResponse({ success: false, error: "ATTACHMENT_UNAVAILABLE" }, 500);
    }
    const bytes = new Uint8Array(await data.arrayBuffer());
    if (bytes.length > MAX_ATTACHMENT_BYTES) {
      bytes.fill(0);
      return jsonResponse({ success: false, error: "ATTACHMENT_TOO_LARGE" }, 400);
    }
    attachments.push({
      filename: safeFileName(metadata.file_name, index),
      content: base64EncodeBytes(bytes),
      contentType: metadata.mime_type,
    });
    bytes.fill(0);
  }

  const { data: customerProfile } = await supabase
    .from("customer_profiles")
    .select("first_name, last_name")
    .eq("user_id", user.id)
    .maybeSingle();
  const customerName = [
    customerProfile?.first_name,
    customerProfile?.last_name,
  ].map((value) => String(value ?? "").trim()).filter(Boolean).join(" ") || "-";
  const typeLabel = requestTypeLabel(supportRequest.request_type);
  const createdAtLabel = swissDateTime(supportRequest.created_at);

  const textBody = [
    "Nuova richiesta di assistenza CID Digitale",
    "",
    `Numero richiesta: ${reference}`,
    `Data e ora: ${createdAtLabel}`,
    `Tipo: ${typeLabel}`,
    `Oggetto: ${subject}`,
    `Cliente: ${customerName}`,
    `E-mail di risposta: ${replyEmail}`,
    `User ID: ${user.id}`,
    "",
    "Descrizione:",
    message,
    "",
    `Allegati: ${attachments.length}`,
  ].join("\n");

  const htmlBody = `
    <!doctype html>
    <html lang="it">
      <body style="margin:0;padding:24px;background:#eff4fb;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
          <tr><td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:680px;background:#ffffff;border-radius:24px;overflow:hidden;">
              <tr><td style="padding:28px;background:#2563eb;color:#ffffff;">
                <div style="font-size:12px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#bfdbfe;">CID Digitale</div>
                <div style="font-size:26px;font-weight:800;margin-top:10px;">Nuova richiesta di assistenza</div>
                <div style="font-size:15px;margin-top:8px;color:#dbeafe;">${escapeHtml(reference)}</div>
              </td></tr>
              <tr><td style="padding:26px;">
                <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="font-size:14px;line-height:1.55;">
                  <tr><td style="padding:0 0 8px;color:#64748b;width:160px;">Data e ora</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(createdAtLabel)}</td></tr>
                  <tr><td style="padding:0 0 8px;color:#64748b;">Tipo</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(typeLabel)}</td></tr>
                  <tr><td style="padding:0 0 8px;color:#64748b;">Oggetto</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(subject)}</td></tr>
                  <tr><td style="padding:0 0 8px;color:#64748b;">Cliente</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(customerName)}</td></tr>
                  <tr><td style="padding:0 0 8px;color:#64748b;">E-mail di risposta</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(replyEmail)}</td></tr>
                  <tr><td style="padding:0 0 8px;color:#64748b;">User ID</td><td style="padding:0 0 8px;font-weight:700;">${escapeHtml(user.id)}</td></tr>
                </table>
                <div style="margin-top:18px;padding:18px;background:#f8fafc;border-radius:16px;">
                  <div style="font-size:13px;font-weight:800;color:#2563eb;text-transform:uppercase;letter-spacing:.06em;">Descrizione</div>
                  <div style="font-size:15px;line-height:1.6;margin-top:10px;white-space:pre-wrap;">${escapeHtml(message)}</div>
                </div>
                <div style="font-size:13px;color:#64748b;margin-top:18px;">Allegati sicuri inclusi: ${attachments.length}</div>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
  `;

  console.log("support notification ready", {
    requestId,
    attachmentCount: attachments.length,
    requestType: supportRequest.request_type,
  });
  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM_EMAIL,
      to: [SUPPORT_EMAIL],
      reply_to: replyEmail,
      subject: `[CID Digitale Supporto] ${typeLabel} – ${subject}`,
      text: textBody,
      html: htmlBody,
      attachments,
    }),
  });
  const resendBody = await resendResponse.json().catch(() => ({} as any));
  if (!resendResponse.ok) {
    console.error("support notification Resend failure", {
      status: resendResponse.status,
      attachmentCount: attachments.length,
    });
    return jsonResponse({ success: false, error: "EMAIL_SEND_FAILED" }, 502);
  }

  const { error: updateError } = await supabase
    .from("support_requests")
    .update({ notified_at: new Date().toISOString() })
    .eq("id", requestId)
    .eq("created_by", user.id);
  if (updateError) {
    console.error("support notification status update failed", {
      requestId,
    });
  }

  const providerId = typeof resendBody?.id === "string" ? resendBody.id : null;
  console.log("support notification sent", {
    requestId,
    status: resendResponse.status,
    hasProviderId: Boolean(providerId),
  });
  return jsonResponse({ success: true, reference }, 200);
});

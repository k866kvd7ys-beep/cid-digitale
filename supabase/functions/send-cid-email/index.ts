// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  PDFDocument,
  StandardFonts,
  rgb,
} from "https://esm.sh/pdf-lib@1.17.1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = "onboarding@resend.dev";
const MAX_ATTACHMENTS = 8;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type ResendAttachment = {
  filename: string;
  content: string;
  contentType?: string;
};

type AttachmentCandidate = {
  source: string;
  origin: string;
};

const damageKeyTerms = [
  "damage",
  "danno",
  "danni",
  "libretto",
  "fotolibretto",
  "foto_libretto",
  "vehicle",
  "registration",
  "document",
  "fahrzeug",
  "carte",
  "certificat",
];

const damagePathSegments = [
  "damage",
  "danni",
  "libretto",
  "vehicle",
  "vehicle-document",
  "registration",
  "document",
];

const isValidEmail = (email: string) => {
  const trimmed = email.trim();
  return trimmed.length > 3 && trimmed.includes("@");
};

const buildFileNameFromPath = (path: string, fallback: string) => {
  const cleaned = path.split("?")[0].split("#")[0];
  const parts = cleaned.split("/").filter((p) => p.length > 0);
  if (parts.length === 0) return fallback;
  const last = parts[parts.length - 1];
  return last.length > 2 ? last : fallback;
};

const normalizeClaimAttachmentPath = (value: string) => {
  const trimmed = value.trim();
  const marker = "claim_attachments/";
  const idx = trimmed.indexOf(marker);
  if (idx !== -1) {
    return trimmed.substring(idx + marker.length);
  }
  return trimmed;
};

const extractStorageLocation = (value: string) => {
  try {
    if (value.startsWith("http")) {
      const url = new URL(value);
      const publicPrefix = "/storage/v1/object/public/";
      const signPrefix = "/storage/v1/object/sign/";
      const matchedPrefix = url.pathname.startsWith(publicPrefix)
        ? publicPrefix
        : url.pathname.startsWith(signPrefix)
        ? signPrefix
        : null;
      if (matchedPrefix) {
        const remainder = url.pathname.substring(matchedPrefix.length);
        const [bucket, ...rest] = remainder.split("/").filter((p) => p.length > 0);
        if (bucket && rest.length > 0) {
          return { bucket, path: decodeURIComponent(rest.join("/")) };
        }
      }
    }
    const normalizedPath = normalizeClaimAttachmentPath(value);
    if (normalizedPath.startsWith("claims/")) {
      return { bucket: "claim_attachments", path: normalizedPath };
    }
  } catch (_err) {
    // ignore parsing errors
  }
  return null;
};

async function downloadAsAttachment(
  source: string,
  fallbackName: string,
  contentTypeHint?: string,
): Promise<ResendAttachment | null> {
  const storage = extractStorageLocation(source);
  try {
    if (storage) {
      const possiblePath = normalizeClaimAttachmentPath(storage.path);
      const { data, error } = await supabase.storage
        .from(storage.bucket)
        .download(possiblePath);
      if (!error && data) {
        const bytes = new Uint8Array(await data.arrayBuffer());
        const filename = buildFileNameFromPath(possiblePath, fallbackName);
        const contentType = data.type || contentTypeHint;
        console.log(
          `SEND CID EMAIL attachment from storage: bucket=${storage.bucket} path=${possiblePath} bytes=${bytes.length}`,
        );
        return {
          filename,
          content: base64Encode(bytes),
          contentType,
        };
      } else {
        console.error("SEND CID EMAIL storage download error", storage, error);
      }
    }

    if (source.startsWith("http")) {
      const resp = await fetch(source);
      if (!resp.ok) {
        console.error(
          "SEND CID EMAIL fetch attachment failed",
          source,
          resp.status,
        );
      } else {
        const arrayBuffer = await resp.arrayBuffer();
        const bytes = new Uint8Array(arrayBuffer);
        const filename = buildFileNameFromPath(resp.url || source, fallbackName);
        const contentType = resp.headers.get("content-type") ?? contentTypeHint;
        console.log(
          `SEND CID EMAIL attachment fetched: url=${source} bytes=${bytes.length}`,
        );
        return {
          filename,
          content: base64Encode(bytes),
          contentType,
        };
      }
    }
  } catch (err) {
    console.error("SEND CID EMAIL attachment download error", err);
  }

  return null;
}

const buildAttachmentKey = (source: string) => {
  const storage = extractStorageLocation(source);
  if (storage) {
    return `${storage.bucket}:${normalizeClaimAttachmentPath(storage.path)}`;
  }
  return source.trim();
};

const matchesKeyTerms = (keyPath: string[], terms: string[]) => {
  const normalizedPath = keyPath.map((part) => part.toLowerCase());
  return normalizedPath.some((part) => terms.some((term) => part.includes(term)));
};

const matchesPathSegments = (source: string, segments: string[]) => {
  const storage = extractStorageLocation(source);
  if (!storage) return false;
  const normalizedPath = normalizeClaimAttachmentPath(storage.path).toLowerCase();
  return segments.some((segment) =>
    normalizedPath.includes(`/${segment}/`) ||
    normalizedPath.startsWith(`${segment}/`) ||
    normalizedPath.endsWith(`/${segment}`) ||
    normalizedPath === segment
  );
};

function collectCategoryPayloadAttachmentCandidates(
  value: unknown,
  options: {
    keyTerms: string[];
    pathSegments: string[];
  },
  keyPath: string[] = [],
  acc: AttachmentCandidate[] = [],
): AttachmentCandidate[] {
  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      collectCategoryPayloadAttachmentCandidates(
        item,
        options,
        [...keyPath, `${index}`],
        acc,
      );
    });
    return acc;
  }

  if (value && typeof value === "object") {
    for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
      collectCategoryPayloadAttachmentCandidates(
        nested,
        options,
        [...keyPath, key],
        acc,
      );
    }
    return acc;
  }

  if (typeof value !== "string") {
    return acc;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return acc;
  }

  const storage = extractStorageLocation(trimmed);
  if (!storage) {
    return acc;
  }

  const normalizedPath = normalizeClaimAttachmentPath(storage.path);
  if (normalizedPath.toLowerCase().endsWith(".pdf")) {
    return acc;
  }

  const matchesCategory = matchesPathSegments(trimmed, options.pathSegments) ||
    matchesKeyTerms(keyPath, options.keyTerms);
  if (!matchesCategory) {
    return acc;
  }

  acc.push({
    source: trimmed,
    origin: keyPath.join(".") || "(root)",
  });
  return acc;
}

const findPdfReference = (obj: Record<string, any> | null | undefined) => {
  if (!obj) return null;
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === "string" && value.toLowerCase().includes(".pdf")) {
      console.log("SEND CID EMAIL pdf reference found:", { key, value });
      return value;
    }
  }
  return null;
};

const readStringField = (payload: Record<string, any>, keys: string[]) => {
  for (const key of keys) {
    const value = payload?.[key];
    if (typeof value === "string" && value.trim().length > 0) {
      return value.trim();
    }
  }
  return null;
};

const findSignatureValue = (
  payload: Record<string, any>,
  variant: "A" | "B",
) => {
  const directKeys = variant === "A"
    ? [
      "firmaA",
      "firmaAPath",
      "signatureA",
      "signatureAPath",
      "signA",
      "signaturaA",
    ]
    : [
      "firmaB",
      "firmaBPath",
      "signatureB",
      "signatureBPath",
      "signB",
      "signaturaB",
    ];

  const direct = readStringField(payload, directKeys);
  if (direct) return direct;

  const variantLower = variant.toLowerCase();
  for (const [key, value] of Object.entries(payload)) {
    if (typeof value !== "string" || value.trim().length === 0) continue;
    const lowerKey = key.toLowerCase();
    const looksLikeSignature = lowerKey.includes("firma") ||
      lowerKey.includes("signature") ||
      lowerKey.includes("sign");
    const matchesVariant = lowerKey.includes(variantLower) ||
      lowerKey.includes(`driver${variantLower}`) ||
      lowerKey.includes(`conducente${variantLower}`) ||
      lowerKey.includes(`fahrer${variantLower}`);
    if (looksLikeSignature && matchesVariant) {
      return value.trim();
    }
  }

  return null;
};

const decodeBase64Image = (value: string) => {
  const trimmed = value.trim();
  const match = trimmed.match(/^data:image\/[a-zA-Z0-9.+-]+;base64,(.+)$/);
  const base64 = match ? match[1] : trimmed;
  try {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  } catch (_err) {
    return null;
  }
};

async function generatePdfFromPayload(
  payload: Record<string, any>,
  claimId: string,
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const fontRegular = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  let page = pdfDoc.addPage();
  let { height } = page.getSize();
  let y = height - 40;

  const ensureSpace = (neededHeight = 20) => {
    if (y >= neededHeight) return;
    page = pdfDoc.addPage();
    ({ height } = page.getSize());
    y = height - 40;
  };

  const line = (text: string, bold = false, size = 12) => {
    ensureSpace(size + 12);
    page.drawText(text ?? "", {
      x: 40,
      y,
      size,
      font: bold ? fontBold : fontRegular,
      color: rgb(0, 0, 0),
    });
    y -= size + 6;
  };

  const drawSignature = async (label: string, value: string | null) => {
    if (!value) return;
    const bytes = decodeBase64Image(value);
    if (!bytes) return;

    let image;
    try {
      image = await pdfDoc.embedPng(bytes);
    } catch (_pngErr) {
      try {
        image = await pdfDoc.embedJpg(bytes);
      } catch (_jpgErr) {
        return;
      }
    }

    line(label, true, 14);
    const dimensions = image.scale(1);
    const scale = Math.min(180 / dimensions.width, 70 / dimensions.height, 1);
    const width = dimensions.width * scale;
    const imageHeight = dimensions.height * scale;
    ensureSpace(imageHeight + 20);
    page.drawImage(image, {
      x: 40,
      y: y - imageHeight,
      width,
      height: imageHeight,
    });
    y -= imageHeight + 16;
  };

  line("CID Digitale", true, 18);
  line(`Claim ID: ${claimId}`, false, 12);
  line(`Data/Ora: ${payload?.dataOra ?? "-"}`);
  line(`Luogo: ${payload?.luogo ?? "-"}`);
  line("");
  line("Conducente A", true, 14);
  line(`${payload?.nomeA ?? ""} ${payload?.cognomeA ?? ""}`.trim() || "-", false);
  line(`Targa: ${payload?.targaA ?? "-"}`);
  line(`Telefono: ${payload?.telefonoA ?? "-"}`);
  line(`Email: ${payload?.emailA ?? "-"}`);
  line("");
  line("Conducente B", true, 14);
  line(`${payload?.nomeB ?? ""} ${payload?.cognomeB ?? ""}`.trim() || "-", false);
  line(`Targa: ${payload?.targaB ?? "-"}`);
  line(`Telefono: ${payload?.telefonoB ?? "-"}`);
  line(`Email: ${payload?.emailB ?? "-"}`);
  line("");
  line("Descrizione", true, 14);
  line(`${payload?.descrizione ?? "-"}`);
  line("");
  line("Integrità dati", true, 14);
  line(`Hash: ${payload?.hashIntegrita ?? "-"}`);
  line("");

  await drawSignature("Firma A", findSignatureValue(payload, "A"));
  await drawSignature("Firma B", findSignatureValue(payload, "B"));

  const pdfBytes = await pdfDoc.save();
  console.log("SEND CID EMAIL pdf generated bytes:", pdfBytes.length);
  return pdfBytes;
}

async function savePdfToStorage(
  pdfBytes: Uint8Array,
  claimId: string,
  bucket = "claim_attachments",
) {
  try {
    const path = `claims/${claimId}/cid/cid-digitale-${claimId}.pdf`;
    const blob = new Blob([pdfBytes], { type: "application/pdf" });
    const { error } = await supabase.storage.from(bucket).upload(path, blob, {
      upsert: true,
      contentType: "application/pdf",
    });
    if (error) {
      console.error("SEND CID EMAIL pdf upload error", error);
      return null;
    }
    console.log("SEND CID EMAIL pdf saved to storage", { bucket, path });
    return { bucket, path };
  } catch (err) {
    console.error("SEND CID EMAIL pdf upload unexpected error", err);
    return null;
  }
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { claimId } = await req.json();
    console.log("SEND CID EMAIL claimId:", claimId);
    if (!claimId) {
      return Response.json(
        { error: "Missing claimId", success: false },
        { status: 400 },
      );
    }

    console.log("SEND CID EMAIL query start");

    const { data: claimRow, error: claimError } = await supabase
      .from("claims")
      .select("*")
      .eq("id", claimId)
      .single();

    console.log("SEND CID EMAIL claim row:", claimRow);
    console.log("SEND CID EMAIL claim error:", claimError);

    if (claimError || !claimRow) {
      console.error("Claim fetch error", claimError);
      return new Response(
        JSON.stringify({
          success: false,
          error: "CLAIM_NOT_FOUND",
          claimId,
          details: claimError ?? null,
        }),
        {
          status: 404,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const payload = (claimRow?.payload_json ?? {}) as Record<string, any>;
    console.log("SEND CID EMAIL payload keys:", Object.keys(payload));

    const recipients = [payload["emailA"], payload["emailB"]]
      .map((v) => (typeof v === "string" ? v.trim() : ""))
      .filter((v, i, arr) => isValidEmail(v) && arr.indexOf(v) === i);

    console.log("SEND CID EMAIL recipients final:", recipients);

    if (recipients.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "NO_VALID_RECIPIENTS",
          claimId,
          emailA: payload?.emailA ?? null,
          emailB: payload?.emailB ?? null,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // === RACCOLTA ALLEGATI DA DATABASE + PAYLOAD ===
    const attachments: ResendAttachment[] = [];
    const addedPaths = new Set<string>();
    const MAX_ATTACHMENTS = 10;
    let pdfAttached = false;

    // 1. AGGIUNGI SEMPRE PDF generato dal payload corrente come primo allegato
    try {
      const pdfBytes = await generatePdfFromPayload(payload, claimId);
      await savePdfToStorage(pdfBytes, claimId);
      attachments.push({
        filename: `cid-digitale-${claimId}.pdf`,
        content: base64Encode(pdfBytes),
        contentType: "application/pdf",
      });
      pdfAttached = true;
      console.log("SEND CID EMAIL pdf generated and attached");
    } catch (err) {
      console.error("SEND CID EMAIL pdf generation failed", err);
    }

    const addAttachmentFromSource = async (
      source: string,
      fallbackName: string,
      contentTypeHint?: string,
    ) => {
      const attachmentKey = buildAttachmentKey(source);
      if (addedPaths.has(attachmentKey)) {
        return;
      }
      if (attachments.length >= MAX_ATTACHMENTS) {
        return;
      }

      try {
        const downloaded = await downloadAsAttachment(
          source,
          fallbackName,
          contentTypeHint,
        );
        if (downloaded) {
          attachments.push({
            filename: downloaded.filename || fallbackName,
            content: downloaded.content,
            contentType: downloaded.contentType || contentTypeHint,
          });
          addedPaths.add(attachmentKey);
          console.log("CLAIM_ATTACHMENT_DOWNLOAD_OK:", attachmentKey);
        } else {
          console.error("CLAIM_ATTACHMENT_DOWNLOAD_ERROR:", attachmentKey);
        }
      } catch (err) {
        console.error("CLAIM_ATTACHMENT_DOWNLOAD_ERROR:", attachmentKey, err);
      }
    };

    // 2. PRENDI ALLEGATI DA claim_attachments
    const { data: dbAttachments, error: dbAttachmentsError } = await supabase
      .from("claim_attachments")
      .select("*")
      .eq("claim_id", claimId);

    console.log("CLAIM_ATTACHMENTS_DB_COUNT:", dbAttachments?.length ?? 0);
    console.log("CLAIM_ATTACHMENTS_ROWS:", JSON.stringify(dbAttachments));
    if (dbAttachmentsError) {
      console.error("CLAIM_ATTACHMENT_DOWNLOAD_ERROR:", dbAttachmentsError);
    }

    if (dbAttachments && dbAttachments.length > 0) {
      for (const file of dbAttachments) {
        const possibleSource = [
          file.file_path,
          file.object_path,
          file.storage_path,
          file.path,
          file.public_url,
          file.url,
          file.signed_url,
          file.attachment_url,
          file.file_url,
        ].find((value) => typeof value === "string" && value.trim().length > 0);

        if (typeof possibleSource !== "string") continue;
        if (attachments.length >= MAX_ATTACHMENTS) break;

        await addAttachmentFromSource(
          possibleSource.trim(),
          file.filename ||
            file.file_name ||
            file.name ||
            `allegato-${attachments.length + 1}.bin`,
          file.mime_type || file.content_type || "application/octet-stream",
        );
      }
    }

    // 3. FALLBACK ROBUSTO SU payload_json
    const payloadAttachmentCandidates = collectCategoryPayloadAttachmentCandidates(
      payload,
      {
        keyTerms: damageKeyTerms,
        pathSegments: damagePathSegments,
      },
    );
    console.log(
      "DAMAGE_LOGIC_FOUND:",
      JSON.stringify(
        payloadAttachmentCandidates.filter((candidate) =>
          matchesPathSegments(candidate.source, ["damage", "danni"]) ||
          matchesKeyTerms(candidate.origin.split(".").filter(Boolean), [
            "damage",
            "danno",
            "danni",
          ])
        ),
      ),
    );
    console.log(
      "LIBRETTO_LOGIC_FOUND:",
      JSON.stringify(
        payloadAttachmentCandidates.filter((candidate) =>
          matchesPathSegments(candidate.source, [
            "libretto",
            "vehicle",
            "vehicle-document",
            "registration",
            "document",
          ]) ||
          matchesKeyTerms(candidate.origin.split(".").filter(Boolean), [
            "libretto",
            "fotolibretto",
            "foto_libretto",
            "vehicle",
            "registration",
            "document",
            "fahrzeug",
            "carte",
            "certificat",
          ])
        ),
      ),
    );

    for (const candidate of payloadAttachmentCandidates) {
      if (attachments.length >= MAX_ATTACHMENTS) break;
      await addAttachmentFromSource(
        candidate.source,
        `allegato-${attachments.length + 1}.bin`,
        "application/octet-stream",
      );
    }

    console.log("EMAIL_ATTACHMENTS_FINAL:", attachments.map((a) => a.filename));

    const textBody = [
      "Guten Tag,",
      "",
      `Im Anhang finden Sie den digitalen Unfallbericht zur Vorgangsnummer ${claimId}.`,
      "Der PDF-Bericht und die hochgeladenen Anhänge sind beigefügt.",
      "",
      `Fahrer A: ${
        [payload?.nomeA, payload?.cognomeA].filter(Boolean).join(" ")
      } (${payload?.targaA ?? "-"})`,
      `Fahrer B: ${
        [payload?.nomeB, payload?.cognomeB].filter(Boolean).join(" ")
      } (${payload?.targaB ?? "-"})`,
      "",
      "Falls ein Anhang fehlt, wurde dieser möglicherweise noch nicht hochgeladen.",
      "",
      "Freundliche Grüße",
    ].join("\n");

    const htmlBody = `
      <p>Guten Tag,</p>
      <p>Im Anhang finden Sie den digitalen Unfallbericht zur Vorgangsnummer <strong>${claimId}</strong>.</p>

      <p><strong>Fahrer A:</strong> ${
        [payload?.nomeA, payload?.cognomeA].filter(Boolean).join(" ")
      } (${payload?.targaA ?? "-"})<br/>
      <strong>E-Mail:</strong> ${payload?.emailA ?? "-"}<br/>
      <strong>Telefon:</strong> ${payload?.telefonoA ?? "-"}</p>

      <p><strong>Fahrer B:</strong> ${
        [payload?.nomeB, payload?.cognomeB].filter(Boolean).join(" ")
      } (${payload?.targaB ?? "-"})<br/>
      <strong>E-Mail:</strong> ${payload?.emailB ?? "-"}<br/>
      <strong>Telefon:</strong> ${payload?.telefonoB ?? "-"}</p>

      <p>Der PDF-Bericht und die hochgeladenen Anhänge sind beigefügt. Falls ein Anhang fehlt, wurde dieser möglicherweise noch nicht hochgeladen.</p>

      <p>Freundliche Grüße</p>
    `;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: ["antonio.privitera1984@gmail.com"],
        subject: "Digitaler Unfallbericht (CID) – Vorgang",
        text: textBody,
        html: htmlBody,
        attachments,
      }),
    });

    if (!res.ok) {
      const resendResult = await res.json().catch(() => ({} as any));
      console.error("SEND CID EMAIL Resend error", {
        status: res.status,
        body: resendResult,
      });
      return new Response(
        JSON.stringify({
          success: false,
          error: resendResult?.message ?? "Errore invio Resend",
          resendStatus: res.status,
          resendBody: resendResult,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Email inviata correttamente",
        recipients,
        claimId,
        attachmentsCount: attachments.length,
        pdfAttached,
        attachmentFilenames: attachments.map((a) => a.filename),
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    console.error("Function error", err);
    return Response.json(
      { error: "Unexpected error", success: false },
      { status: 500 },
    );
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  const response = await handleRequest(req);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
});

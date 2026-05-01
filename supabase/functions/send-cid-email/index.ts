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

const extractStorageLocation = (value: string) => {
  try {
    if (value.startsWith("http")) {
      const url = new URL(value);
      const prefix = "/storage/v1/object/public/";
      if (url.pathname.startsWith(prefix)) {
        const remainder = url.pathname.substring(prefix.length);
        const [bucket, ...rest] = remainder.split("/").filter((p) => p.length > 0);
        if (bucket && rest.length > 0) {
          return { bucket, path: decodeURIComponent(rest.join("/")) };
        }
      }
    }
    const marker = "claim_attachments/";
    const idx = value.indexOf(marker);
    if (idx !== -1) {
      return { bucket: "claim_attachments", path: value.substring(idx + marker.length) };
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
      const { data, error } = await supabase.storage
        .from(storage.bucket)
        .download(storage.path);
      if (!error && data) {
        const bytes = new Uint8Array(await data.arrayBuffer());
        const filename = buildFileNameFromPath(storage.path, fallbackName);
        const contentType = data.type || contentTypeHint;
        console.log(
          `SEND CID EMAIL attachment from storage: bucket=${storage.bucket} path=${storage.path} bytes=${bytes.length}`,
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

async function generatePdfFromPayload(
  payload: Record<string, any>,
  claimId: string,
): Promise<Uint8Array> {
  const pdfDoc = await PDFDocument.create();
  const page = pdfDoc.addPage();
  const fontRegular = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const { height } = page.getSize();
  let y = height - 40;

  const line = (text: string, bold = false, size = 12) => {
    page.drawText(text ?? "", {
      x: 40,
      y,
      size,
      font: bold ? fontBold : fontRegular,
      color: rgb(0, 0, 0),
    });
    y -= size + 6;
    if (y < 40) {
      y = height - 40;
      page.drawText("...", { x: 40, y, size: 10, font: fontRegular });
      y -= 16;
    }
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

serve(async (req) => {
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

    // === RACCOLTA ALLEGATI DA DATABASE ===
    const attachments: any[] = [];
    const addedPaths = new Set<string>();
    const MAX_ATTACHMENTS = 10;
    let pdfAttached = false;

    // 1. PRENDI ALLEGATI DA claim_attachments
    const { data: dbAttachments } = await supabase
      .from("claim_attachments")
      .select("*")
      .eq("claim_id", claimId);

    if (dbAttachments && dbAttachments.length > 0) {
      for (const file of dbAttachments) {
        const possiblePath =
          file.storage_path ||
          file.path ||
          file.file_path ||
          file.url ||
          file.public_url ||
          file.signed_url;

        if (!possiblePath) continue;
        if (addedPaths.has(possiblePath)) continue;
        if (attachments.length >= MAX_ATTACHMENTS) break;

        try {
          const filename =
            file.filename ||
            file.file_name ||
            file.name ||
            `allegato-${attachments.length + 1}.jpg`;
          const contentType =
            file.mime_type ||
            file.content_type ||
            "application/octet-stream";
          const downloaded = await downloadAsAttachment(
            possiblePath,
            filename,
            contentType,
          );

          if (downloaded) {
            attachments.push({
              filename,
              content: downloaded.content,
              contentType,
            });

            addedPaths.add(possiblePath);
          }
        } catch (e) {
          console.error("Errore allegato:", e);
        }
      }
    }

    // 2. AGGIUNGI SEMPRE PDF (già esistente nel codice)
    const pdfRef =
      findPdfReference(payload) ||
      findPdfReference(claimRow as Record<string, any>);
    if (pdfRef) {
      console.log("SEND CID EMAIL pdf reference value:", pdfRef);
      const pdfAttachment = await downloadAsAttachment(
        pdfRef,
        `cid-digitale-${claimId}.pdf`,
        "application/pdf",
      );
      if (pdfAttachment) {
        attachments.push(pdfAttachment);
        pdfAttached = true;
      } else {
        console.error(
          "SEND CID EMAIL pdf reference download failed, falling back to generation",
        );
      }
    }

    if (!pdfAttached) {
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
    }

    console.log("SEND CID EMAIL attachments summary", {
      count: attachments.length,
      filenames: attachments.map((a) => a.filename),
    });

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
});

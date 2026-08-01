// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  PDFDocument,
  StandardFonts,
  rgb,
} from "https://esm.sh/pdf-lib@1.17.1";
import { formatIncidentDateTime } from "./incident_datetime.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
// TODO: sostituire il mittente Resend con email professionale del dominio quando disponibile.
const FROM_EMAIL = "CID Digitale <onboarding@resend.dev>";
const MAX_BOOKLET_PHOTOS = 2;
const MAX_DAMAGE_PHOTOS = 4;
const MAX_ATTACHMENTS = 1 + MAX_BOOKLET_PHOTOS + MAX_DAMAGE_PHOTOS;
const MAX_EMAIL_ATTACHMENT_BYTES = 10 * 1024 * 1024;
const JPEG_MAX_WIDTH = 1024;
const JPEG_QUALITY = 58;
const SIGNED_URL_TTL_SECONDS = 60;
const textEncoder = new TextEncoder();

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type ResendAttachment = {
  filename: string;
  content: string;
  contentType?: string;
};

type DownloadedAttachment = {
  filename: string;
  bytes: Uint8Array;
  contentType?: string;
};

type EncodedAttachment = {
  attachment: ResendAttachment;
  payloadBytes: number;
};

type AttachmentCandidate = {
  source: string;
  origin: string;
};

type PhotoCategory = "booklet" | "damage";

type PhotoAttachmentCandidate = {
  attachmentKey: string;
  category: PhotoCategory;
  contentTypeHint?: string;
  fallbackName: string;
  source: string;
};

type PhotoDownloadFailureReason = "download_error" | "compression_error";

type PhotoDownloadResult = {
  attachment: DownloadedAttachment | null;
  failureReason?: PhotoDownloadFailureReason;
  detail?: string;
};

type SupportedLang = "de" | "it" | "fr" | "en";

const bookletKeyTerms = [
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

const bookletPathSegments = [
  "libretto",
  "vehicle",
  "vehicle-document",
  "registration",
  "document",
];

const damageKeyTerms = [
  "damage",
  "danno",
  "danni",
];

const damagePathSegments = [
  "damage",
  "danni",
];

const isValidEmail = (email: string) => {
  const trimmed = email.trim();
  return trimmed.length > 3 && trimmed.includes("@");
};

const collectRecipients = (...candidates: unknown[]) => {
  const recipients: string[] = [];

  for (const candidate of candidates) {
    if (typeof candidate !== "string") continue;
    const trimmed = candidate.trim();
    if (!isValidEmail(trimmed) || recipients.includes(trimmed)) continue;
    recipients.push(trimmed);
  }

  return recipients;
};

const base64EncodeBytes = (bytes: Uint8Array) => {
  const chunkSize = 0x8000;
  const parts: string[] = [];
  for (let index = 0; index < bytes.length; index += chunkSize) {
    parts.push(
      String.fromCharCode(...bytes.subarray(index, index + chunkSize)),
    );
  }
  return btoa(parts.join(""));
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
  url: string,
  fallbackName: string,
  contentTypeHint?: string,
  logLabel = "fetch",
): Promise<DownloadedAttachment | null> {
  const resp = await fetch(url);
  if (!resp.ok) {
    console.error(
      "SEND CID EMAIL fetch attachment failed",
      JSON.stringify({
        logLabel,
        status: resp.status,
      }),
    );
    return null;
  }

  const filename = buildFileNameFromPath(resp.url || url, fallbackName);
  const contentType = resp.headers.get("content-type") ?? contentTypeHint;
  const bytes = new Uint8Array(await resp.arrayBuffer());
  console.log(
    "SEND CID EMAIL attachment fetched",
    JSON.stringify({ logLabel, bytes: bytes.length }),
  );
  return {
    filename,
    bytes,
    contentType,
  };
}

async function createSignedOptimizedJpegUrl(
  bucket: string,
  path: string,
): Promise<string | null> {
  try {
    const { data, error } = await supabase.storage.from(bucket).createSignedUrl(
      path,
      SIGNED_URL_TTL_SECONDS,
      {
        transform: {
          width: JPEG_MAX_WIDTH,
          quality: JPEG_QUALITY,
        },
      },
    );
    if (error || !data?.signedUrl) {
      console.error(
        "SEND CID EMAIL jpeg transform signed url error",
        JSON.stringify({ hasStorageError: Boolean(error) }),
      );
      return null;
    }
    return data.signedUrl;
  } catch (_err) {
    console.error(
      "SEND CID EMAIL jpeg transform signed url unexpected error",
      JSON.stringify({ failed: true }),
    );
    return null;
  }
}

async function downloadAttachmentBytes(
  source: string,
  fallbackName: string,
  contentTypeHint?: string,
): Promise<PhotoDownloadResult> {
  const storage = extractStorageLocation(source);
  try {
    if (storage) {
      const possiblePath = normalizeClaimAttachmentPath(storage.path);
      const filename = buildFileNameFromPath(possiblePath, fallbackName);
      const optimizedUrl = await createSignedOptimizedJpegUrl(
        storage.bucket,
        possiblePath,
      );
      if (!optimizedUrl) {
        return {
          attachment: null,
          failureReason: "compression_error",
          detail: "transform_signed_url_failed",
        };
      }

      const optimizedAttachment = await downloadAsAttachment(
        optimizedUrl,
        filename,
        "image/jpeg",
        "jpeg-transform",
      );
      if (!optimizedAttachment) {
        return {
          attachment: null,
          failureReason: "compression_error",
          detail: "transform_download_failed",
        };
      }
      return { attachment: optimizedAttachment };
    }

    if (source.startsWith("http")) {
      const downloaded = await downloadAsAttachment(
        source,
        fallbackName,
        contentTypeHint,
      );
      if (!downloaded) {
        return {
          attachment: null,
          failureReason: "download_error",
          detail: "http_download_failed",
        };
      }
      return { attachment: downloaded };
    }
  } catch (err) {
    console.error("SEND CID EMAIL attachment download error", {
      failureReason: storage ? "compression_error" : "download_error",
    });
    return {
      attachment: null,
      failureReason: storage ? "compression_error" : "download_error",
      detail: String(err),
    };
  }

  return {
    attachment: null,
    failureReason: "download_error",
    detail: "unsupported_source",
  };
}

const encodeAttachment = (
  attachment: DownloadedAttachment,
  overrides?: {
    filename?: string;
    contentType?: string;
  },
): EncodedAttachment | null => {
  const filename = (overrides?.filename ?? attachment.filename).trim();
  if (!filename) return null;

  try {
    const content = base64EncodeBytes(attachment.bytes);
    const resendAttachment: ResendAttachment = {
      filename,
      content,
      contentType: overrides?.contentType ?? attachment.contentType,
    };
    const payloadBytes =
      textEncoder.encode(resendAttachment.content).length +
      textEncoder.encode(resendAttachment.filename).length +
      textEncoder.encode(resendAttachment.contentType ?? "").length;

    return {
      attachment: resendAttachment,
      payloadBytes,
    };
  } finally {
    attachment.bytes.fill(0);
  }
};

const buildAttachmentKey = (source: string) => {
  const storage = extractStorageLocation(source);
  if (storage) {
    return `${storage.bucket}:${normalizeClaimAttachmentPath(storage.path)}`;
  }
  return source.trim();
};

const isPdfSource = (source: string) => {
  const storage = extractStorageLocation(source);
  const candidate = storage
    ? normalizeClaimAttachmentPath(storage.path)
    : source;
  return candidate.trim().toLowerCase().endsWith(".pdf");
};

const matchesAttachmentCategory = (
  source: string,
  keyPath: string[],
  options: {
    keyTerms: string[];
    pathSegments: string[];
  },
) =>
  matchesPathSegments(source, options.pathSegments) ||
  matchesKeyTerms(keyPath, options.keyTerms);

const detectPhotoCategory = (
  source: string,
  originParts: string[],
  kindHint?: string | null,
): PhotoCategory | null => {
  const normalizedKind = (kindHint ?? "").trim().toLowerCase();
  if (normalizedKind.includes("libretto")) {
    return "booklet";
  }
  if (normalizedKind.includes("damage") || normalizedKind.includes("danni")) {
    return "damage";
  }

  if (
    matchesAttachmentCategory(source, originParts, {
      keyTerms: bookletKeyTerms,
      pathSegments: bookletPathSegments,
    })
  ) {
    return "booklet";
  }

  if (
    matchesAttachmentCategory(source, originParts, {
      keyTerms: damageKeyTerms,
      pathSegments: damagePathSegments,
    })
  ) {
    return "damage";
  }

  return null;
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
  for (const value of Object.values(obj)) {
    if (typeof value === "string" && value.toLowerCase().includes(".pdf")) {
      console.log("SEND CID EMAIL pdf reference found", { found: true });
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

const normalizeEmailLanguage = (
  value: string | null | undefined,
): SupportedLang | null => {
  const normalized = (value ?? "").trim().toLowerCase();
  if (!normalized) return null;
  if (normalized.startsWith("de")) return "de";
  if (normalized.startsWith("it")) return "it";
  if (normalized.startsWith("fr")) return "fr";
  if (normalized.startsWith("en")) return "en";
  return null;
};

const detectPayloadLanguage = (
  payload: Record<string, any>,
): SupportedLang => {
  const detected = normalizeEmailLanguage(
    readStringField(payload, [
      "locale",
      "language",
      "lang",
      "languageCode",
      "lingua",
      "appLanguage",
      "preferredLanguage",
    ]),
  );
  return detected ?? "de";
};

const extractIncidentYear = (value: unknown) => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    const directYear = trimmed.match(/^(\d{4})/);
    if (directYear) {
      return directYear[1];
    }
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) {
      return String(parsed.getUTCFullYear()).padStart(4, "0");
    }
  }

  return String(new Date().getUTCFullYear()).padStart(4, "0");
};

const formatClaimDisplayId = (claimId: string, incidentDate: unknown) => {
  const year = extractIncidentYear(incidentDate);
  const source = claimId.trim();
  if (!source) {
    return `CID-${year}-000000`;
  }

  const sanitized = source.replace(/[^A-Fa-f0-9]/g, "").toUpperCase();
  const seed = sanitized || source.toUpperCase();
  let value = 0;
  for (const char of seed) {
    value = ((value * 31) + char.charCodeAt(0)) % 1000000;
  }

  return `CID-${year}-${String(value).padStart(6, "0")}`;
};

const formatWorkshopDisplayCode = (displayClaimId: string) =>
  `${displayClaimId}-W`;

const getLocalizedCopy = (lang: SupportedLang, displayClaimId: string) => ({
  de: {
    emailSubject: `Digitale Schadenakte ${displayClaimId}`,
    emailHeading: "Digitale Schadenakte",
    pdfTitle: "Digitale Schadenakte",
    claimNumber: "Vorgangsnummer",
    summaryHeading: "Kurzuebersicht",
    greeting: "Guten Tag,",
    intro: "Ihre digitale Schadenakte wurde erfolgreich registriert.",
    pdfSummaryNote:
      "Die vollständige digitale Schadenakte befindet sich im beigefügten PDF.",
    photosSummaryNote:
      "Zusätzliche Fotos werden - sofern die Größenbeschränkung dies zulässt - als separate Anhänge übermittelt.",
    dateTime: "Datum und Uhrzeit",
    place: "Ort",
    driverA: "Fahrer A",
    driverB: "Fahrer B",
    name: "Name",
    plate: "Kennzeichen",
    insurance: "Versicherung",
    phone: "Telefon",
    email: "E-Mail",
    address: "Adresse",
    description: "Beschreibung",
    witnesses: "Zeugen",
    injuries: "Verletzte",
    damage: "Beschädigung",
    vehicleA: "Fahrzeug A",
    vehicleB: "Fahrzeug B",
    liability: "Haftung (Angabe der Parteien)",
    signatures: "Unterschriften",
    workshopCode: "Werkstattcode",
    integrity: "Datenintegrität",
    hash: "Hash",
    workshopCodeNote:
      "QR-Code in der App verfügbar, um die Schadenakte schnell zu importieren.",
    pdfNote: "Der PDF-Bericht und die hochgeladenen Anhänge sind beigefügt.",
    attachmentsLimitNote:
      "Einige Fotos sind gegebenenfalls nur in der digitalen Schadenakte verfügbar, wenn das E-Mail-Anhangslimit überschritten wird.",
    closing: "Freundliche Grüße",
    signatureSigned: "digital signiert",
    signatureMissing: "nicht vorhanden",
    signatureTimestamp: "UTC-Zeitstempel",
  },
  it: {
    emailSubject: `Pratica incidente digitale ${displayClaimId}`,
    emailHeading: "Pratica incidente digitale",
    pdfTitle: "Pratica incidente digitale",
    claimNumber: "Numero pratica",
    summaryHeading: "Riepilogo",
    greeting: "Gentile utente,",
    intro: "La pratica incidente digitale e stata registrata correttamente.",
    pdfSummaryNote:
      "La pratica digitale completa è disponibile nel PDF allegato.",
    photosSummaryNote:
      "Le fotografie aggiuntive vengono allegate separatamente quando consentito dai limiti dimensionali.",
    dateTime: "Data e ora",
    place: "Luogo",
    driverA: "Conducente A",
    driverB: "Conducente B",
    name: "Nome",
    plate: "Targa",
    insurance: "Assicurazione",
    phone: "Telefono",
    email: "E-Mail",
    address: "Indirizzo",
    description: "Descrizione",
    witnesses: "Testimoni",
    injuries: "Feriti",
    damage: "Danni",
    vehicleA: "Veicolo A",
    vehicleB: "Veicolo B",
    liability: "Responsabilità (dichiarazione delle parti)",
    signatures: "Firme",
    workshopCode: "Codice officina",
    integrity: "Integrità dati",
    hash: "Hash",
    workshopCodeNote:
      "QR disponibile nell’app per importare rapidamente la pratica.",
    pdfNote: "Il PDF della pratica e gli allegati caricati sono inclusi.",
    attachmentsLimitNote:
      "Alcune foto potrebbero essere disponibili solo nella pratica digitale se superano il limite allegati.",
    closing: "Cordiali saluti",
    signatureSigned: "firmato digitalmente",
    signatureMissing: "firma non presente",
    signatureTimestamp: "Timestamp UTC",
  },
  fr: {
    emailSubject: `Dossier d’accident numérique ${displayClaimId}`,
    emailHeading: "Dossier d’accident numérique",
    pdfTitle: "Dossier d’accident numérique",
    claimNumber: "Numéro de dossier",
    summaryHeading: "Resume",
    greeting: "Bonjour,",
    intro: "Votre dossier d’accident numerique a ete enregistre avec succes.",
    pdfSummaryNote:
      "Le dossier numérique complet est disponible dans le PDF joint.",
    photosSummaryNote:
      "Des photographies supplémentaires sont jointes séparément lorsque la limite de taille le permet.",
    dateTime: "Date et heure",
    place: "Lieu",
    driverA: "Conducteur A",
    driverB: "Conducteur B",
    name: "Nom",
    plate: "Plaque",
    insurance: "Assurance",
    phone: "Téléphone",
    email: "E-Mail",
    address: "Adresse",
    description: "Description",
    witnesses: "Témoins",
    injuries: "Blessés",
    damage: "Dommages",
    vehicleA: "Véhicule A",
    vehicleB: "Véhicule B",
    liability: "Responsabilité (déclaration des parties)",
    signatures: "Signatures",
    workshopCode: "Code atelier",
    integrity: "Intégrité des données",
    hash: "Hash",
    workshopCodeNote:
      "QR disponible dans l’application pour importer rapidement le dossier.",
    pdfNote: "Le rapport PDF et les pièces jointes téléchargées sont inclus.",
    attachmentsLimitNote:
      "Certaines photos peuvent rester disponibles uniquement dans le dossier numérique si la limite des pièces jointes est dépassée.",
    closing: "Cordialement",
    signatureSigned: "signé numériquement",
    signatureMissing: "absente",
    signatureTimestamp: "Horodatage UTC",
  },
  en: {
    emailSubject: `Digital accident claim ${displayClaimId}`,
    emailHeading: "Digital accident claim",
    pdfTitle: "Digital accident claim",
    claimNumber: "Claim number",
    summaryHeading: "Summary",
    greeting: "Hello,",
    intro: "Your digital accident claim has been registered successfully.",
    pdfSummaryNote:
      "The complete digital claim file is available in the attached PDF.",
    photosSummaryNote:
      "Additional photographs are included as separate attachments whenever size limits allow.",
    dateTime: "Date and time",
    place: "Location",
    driverA: "Driver A",
    driverB: "Driver B",
    name: "Name",
    plate: "License plate",
    insurance: "Insurance",
    phone: "Phone",
    email: "E-Mail",
    address: "Address",
    description: "Description",
    witnesses: "Witnesses",
    injuries: "Injuries",
    damage: "Damage",
    vehicleA: "Vehicle A",
    vehicleB: "Vehicle B",
    liability: "Liability (party statement)",
    signatures: "Signatures",
    workshopCode: "Workshop code",
    integrity: "Data integrity",
    hash: "Hash",
    workshopCodeNote:
      "QR code available in the app to quickly import the claim.",
    pdfNote: "The PDF report and the uploaded attachments are included.",
    attachmentsLimitNote:
      "Some photos may remain available only in the digital claim if they exceed the email attachment limit.",
    closing: "Kind regards",
    signatureSigned: "digitally signed",
    signatureMissing: "not available",
    signatureTimestamp: "UTC timestamp",
  },
})[lang];

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const normalizePdfText = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[’‘]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, "-")
    .replace(/…/g, "...")
    .replace(/•/g, "-");

const stringOrDash = (value: unknown) => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : "-";
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return "-";
};

const formatDisplayDateTime = formatIncidentDateTime;

const formatUtcTimestamp = (value: unknown) => {
  if (typeof value !== "string" || value.trim().length === 0) {
    return stringOrDash(value);
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value.trim();
  }

  return parsed.toISOString().replace("T", " ").replace(/\.\d{3}Z$/, " UTC");
};

const renderHtmlMultiline = (value: string) =>
  escapeHtml(value).replaceAll("\n", "<br/>");

const renderHtmlRows = (rows: Array<[string, string]>) =>
  rows.map(([label, value]) =>
    `<tr><td style="padding:0 0 10px 0;color:#475569;font-size:13px;vertical-align:top;width:180px;"><strong>${escapeHtml(label)}</strong></td><td style="padding:0 0 10px 0;color:#0f172a;font-size:13px;">${renderHtmlMultiline(value)}</td></tr>`
  ).join("");

const renderHtmlSection = (title: string, content: string) => `
  <div style="margin:0 0 16px 0;padding:18px 20px;border:1px solid #e2e8f0;border-radius:16px;background:#ffffff;">
    <div style="font-size:14px;font-weight:700;color:#0f172a;margin-bottom:12px;">${escapeHtml(title)}</div>
    ${content}
  </div>
`;

const joinNonEmpty = (parts: Array<string | null | undefined>, separator = " ") => {
  const cleaned = parts
    .map((part) => (typeof part === "string" ? part.trim() : ""))
    .filter((part) => part.length > 0);
  return cleaned.length > 0 ? cleaned.join(separator) : "-";
};

const getFullName = (payload: Record<string, any>, variant: "A" | "B") =>
  joinNonEmpty([payload?.[`nome${variant}`], payload?.[`cognome${variant}`]]);

const getFullAddress = (payload: Record<string, any>, variant: "A" | "B") => {
  const street = typeof payload?.[`indirizzo${variant}`] === "string"
    ? payload[`indirizzo${variant}`].trim()
    : "";
  const zipCity = joinNonEmpty(
    [payload?.[`zip${variant}`], payload?.[`city${variant}`]],
  );
  if (!street && zipCity === "-") return "-";
  if (!street) return zipCity;
  if (zipCity === "-") return street;
  return `${street}, ${zipCity}`;
};

const excludedUiKeyFragments = [
  "syncstatus",
  "sendstatus",
  "statustext",
  "locktext",
  "lockedmessage",
  "completionmessage",
  "uimessage",
  "snackbar",
  "localstatus",
];

const excludedUiTextFragments = [
  "pratica salvata",
  "pratica sincronizzata e inviata",
  "firme completate",
  "pratica bloccata",
  "vorgang synchronisiert und gesendet",
  "unterschriften vollstandig",
  "vorgang gesperrt",
];

const isExcludedUiPath = (path: string) => {
  const normalizedPath = normalizeKeyName(path);
  return excludedUiKeyFragments.some((fragment) =>
    normalizedPath.includes(fragment)
  );
};

const isExcludedUiText = (value: string) => {
  const normalized = normalizeKeyName(value);
  return excludedUiTextFragments.some((fragment) =>
    normalized.includes(normalizeKeyName(fragment))
  );
};

const findByKeyFragments = (
  payload: unknown,
  fragments: string[],
): Array<{ path: string; key: string; value: unknown }> => {
  const results: Array<{ path: string; key: string; value: unknown }> = [];
  const normalizedFragments = fragments.map(normalizeKeyName);
  const visited = new Set<unknown>();

  const walk = (node: unknown, path: string[] = []) => {
    if (!node || typeof node !== "object") return;
    if (visited.has(node)) return;
    visited.add(node);

    if (Array.isArray(node)) {
      node.forEach((item, index) => walk(item, [...path, `${index}`]));
      return;
    }

    for (const [key, value] of Object.entries(node as Record<string, unknown>)) {
      const nextPath = [...path, key];
      const pathText = nextPath.join(".");
      const normalizedKey = normalizeKeyName(key);
      const normalizedPath = normalizeKeyName(pathText);
      const matches = normalizedFragments.some((fragment) =>
        normalizedKey.includes(fragment) || normalizedPath.includes(fragment)
      );
      if (matches && !isExcludedUiPath(pathText)) {
        results.push({ path: pathText, key, value });
      }
      walk(value, nextPath);
    }
  };

  walk(payload);
  return results;
};

const extractTextCandidate = (value: unknown): string | null => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed || isExcludedUiText(trimmed)) return null;
    return trimmed;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const nested = extractTextCandidate(item);
      if (nested) return nested;
    }
    return null;
  }
  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    for (
      const key of ["value", "text", "label", "selected", "code", "id", "name"]
    ) {
      const nested = extractTextCandidate(record[key]);
      if (nested) return nested;
    }
    for (const nestedValue of Object.values(record)) {
      const nested = extractTextCandidate(nestedValue);
      if (nested) return nested;
    }
  }
  return null;
};

const detectLiabilityParty = (value: string): "A" | "B" | null => {
  const compact = normalizeKeyName(value);
  if (compact === "a") return "A";
  if (compact === "b") return "B";

  const ascii = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  const patternsA = [
    /\bfahrer\s*a\b/,
    /\bconducente\s*a\b/,
    /\bconducteur\s*a\b/,
    /\bdriver\s*a\b/,
    /\b(colpevole|responsabile|responsible|schuld|fault|liability|liable)\b.*\ba\b/,
    /\ba\b.*\b(colpevole|responsabile|responsible|schuld|fault|liability|liable)\b/,
  ];
  const patternsB = [
    /\bfahrer\s*b\b/,
    /\bconducente\s*b\b/,
    /\bconducteur\s*b\b/,
    /\bdriver\s*b\b/,
    /\b(colpevole|responsabile|responsible|schuld|fault|liability|liable)\b.*\bb\b/,
    /\bb\b.*\b(colpevole|responsabile|responsible|schuld|fault|liability|liable)\b/,
  ];

  if (patternsA.some((pattern) => pattern.test(ascii))) return "A";
  if (patternsB.some((pattern) => pattern.test(ascii))) return "B";
  return null;
};

const getLocalizedLiability = (
  payload: Record<string, any>,
  lang: SupportedLang,
) => {
  const emptyMap = {
    de: "Keine Angabe.",
    it: "Nessuna indicazione.",
    fr: "Aucune indication.",
    en: "No information provided.",
  } as const;
  const localizedByParty = {
    A: {
      de: "Laut den Parteien ist Fahrer A der schuldige Fahrer.",
      it: "Secondo le parti il conducente responsabile è A.",
      fr: "Selon les parties, le conducteur responsable est A.",
      en: "According to the parties, driver A is the liable driver.",
    },
    B: {
      de: "Laut den Parteien ist Fahrer B der schuldige Fahrer.",
      it: "Secondo le parti il conducente responsabile è B.",
      fr: "Selon les parties, le conducteur responsable est B.",
      en: "According to the parties, driver B is the liable driver.",
    },
  } as const;

  const candidates = findByKeyFragments(payload, [
    "haftung",
    "responsabilita",
    "responsabilità",
    "colpa",
    "schuld",
    "liability",
    "fault",
    "responsible",
    "responsabile",
    "colpevole",
  ]);

  for (const candidate of candidates) {
    if (isExcludedUiPath(candidate.path)) continue;
    const text = extractTextCandidate(candidate.value);
    if (!text) continue;

    const party = detectLiabilityParty(text);
    if (party) {
      return localizedByParty[party][lang];
    }

    return text;
  }

  return emptyMap[lang];
};

const formatWitnesses = (
  payload: Record<string, any>,
  lang: "de" | "it" | "fr" | "en",
) => {
  const items = Array.isArray(payload?.testimoni) ? payload.testimoni : [];
  if (items.length === 0) {
    return ({
      de: "Keine Zeugen angegeben.",
      it: "Nessun testimone indicato.",
      fr: "Aucun témoin indiqué.",
      en: "No witnesses provided.",
    } as const)[lang];
  }

  const lines = items
    .map((item) => {
      if (!item || typeof item !== "object") return "";
      const nome = stringOrDash((item as Record<string, unknown>).nome);
      const telefono = stringOrDash((item as Record<string, unknown>).telefono);
      return `- ${nome} (${telefono})`;
    })
    .filter((line) => line.trim().length > 0);

  return lines.length > 0
    ? lines.join("\n")
    : ({
      de: "Keine Zeugen angegeben.",
      it: "Nessun testimone indicato.",
      fr: "Aucun témoin indiqué.",
      en: "No witnesses provided.",
    } as const)[lang];
};

const formatInjuries = (
  payload: Record<string, any>,
  lang: SupportedLang,
) => {
  const items = Array.isArray(payload?.feriti) ? payload.feriti : [];
  if (items.length === 0) {
    return ({
      de: "Keine Verletzten angegeben.",
      it: "Nessun ferito indicato.",
      fr: "Aucun blessé indiqué.",
      en: "No injuries reported.",
    } as const)[lang];
  }

  const lines = items
    .map((item) => {
      if (!item || typeof item !== "object") return "";
      const record = item as Record<string, unknown>;
      return `- ${stringOrDash(record.nome)} | ${stringOrDash(record.indirizzo)} | ${stringOrDash(record.telefono)}`;
    })
    .filter((line) => line.trim().length > 0);

  return lines.length > 0
    ? lines.join("\n")
    : ({
      de: "Keine Verletzten angegeben.",
      it: "Nessun ferito indicato.",
      fr: "Aucun blessé indiqué.",
      en: "No injuries reported.",
    } as const)[lang];
};

const normalizeKeyName = (value: string) =>
  value.toLowerCase().replace(/[^a-z0-9]/g, "");

const extractSignatureSource = (value: unknown): string | null => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }

  if (Array.isArray(value)) {
    for (const item of value) {
      const nested = extractSignatureSource(item);
      if (nested) return nested;
    }
    return null;
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    for (const key of ["base64", "value", "data", "url", "path", "src"]) {
      const nested = extractSignatureSource(record[key]);
      if (nested) return nested;
    }
    for (const nested of Object.values(record)) {
      const result = extractSignatureSource(nested);
      if (result) return result;
    }
  }

  return null;
};

const isSignatureLikeValue = (value: unknown): boolean => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return false;
    if (trimmed.startsWith("data:image/")) return true;
    if (trimmed.length > 80) return true;
    if (trimmed.startsWith("http")) return true;
    return trimmed.startsWith("claims/");
  }

  if (Array.isArray(value)) {
    return value.length > 0 && value.some((item) => isSignatureLikeValue(item));
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (
      ["url", "path", "base64", "value", "data", "src"].some((key) =>
        isSignatureLikeValue(record[key])
      )
    ) {
      return true;
    }
    return Object.values(record).some((nested) => isSignatureLikeValue(nested));
  }

  return false;
};

const findSignatureValue = (
  payload: Record<string, any>,
  variant: "A" | "B",
) => {
  const directKeys = (variant === "A"
    ? [
      "firmaA",
      "firma_a",
      "firmaConducenteA",
      "firmaAPath",
      "signatureA",
      "signature_a",
      "signatureAPath",
      "driverASignature",
      "conducenteAFirma",
      "signA",
      "sign_a",
      "signaturaA",
    ]
    : [
      "firmaB",
      "firma_b",
      "firmaConducenteB",
      "firmaBPath",
      "signatureB",
      "signature_b",
      "signatureBPath",
      "driverBSignature",
      "conducenteBFirma",
      "signB",
      "sign_b",
      "signaturaB",
    ]) as string[];

  const candidates = findByKeyFragments(payload, directKeys);
  for (const candidate of candidates) {
    if (!isSignatureLikeValue(candidate.value)) continue;
    const source = extractSignatureSource(candidate.value);
    if (source) return source;
  }

  return null;
};

const getSignatureTimestamp = (
  payload: Record<string, any>,
  variant: "A" | "B",
) =>
  readStringField(
    payload,
    variant === "A"
      ? [
        "timestampFirmaA",
        "timestamp_firma_a",
        "signatureATimestamp",
        "signature_a_timestamp",
        "driverASignatureTimestamp",
      ]
      : [
        "timestampFirmaB",
        "timestamp_firma_b",
        "signatureBTimestamp",
        "signature_b_timestamp",
        "driverBSignatureTimestamp",
      ],
  );

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

const resolveSignatureImageBytes = async (value: string) => {
  const fromBase64 = decodeBase64Image(value);
  if (fromBase64) return fromBase64;

  try {
    const storage = extractStorageLocation(value);
    if (storage) {
      const { data, error } = await supabase.storage
        .from(storage.bucket)
        .download(normalizeClaimAttachmentPath(storage.path));
      if (!error && data) {
        return new Uint8Array(await data.arrayBuffer());
      }
    }

    if (value.startsWith("http")) {
      const response = await fetch(value);
      if (response.ok) {
        return new Uint8Array(await response.arrayBuffer());
      }
    }
  } catch (_err) {
    console.error("SEND CID EMAIL signature download error", { failed: true });
  }

  return null;
};

async function generatePdfFromPayload(
  payload: Record<string, any>,
  claimId: string,
): Promise<Uint8Array> {
  const lang = detectPayloadLanguage(payload);
  const displayClaimId = formatClaimDisplayId(claimId, payload?.dataOra);
  const displayWorkshopCode = formatWorkshopDisplayCode(displayClaimId);
  const copy = getLocalizedCopy(lang, displayClaimId);
  const driverAName = getFullName(payload, "A");
  const driverBName = getFullName(payload, "B");
  const driverAAddress = getFullAddress(payload, "A");
  const driverBAddress = getFullAddress(payload, "B");
  const witnessesText = formatWitnesses(payload, lang);
  const injuriesText = formatInjuries(payload, lang);
  const liabilityText = getLocalizedLiability(payload, lang);
  const formattedDateTime = formatDisplayDateTime(payload?.dataOra, lang);
  const signatureATimestamp = formatUtcTimestamp(getSignatureTimestamp(payload, "A"));
  const signatureBTimestamp = formatUtcTimestamp(getSignatureTimestamp(payload, "B"));

  const pdfDoc = await PDFDocument.create();
  const fontRegular = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const signatureAValue = findSignatureValue(payload, "A");
  const signatureBValue = findSignatureValue(payload, "B");
  const signatureABytes = signatureAValue
    ? await resolveSignatureImageBytes(signatureAValue)
    : null;
  const signatureBBytes = signatureBValue
    ? await resolveSignatureImageBytes(signatureBValue)
    : null;

  let signatureAImage:
    | Awaited<ReturnType<PDFDocument["embedPng"]>>
    | Awaited<ReturnType<PDFDocument["embedJpg"]>>
    | null = null;
  let signatureBImage:
    | Awaited<ReturnType<PDFDocument["embedPng"]>>
    | Awaited<ReturnType<PDFDocument["embedJpg"]>>
    | null = null;

  if (signatureABytes) {
    try {
      signatureAImage = await pdfDoc.embedPng(signatureABytes);
    } catch (_pngErr) {
      try {
        signatureAImage = await pdfDoc.embedJpg(signatureABytes);
      } catch (_jpgErr) {
        signatureAImage = null;
      }
    }
  }

  if (signatureBBytes) {
    try {
      signatureBImage = await pdfDoc.embedPng(signatureBBytes);
    } catch (_pngErr) {
      try {
        signatureBImage = await pdfDoc.embedJpg(signatureBBytes);
      } catch (_jpgErr) {
        signatureBImage = null;
      }
    }
  }

  const hasWitnesses = Array.isArray(payload?.testimoni) && payload.testimoni.length > 0;
  const hasInjuries = Array.isArray(payload?.feriti) && payload.feriti.length > 0;

  let summarySubtitle = "";
  let protectionNote = "";
  switch (lang) {
    case "it":
      summarySubtitle =
        "Documento riepilogativo per assicurazione, officina e concessionaria.";
      protectionNote =
        "Documento protetto con hash SHA-256 e timestamp UTC.";
      break;
    case "fr":
      summarySubtitle =
        "Document de synthèse destiné à l’assurance, à l’atelier et à la concession.";
      protectionNote =
        "Document protégé par un hachage SHA-256 et un horodatage UTC.";
      break;
    case "en":
      summarySubtitle =
        "Summary document for insurance, workshop and dealership use.";
      protectionNote =
        "Document protected by SHA-256 hash and UTC timestamp.";
      break;
    case "de":
    default:
      summarySubtitle =
        "Zusammenfassendes Dokument für Versicherung, Werkstatt und Autohaus.";
      protectionNote =
        "Dokument geschützt durch SHA-256-Hash und UTC-Zeitstempel.";
      break;
  }

  const pageWidth = 595.28;
  const pageHeight = 841.89;
  const margin = 28;
  const cardGap = 12;
  const cardPadding = 12;
  const contentWidth = pageWidth - (margin * 2);
  const halfWidth = (contentWidth - cardGap) / 2;
  const blue = rgb(0.11, 0.36, 0.83);
  const blueLight = rgb(0.94, 0.97, 1);
  const white = rgb(1, 1, 1);
  const lightGray = rgb(0.98, 0.98, 0.98);
  const dark = rgb(0.06, 0.09, 0.16);
  const muted = rgb(0.42, 0.47, 0.55);
  const border = rgb(0.87, 0.9, 0.95);
  const signatureBorder = rgb(0.84, 0.87, 0.91);
  const footerColor = rgb(0.47, 0.47, 0.47);
  const success = rgb(0.09, 0.39, 0.2);

  let page = pdfDoc.addPage([pageWidth, pageHeight]);
  let y = pageHeight - margin;

  const wrapText = (
    text: string,
    font: typeof fontRegular,
    size: number,
    maxWidth: number,
  ) => {
    const normalized = normalizePdfText(text || "-");
    const paragraphs = normalized.split("\n");
    const lines: string[] = [];

    for (const paragraph of paragraphs) {
      const trimmed = paragraph.trim();
      if (!trimmed) {
        lines.push("");
        continue;
      }
      const words = trimmed.split(/\s+/);
      let current = "";
      for (const word of words) {
        const candidate = current ? `${current} ${word}` : word;
        if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
          current = candidate;
          continue;
        }
        if (current) {
          lines.push(current);
        }
        current = word;
      }
      if (current) {
        lines.push(current);
      }
    }

    return lines.length > 0 ? lines : ["-"];
  };

  const measureLines = (lines: string[], size: number, gap = 3) =>
    lines.length * (size + gap);

  const drawWrappedText = (options: {
    text: string;
    x: number;
    y: number;
    width: number;
    font: typeof fontRegular;
    size: number;
    color: ReturnType<typeof rgb>;
    gap?: number;
  }) => {
    const gap = options.gap ?? 3;
    const lines = wrapText(
      options.text,
      options.font,
      options.size,
      options.width,
    );
    let currentY = options.y;
    for (const lineText of lines) {
      page.drawText(lineText || " ", {
        x: options.x,
        y: currentY,
        size: options.size,
        font: options.font,
        color: options.color,
      });
      currentY -= options.size + gap;
    }
    return currentY;
  };

  const drawCardBackground = (
    x: number,
    yTop: number,
    width: number,
    height: number,
    background: ReturnType<typeof rgb>,
    borderColor = border,
  ) => {
    page.drawRectangle({
      x,
      y: yTop - height,
      width,
      height,
      color: background,
      borderColor,
      borderWidth: 0.8,
    });
  };

  const measureRowsCard = (
    title: string,
    rows: Array<[string, string]>,
    width: number,
  ) => {
    const innerWidth = width - (cardPadding * 2);
    let totalHeight = cardPadding;
    totalHeight += measureLines(
      wrapText(title, fontBold, 11, innerWidth),
      11,
      3,
    );
    totalHeight += 6;
    for (const [label, value] of rows) {
      totalHeight += measureLines(
        wrapText(label, fontBold, 8.5, innerWidth),
        8.5,
        2,
      );
      totalHeight += 2;
      totalHeight += measureLines(
        wrapText(value, fontRegular, 10, innerWidth),
        10,
        3,
      );
      totalHeight += 6;
    }
    return totalHeight + 6;
  };

  const drawRowsCard = (options: {
    x: number;
    yTop: number;
    width: number;
    height: number;
    title: string;
    rows: Array<[string, string]>;
    background?: ReturnType<typeof rgb>;
    titleColor?: ReturnType<typeof rgb>;
  }) => {
    drawCardBackground(
      options.x,
      options.yTop,
      options.width,
      options.height,
      options.background ?? white,
    );
    const innerWidth = options.width - (cardPadding * 2);
    let currentY = options.yTop - cardPadding - 11;
    currentY = drawWrappedText({
      text: options.title,
      x: options.x + cardPadding,
      y: currentY,
      width: innerWidth,
      font: fontBold,
      size: 11,
      color: options.titleColor ?? dark,
      gap: 3,
    });
    currentY -= 3;
    for (const [label, value] of options.rows) {
      currentY = drawWrappedText({
        text: label,
        x: options.x + cardPadding,
        y: currentY,
        width: innerWidth,
        font: fontBold,
        size: 8.5,
        color: muted,
        gap: 2,
      });
      currentY -= 2;
      currentY = drawWrappedText({
        text: value,
        x: options.x + cardPadding,
        y: currentY,
        width: innerWidth,
        font: fontRegular,
        size: 10,
        color: dark,
        gap: 3,
      });
      currentY -= 3;
    }
  };

  const measureTextCard = (
    title: string,
    blocks: Array<{ label?: string; text: string }>,
    width: number,
  ) => {
    const innerWidth = width - (cardPadding * 2);
    let totalHeight = cardPadding;
    totalHeight += measureLines(
      wrapText(title, fontBold, 11, innerWidth),
      11,
      3,
    );
    totalHeight += 6;
    for (const block of blocks) {
      if (block.label) {
        totalHeight += measureLines(
          wrapText(block.label, fontBold, 8.5, innerWidth),
          8.5,
          2,
        );
        totalHeight += 2;
      }
      totalHeight += measureLines(
        wrapText(block.text, fontRegular, 10, innerWidth),
        10,
        3,
      );
      totalHeight += 6;
    }
    return totalHeight + 6;
  };

  const drawTextCard = (options: {
    x: number;
    yTop: number;
    width: number;
    height: number;
    title: string;
    blocks: Array<{ label?: string; text: string }>;
    background?: ReturnType<typeof rgb>;
  }) => {
    drawCardBackground(
      options.x,
      options.yTop,
      options.width,
      options.height,
      options.background ?? white,
    );
    const innerWidth = options.width - (cardPadding * 2);
    let currentY = options.yTop - cardPadding - 11;
    currentY = drawWrappedText({
      text: options.title,
      x: options.x + cardPadding,
      y: currentY,
      width: innerWidth,
      font: fontBold,
      size: 11,
      color: dark,
      gap: 3,
    });
    currentY -= 3;
    for (const block of options.blocks) {
      if (block.label) {
        currentY = drawWrappedText({
          text: block.label,
          x: options.x + cardPadding,
          y: currentY,
          width: innerWidth,
          font: fontBold,
          size: 8.5,
          color: muted,
          gap: 2,
        });
        currentY -= 2;
      }
      currentY = drawWrappedText({
        text: block.text,
        x: options.x + cardPadding,
        y: currentY,
        width: innerWidth,
        font: fontRegular,
        size: 10,
        color: dark,
        gap: 3,
      });
      currentY -= 3;
    }
  };

  const signatureCardHeight = 190;

  const drawSignatureCard = (options: {
    x: number;
    yTop: number;
    width: number;
    title: string;
    status: string;
    timestamp: string;
    image:
      | Awaited<ReturnType<PDFDocument["embedPng"]>>
      | Awaited<ReturnType<PDFDocument["embedJpg"]>>
      | null;
  }) => {
    drawCardBackground(
      options.x,
      options.yTop,
      options.width,
      signatureCardHeight,
      lightGray,
      signatureBorder,
    );
    const innerWidth = options.width - (cardPadding * 2);
    let currentY = options.yTop - cardPadding - 11;
    currentY = drawWrappedText({
      text: options.title,
      x: options.x + cardPadding,
      y: currentY,
      width: innerWidth,
      font: fontBold,
      size: 11,
      color: dark,
      gap: 3,
    });
    currentY -= 4;
    if (options.image) {
      const checkText = "✓";
      const checkSize = 10;
      const checkWidth = fontBold.widthOfTextAtSize(checkText, checkSize);
      page.drawText(checkText, {
        x: options.x + cardPadding,
        y: currentY,
        size: checkSize,
        font: fontBold,
        color: success,
      });
      currentY = drawWrappedText({
        text: options.status,
        x: options.x + cardPadding + checkWidth + 4,
        y: currentY,
        width: innerWidth - checkWidth - 4,
        font: fontBold,
        size: 9.5,
        color: success,
        gap: 3,
      });
    } else {
      currentY = drawWrappedText({
        text: options.status,
        x: options.x + cardPadding,
        y: currentY,
        width: innerWidth,
        font: fontBold,
        size: 9.5,
        color: muted,
        gap: 3,
      });
    }
    currentY -= 8;
    const imageBoxHeight = 76;
    const imageBoxY = currentY - imageBoxHeight;
    page.drawRectangle({
      x: options.x + cardPadding,
      y: imageBoxY,
      width: innerWidth,
      height: imageBoxHeight,
      color: white,
      borderColor: signatureBorder,
      borderWidth: 0.7,
    });
    if (options.image) {
      const dimensions = options.image.scale(1);
      const scale = Math.min(
        (innerWidth - 12) / dimensions.width,
        (imageBoxHeight - 10) / dimensions.height,
        1,
      );
      const imageWidth = dimensions.width * scale;
      const imageHeight = dimensions.height * scale;
      page.drawImage(options.image, {
        x: options.x + cardPadding + ((innerWidth - imageWidth) / 2),
        y: imageBoxY + ((imageBoxHeight - imageHeight) / 2),
        width: imageWidth,
        height: imageHeight,
      });
    }
    currentY = imageBoxY - 12;
    drawWrappedText({
      text: `${copy.signatureTimestamp}: ${options.timestamp}`,
      x: options.x + cardPadding,
      y: currentY,
      width: innerWidth,
      font: fontRegular,
      size: 9,
      color: muted,
      gap: 3,
    });
  };

  const drawFooter = () => {
    const footerEntries = [
      { text: "CID DIGITALE", font: fontBold, size: 7.5 },
      { text: "Documento generato automaticamente.", font: fontRegular, size: 7 },
      { text: "Protetto mediante SHA-256 e UTC Timestamp.", font: fontRegular, size: 7 },
      { text: "www.cid-digitale.com", font: fontRegular, size: 7 },
    ];
    const footerGap = 2;
    const footerHeight = footerEntries.reduce(
      (total, entry, index) => total + entry.size + (index < footerEntries.length - 1 ? footerGap : 0),
      0,
    );
    let currentY = 16 + footerHeight - footerEntries[0].size;

    for (const entry of footerEntries) {
      const text = normalizePdfText(entry.text);
      const textWidth = entry.font.widthOfTextAtSize(text, entry.size);
      page.drawText(text, {
        x: (pageWidth - textWidth) / 2,
        y: currentY,
        size: entry.size,
        font: entry.font,
        color: footerColor,
      });
      currentY -= entry.size + footerGap;
    }
  };

  const ensureSpace = (requiredHeight: number) => {
    if (y - requiredHeight >= margin) return;
    page = pdfDoc.addPage([pageWidth, pageHeight]);
    y = pageHeight - margin;
  };

  console.log("SEND CID EMAIL PDF VERSION: detailed-v3");
  const headerHeight = 82;
  page.drawRectangle({
    x: margin,
    y: y - headerHeight,
    width: contentWidth,
    height: headerHeight,
    color: blue,
  });
  page.drawText("CID DIGITALE", {
    x: margin + 16,
    y: y - 24,
    size: 18,
    font: fontBold,
    color: white,
  });
  page.drawText(normalizePdfText(copy.pdfTitle), {
    x: margin + 16,
    y: y - 42,
    size: 11,
    font: fontRegular,
    color: white,
  });
  page.drawText(`${copy.claimNumber}: ${displayClaimId}`, {
    x: margin + 16,
    y: y - 59,
    size: 13,
    font: fontBold,
    color: white,
  });
  page.drawText(normalizePdfText(summarySubtitle), {
    x: margin + 16,
    y: y - 73,
    size: 8.5,
    font: fontRegular,
    color: white,
  });
  y -= headerHeight + cardGap;

  const summaryRows: Array<[string, string]> = [
    [copy.claimNumber, displayClaimId],
    [copy.dateTime, formattedDateTime],
    [copy.place, stringOrDash(payload?.luogo)],
  ];
  const summaryHeight = measureRowsCard(copy.summaryHeading, summaryRows, contentWidth);
  ensureSpace(summaryHeight);
  drawRowsCard({
    x: margin,
    yTop: y,
    width: contentWidth,
    height: summaryHeight,
    title: copy.summaryHeading,
    rows: summaryRows,
    background: blueLight,
  });
  y -= summaryHeight + cardGap;

  const driverARows: Array<[string, string]> = [
    [copy.name, driverAName],
    [copy.plate, stringOrDash(payload?.targaA)],
    [copy.insurance, stringOrDash(payload?.assicurazioneA)],
    [copy.phone, stringOrDash(payload?.telefonoA)],
    [copy.email, stringOrDash(payload?.emailA)],
    [copy.address, driverAAddress],
  ];
  const driverBRows: Array<[string, string]> = [
    [copy.name, driverBName],
    [copy.plate, stringOrDash(payload?.targaB)],
    [copy.insurance, stringOrDash(payload?.assicurazioneB)],
    [copy.phone, stringOrDash(payload?.telefonoB)],
    [copy.email, stringOrDash(payload?.emailB)],
    [copy.address, driverBAddress],
  ];
  const driverAHeight = measureRowsCard(copy.driverA, driverARows, halfWidth);
  const driverBHeight = measureRowsCard(copy.driverB, driverBRows, halfWidth);
  const driversHeight = Math.max(driverAHeight, driverBHeight);
  ensureSpace(driversHeight);
  drawRowsCard({
    x: margin,
    yTop: y,
    width: halfWidth,
    height: driversHeight,
    title: copy.driverA,
    rows: driverARows,
    background: white,
  });
  drawRowsCard({
    x: margin + halfWidth + cardGap,
    yTop: y,
    width: halfWidth,
    height: driversHeight,
    title: copy.driverB,
    rows: driverBRows,
    background: white,
  });
  y -= driversHeight + cardGap;

  const descriptionBlocks = [
    { text: stringOrDash(payload?.descrizione) },
    ...(hasWitnesses ? [{ label: copy.witnesses, text: witnessesText }] : []),
    ...(hasInjuries ? [{ label: copy.injuries, text: injuriesText }] : []),
  ];
  const descriptionHeight = measureTextCard(
    copy.description,
    descriptionBlocks,
    contentWidth,
  );
  ensureSpace(descriptionHeight);
  drawTextCard({
    x: margin,
    yTop: y,
    width: contentWidth,
    height: descriptionHeight,
    title: copy.description,
    blocks: descriptionBlocks,
    background: white,
  });
  y -= descriptionHeight + cardGap;

  const damageBlocks = [
    { label: copy.vehicleA, text: stringOrDash(payload?.danniVeicoloA) },
    { label: copy.vehicleB, text: stringOrDash(payload?.danniVeicoloB) },
  ];
  const damageHeight = measureTextCard(copy.damage, damageBlocks, halfWidth);
  const liabilityHeight = measureTextCard(
    copy.liability,
    [{ text: liabilityText }],
    halfWidth,
  );
  const damageRowHeight = Math.max(damageHeight, liabilityHeight);
  ensureSpace(damageRowHeight);
  drawTextCard({
    x: margin,
    yTop: y,
    width: halfWidth,
    height: damageRowHeight,
    title: copy.damage,
    blocks: damageBlocks,
    background: white,
  });
  drawTextCard({
    x: margin + halfWidth + cardGap,
    yTop: y,
    width: halfWidth,
    height: damageRowHeight,
    title: copy.liability,
    blocks: [{ text: liabilityText }],
    background: white,
  });
  y -= damageRowHeight + cardGap;

  const protectionBlocks = [
    { text: protectionNote },
    { label: copy.hash, text: stringOrDash(payload?.hashIntegrita) },
    {
      label: copy.signatureTimestamp,
      text: `A: ${signatureATimestamp}   |   B: ${signatureBTimestamp}`,
    },
    { label: copy.workshopCode, text: displayWorkshopCode },
  ];
  const protectionHeight = measureTextCard(
    copy.integrity,
    protectionBlocks,
    contentWidth,
  );
  ensureSpace(protectionHeight);
  drawTextCard({
    x: margin,
    yTop: y,
    width: contentWidth,
    height: protectionHeight,
    title: copy.integrity,
    blocks: protectionBlocks,
    background: blueLight,
  });
  y -= protectionHeight + cardGap;

  const signaturesTitleHeight = 18;
  const footerReserveHeight = 42;
  ensureSpace(signaturesTitleHeight + signatureCardHeight + footerReserveHeight);
  page.drawText(normalizePdfText(copy.signatures), {
    x: margin,
    y,
    size: 12,
    font: fontBold,
    color: dark,
  });
  y -= signaturesTitleHeight;
  drawSignatureCard({
    x: margin,
    yTop: y,
    width: halfWidth,
    title: copy.driverA,
    status: signatureAImage ? copy.signatureSigned : copy.signatureMissing,
    timestamp: signatureATimestamp,
    image: signatureAImage,
  });
  drawSignatureCard({
    x: margin + halfWidth + cardGap,
    yTop: y,
    width: halfWidth,
    title: copy.driverB,
    status: signatureBImage ? copy.signatureSigned : copy.signatureMissing,
    timestamp: signatureBTimestamp,
    image: signatureBImage,
  });
  drawFooter();

  const pdfBytes = await pdfDoc.save();
  console.log("SEND CID EMAIL pdf generated bytes:", pdfBytes.length);
  return pdfBytes;
}

async function generateFallbackPdf(
  displayClaimId: string,
  payload: Record<string, any>,
) {
  const pdfDoc = await PDFDocument.create();
  const fontRegular = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const page = pdfDoc.addPage();
  const formattedDateTime = formatDisplayDateTime(
    payload?.dataOra,
    detectPayloadLanguage(payload),
  );
  const lines = [
    "CID Digitale",
    `Numero pratica: ${displayClaimId}`,
    `Data e ora: ${formattedDateTime}`,
    `Luogo: ${stringOrDash(payload?.luogo)}`,
    "",
    "PDF di fallback generato automaticamente per garantire l'invio della pratica.",
  ];

  let y = page.getSize().height - 50;
  lines.forEach((text, index) => {
    page.drawText(normalizePdfText(text), {
      x: 40,
      y,
      size: index === 0 ? 18 : 12,
      font: index === 0 ? fontBold : fontRegular,
      color: rgb(0, 0, 0),
    });
    y -= index === 0 ? 28 : 18;
  });

  return await pdfDoc.save();
}

async function savePdfToStorage(
  pdfBytes: Uint8Array,
  claimId: string,
  bucket = "claim_attachments",
) {
  try {
    const path = `claims/${claimId}/cid/cid-digitale-${claimId}.pdf`;
    const { error } = await supabase.storage.from(bucket).upload(path, pdfBytes, {
      upsert: true,
      contentType: "application/pdf",
    });
    if (error) {
      console.error("SEND CID EMAIL pdf upload error", { failed: true });
      return null;
    }
    console.log("SEND CID EMAIL pdf saved to storage", { saved: true });
    return { bucket, path };
  } catch (_err) {
    console.error("SEND CID EMAIL pdf upload unexpected error", {
      failed: true,
    });
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
    console.log("[CIDEmail] start", JSON.stringify({
      hasClaimId: Boolean(claimId),
    }));
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

    console.log("SEND CID EMAIL claim lookup", {
      found: Boolean(claimRow),
      hasError: Boolean(claimError),
    });

    if (claimError || !claimRow) {
      console.error("Claim fetch error", {
        found: Boolean(claimRow),
        hasError: Boolean(claimError),
      });
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
    console.log("SEND CID EMAIL payload ready", {
      fieldCount: Object.keys(payload).length,
    });
    const lang = detectPayloadLanguage(payload);
    const displayClaimId = formatClaimDisplayId(
      claimId,
      payload?.dataOra ?? claimRow?.created_at,
    );
    console.log("[CIDEmail] displayId ready", {
      available: Boolean(displayClaimId),
    });
    console.log("LANG_USED", lang);
    console.log(
      "SIGNATURE_KEYS_SCAN",
      JSON.stringify(
        [...new Set(
          findByKeyFragments(payload, [
            "firma",
            "sign",
            "signature",
            "unterschrift",
          ]).map((match) => match.path),
        )].length,
      ),
    );
    console.log(
      "LIABILITY_KEYS_SCAN",
      JSON.stringify(
        [...new Set(
          findByKeyFragments(payload, [
            "haftung",
            "responsabil",
            "colpa",
            "schuld",
            "liability",
            "fault",
          ]).map((match) => match.path),
        )].length,
      ),
    );

    const recipients = collectRecipients(
      payload["emailA"],
      payload["emailB"],
      payload["recipient"],
      payload["customerEmail"],
      payload["customer_email"],
      claimRow?.emailA,
      claimRow?.emailB,
      claimRow?.recipient,
      claimRow?.customerEmail,
      claimRow?.customer_email,
      claimRow?.email,
    );

    console.log("[CIDEmail] recipients ready", JSON.stringify({
      recipientCount: recipients.length,
      hasEmailA: Boolean(payload?.emailA ?? claimRow?.emailA),
      hasEmailB: Boolean(payload?.emailB ?? claimRow?.emailB),
    }));

    if (recipients.length === 0) {
      console.error("[CIDEmail] error full", {
        error: "NO_VALID_RECIPIENTS",
        recipientCount: recipients.length,
        hasEmailA: Boolean(payload?.emailA ?? claimRow?.emailA),
        hasEmailB: Boolean(payload?.emailB ?? claimRow?.emailB),
      });
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
    const queuedPhotoKeys = new Set<string>();
    const bookletCandidates: PhotoAttachmentCandidate[] = [];
    const damageCandidates: PhotoAttachmentCandidate[] = [];
    let pdfAttached = false;
    let totalAttachmentBytes = 0;
    let reducedAttachments = false;
    let bookletAttachedCount = 0;
    let damageAttachedCount = 0;
    let skippedForSizeLimitCount = 0;

    // 1. AGGIUNGI SEMPRE PDF generato dal payload corrente come primo allegato
    try {
      const pdfBytes = await generatePdfFromPayload(payload, claimId);
      await savePdfToStorage(pdfBytes, claimId);
      const encodedPdf = encodeAttachment({
        filename: `cid-digitale-${displayClaimId}.pdf`,
        bytes: pdfBytes,
        contentType: "application/pdf",
      });
      if (!encodedPdf) {
        throw new Error("PDF_ENCODE_FAILED");
      }
      attachments.push(encodedPdf.attachment);
      totalAttachmentBytes += encodedPdf.payloadBytes;
      pdfAttached = true;
      console.log("[CIDEmail] pdf attached", JSON.stringify({
        attachmentCount: attachments.length,
        totalAttachmentBytes,
      }));
    } catch (_err) {
      console.error("SEND CID EMAIL pdf generation failed", { failed: true });
      try {
        const fallbackPdfBytes = await generateFallbackPdf(displayClaimId, payload);
        await savePdfToStorage(fallbackPdfBytes, claimId);
        const encodedFallbackPdf = encodeAttachment({
          filename: `cid-digitale-${displayClaimId}.pdf`,
          bytes: fallbackPdfBytes,
          contentType: "application/pdf",
        });
        if (encodedFallbackPdf) {
          attachments.push(encodedFallbackPdf.attachment);
          totalAttachmentBytes += encodedFallbackPdf.payloadBytes;
          pdfAttached = true;
          console.log("[CIDEmail] pdf attached", JSON.stringify({
            attachmentCount: attachments.length,
            totalAttachmentBytes,
            fallback: true,
          }));
        }
      } catch (_fallbackErr) {
        console.error("SEND CID EMAIL fallback pdf generation failed", {
          failed: true,
        });
      }
    }

    const queuePhotoCandidate = (
      category: PhotoCategory,
      source: string,
      fallbackName: string,
      contentTypeHint?: string,
    ) => {
      const trimmedSource = source.trim();
      if (!trimmedSource || isPdfSource(trimmedSource)) {
        return;
      }
      const attachmentKey = buildAttachmentKey(trimmedSource);
      if (queuedPhotoKeys.has(attachmentKey)) {
        return;
      }
      queuedPhotoKeys.add(attachmentKey);

      const candidate: PhotoAttachmentCandidate = {
        attachmentKey,
        category,
        contentTypeHint,
        fallbackName,
        source: trimmedSource,
      };
      if (category === "booklet") {
        bookletCandidates.push(candidate);
      } else {
        damageCandidates.push(candidate);
      }
    };

    const attachPhotoCandidates = async (
      candidates: PhotoAttachmentCandidate[],
      maxPhotos: number,
    ) => {
      for (let index = 0; index < candidates.length; index++) {
        if (attachments.length >= MAX_ATTACHMENTS) {
          reducedAttachments = true;
          break;
        }

        const candidate = candidates[index];
        if (index >= maxPhotos) {
          reducedAttachments = true;
          continue;
        }

        try {
          const downloadResult = await downloadAttachmentBytes(
            candidate.source,
            candidate.fallbackName,
            candidate.contentTypeHint,
          );
          if (!downloadResult.attachment) {
            reducedAttachments = true;
            if (downloadResult.failureReason === "compression_error") {
              console.error("[CIDEmail] photo skipped compression error", JSON.stringify({
                category: candidate.category,
                hasDetail: Boolean(downloadResult.detail),
              }));
            } else {
              console.error("[CIDEmail] photo skipped download error", JSON.stringify({
                category: candidate.category,
                hasDetail: Boolean(downloadResult.detail),
              }));
            }
            continue;
          }

          const nextAttachmentIndex = candidate.category === "booklet"
            ? bookletAttachedCount + 1
            : damageAttachedCount + 1;
          const attachmentFilename = candidate.category === "booklet"
            ? `libretto-${nextAttachmentIndex}.jpg`
            : `danno-${nextAttachmentIndex}.jpg`;
          const encodedAttachment = encodeAttachment(downloadResult.attachment, {
            filename: attachmentFilename,
            contentType: "image/jpeg",
          });
          if (!encodedAttachment) {
            reducedAttachments = true;
            console.error("[CIDEmail] photo skipped compression error", JSON.stringify({
              category: candidate.category,
              reason: "encode_failed",
            }));
            continue;
          }

          if (
            totalAttachmentBytes + encodedAttachment.payloadBytes >
              MAX_EMAIL_ATTACHMENT_BYTES
          ) {
            console.log("[CIDEmail] photo skipped size limit", JSON.stringify({
              bytes: encodedAttachment.payloadBytes,
              category: candidate.category,
              currentTotalBytes: totalAttachmentBytes,
              maxBytes: MAX_EMAIL_ATTACHMENT_BYTES,
            }));
            reducedAttachments = true;
            skippedForSizeLimitCount += 1;
            continue;
          }

          attachments.push(encodedAttachment.attachment);
          totalAttachmentBytes += encodedAttachment.payloadBytes;

          if (candidate.category === "booklet") {
            bookletAttachedCount += 1;
            console.log("[CIDEmail] booklet photo attached", JSON.stringify({
              attachmentCount: attachments.length,
              totalAttachmentBytes,
            }));
          } else {
            damageAttachedCount += 1;
            console.log("[CIDEmail] damage photo attached", JSON.stringify({
              attachmentCount: attachments.length,
              totalAttachmentBytes,
            }));
          }
        } catch (_err) {
          reducedAttachments = true;
          console.error("[CIDEmail] photo skipped compression error", JSON.stringify({
            category: candidate.category,
            failed: true,
          }));
        }
      }
    };

    // 2. PRENDI ALLEGATI DA claim_attachments
    const { data: dbAttachments, error: dbAttachmentsError } = await supabase
      .from("claim_attachments")
      .select("*")
      .eq("claim_id", claimId);

    console.log("CLAIM_ATTACHMENTS_DB_COUNT:", dbAttachments?.length ?? 0);
    if (dbAttachmentsError) {
      console.error("CLAIM_ATTACHMENT_DOWNLOAD_ERROR:", { failed: true });
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
        const category = detectPhotoCategory(
          possibleSource.trim(),
          [],
          typeof file.kind === "string" ? file.kind : null,
        );
        if (!category) continue;

        const fallbackName = file.filename ||
          file.file_name ||
          file.name ||
          `${category}-${category === "booklet"
            ? bookletCandidates.length + 1
            : damageCandidates.length + 1}.jpg`;

        queuePhotoCandidate(
          category,
          possibleSource.trim(),
          fallbackName,
          file.mime_type || file.content_type || "image/jpeg",
        );
      }
    }

    // 3. FALLBACK ROBUSTO SU payload_json
    const bookletPayloadAttachmentCandidates =
      collectCategoryPayloadAttachmentCandidates(
      payload,
      {
        keyTerms: bookletKeyTerms,
        pathSegments: bookletPathSegments,
      },
    );
    console.log(
      "LIBRETTO_LOGIC_FOUND:",
      JSON.stringify({ count: bookletPayloadAttachmentCandidates.length }),
    );
    for (const candidate of bookletPayloadAttachmentCandidates) {
      queuePhotoCandidate(
        "booklet",
        candidate.source,
        `libretto-${bookletCandidates.length + 1}.jpg`,
        "image/jpeg",
      );
    }

    const damagePayloadAttachmentCandidates = collectCategoryPayloadAttachmentCandidates(
      payload,
      {
        keyTerms: damageKeyTerms,
        pathSegments: damagePathSegments,
      },
    );
    console.log(
      "DAMAGE_LOGIC_FOUND:",
      JSON.stringify({ count: damagePayloadAttachmentCandidates.length }),
    );
    for (const candidate of damagePayloadAttachmentCandidates) {
      queuePhotoCandidate(
        "damage",
        candidate.source,
        `damage-${damageCandidates.length + 1}.jpg`,
        "image/jpeg",
      );
    }

    await attachPhotoCandidates(bookletCandidates, MAX_BOOKLET_PHOTOS);
    await attachPhotoCandidates(damageCandidates, MAX_DAMAGE_PHOTOS);

    console.log("EMAIL_ATTACHMENTS_FINAL:", {
      attachmentCount: attachments.length,
    });

    const copy = getLocalizedCopy(lang, displayClaimId);

    const driverAName = getFullName(payload, "A");
    const driverBName = getFullName(payload, "B");
    const formattedDateTime = formatDisplayDateTime(payload?.dataOra, lang);
    const driverASummary = stringOrDash(driverAName) +
      (stringOrDash(payload?.targaA) !== "-"
        ? ` (${copy.plate}: ${stringOrDash(payload?.targaA)})`
        : "");
    const driverBSummary = stringOrDash(driverBName) +
      (stringOrDash(payload?.targaB) !== "-"
        ? ` (${copy.plate}: ${stringOrDash(payload?.targaB)})`
        : "");
    const shouldShowAttachmentLimitNote = skippedForSizeLimitCount > 0;

    console.log("SEND CID EMAIL BODY VERSION: summary-v1");

    const textBody = [
      copy.emailHeading,
      `${copy.claimNumber}: ${displayClaimId}`,
      "",
      copy.greeting,
      "",
      copy.intro,
      "",
      `${copy.dateTime}: ${formattedDateTime}`,
      `${copy.place}: ${stringOrDash(payload?.luogo)}`,
      "",
      `${copy.driverA}: ${driverASummary}`,
      `${copy.driverB}: ${driverBSummary}`,
      "",
      copy.pdfSummaryNote,
      copy.photosSummaryNote,
      ...(shouldShowAttachmentLimitNote ? [copy.attachmentsLimitNote] : []),
      "",
      copy.closing,
    ].join("\n");

    const htmlBody = `
      <div style="margin:0;padding:24px;background:#f3f6fb;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <div style="max-width:760px;margin:0 auto;background:#ffffff;border:1px solid #dbe4f0;border-radius:20px;overflow:hidden;">
          <div style="padding:24px 28px;background:linear-gradient(135deg,#0f5bd3,#2563eb);color:#ffffff;">
            <div style="font-size:12px;letter-spacing:0.08em;text-transform:uppercase;opacity:0.88;">CID Digitale</div>
            <div style="margin-top:8px;font-size:24px;font-weight:700;">${escapeHtml(copy.emailHeading)}</div>
            <div style="margin-top:14px;display:inline-block;padding:9px 14px;border-radius:999px;background:rgba(255,255,255,0.14);border:1px solid rgba(255,255,255,0.24);font-size:13px;">
              ${escapeHtml(copy.claimNumber)}: ${escapeHtml(displayClaimId)}
            </div>
          </div>
          <div style="padding:28px;">
            <p style="margin:0 0 16px 0;">${escapeHtml(copy.greeting)}</p>
            <p style="margin:0 0 10px 0;">${escapeHtml(copy.intro)}</p>

            ${renderHtmlSection(
      copy.summaryHeading,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.claimNumber, displayClaimId],
        [copy.dateTime, formattedDateTime],
        [copy.place, stringOrDash(payload?.luogo)],
      ])}</table>`,
    )}

            ${renderHtmlSection(
      `${copy.driverA} / ${copy.driverB}`,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.driverA, driverASummary],
        [copy.driverB, driverBSummary],
      ])}</table>`,
    )}

            <div style="margin-top:20px;padding:16px 18px;border-radius:16px;background:#eff6ff;color:#1e3a8a;font-size:13px;line-height:1.6;">
              ${escapeHtml(copy.pdfSummaryNote)}<br/><br/>
              ${escapeHtml(copy.photosSummaryNote)}
              ${shouldShowAttachmentLimitNote
      ? `<br/><br/>${escapeHtml(copy.attachmentsLimitNote)}`
      : ""}
            </div>

            <p style="margin:24px 0 0 0;">${escapeHtml(copy.closing)}</p>
          </div>
        </div>
      </div>
    `;

    const safeSubject = copy.emailSubject.trim().length > 0
      ? copy.emailSubject.trim()
      : `CID Digitale ${displayClaimId}`;
    const safeTextBody = textBody.trim().length > 0
      ? textBody
      : `${copy.emailHeading}\n${copy.claimNumber}: ${displayClaimId}`;
    const safeHtmlBody = htmlBody.trim().length > 0
      ? htmlBody
      : `<p>${escapeHtml(safeTextBody)}</p>`;
    const safeAttachments = attachments;

    console.log("[CIDEmail] payload ready", JSON.stringify({
      lang,
      recipientCount: recipients.length,
      totalAttachmentBytes,
      subjectLength: safeSubject.length,
      textLength: safeTextBody.length,
      htmlLength: safeHtmlBody.length,
      attachmentsCount: safeAttachments.length,
      bookletAttachedCount,
      damageAttachedCount,
      skippedForSizeLimitCount,
      pdfAttached,
    }));

    if (reducedAttachments) {
      console.log("[CIDEmail] sending with reduced attachments", JSON.stringify({
        totalAttachmentBytes,
        attachmentsCount: safeAttachments.length,
        bookletAttachedCount,
        damageAttachedCount,
      }));
    }

    const resendFrom = FROM_EMAIL;
    const resendTo = recipients;
    const resendCc: string[] = [];
    const resendBcc: string[] = [];

    console.log("[CIDEmail] sender ready", {
      configured: Boolean(resendFrom),
    });
    console.log("[CIDEmail] recipients selected", {
      recipientCount: resendTo.length,
      ccCount: resendCc.length,
      bccCount: resendBcc.length,
    });

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: resendFrom,
        to: resendTo,
        subject: safeSubject,
        text: safeTextBody,
        html: safeHtmlBody,
        attachments: safeAttachments,
        ...(resendCc.length > 0 ? { cc: resendCc } : {}),
        ...(resendBcc.length > 0 ? { bcc: resendBcc } : {}),
      }),
    });

    const resendResponseText = await res.text();
    let resendResponseBody: unknown = resendResponseText;
    try {
      resendResponseBody = resendResponseText
        ? JSON.parse(resendResponseText)
        : null;
    } catch (_err) {
      // keep raw body
    }
    console.log("[CIDEmail] resend response", JSON.stringify({
      ok: res.ok,
      status: res.status,
    }));

    if (!res.ok) {
      const resendResult = resendResponseBody && typeof resendResponseBody === "object"
        ? resendResponseBody as Record<string, unknown>
        : null;
      console.error("[CIDEmail] error full", {
        status: res.status,
      });
      return new Response(
        JSON.stringify({
          success: false,
          error: resendResult?.message ?? "Errore invio Resend",
          resendStatus: res.status,
          resendBody: resendResponseBody,
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    console.log("[CIDEmail] send success", JSON.stringify({
      recipientCount: recipients.length,
      attachmentsCount: attachments.length,
      totalAttachmentBytes,
    }));

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
  } catch (_err) {
    console.error("[CIDEmail] error full", { failed: true });
    return Response.json(
      { error: "Unexpected error", success: false },
      { status: 500 },
    );
  }
}

Deno.serve(async (req) => {
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

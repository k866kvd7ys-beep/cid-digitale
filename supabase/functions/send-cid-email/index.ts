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
// TODO: sostituire il mittente Resend con email professionale del dominio quando disponibile.
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

type SupportedLang = "de" | "it" | "fr" | "en";

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
    greeting: "Guten Tag,",
    intro:
      `im Anhang finden Sie die digitale Schadenakte zur Vorgangsnummer ${displayClaimId}.`,
    introDetails:
      "Die Schadenakte wurde digital erstellt und enthält die erfassten Angaben, Anhänge und, sofern vorhanden, die digitalen Unterschriften der beteiligten Fahrer.",
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
    greeting: "Gentile utente,",
    intro:
      `in allegato trova la pratica incidente digitale n° ${displayClaimId}.`,
    introDetails:
      "La pratica è stata creata digitalmente e include i dati registrati, gli allegati e, se presenti, le firme digitali dei conducenti coinvolti.",
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
    greeting: "Bonjour,",
    intro:
      `vous trouverez en pièce jointe le dossier d’accident numérique n° ${displayClaimId}.`,
    introDetails:
      "Le dossier a été créé numériquement et inclut les données enregistrées, les pièces jointes et, si disponibles, les signatures numériques des conducteurs concernés.",
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
    greeting: "Hello,",
    intro:
      `Attached you will find the digital accident claim no. ${displayClaimId}.`,
    introDetails:
      "The claim was created digitally and includes the recorded data, uploaded attachments and, when available, the drivers' digital signatures.",
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

const formatDisplayDateTime = (value: unknown, lang: SupportedLang) => {
  if (typeof value !== "string" || value.trim().length === 0) {
    return stringOrDash(value);
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return value.trim();
  }

  const localeByLang: Record<SupportedLang, string> = {
    de: "de-CH",
    it: "it-CH",
    fr: "fr-CH",
    en: "en-CH",
  };

  return new Intl.DateTimeFormat(localeByLang[lang], {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "Europe/Zurich",
  }).format(parsed).replace(",", "");
};

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
  } catch (err) {
    console.error("SEND CID EMAIL signature download error", err);
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
    page.drawText(normalizePdfText(text ?? ""), {
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
    const bytes = await resolveSignatureImageBytes(value);
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

  const signatureAValue = findSignatureValue(payload, "A");
  const signatureBValue = findSignatureValue(payload, "B");

  console.log("SEND CID EMAIL PDF VERSION: detailed-v3");

  line(copy.pdfTitle, true, 18);
  line(`${copy.claimNumber}: ${displayClaimId}`, false, 12);
  line(`${copy.dateTime}: ${formattedDateTime}`);
  line(`${copy.place}: ${stringOrDash(payload?.luogo)}`);
  line("");
  line(copy.driverA, true, 14);
  line(`${copy.name}: ${driverAName}`);
  line(`${copy.plate}: ${stringOrDash(payload?.targaA)}`);
  line(`${copy.insurance}: ${stringOrDash(payload?.assicurazioneA)}`);
  line(`${copy.phone}: ${stringOrDash(payload?.telefonoA)}`);
  line(`${copy.email}: ${stringOrDash(payload?.emailA)}`);
  line(`${copy.address}: ${driverAAddress}`);
  line("");
  line(copy.driverB, true, 14);
  line(`${copy.name}: ${driverBName}`);
  line(`${copy.plate}: ${stringOrDash(payload?.targaB)}`);
  line(`${copy.insurance}: ${stringOrDash(payload?.assicurazioneB)}`);
  line(`${copy.phone}: ${stringOrDash(payload?.telefonoB)}`);
  line(`${copy.email}: ${stringOrDash(payload?.emailB)}`);
  line(`${copy.address}: ${driverBAddress}`);
  line("");
  line(copy.description, true, 14);
  line(stringOrDash(payload?.descrizione));
  line("");
  line(copy.witnesses, true, 14);
  for (const witnessLine of witnessesText.split("\n")) {
    line(witnessLine);
  }
  line("");
  line(copy.injuries, true, 14);
  for (const injuryLine of injuriesText.split("\n")) {
    line(injuryLine);
  }
  line("");
  line(copy.damage, true, 14);
  line(`${copy.vehicleA}: ${stringOrDash(payload?.danniVeicoloA)}`);
  line(`${copy.vehicleB}: ${stringOrDash(payload?.danniVeicoloB)}`);
  line("");
  line(copy.liability, true, 14);
  line(liabilityText);
  line("");
  line(copy.workshopCode, true, 14);
  line(displayWorkshopCode);
  line("");
  line(copy.integrity, true, 14);
  line(`${copy.hash}: ${stringOrDash(payload?.hashIntegrita)}`);
  line("");

  line(copy.signatures, true, 14);
  line(
    `${copy.driverA}: ${signatureAValue ? copy.signatureSigned : copy.signatureMissing}`,
  );
  if (signatureAValue) {
    line(`${copy.signatureTimestamp}: ${signatureATimestamp}`);
  }
  await drawSignature(copy.driverA, signatureAValue);
  line(
    `${copy.driverB}: ${signatureBValue ? copy.signatureSigned : copy.signatureMissing}`,
  );
  if (signatureBValue) {
    line(`${copy.signatureTimestamp}: ${signatureBTimestamp}`);
  }
  await drawSignature(copy.driverB, signatureBValue);

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
    console.log("[CIDEmail] start", JSON.stringify({ claimId }));
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
    const lang = detectPayloadLanguage(payload);
    const displayClaimId = formatClaimDisplayId(
      claimId,
      payload?.dataOra ?? claimRow?.created_at,
    );
    console.log("[CIDEmail] displayId", displayClaimId);
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
        )],
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
        )],
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

    console.log("[CIDEmail] recipient", JSON.stringify(recipients));

    if (recipients.length === 0) {
      console.error("[CIDEmail] error full", {
        error: "NO_VALID_RECIPIENTS",
        emailA: payload?.emailA ?? null,
        emailB: payload?.emailB ?? null,
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
    const addedPaths = new Set<string>();
    const MAX_ATTACHMENTS = 10;
    let pdfAttached = false;

    // 1. AGGIUNGI SEMPRE PDF generato dal payload corrente come primo allegato
    try {
      const displayClaimId = formatClaimDisplayId(
        claimId,
        payload?.dataOra ?? claimRow?.created_at,
      );
      const pdfBytes = await generatePdfFromPayload(payload, claimId);
      await savePdfToStorage(pdfBytes, claimId);
      attachments.push({
        filename: `cid-digitale-${displayClaimId}.pdf`,
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
    const signatureAValue = findSignatureValue(payload, "A");
    const signatureBValue = findSignatureValue(payload, "B");
    const signatureATimestamp = formatUtcTimestamp(getSignatureTimestamp(payload, "A"));
    const signatureBTimestamp = formatUtcTimestamp(getSignatureTimestamp(payload, "B"));
    const signatureAText = signatureAValue
      ? copy.signatureSigned
      : copy.signatureMissing;
    const signatureBText = signatureBValue
      ? copy.signatureSigned
      : copy.signatureMissing;

    console.log("SEND CID EMAIL BODY VERSION: detailed-v3");

    const signatureALines = [`${copy.driverA}: ${signatureAText}`];
    if (signatureAValue) {
      signatureALines.push(`${copy.signatureTimestamp}: ${signatureATimestamp}`);
    }

    const signatureBLines = [`${copy.driverB}: ${signatureBText}`];
    if (signatureBValue) {
      signatureBLines.push(`${copy.signatureTimestamp}: ${signatureBTimestamp}`);
    }

    const textBody = [
      copy.emailHeading,
      `${copy.claimNumber}: ${displayClaimId}`,
      "",
      copy.greeting,
      "",
      copy.intro,
      copy.introDetails,
      "",
      `${copy.dateTime}: ${formattedDateTime}`,
      `${copy.place}: ${stringOrDash(payload?.luogo)}`,
      `${copy.workshopCode}: ${displayWorkshopCode}`,
      "",
      `${copy.driverA}:`,
      `${copy.name}: ${driverAName}`,
      `${copy.plate}: ${stringOrDash(payload?.targaA)}`,
      `${copy.insurance}: ${stringOrDash(payload?.assicurazioneA)}`,
      `${copy.phone}: ${stringOrDash(payload?.telefonoA)}`,
      `${copy.email}: ${stringOrDash(payload?.emailA)}`,
      `${copy.address}: ${driverAAddress}`,
      "",
      `${copy.driverB}:`,
      `${copy.name}: ${driverBName}`,
      `${copy.plate}: ${stringOrDash(payload?.targaB)}`,
      `${copy.insurance}: ${stringOrDash(payload?.assicurazioneB)}`,
      `${copy.phone}: ${stringOrDash(payload?.telefonoB)}`,
      `${copy.email}: ${stringOrDash(payload?.emailB)}`,
      `${copy.address}: ${driverBAddress}`,
      "",
      `${copy.description}:`,
      stringOrDash(payload?.descrizione),
      "",
      `${copy.witnesses}:`,
      witnessesText,
      "",
      `${copy.injuries}:`,
      injuriesText,
      "",
      `${copy.damage}:`,
      `${copy.vehicleA}: ${stringOrDash(payload?.danniVeicoloA)}`,
      `${copy.vehicleB}: ${stringOrDash(payload?.danniVeicoloB)}`,
      "",
      `${copy.liability}:`,
      liabilityText,
      "",
      `${copy.signatures}:`,
      ...signatureALines,
      ...signatureBLines,
      "",
      copy.workshopCodeNote,
      "",
      copy.pdfNote,
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
            <p style="margin:0 0 24px 0;color:#475569;line-height:1.6;">${escapeHtml(copy.introDetails)}</p>

            ${renderHtmlSection(
      copy.claimNumber,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.claimNumber, displayClaimId],
        [copy.dateTime, formattedDateTime],
        [copy.place, stringOrDash(payload?.luogo)],
        [copy.workshopCode, displayWorkshopCode],
      ])}</table>`,
    )}

            ${renderHtmlSection(
      copy.driverA,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.name, driverAName],
        [copy.plate, stringOrDash(payload?.targaA)],
        [copy.insurance, stringOrDash(payload?.assicurazioneA)],
        [copy.phone, stringOrDash(payload?.telefonoA)],
        [copy.email, stringOrDash(payload?.emailA)],
        [copy.address, driverAAddress],
      ])}</table>`,
    )}

            ${renderHtmlSection(
      copy.driverB,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.name, driverBName],
        [copy.plate, stringOrDash(payload?.targaB)],
        [copy.insurance, stringOrDash(payload?.assicurazioneB)],
        [copy.phone, stringOrDash(payload?.telefonoB)],
        [copy.email, stringOrDash(payload?.emailB)],
        [copy.address, driverBAddress],
      ])}</table>`,
    )}

            ${renderHtmlSection(
      copy.description,
      `<div style="font-size:13px;line-height:1.6;color:#0f172a;">${renderHtmlMultiline(stringOrDash(payload?.descrizione))}</div>`,
    )}

            ${renderHtmlSection(
      copy.witnesses,
      `<div style="font-size:13px;line-height:1.7;color:#0f172a;">${renderHtmlMultiline(witnessesText)}</div>`,
    )}

            ${renderHtmlSection(
      copy.injuries,
      `<div style="font-size:13px;line-height:1.7;color:#0f172a;">${renderHtmlMultiline(injuriesText)}</div>`,
    )}

            ${renderHtmlSection(
      copy.damage,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.vehicleA, stringOrDash(payload?.danniVeicoloA)],
        [copy.vehicleB, stringOrDash(payload?.danniVeicoloB)],
      ])}</table>`,
    )}

            ${renderHtmlSection(
      copy.liability,
      `<div style="font-size:13px;line-height:1.6;color:#0f172a;">${renderHtmlMultiline(liabilityText)}</div>`,
    )}

            ${renderHtmlSection(
      copy.signatures,
      `<table style="width:100%;border-collapse:collapse;">${renderHtmlRows([
        [copy.driverA, signatureAValue
          ? `${signatureAText}\n${copy.signatureTimestamp}: ${signatureATimestamp}`
          : signatureAText],
        [copy.driverB, signatureBValue
          ? `${signatureBText}\n${copy.signatureTimestamp}: ${signatureBTimestamp}`
          : signatureBText],
      ])}</table>`,
    )}

            <div style="margin-top:20px;padding:16px 18px;border-radius:16px;background:#eff6ff;color:#1e3a8a;font-size:13px;line-height:1.6;">
              <strong>${escapeHtml(copy.workshopCode)}:</strong> ${escapeHtml(displayWorkshopCode)}<br/>
              ${escapeHtml(copy.workshopCodeNote)}<br/><br/>
              ${escapeHtml(copy.pdfNote)}
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
    const safeAttachments = attachments.filter((attachment) =>
      typeof attachment.filename === "string" &&
      attachment.filename.trim().length > 0 &&
      typeof attachment.content === "string" &&
      attachment.content.trim().length > 0
    );

    console.log("[CIDEmail] payload ready", JSON.stringify({
      claimId,
      displayClaimId,
      lang,
      recipients,
      subjectLength: safeSubject.length,
      textLength: safeTextBody.length,
      htmlLength: safeHtmlBody.length,
      attachmentsCount: safeAttachments.length,
      pdfAttached,
    }));

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: recipients,
        subject: safeSubject,
        text: safeTextBody,
        html: safeHtmlBody,
        attachments: safeAttachments,
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
      status: res.status,
      body: resendResponseBody,
    }));

    if (!res.ok) {
      const resendResult = resendResponseBody && typeof resendResponseBody === "object"
        ? resendResponseBody as Record<string, unknown>
        : null;
      console.error("[CIDEmail] error full", {
        status: res.status,
        body: resendResponseBody,
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
    console.error("[CIDEmail] error full", err);
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

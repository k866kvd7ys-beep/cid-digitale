export type IncidentDateTimeLanguage = "de" | "it" | "fr" | "en";

const localeByLanguage: Record<IncidentDateTimeLanguage, string> = {
  de: "de-CH",
  it: "it-CH",
  fr: "fr-CH",
  en: "en-CH",
};

const localIncidentDateTimePattern =
  /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?$/;

const fallbackDisplayValue = (value: unknown) => {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : "-";
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  return "-";
};

const formatDateTime = (
  value: Date,
  language: IncidentDateTimeLanguage,
  timeZone: "Europe/Zurich" | "UTC",
) =>
  new Intl.DateTimeFormat(localeByLanguage[language], {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone,
  }).format(value).replace(",", "");

const parseLocalIncidentDateTime = (match: RegExpExecArray) => {
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6] ?? "0");
  const millisecond = Number((match[7] ?? "").padEnd(3, "0").slice(0, 3));
  const parsed = new Date(
    Date.UTC(year, month - 1, day, hour, minute, second, millisecond),
  );

  const isValid = parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() === month - 1 &&
    parsed.getUTCDate() === day &&
    parsed.getUTCHours() === hour &&
    parsed.getUTCMinutes() === minute &&
    parsed.getUTCSeconds() === second;

  return isValid ? parsed : null;
};

export const formatIncidentDateTime = (
  value: unknown,
  language: IncidentDateTimeLanguage,
) => {
  if (typeof value !== "string" || value.trim().length === 0) {
    return fallbackDisplayValue(value);
  }

  const normalized = value.trim();
  const localMatch = localIncidentDateTimePattern.exec(normalized);
  if (localMatch !== null) {
    const localDateTime = parseLocalIncidentDateTime(localMatch);
    if (localDateTime === null) return normalized;

    // dataOra storico rappresenta l'ora civile svizzera senza un offset.
    // UTC viene usato solo come contenitore neutro, senza convertire l'orario.
    return formatDateTime(localDateTime, language, "UTC");
  }

  const zonedDateTime = new Date(normalized);
  if (Number.isNaN(zonedDateTime.getTime())) {
    return normalized;
  }

  return formatDateTime(zonedDateTime, language, "Europe/Zurich");
};

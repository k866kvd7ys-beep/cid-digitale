import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import { formatIncidentDateTime } from "./incident_datetime.ts";

const languages = ["de", "it", "fr", "en"] as const;

test("preserves the stored Swiss local incident time in every language", () => {
  for (const language of languages) {
    assert.equal(
      formatIncidentDateTime("2026-08-01T08:09:46.621", language),
      "01.08.2026 08:09",
    );
  }
});

test("preserves legacy local incident values with a space", () => {
  for (const language of languages) {
    assert.equal(
      formatIncidentDateTime("2025-01-20 18:45", language),
      "20.01.2025 18:45",
    );
  }
});

test("converts explicit instants with Europe/Zurich daylight saving time", () => {
  for (const language of languages) {
    assert.equal(
      formatIncidentDateTime("2026-08-01T06:09:46.621Z", language),
      "01.08.2026 08:09",
    );
    assert.equal(
      formatIncidentDateTime("2026-08-01T08:09:46.621+02:00", language),
      "01.08.2026 08:09",
    );
  }
});

test("converts explicit instants with Europe/Zurich winter time", () => {
  for (const language of languages) {
    assert.equal(
      formatIncidentDateTime("2026-01-15T07:09:46.621Z", language),
      "15.01.2026 08:09",
    );
  }
});

test("does not reinterpret invalid or empty values as valid timestamps", () => {
  assert.equal(formatIncidentDateTime("not-a-date", "it"), "not-a-date");
  assert.equal(
    formatIncidentDateTime("2026-02-30T08:09:00", "it"),
    "2026-02-30T08:09:00",
  );
  assert.equal(formatIncidentDateTime("", "it"), "-");
  assert.equal(formatIncidentDateTime(null, "it"), "-");
});

test("email and both PDF generators use the same incident formatter", () => {
  const edgeFunctionSource = readFileSync(
    new URL("./index.ts", import.meta.url),
    "utf8",
  );

  assert.match(
    edgeFunctionSource,
    /const formatDisplayDateTime = formatIncidentDateTime;/,
  );
  assert.equal(
    edgeFunctionSource.match(/formatDisplayDateTime/g)?.length,
    4,
  );
});

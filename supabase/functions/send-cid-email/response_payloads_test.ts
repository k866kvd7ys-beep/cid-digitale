import assert from "node:assert/strict";

import {
  buildCidEmailErrorPayload,
  buildCidEmailSuccessPayload,
  type CidEmailErrorCode,
} from "./response_payloads.ts";

const sensitivePatterns = [
  /"claimId"\s*:/i,
  /"recipients"\s*:/i,
  /"recipientEmail"\s*:/i,
  /"resendBody"\s*:/i,
  /"providerResponse"\s*:/i,
  /"attachmentFilenames"\s*:/i,
  /"signedUrl"\s*:/i,
  /"token"\s*:/i,
  /cliente@example\.com/i,
  /https:\/\/signed\.example\/path\?token=secret/i,
];

const assertSanitized = (payload: Record<string, unknown>) => {
  const serialized = JSON.stringify(payload);
  for (const pattern of sensitivePatterns) {
    assert.doesNotMatch(serialized, pattern);
  }
};

Deno.test("successful CID e-mail response contains only allowlisted fields", () => {
  const payload = buildCidEmailSuccessPayload({
    attachmentsCount: 3,
    pdfAttached: true,
  });

  assert.deepEqual(payload, {
    success: true,
    message: "Email inviata correttamente",
    attachmentsCount: 3,
    pdfAttached: true,
  });
  assertSanitized(payload);
});

Deno.test("CID e-mail error responses never expose provider or user data", () => {
  const codes: CidEmailErrorCode[] = [
    "INVALID_REQUEST",
    "CLAIM_NOT_FOUND",
    "NO_VALID_RECIPIENTS",
    "EMAIL_PROVIDER_ERROR",
    "INTERNAL_ERROR",
  ];

  for (const code of codes) {
    const payload = buildCidEmailErrorPayload(code);
    assert.equal(payload.success, false);
    assert.equal(payload.error, code);
    assert.equal(typeof payload.message, "string");
    assert.deepEqual(Object.keys(payload).sort(), [
      "error",
      "message",
      "success",
    ]);
    assertSanitized(payload);
  }
});

Deno.test("send-cid-email handler does not reintroduce raw response fields", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );

  for (
    const forbiddenResponseField of [
      "resendBody",
      "resendStatus",
      "attachmentFilenames",
    ]
  ) {
    assert.doesNotMatch(source, new RegExp(forbiddenResponseField));
  }
  assert.doesNotMatch(source, /error instanceof Error \? error\.message/);
});

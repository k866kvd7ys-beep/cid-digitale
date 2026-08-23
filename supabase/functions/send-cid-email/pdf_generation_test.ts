import assert from "node:assert/strict";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { getDocument } from "npm:pdfjs-dist@4.10.38/legacy/build/pdf.mjs";

type PdfGenerator = (
  payload: Record<string, unknown>,
  claimId: string,
) => Promise<Uint8Array>;

type FallbackPdfGenerator = (
  displayClaimId: string,
  payload: Record<string, unknown>,
) => Promise<Uint8Array>;

const signatureData =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

const completePayload: Record<string, unknown> = {
  locale: "de",
  dataOra: "2026-08-23T10:00:00.000Z",
  luogo: "Aarau",
  nomeA: "Antonio",
  cognomeA: "Test",
  marcaA: "Porsche",
  modelloA: "Cayenne S",
  targaA: "AG123456",
  assicurazioneA: "AXA",
  telefonoA: "+41000000001",
  emailA: "antonio@example.com",
  indirizzoA: "Teststrasse 1",
  nomeB: "Fahrer B",
  cognomeB: "Test",
  marcaB: "Audi",
  modelloB: "A4",
  targaB: "ZG5555",
  assicurazioneB: "Zurich",
  telefonoB: "+41000000002",
  emailB: "fahrer-b@example.com",
  indirizzoB: "Testweg 2",
  descrizione: "Test collision",
  danniVeicoloA: "Frontschaden",
  danniVeicoloB: "Heckschaden",
  colpevole: "B",
  hashIntegrita:
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  timestampFirmaA: "2026-08-23T10:05:00.000Z",
  timestampFirmaB: "2026-08-23T10:06:00.000Z",
  firmaAPath: signatureData,
  firmaBPath: signatureData,
};

const copyFile = (
  sourceDirectory: string,
  targetDirectory: string,
  name: string,
) => Deno.copyFile(join(sourceDirectory, name), join(targetDirectory, name));

const loadPdfGenerators = async () => {
  const sourceDirectory = dirname(fileURLToPath(import.meta.url));
  const targetDirectory = await Deno.makeTempDir({
    prefix: "cid-edge-pdf-test-",
  });

  await Promise.all([
    copyFile(sourceDirectory, targetDirectory, "incident_datetime.ts"),
    copyFile(sourceDirectory, targetDirectory, "driver_vehicle_pdf_rows.ts"),
  ]);

  const source = await Deno.readTextFile(join(sourceDirectory, "index.ts"));
  const testableSource = source
    .replace(
      "async function generatePdfFromPayload(",
      "export async function generatePdfFromPayload(",
    )
    .replace(
      "async function generateFallbackPdf(",
      "export async function generateFallbackPdf(",
    )
    .replace(
      "Deno.serve(async (req) => {",
      "if (import.meta.main) Deno.serve(async (req) => {",
    );

  assert.notEqual(testableSource, source);
  await Deno.writeTextFile(join(targetDirectory, "index.ts"), testableSource);

  Deno.env.set("SUPABASE_URL", "https://example.supabase.co");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-role");
  Deno.env.set("RESEND_API_KEY", "test-resend-key");

  const moduleUrl = `${
    pathToFileURL(join(targetDirectory, "index.ts")).href
  }?${crypto.randomUUID()}`;
  const module = await import(moduleUrl);
  return {
    generatePdfFromPayload: module.generatePdfFromPayload as PdfGenerator,
    generateFallbackPdf: module.generateFallbackPdf as FallbackPdfGenerator,
    targetDirectory,
  };
};

const pdfText = async (bytes: Uint8Array) => {
  // pdf.js transfers the supplied buffer to its worker; keep the generated
  // bytes intact so the test can also validate the real attachment size.
  const document = await getDocument({ data: bytes.slice() }).promise;
  const text: string[] = [];
  for (let pageNumber = 1; pageNumber <= document.numPages; pageNumber++) {
    const page = await document.getPage(pageNumber);
    const content = await page.getTextContent();
    text.push(
      content.items
        .map((item) => ("str" in item ? item.str : ""))
        .join(" "),
    );
  }
  await document.destroy();
  return text.join("\n");
};

Deno.test("complete Edge PDF keeps vehicle data, signatures and emergency fallback", async () => {
  const harness = await loadPdfGenerators();
  try {
    const completeBytes = await harness.generatePdfFromPayload(
      completePayload,
      "test-complete-claim",
    );
    const completeText = await pdfText(completeBytes);

    assert.ok(completeBytes.length > 3000);
    assert.doesNotMatch(completeText, /PDF di fallback/);
    for (
      const value of [
        "CID DIGITALE",
        "Fahrer A",
        "Fahrer B",
        "Marke",
        "Modell",
        "Porsche",
        "Cayenne S",
        "Audi",
        "A4",
        "AG123456",
        "ZG5555",
        "Beschreibung",
        "Beschadigung",
        "Haftung",
        "Datenintegritat",
        "SHA-256-Hash",
        "UTC-Zeitstempel",
        "Unterschriften",
        "Digital signiert",
      ]
    ) {
      assert.match(completeText, new RegExp(value));
    }
    assert.equal(completeText.match(/Digital signiert/g)?.length, 2);
    assert.doesNotMatch(completeText, /OK digital signiert|✓/);
    assert.equal(completeText.match(/Porsche/g)?.length, 1);
    assert.equal(completeText.match(/Cayenne S/g)?.length, 1);

    const missingBytes = await harness.generatePdfFromPayload(
      {
        ...completePayload,
        marcaA: null,
        modelloA: undefined,
        marcaB: "",
        modelloB: "",
        driverA: { vehicle: { brand: null, model: null } },
        driverB: { vehicle: {} },
      },
      "test-missing-vehicle-identity",
    );
    const missingText = await pdfText(missingBytes);
    assert.doesNotMatch(missingText, /PDF di fallback/);
    assert.equal(missingText.match(/Marke/g)?.length, 2);
    assert.equal(missingText.match(/Modell/g)?.length, 2);

    let fallbackCalls = 0;
    const generateWithEmergencyFallback = async (
      primary: () => Promise<Uint8Array>,
    ) => {
      try {
        return { bytes: await primary(), fallback: false };
      } catch {
        fallbackCalls++;
        return {
          bytes: await harness.generateFallbackPdf(
            "CID-2026-000001",
            completePayload,
          ),
          fallback: true,
        };
      }
    };

    const healthy = await generateWithEmergencyFallback(
      () => harness.generatePdfFromPayload(completePayload, "healthy-claim"),
    );
    assert.equal(healthy.fallback, false);
    assert.equal(fallbackCalls, 0);

    const emergency = await generateWithEmergencyFallback(
      () => Promise.reject(new Error("forced real PDF error")),
    );
    assert.equal(emergency.fallback, true);
    assert.equal(fallbackCalls, 1);
    assert.match(await pdfText(emergency.bytes), /PDF di fallback/);
  } finally {
    await Deno.remove(harness.targetDirectory, { recursive: true });
  }
});

import assert from "node:assert/strict";
import test from "node:test";

import { buildDriverVehicleIdentityPdfRows } from "./driver_vehicle_pdf_rows.ts";

test("real PDF rows keep separate brand and model for Fahrer A and B", () => {
  const labels = { brand: "Marke", model: "Modell" };

  assert.deepEqual(
    buildDriverVehicleIdentityPdfRows(labels, {
      brand: "Porsche",
      model: "Cayenne S",
    }),
    [
      ["Marke", "Porsche"],
      ["Modell", "Cayenne S"],
    ],
  );
  assert.deepEqual(
    buildDriverVehicleIdentityPdfRows(labels, {
      brand: "Audi",
      model: "A4",
    }),
    [
      ["Marke", "Audi"],
      ["Modell", "A4"],
    ],
  );
});

test("real PDF rows use dashes when brand or model is unavailable", () => {
  assert.deepEqual(
    buildDriverVehicleIdentityPdfRows(
      { brand: "Marke", model: "Modell" },
      { brand: "", model: "   " },
    ),
    [
      ["Marke", "-"],
      ["Modell", "-"],
    ],
  );
});

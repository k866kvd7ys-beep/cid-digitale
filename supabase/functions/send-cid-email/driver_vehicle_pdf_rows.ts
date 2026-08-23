export type DriverVehicleIdentity = {
  brand: unknown;
  model: unknown;
};

export type DriverVehicleIdentityLabels = {
  brand: string;
  model: string;
};

const valueOrDash = (value: unknown) => {
  const normalized = typeof value === "string" ? value.trim() : "";
  return normalized.length > 0 ? normalized : "-";
};

export const buildDriverVehicleIdentityPdfRows = (
  labels: DriverVehicleIdentityLabels,
  vehicle: DriverVehicleIdentity,
): Array<[string, string]> => [
  [labels.brand, valueOrDash(vehicle.brand)],
  [labels.model, valueOrDash(vehicle.model)],
];

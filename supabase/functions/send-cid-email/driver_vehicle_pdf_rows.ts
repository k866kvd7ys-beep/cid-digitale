export type DriverVehicleIdentity = {
  brand: string;
  model: string;
};

export type DriverVehicleIdentityLabels = {
  brand: string;
  model: string;
};

const valueOrDash = (value: string) => {
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : "-";
};

export const buildDriverVehicleIdentityPdfRows = (
  labels: DriverVehicleIdentityLabels,
  vehicle: DriverVehicleIdentity,
): Array<[string, string]> => [
  [labels.brand, valueOrDash(vehicle.brand)],
  [labels.model, valueOrDash(vehicle.model)],
];

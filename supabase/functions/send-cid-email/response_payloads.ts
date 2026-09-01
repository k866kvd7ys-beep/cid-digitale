export type CidEmailErrorCode =
  | "INVALID_REQUEST"
  | "CLAIM_NOT_FOUND"
  | "NO_VALID_RECIPIENTS"
  | "EMAIL_PROVIDER_ERROR"
  | "INTERNAL_ERROR";

const errorMessages: Record<CidEmailErrorCode, string> = {
  INVALID_REQUEST: "Richiesta non valida",
  CLAIM_NOT_FOUND: "Pratica non disponibile",
  NO_VALID_RECIPIENTS: "Nessun destinatario valido disponibile",
  EMAIL_PROVIDER_ERROR: "Invio e-mail non riuscito",
  INTERNAL_ERROR: "Invio e-mail non riuscito",
};

export const buildCidEmailErrorPayload = (code: CidEmailErrorCode) => ({
  success: false as const,
  error: code,
  message: errorMessages[code],
});

export const buildCidEmailSuccessPayload = ({
  attachmentsCount,
  pdfAttached,
}: {
  attachmentsCount: number;
  pdfAttached: boolean;
}) => ({
  success: true as const,
  message: "Email inviata correttamente",
  attachmentsCount,
  pdfAttached,
});

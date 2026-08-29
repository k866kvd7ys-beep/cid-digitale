// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("RESEND_FROM_EMAIL") ?? "onboarding@resend.dev";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type SupportedLang = "de" | "it" | "fr" | "en";

const isValidEmail = (email: string) => {
  const trimmed = email.trim();
  return trimmed.length > 3 && trimmed.includes("@");
};

const normalizeLocale = (value: unknown): SupportedLang => {
  const normalized = String(value ?? "de").trim().toLowerCase();
  if (normalized === "it" || normalized === "fr" || normalized === "en") {
    return normalized;
  }
  return "de";
};

const escapeHtml = (value: unknown) =>
  String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

const stringOrDash = (value: unknown) => {
  const trimmed = String(value ?? "").trim();
  return trimmed.length === 0 ? "-" : trimmed;
};

const joinLines = (lines: Array<string | null | undefined>) =>
  lines.map((line) => String(line ?? "").trim()).filter(Boolean).join("\n");

const joinHtmlLines = (lines: Array<string | null | undefined>) =>
  lines.map((line) => String(line ?? "").trim()).filter(Boolean).map(escapeHtml).join("<br/>");

const buildTextSection = (
  title: string,
  lines: Array<string | null | undefined>,
) =>
  [
    title,
    ...lines.filter((line) => String(line ?? "").trim().length > 0),
  ].join("\n");

const buildHtmlDetailRow = (label: string, value: string) => `
  <tr>
    <td style="padding:0 0 8px 0;font-size:13px;line-height:1.45;color:#64748b;width:160px;vertical-align:top;">
      ${escapeHtml(label)}
    </td>
    <td style="padding:0 0 8px 0;font-size:14px;line-height:1.5;color:#0f172a;font-weight:600;vertical-align:top;">
      ${value}
    </td>
  </tr>
`;

const buildHtmlSection = (title: string, rowsHtml: string) => `
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin:0 0 16px 0;border:1px solid #dbe7f5;border-radius:20px;background:#ffffff;">
    <tr>
      <td style="padding:18px 20px 8px 20px;font-size:14px;line-height:1.3;font-weight:800;color:#2563eb;text-transform:uppercase;letter-spacing:0.06em;">
        ${escapeHtml(title)}
      </td>
    </tr>
    <tr>
      <td style="padding:0 20px 14px 20px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
          ${rowsHtml}
        </table>
      </td>
    </tr>
  </table>
`;

const buildStatusItem = (label: string) => `
  <tr>
    <td style="padding:0 0 10px 0;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="border:1px solid #dbeafe;border-radius:14px;background:#eff6ff;">
        <tr>
          <td style="padding:12px 14px;font-size:14px;line-height:1.4;color:#0f172a;font-weight:700;">
            <span style="display:inline-block;width:22px;height:22px;line-height:22px;border-radius:999px;background:#2563eb;color:#ffffff;text-align:center;font-size:12px;font-weight:800;margin-right:10px;">&#10003;</span>
            ${escapeHtml(label)}
          </td>
        </tr>
      </table>
    </td>
  </tr>
`;

const copyByLocale = (locale: SupportedLang) => {
  switch (locale) {
    case "it":
      return {
        subject: "Conferma richiesta appuntamento - CID Digitale",
        title: "Richiesta ricevuta con successo",
        subtitle: "La tua richiesta è stata registrata correttamente.",
        sectionCustomer: "Cliente",
        sectionVehicle: "Veicolo",
        sectionService: "Servizio richiesto",
        sectionAppointment: "Appuntamento",
        sectionWorkshop: "Officina selezionata",
        sectionRequestId: "Numero pratica",
        sectionStatus: "Stato della richiesta",
        customer: "Cliente",
        name: "Nome",
        email: "E-mail",
        phone: "Telefono",
        plate: "Targa",
        service: "Servizio",
        date: "Data",
        time: "Ora",
        workshop: "Officina selezionata",
        requestId: "ID richiesta",
        statusCreated: "Richiesta creata",
        statusSaved: "Dati salvati",
        statusInformed: "Officina informata",
        footerBrand: "CID Digitale",
        footerTagline: "La gestione intelligente di sinistri e appuntamenti.",
      };
    case "fr":
      return {
        subject: "Confirmation de rendez-vous - CID Digitale",
        title: "Demande reçue avec succès",
        subtitle: "Votre demande a bien été enregistrée.",
        sectionCustomer: "Client",
        sectionVehicle: "Véhicule",
        sectionService: "Service demandé",
        sectionAppointment: "Rendez-vous",
        sectionWorkshop: "Atelier sélectionné",
        sectionRequestId: "Numéro de dossier",
        sectionStatus: "Statut de la demande",
        customer: "Client",
        name: "Nom",
        email: "E-mail",
        phone: "Téléphone",
        plate: "Plaque",
        service: "Service",
        date: "Date",
        time: "Heure",
        workshop: "Atelier sélectionné",
        requestId: "ID de demande",
        statusCreated: "Demande créée",
        statusSaved: "Données enregistrées",
        statusInformed: "Atelier informé",
        footerBrand: "CID Digitale",
        footerTagline: "La gestion intelligente des sinistres et des rendez-vous.",
      };
    case "en":
      return {
        subject: "Appointment request confirmation - CID Digitale",
        title: "Request received successfully",
        subtitle: "Your request was recorded successfully.",
        sectionCustomer: "Customer",
        sectionVehicle: "Vehicle",
        sectionService: "Requested service",
        sectionAppointment: "Appointment",
        sectionWorkshop: "Selected workshop",
        sectionRequestId: "Request number",
        sectionStatus: "Request status",
        customer: "Customer",
        name: "Name",
        email: "Email",
        phone: "Phone",
        plate: "License plate",
        service: "Service",
        date: "Date",
        time: "Time",
        workshop: "Selected workshop",
        requestId: "Request ID",
        statusCreated: "Request created",
        statusSaved: "Data saved",
        statusInformed: "Workshop informed",
        footerBrand: "CID Digitale",
        footerTagline: "Smart claims and appointments management.",
      };
    case "de":
    default:
      return {
        subject: "Bestaetigung Ihrer Terminanfrage - CID Digitale",
        title: "Anfrage erfolgreich erhalten",
        subtitle: "Ihre Anfrage wurde erfolgreich gespeichert.",
        sectionCustomer: "Kunde",
        sectionVehicle: "Fahrzeug",
        sectionService: "Gewuenschter Service",
        sectionAppointment: "Termin",
        sectionWorkshop: "Ausgewaehlte Werkstatt",
        sectionRequestId: "Vorgangsnummer",
        sectionStatus: "Status der Anfrage",
        customer: "Kunde",
        name: "Name",
        email: "E-Mail",
        phone: "Telefon",
        plate: "Kennzeichen",
        service: "Service",
        date: "Datum",
        time: "Uhrzeit",
        workshop: "Ausgewaehlte Werkstatt",
        requestId: "Anfrage-ID",
        statusCreated: "Anfrage erstellt",
        statusSaved: "Daten gespeichert",
        statusInformed: "Werkstatt informiert",
        footerBrand: "CID Digitale",
        footerTagline: "Die intelligente Verwaltung von Schaeden und Terminen.",
      };
  }
};

async function handleRequest(req: Request) {
  if (!RESEND_API_KEY) {
    return Response.json(
      {
        success: false,
        error: "Missing RESEND_API_KEY",
      },
      { status: 500 },
    );
  }

  const payload = await req.json().catch(() => ({} as Record<string, any>));
  const recipient = String(payload?.recipient ?? "").trim();
  const locale = normalizeLocale(payload?.locale);
  const copy = copyByLocale(locale);

  if (!isValidEmail(recipient)) {
    return Response.json(
      {
        success: false,
        error: "Missing or invalid recipient",
      },
      { status: 400 },
    );
  }

  const workshopLabel = joinLines([
    payload?.selected_workshop_name,
    payload?.selected_workshop_address,
    payload?.selected_workshop_city,
  ]) || String(payload?.selected_workshop ?? "").trim();

  const serviceText = String(payload?.service ?? "").trim();
  const requestId = String(payload?.request_id ?? "").trim();
  const customerName = stringOrDash(payload?.name);
  const customerEmail = stringOrDash(payload?.recipient);
  const customerPhone = stringOrDash(payload?.phone);
  const vehicle = String(payload?.vehicle ?? "").trim();
  const plate = stringOrDash(payload?.plate);
  const appointmentDate = stringOrDash(payload?.date);
  const appointmentTime = stringOrDash(payload?.time);
  const normalizedServiceText = stringOrDash(serviceText);
  const normalizedWorkshopLabel =
    workshopLabel.trim().length > 0 ? workshopLabel : "-";
  const normalizedRequestId = stringOrDash(requestId);

  const textBody = [
    copy.title,
    "",
    copy.subtitle,
    "",
    buildTextSection(copy.sectionCustomer, [
      `${copy.name}: ${customerName}`,
      `${copy.email}: ${customerEmail}`,
      `${copy.phone}: ${customerPhone}`,
    ]),
    "",
    buildTextSection(copy.sectionVehicle, [
      vehicle.length > 0 ? vehicle : null,
      `${copy.plate}: ${plate}`,
    ]),
    "",
    buildTextSection(copy.sectionService, [
      `${copy.service}: ${normalizedServiceText}`,
    ]),
    "",
    buildTextSection(copy.sectionAppointment, [
      `${copy.date}: ${appointmentDate}`,
      `${copy.time}: ${appointmentTime}`,
    ]),
    "",
    buildTextSection(copy.sectionWorkshop, [
      normalizedWorkshopLabel,
    ]),
    "",
    buildTextSection(copy.sectionRequestId, [
      normalizedRequestId,
    ]),
    "",
    buildTextSection(copy.sectionStatus, [
      `- ${copy.statusCreated}`,
      `- ${copy.statusSaved}`,
      `- ${copy.statusInformed}`,
    ]),
    "",
    copy.footerBrand,
    copy.footerTagline,
  ].filter((line) => line != null).join("\n");

  const customerSection = buildHtmlSection(
    copy.sectionCustomer,
    [
      buildHtmlDetailRow(copy.name, escapeHtml(customerName)),
      buildHtmlDetailRow(copy.email, escapeHtml(customerEmail)),
      buildHtmlDetailRow(copy.phone, escapeHtml(customerPhone)),
    ].join(""),
  );

  const vehicleSection = buildHtmlSection(
    copy.sectionVehicle,
    [
      vehicle.length > 0
        ? `<tr><td colspan="2" style="padding:0 0 12px 0;font-size:16px;line-height:1.5;color:#0f172a;font-weight:700;">${escapeHtml(vehicle)}</td></tr>`
        : "",
      buildHtmlDetailRow(copy.plate, escapeHtml(plate)),
    ].join(""),
  );

  const serviceSection = buildHtmlSection(
    copy.sectionService,
    buildHtmlDetailRow(
      copy.service,
      escapeHtml(normalizedServiceText).replaceAll("\n", "<br/>"),
    ),
  );

  const appointmentSection = buildHtmlSection(
    copy.sectionAppointment,
    [
      buildHtmlDetailRow(copy.date, escapeHtml(appointmentDate)),
      buildHtmlDetailRow(copy.time, escapeHtml(appointmentTime)),
    ].join(""),
  );

  const workshopSection = buildHtmlSection(
    copy.sectionWorkshop,
    buildHtmlDetailRow(
      copy.workshop,
      joinHtmlLines(normalizedWorkshopLabel.split("\n")),
    ),
  );

  const requestSection = buildHtmlSection(
    copy.sectionRequestId,
    buildHtmlDetailRow(copy.requestId, escapeHtml(normalizedRequestId)),
  );

  const statusSection = buildHtmlSection(
    copy.sectionStatus,
    [
      buildStatusItem(copy.statusCreated),
      buildStatusItem(copy.statusSaved),
      buildStatusItem(copy.statusInformed),
    ].join(""),
  );

  const htmlBody = `
    <!DOCTYPE html>
    <html lang="${escapeHtml(locale)}">
      <body style="margin:0;padding:0;background:#eff4fb;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#eff4fb;">
          <tr>
            <td align="center" style="padding:24px 12px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:680px;">
                <tr>
                  <td style="padding:0 0 16px 0;">
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:linear-gradient(135deg,#2563eb 0%,#1d4ed8 100%);border-radius:28px;overflow:hidden;">
                      <tr>
                        <td style="padding:28px 28px 26px 28px;">
                          <div style="font-size:12px;line-height:1.3;font-weight:800;letter-spacing:0.14em;text-transform:uppercase;color:#bfdbfe;margin-bottom:14px;">
                            CID Digitale
                          </div>
                          <div style="font-size:30px;line-height:1.15;font-weight:800;color:#ffffff;margin-bottom:10px;">
                            ${escapeHtml(copy.title)}
                          </div>
                          <div style="font-size:15px;line-height:1.55;color:#dbeafe;">
                            ${escapeHtml(copy.subtitle)}
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td>
                    ${customerSection}
                    ${vehicleSection}
                    ${serviceSection}
                    ${appointmentSection}
                    ${workshopSection}
                    ${requestSection}
                    ${statusSection}
                  </td>
                </tr>
                <tr>
                  <td style="padding:8px 12px 0 12px;text-align:center;">
                    <div style="font-size:14px;line-height:1.4;font-weight:800;color:#0f172a;">
                      ${escapeHtml(copy.footerBrand)}
                    </div>
                    <div style="font-size:13px;line-height:1.5;color:#64748b;margin-top:4px;">
                      ${escapeHtml(copy.footerTagline)}
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
  `;

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: [recipient],
      subject: copy.subject,
      text: textBody,
      html: htmlBody,
    }),
  });

  const resendBody = await resendResponse.json().catch(() => ({} as any));
  if (!resendResponse.ok) {
    console.error("SEND APPOINTMENT CONFIRMATION Resend error", {
      status: resendResponse.status,
      body: resendBody,
      recipient,
    });
    return Response.json(
      {
        success: false,
        error: resendBody?.message ?? "Resend send failed",
        resendStatus: resendResponse.status,
        resendBody,
      },
      { status: 400 },
    );
  }

  return Response.json(
    {
      success: true,
      recipient,
      requestId,
      resendBody,
    },
    { status: 200 },
  );
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const response = await handleRequest(req);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }

  return new Response(response.body, {
    status: response.status,
    headers,
  });
});

// Edge Function: ocr-libretto-cloud
// Calls Google Cloud Vision (DOCUMENT_TEXT_DETECTION) to OCR a libretto image.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type VisionResponse = {
  responses?: Array<{
    fullTextAnnotation?: {
      text?: string;
      pages?: Array<{
        confidence?: number;
        blocks?: Array<{
          boundingBox?: { vertices?: Array<{ x?: number; y?: number }> };
          paragraphs?: Array<{
            boundingBox?: { vertices?: Array<{ x?: number; y?: number }> };
            words?: Array<{
              boundingBox?: { vertices?: Array<{ x?: number; y?: number }> };
              symbols?: Array<{ text?: string }>;
            }>;
          }>;
        }>;
      }>;
    };
    error?: { message?: string };
  }>;
};

serve(async (req) => {
  console.log("ocr-libretto-cloud: request received", {
    method: req.method,
    url: req.url,
  });

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = await req.json();
    const { imageBase64 } = body ?? {};
    console.log("ocr-libretto-cloud: body keys", Object.keys(body ?? {}));
    if (!imageBase64 || typeof imageBase64 !== "string") {
      return new Response(JSON.stringify({ success: false, error: "Missing imageBase64" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log("ocr-libretto-cloud: imageBase64 length", imageBase64.length);

    const apiKey = Deno.env.get("GOOGLE_VISION_API_KEY");
    console.log(
      "ocr-libretto-cloud: api key present?",
      apiKey && apiKey.length > 5 ? "yes" : "no",
    );
    if (!apiKey) {
      return new Response(JSON.stringify({ success: false, error: "Missing Vision API key" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const visionPayload = {
      requests: [
        {
          image: { content: imageBase64 },
          features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
        },
      ],
    };

    console.log("ocr-libretto-cloud: calling Google Vision DOCUMENT_TEXT_DETECTION");
    const visionRes = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(visionPayload),
      },
    );

    const googleStatus = visionRes.status;
    const visionBodyText = await visionRes.text();
    console.log("ocr-libretto-cloud: vision status", googleStatus);
    console.log("ocr-libretto-cloud: vision raw body", visionBodyText);

    if (!visionRes.ok) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "google_vision_error",
          details: `status ${googleStatus}`,
          googleStatus,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    let visionJson: VisionResponse;
    try {
      visionJson = JSON.parse(visionBodyText) as VisionResponse;
    } catch (e) {
      console.error("ocr-libretto-cloud: failed to parse vision json", e);
      return new Response(
        JSON.stringify({
          success: false,
          error: "vision_parse_error",
          details: String(e),
          googleStatus,
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const text = visionJson.responses?.[0]?.fullTextAnnotation?.text ?? "";
    const confidence = visionJson.responses?.[0]?.fullTextAnnotation?.pages?.[0]?.confidence;
    const apiError = visionJson.responses?.[0]?.error?.message;
    console.log(
      "ocr-libretto-cloud: fullTextAnnotation present?",
      visionJson.responses?.[0]?.fullTextAnnotation ? "yes" : "no",
    );

    if (apiError) {
      console.error("ocr-libretto-cloud: api error", apiError);
      return new Response(JSON.stringify({
        success: false,
        error: "google_vision_error",
        details: apiError,
        googleStatus,
      }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    if (!text || text.trim().length === 0) {
      console.log("ocr-libretto-cloud: no text detected");
      return new Response(
        JSON.stringify({
          success: false,
          error: "no_text_detected",
          googleStatus,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log("ocr-libretto-cloud: text length", text.length);

    // Build blocks with bounding boxes (paragraph-level)
    const blocks: Array<{ text: string; x: number; y: number; w: number; h: number }> = [];
    const page = visionJson.responses?.[0]?.fullTextAnnotation?.pages?.[0];
    if (page?.blocks) {
      for (const b of page.blocks) {
        if (!b.paragraphs) continue;
        for (const p of b.paragraphs) {
          if (!p.words) continue;
          const words = p.words
            .map((w) => (w.symbols || []).map((s) => s.text ?? "").join(""))
            .filter((t) => t.length > 0);
          const pText = words.join(" ").trim();
          const vertices = p.boundingBox?.vertices ?? [];
          if (pText.length === 0 || vertices.length === 0) continue;
          const xs = vertices.map((v) => v.x ?? 0);
          const ys = vertices.map((v) => v.y ?? 0);
          const x = Math.min(...xs);
          const y = Math.min(...ys);
          const w = Math.max(...xs) - x;
          const h = Math.max(...ys) - y;
          blocks.push({ text: pText, x, y, w, h });
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, text, confidence, googleStatus, blocks }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error("ocr-libretto-cloud: exception", e);
    return new Response(JSON.stringify({ success: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

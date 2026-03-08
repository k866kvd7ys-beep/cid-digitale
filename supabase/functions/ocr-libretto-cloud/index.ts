// Edge Function: ocr-libretto-cloud
// Calls Google Cloud Vision (DOCUMENT_TEXT_DETECTION) to OCR a libretto image.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type VisionResponse = {
  responses?: Array<{
    fullTextAnnotation?: { text?: string; pages?: Array<{ confidence?: number }> };
    error?: { message?: string };
  }>;
};

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const { imageBase64 } = await req.json();
    if (!imageBase64 || typeof imageBase64 !== "string") {
      return new Response(JSON.stringify({ success: false, error: "Missing imageBase64" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("GOOGLE_VISION_API_KEY");
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

    const visionRes = await fetch(
      `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(visionPayload),
      },
    );

    if (!visionRes.ok) {
      const err = await visionRes.text();
      return new Response(
        JSON.stringify({ success: false, error: `Vision API error: ${visionRes.status} ${err}` }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const visionJson = (await visionRes.json()) as VisionResponse;
    const text = visionJson.responses?.[0]?.fullTextAnnotation?.text ?? "";
    const confidence = visionJson.responses?.[0]?.fullTextAnnotation?.pages?.[0]?.confidence;
    const apiError = visionJson.responses?.[0]?.error?.message;

    if (apiError) {
      return new Response(JSON.stringify({ success: false, error: apiError }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, text, confidence }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ success: false, error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

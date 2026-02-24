import { createGateway } from "@ai-sdk/gateway";
import { generateText, experimental_generateImage as generateImage } from "ai";
import { useRoomImageBase } from "./use-room-image-base";
import type { CachedImage } from "./room-image-cache";

export type { RoomImageState } from "./use-room-image-base";

// ─── Config ───────────────────────────────────────────────────────────────────

const GATEWAY_KEY = import.meta.env.VITE_AI_GATEWAY_API_KEY as string | undefined;
const GOOGLE_KEY = import.meta.env.VITE_GOOGLE_AI_API_KEY as string | undefined;
const OPENAI_KEY = import.meta.env.VITE_OPENAI_API_KEY as string | undefined;

// ─── Helpers ──────────────────────────────────────────────────────────────────

function getGateway() {
  if (!GATEWAY_KEY) throw new Error("Set VITE_AI_GATEWAY_API_KEY in .env");
  return createGateway({ apiKey: GATEWAY_KEY });
}

function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

// ─── Generators ───────────────────────────────────────────────────────────────

/**
 * Google Nano Banana Pro (gemini-3-pro-image) via Vercel AI Gateway.
 * Uses generateText — model returns images in result.files.
 */
async function generateWithNanoBanana(prompt: string): Promise<CachedImage> {
  const g = getGateway();
  const result = await generateText({
    model: g("google/gemini-3-pro-image"),
    prompt,
  });

  const img = result.files.find((f) => f.mediaType?.startsWith("image/"));
  if (!img) throw new Error("Nano Banana returned no image");

  return { base64: uint8ArrayToBase64(img.uint8Array), mimeType: img.mediaType };
}

/**
 * OpenAI DALL-E 3 via Vercel AI Gateway image model.
 * Uses experimental_generateImage — images in result.images[].base64.
 */
async function generateWithDallE(prompt: string): Promise<CachedImage> {
  const g = getGateway();
  const result = await generateImage({
    model: g.imageModel("openai/dall-e-3"),
    prompt,
    aspectRatio: "16:9",
    ...(OPENAI_KEY && {
      providerOptions: {
        gateway: { byok: { openai: [{ apiKey: OPENAI_KEY }] } },
      },
    }),
  });

  const image = result.images[0];
  return { base64: image.base64, mimeType: image.mediaType ?? "image/png" };
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

const useOpenAI = !GOOGLE_KEY && Boolean(OPENAI_KEY);
const vercelGenerator = useOpenAI ? generateWithDallE : generateWithNanoBanana;

/**
 * Generates a room image via the Vercel AI Gateway.
 *   - Google key set → Nano Banana Pro (google/gemini-3-pro-image)  [preferred]
 *   - OpenAI key set → DALL-E 3 (openai/dall-e-3)                  [fallback]
 *   - Neither key   → Nano Banana Pro via gateway system credentials
 */
export function useRoomImage(
  prompt: string,
  dungeonId: bigint,
  chamberId: bigint,
) {
  return useRoomImageBase(prompt, dungeonId, chamberId, vercelGenerator);
}

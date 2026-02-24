import { GoogleGenAI } from "@google/genai";
import { useRoomImageBase } from "./use-room-image-base";
import type { CachedImage } from "./room-image-cache";

export type { RoomImageState } from "./use-room-image-base";

// ─── Config ───────────────────────────────────────────────────────────────────

const GOOGLE_KEY = import.meta.env.VITE_GOOGLE_AI_API_KEY as string | undefined;

// ─── Generator ────────────────────────────────────────────────────────────────

/**
 * Gemini 3 Pro Image Preview (gemini-3-pro-image-preview) via Google AI Studio.
 * Calls generateContent — model returns images as inlineData parts.
 */
async function generate(prompt: string): Promise<CachedImage> {
  if (!GOOGLE_KEY) throw new Error("Set VITE_GOOGLE_AI_API_KEY in .env");

  const ai = new GoogleGenAI({ apiKey: GOOGLE_KEY });

  const response = await ai.models.generateContent({
    model: "gemini-3-pro-image-preview",
    contents: prompt,
  });

  const parts = response.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    if (part.inlineData?.data) {
      return {
        base64: part.inlineData.data,
        mimeType: part.inlineData.mimeType ?? "image/png",
      };
    }
  }

  throw new Error("No image returned by Gemini — check model access and API key");
}

// ─── Hook ─────────────────────────────────────────────────────────────────────

/**
 * Generates a room image via the Google Gemini API (gemini-3-pro-image-preview).
 * Requires VITE_GOOGLE_AI_API_KEY.
 */
export function useRoomImage(
  prompt: string,
  dungeonId: bigint,
  chamberId: bigint,
) {
  return useRoomImageBase(prompt, dungeonId, chamberId, generate);
}

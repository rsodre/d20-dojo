import { useEffect, useRef, useState } from "react";
import { createGateway } from "@ai-sdk/gateway";
import { generateText, experimental_generateImage as generateImage } from "ai";

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

// ─── Provider implementations ─────────────────────────────────────────────────

/**
 * Google Nano Banana Pro (gemini-3-pro-image).
 * Uses generateText — the model returns images in result.files.
 */
async function generateWithNanoBanana(
  prompt: string,
): Promise<{ base64: string; mimeType: string }> {
  const g = getGateway();
  const result = await generateText({
    model: g("google/gemini-3-pro-image"),
    prompt,
  });

  const img = result.files.find((f) => f.mediaType?.startsWith("image/"));
  if (!img) throw new Error("Nano Banana returned no image");

  return {
    base64: uint8ArrayToBase64(img.uint8Array),
    mimeType: img.mediaType,
  };
}

/**
 * OpenAI DALL-E 3 via gateway image model.
 * Uses experimental_generateImage — images in result.images[].base64.
 */
async function generateWithDallE(
  prompt: string,
): Promise<{ base64: string; mimeType: string }> {
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

// ─── Session cache ────────────────────────────────────────────────────────────

// Keyed by "dungeonId:chamberId". Lives for the browser session.
const imageCache = new Map<string, { base64: string; mimeType: string }>();

// ─── Hook ─────────────────────────────────────────────────────────────────────

export interface RoomImageState {
  base64: string | null;
  mimeType: string;
  isGenerating: boolean;
  error: string | null;
}

/**
 * Generates a room image whenever the explorer enters a new chamber.
 * Generated images are cached by dungeonId:chamberId for the browser session,
 * so re-entering a chamber reuses the existing image without a new API call.
 *
 * Model selection (requires VITE_AI_GATEWAY_API_KEY):
 *   - Google key set → Nano Banana Pro (google/gemini-3-pro-image)  [preferred]
 *   - OpenAI key set → DALL-E 3 (openai/dall-e-3)                  [fallback]
 *   - Neither key   → Nano Banana Pro via gateway system credentials
 */
export function useRoomImage(
  prompt: string,
  dungeonId: bigint,
  chamberId: bigint,
): RoomImageState {
  const cacheKey = `${dungeonId}:${chamberId}`;
  const cached = chamberId !== 0n ? imageCache.get(cacheKey) : undefined;

  const [state, setState] = useState<RoomImageState>(() =>
    cached
      ? { base64: cached.base64, mimeType: cached.mimeType, isGenerating: false, error: null }
      : { base64: null, mimeType: "image/png", isGenerating: false, error: null },
  );

  const lastKeyRef = useRef<string | null>(cached ? cacheKey : null);
  const promptRef = useRef(prompt);
  useEffect(() => { promptRef.current = prompt; });

  useEffect(() => {
    if (chamberId === 0n || !prompt) return;
    if (lastKeyRef.current === cacheKey) return; // already generating or done for this chamber

    // Check cache first (handles re-renders where cached value arrived after initial render)
    const hit = imageCache.get(cacheKey);
    if (hit) {
      lastKeyRef.current = cacheKey;
      setState({ base64: hit.base64, mimeType: hit.mimeType, isGenerating: false, error: null });
      return;
    }

    lastKeyRef.current = cacheKey;
    let cancelled = false;
    setState({ base64: null, mimeType: "image/png", isGenerating: true, error: null });

    const useOpenAI = !GOOGLE_KEY && Boolean(OPENAI_KEY);
    const generate = useOpenAI
      ? generateWithDallE(promptRef.current)
      : generateWithNanoBanana(promptRef.current);

    generate
      .then(({ base64, mimeType }) => {
        imageCache.set(cacheKey, { base64, mimeType });
        if (!cancelled) setState({ base64, mimeType, isGenerating: false, error: null });
      })
      .catch((err: unknown) => {
        // On error, allow retry next time by clearing the key
        if (lastKeyRef.current === cacheKey) lastKeyRef.current = null;
        if (!cancelled)
          setState({ base64: null, mimeType: "image/png", isGenerating: false, error: String(err) });
      });

    return () => { cancelled = true; };
  }, [cacheKey, chamberId, prompt]);

  return state;
}

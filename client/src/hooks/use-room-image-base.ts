import { useEffect, useRef, useState } from "react";
import { getCachedImage, setCachedImage } from "./room-image-cache";
import type { CachedImage } from "./room-image-cache";

export interface RoomImageState {
  base64: string | null;
  mimeType: string;
  isGenerating: boolean;
  error: string | null;
}

/**
 * Shared hook logic for room image generation.
 *
 * Handles: session caching, single-fire per chamber, cancellation on unmount,
 * and retry on error. The actual API call is delegated to `generator`.
 *
 * Both `use-room-image-vercel` and `use-room-image-google` wrap this hook.
 */
export function useRoomImageBase(
  prompt: string,
  dungeonId: bigint,
  chamberId: bigint,
  generator: (prompt: string) => Promise<CachedImage>,
): RoomImageState {
  const cacheKey = `${dungeonId}:${chamberId}`;
  const cached = chamberId !== 0n ? getCachedImage(dungeonId, chamberId) : undefined;

  const [state, setState] = useState<RoomImageState>(() =>
    cached
      ? { base64: cached.base64, mimeType: cached.mimeType, isGenerating: false, error: null }
      : { base64: null, mimeType: "image/png", isGenerating: false, error: null },
  );

  // lastKeyRef tracks the cache key we already fired for, preventing double calls.
  const lastKeyRef = useRef<string | null>(cached ? cacheKey : null);
  // Keep mutable refs so the effect always reads the latest values without
  // being re-triggered by prompt/generator churn.
  const promptRef = useRef(prompt);
  const generatorRef = useRef(generator);
  useEffect(() => { promptRef.current = prompt; });
  useEffect(() => { generatorRef.current = generator; });

  useEffect(() => {
    if (chamberId === 0n || !prompt) return;
    if (lastKeyRef.current === cacheKey) return;

    // Second cache check: handles the case where chamber data loads after
    // the first render (prompt was empty, now it's ready).
    const hit = getCachedImage(dungeonId, chamberId);
    if (hit) {
      lastKeyRef.current = cacheKey;
      setState({ base64: hit.base64, mimeType: hit.mimeType, isGenerating: false, error: null });
      return;
    }

    lastKeyRef.current = cacheKey;
    let cancelled = false;
    setState({ base64: null, mimeType: "image/png", isGenerating: true, error: null });

    generatorRef.current(promptRef.current)
      .then(({ base64, mimeType }) => {
        setCachedImage(dungeonId, chamberId, { base64, mimeType });
        if (!cancelled) setState({ base64, mimeType, isGenerating: false, error: null });
      })
      .catch((err: unknown) => {
        // Clear key so the next room entry retries rather than silently skipping.
        if (lastKeyRef.current === cacheKey) lastKeyRef.current = null;
        if (!cancelled)
          setState({ base64: null, mimeType: "image/png", isGenerating: false, error: String(err) });
      });

    return () => { cancelled = true; };
  }, [cacheKey, chamberId, dungeonId, prompt]);

  return state;
}

/**
 * Session-scoped image cache for generated room images.
 * Keyed by "dungeonId:chamberId" — lives until the browser tab is closed.
 * Shared by all room-image generator hooks so swapping implementations
 * never loses already-generated images.
 */

export interface CachedImage {
  base64: string;
  mimeType: string;
}

const cache = new Map<string, CachedImage>();

export function getCachedImage(dungeonId: bigint, chamberId: bigint): CachedImage | undefined {
  return cache.get(`${dungeonId}:${chamberId}`);
}

export function setCachedImage(dungeonId: bigint, chamberId: bigint, image: CachedImage): void {
  cache.set(`${dungeonId}:${chamberId}`, image);
}

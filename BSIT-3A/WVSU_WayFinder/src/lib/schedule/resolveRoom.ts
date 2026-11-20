import { searchPlaces } from "../data";
import { looksLikeRoomCode, normalizeRoomCode } from "../search";

/**
 * Links a typed room code to exactly one place, or returns undefined ("Room location unconfirmed").
 * The typed code itself is always kept by the caller. A failed lookup also counts as unconfirmed.
 */
export async function resolveRoom(code: string): Promise<string | undefined> {
  if (!looksLikeRoomCode(code)) return undefined;
  try {
    const { data } = await searchPlaces(code);
    const hits = data.filter((v) => v.place.roomCode === normalizeRoomCode(code));
    return hits.length === 1 ? hits[0].place.id : undefined;
  } catch {
    return undefined;
  }
}

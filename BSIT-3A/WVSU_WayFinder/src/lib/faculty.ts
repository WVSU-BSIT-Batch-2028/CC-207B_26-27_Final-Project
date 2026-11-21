import type { Faculty } from "./types";

/**
 * The place ID to open on the map, or null when there is no VERIFIED office with a location.
 * Rule: the office (and the building whose point is used) must be verified (demo in demo mode), and
 * have a point of its own or on its building. Unmapped -> the UI says "Office location unconfirmed".
 */
export function mappableOfficeId(f: Faculty): string | null {
  const o = f.office;
  const ok = (s: string) => s === "verified" || (f.isDemo && s === "demo");
  if (!o || !ok(o.status)) return null;
  const hasOwn = o.lng !== undefined && o.lat !== undefined;
  const hasParent = o.parent !== undefined && ok(o.parent.status) && o.parent.lng !== undefined && o.parent.lat !== undefined;
  return hasOwn || hasParent ? o.id : null;
}

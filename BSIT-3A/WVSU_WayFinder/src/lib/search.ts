/** "cb 203", "CB-203", " cb203 " -> "CB203" */
export function normalizeRoomCode(input: string): string {
  return input.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

/** Letters followed by digits (optionally one trailing letter), e.g. CB203, GYM1, LAB2A. */
export function looksLikeRoomCode(input: string): boolean {
  return /^[A-Z]{1,5}\d{1,4}[A-Z]?$/.test(normalizeRoomCode(input));
}

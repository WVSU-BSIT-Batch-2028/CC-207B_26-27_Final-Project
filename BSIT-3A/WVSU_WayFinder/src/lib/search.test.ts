import { looksLikeRoomCode, normalizeRoomCode } from "./search";

describe("room code normalization", () => {
  it.each(["cb 203", "CB-203", " cb203 ", "Cb.203"])("normalizes %j to CB203", (s) => {
    expect(normalizeRoomCode(s)).toBe("CB203");
  });
  it("recognizes room codes vs names", () => {
    expect(looksLikeRoomCode("cb 203")).toBe(true);
    expect(looksLikeRoomCode("Registrar")).toBe(false);
    expect(looksLikeRoomCode("cb")).toBe(false);
  });
});

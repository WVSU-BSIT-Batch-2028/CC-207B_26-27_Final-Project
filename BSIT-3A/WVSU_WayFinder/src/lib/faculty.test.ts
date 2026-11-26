import { mappableOfficeId } from "./faculty";
import type { Faculty } from "./types";

const base: Faculty = { id: "f", fullName: "T", isDemo: false };

describe("mappableOfficeId", () => {
  it("returns the office ID when the office has its own point", () => {
    expect(mappableOfficeId({ ...base, office: { id: "o", name: "O", status: "verified", lng: 1, lat: 2 } })).toBe("o");
  });
  it("uses the building's point when the office has none", () => {
    expect(mappableOfficeId({ ...base, office: { id: "o", name: "O", status: "verified", parent: { id: "b", name: "B", status: "verified", lng: 1, lat: 2 } } })).toBe("o");
  });
  it("is null for an unverified office or building, even with coordinates", () => {
    expect(mappableOfficeId({ ...base, office: { id: "o", name: "O", status: "unverified", lng: 1, lat: 2 } })).toBeNull();
    expect(mappableOfficeId({ ...base, office: { id: "o", name: "O", status: "verified", parent: { id: "b", name: "B", status: "unverified", lng: 1, lat: 2 } } })).toBeNull();
  });
  it("is null when there is no point anywhere, or no office", () => {
    expect(mappableOfficeId({ ...base, office: { id: "o", name: "O", status: "verified", parent: { id: "b", name: "B", status: "verified" } } })).toBeNull();
    expect(mappableOfficeId(base)).toBeNull();
  });
});

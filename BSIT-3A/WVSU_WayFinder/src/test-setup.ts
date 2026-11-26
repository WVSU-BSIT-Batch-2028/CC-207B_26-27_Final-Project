import "@testing-library/jest-dom/vitest";
import { vi } from "vitest";

// MapLibre needs WebGL; jsdom has none. A tiny stand-in lets map screens render their panels.
vi.mock("maplibre-gl", () => {
  class Map { addControl() {} on() {} remove() {} isStyleLoaded() { return false; } flyTo() {} fitBounds() {} setStyle() {} getSource() {} addSource() {} addLayer() {} }
  class Marker { setLngLat() { return this; } addTo() { return this; } remove() {} }
  class NavigationControl {}
  class LngLatBounds { extend() { return this; } }
  return { Map, Marker, NavigationControl, LngLatBounds, setWorkerUrl() {} };
});

beforeEach(() => {
  if (typeof localStorage !== "undefined") localStorage.clear();
});

import { useEffect, useRef, useState } from "react";
import * as maplibregl from "maplibre-gl";
import type { StyleSpecification } from "maplibre-gl";
// Vite pre-bundling breaks MapLibre's default worker path; point it at the shipped worker module.
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?url";

if (typeof maplibregl.setWorkerUrl === "function") maplibregl.setWorkerUrl(workerUrl);
import { CAMPUS_CENTER } from "../../lib/location";

const MAPTILER_KEY = import.meta.env.VITE_MAPTILER_KEY;
export const hasMapTiler = Boolean(MAPTILER_KEY);
const BLANK_STYLE: StyleSpecification = {
  version: 8,
  sources: {},
  layers: [{ id: "bg", type: "background", paint: { "background-color": "#e6edf7" } }],
};
const MAPTILER_STYLE = `https://api.maptiler.com/maps/streets-v2/style.json?key=${MAPTILER_KEY}`;

export interface Pin { id: string; lng: number; lat: number; kind: "dest" | "start" | "building" | "entrance"; title: string; onClick?: () => void }

/** One MapLibre map: basemap (MapTiler or labeled overlay-only), pins, and a route line. */
export function useMapLibre(container: React.RefObject<HTMLDivElement | null>, pins: Pin[], route: [number, number][] | null) {
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markers = useRef<maplibregl.Marker[]>([]);
  const routeRef = useRef(route);
  routeRef.current = route;
  const [basemapFailed, setBasemapFailed] = useState(!hasMapTiler);
  const [mapError, setMapError] = useState<string | null>(null);

  useEffect(() => {
    if (!container.current) return;
    let map: maplibregl.Map;
    try {
      map = new maplibregl.Map({ container: container.current, style: hasMapTiler ? MAPTILER_STYLE : BLANK_STYLE, center: [CAMPUS_CENTER.lng, CAMPUS_CENTER.lat], zoom: 16.5 });
    } catch {
      setMapError("This browser can't display the map (WebGL unavailable). Directions below still work.");
      return;
    }
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
    map.on("error", (e: maplibregl.ErrorEvent) => {
      const status = (e.error as { status?: number } | undefined)?.status;
      if (hasMapTiler && (status === 401 || status === 403 || status === undefined)) {
        setBasemapFailed((was) => { if (!was) map.setStyle(BLANK_STYLE); return true; });
      }
    });
    const draw = () => drawRoute(map, routeRef.current);
    map.on("load", draw);
    map.on("styledata", draw);
    mapRef.current = map;
    return () => { map.remove(); mapRef.current = null; };
  }, [container]);

  useEffect(() => {
    const map = mapRef.current;
    markers.current.forEach((m) => m.remove());
    markers.current = [];
    if (!map) return;
    for (const p of pins) {
      const el = document.createElement("button");
      el.className = `pin pin-${p.kind}`;
      el.title = p.title;
      el.setAttribute("aria-label", p.title);
      if (p.onClick) el.addEventListener("click", p.onClick);
      const anchor = p.kind === "dest" ? "bottom" : "center";
      markers.current.push(new maplibregl.Marker({ element: el, anchor }).setLngLat([p.lng, p.lat]).addTo(map));
    }
  }, [pins]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    drawRoute(map, route);
    const focus = route?.length ? route : pins.filter((p) => p.kind === "dest" || p.kind === "start").map((p) => [p.lng, p.lat] as [number, number]);
    if (focus.length === 1) map.flyTo({ center: focus[0], zoom: 18, duration: 500 });
    if (focus.length > 1) {
      const b = focus.reduce((acc, c) => acc.extend(c), new maplibregl.LngLatBounds(focus[0], focus[0]));
      map.fitBounds(b, { padding: 60, maxZoom: 18.5, duration: 500 });
    }
  }, [route, pins]);

  return { basemapFailed, mapError };
}

function drawRoute(map: maplibregl.Map, coords: [number, number][] | null) {
  // Not isStyleLoaded(): it stays false while any source is still loading. addSource only needs the
  // style itself; before that it throws and the "load"/"styledata" handlers draw it later.
  const data = { type: "Feature" as const, properties: {}, geometry: { type: "LineString" as const, coordinates: coords ?? [] } };
  try {
    const src = map.getSource("route") as maplibregl.GeoJSONSource | undefined;
    if (src) src.setData(data);
    else {
      map.addSource("route", { type: "geojson", data });
      map.addLayer({ id: "route", type: "line", source: "route", layout: { "line-cap": "round", "line-join": "round" }, paint: { "line-color": "#1d3f8c", "line-width": 6, "line-opacity": 0.85 } });
    }
  } catch {
    /* style not ready yet: the load/styledata handler redraws */
  }
}

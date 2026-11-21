// Walking routes over VERIFIED walkways only (demo graph in demo mode). Never draws straight lines.
import type { CampusPaths, Entrance, WalkNode } from "../types";

export const WALK_SPEED_MPS = 1.2;
export const SNAP_RADIUS_M = 40;

export function distanceM(a: { lng: number; lat: number }, b: { lng: number; lat: number }): number {
  const R = 6371000;
  const dLat = ((b.lat - a.lat) * Math.PI) / 180;
  const dLng = ((b.lng - a.lng) * Math.PI) / 180;
  const s = Math.sin(dLat / 2) ** 2 + Math.cos((a.lat * Math.PI) / 180) * Math.cos((b.lat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

export const etaMinutes = (meters: number) => Math.max(1, Math.ceil(meters / WALK_SPEED_MPS / 60));

export interface Route { nodeIds: string[]; coords: [number, number][]; meters: number; minutes: number }

/** Dijkstra over the (small) campus graph. */
export function shortestPath(paths: CampusPaths, fromNode: string, toNode: string): Route | null {
  const nodes = new Map(paths.nodes.map((n) => [n.id, n]));
  if (!nodes.has(fromNode) || !nodes.has(toNode)) return null;
  const adj = new Map<string, { to: string; w: number }[]>();
  for (const e of paths.edges) {
    const a = nodes.get(e.from);
    const b = nodes.get(e.to);
    if (!a || !b) continue;
    const w = e.lengthM ?? distanceM(a, b);
    (adj.get(e.from) ?? adj.set(e.from, []).get(e.from)!).push({ to: e.to, w });
    (adj.get(e.to) ?? adj.set(e.to, []).get(e.to)!).push({ to: e.from, w });
  }
  const dist = new Map<string, number>([[fromNode, 0]]);
  const prev = new Map<string, string>();
  const todo = new Set(nodes.keys());
  while (todo.size) {
    let u: string | null = null;
    for (const n of todo) if (dist.has(n) && (u === null || dist.get(n)! < dist.get(u)!)) u = n;
    if (u === null) break;
    todo.delete(u);
    if (u === toNode) break;
    for (const { to, w } of adj.get(u) ?? []) {
      const alt = dist.get(u)! + w;
      if (alt < (dist.get(to) ?? Infinity)) {
        dist.set(to, alt);
        prev.set(to, u);
      }
    }
  }
  if (!dist.has(toNode)) return null;
  const ids = [toNode];
  while (ids[0] !== fromNode) ids.unshift(prev.get(ids[0])!);
  const meters = dist.get(toNode)!;
  return { nodeIds: ids, coords: ids.map((id) => [nodes.get(id)!.lng, nodes.get(id)!.lat]), meters, minutes: etaMinutes(meters) };
}

/** Entrances of a building that sit on the verified graph. */
export const entrancesOf = (paths: CampusPaths, buildingId: string): Entrance[] =>
  paths.entrances.filter((e) => e.buildingId === buildingId && e.nodeId);

/** Nearest graph node to a GPS point, if within the snap radius. */
export function snapToNode(paths: CampusPaths, p: { lng: number; lat: number }): { node: WalkNode; meters: number } | null {
  let best: { node: WalkNode; meters: number } | null = null;
  for (const n of paths.nodes) {
    const m = distanceM(p, n);
    if (!best || m < best.meters) best = { node: n, meters: m };
  }
  return best && best.meters <= SNAP_RADIUS_M ? best : null;
}

/** Best route between any entrance of `fromBuilding` (or a start node) and any entrance of `toBuilding`. */
export function routeBetween(paths: CampusPaths, from: { buildingId?: string; nodeId?: string }, toBuildingId: string):
  { route: Route; entrance: Entrance } | null {
  const starts = from.nodeId ? [from.nodeId] : entrancesOf(paths, from.buildingId ?? "").map((e) => e.nodeId!);
  let best: { route: Route; entrance: Entrance } | null = null;
  for (const s of starts) {
    for (const ent of entrancesOf(paths, toBuildingId)) {
      const r = shortestPath(paths, s, ent.nodeId!);
      if (r && (!best || r.meters < best.route.meters)) best = { route: r, entrance: ent };
    }
  }
  return best;
}

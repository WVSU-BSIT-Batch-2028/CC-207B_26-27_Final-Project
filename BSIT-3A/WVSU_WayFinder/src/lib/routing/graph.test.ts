import campus from "../../data/demo/campus.json";
import type { CampusPaths } from "../types";
import { distanceM, etaMinutes, routeBetween, shortestPath, snapToNode } from "./graph";

const paths = campus as unknown as CampusPaths;

describe("walking routes over connected paths", () => {
  it("finds the shortest connected path and an ETA", () => {
    const r = shortestPath(paths, "n-admin", "n-lib")!;
    expect(r.nodeIds[0]).toBe("n-admin");
    expect(r.nodeIds.at(-1)).toBe("n-lib");
    expect(r.meters).toBeGreaterThan(distanceM(paths.nodes[1], paths.nodes[2])); // follows walkways, not a straight line
    expect(r.minutes).toBe(etaMinutes(r.meters));
  });

  it("returns null when no path connects the nodes", () => {
    const islanded: CampusPaths = { ...paths, nodes: [...paths.nodes, { id: "lonely", lng: 122.57, lat: 10.72 }] };
    expect(shortestPath(islanded, "n-admin", "lonely")).toBeNull();
  });

  it("routes building to building through their entrances", () => {
    const r = routeBetween(paths, { buildingId: "bldg-demo-admin" }, "bldg-demo-cb")!;
    expect(r.entrance.id).toBe("ent-demo-cb-main");
    expect(r.route.nodeIds).toEqual(["n-admin", "j-west", "n-cb"]);
  });

  it("no verified entrance → no route", () => {
    expect(routeBetween(paths, { buildingId: "bldg-demo-admin" }, "bldg-unknown")).toBeNull();
  });

  it("snaps GPS only when close to a walkway", () => {
    expect(snapToNode(paths, { lng: 122.5613, lat: 10.71614 })?.node.id).toBe("j-west");
    expect(snapToNode(paths, { lng: 122.57, lat: 10.72 })).toBeNull();
  });
});

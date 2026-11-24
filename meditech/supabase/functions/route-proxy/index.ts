const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Calculates straight-line distance between coordinates in meters
function haversineDistanceMeters(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
): number {
    const R = 6371e3;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function looksLikeTurn(text: string): boolean {
    const lower = text.toLowerCase();
    return ["turn", "left", "right", "u-turn", "roundabout", "merge", "ramp", "exit", "fork", "bear", "sharp", "straight", "arrive"]
        .some((k) => lower.includes(k));
}

function turnPhrase(modifier: string, fallback = "Continue"): string {
    switch (modifier) {
        case "uturn": return "Make a U-turn";
        case "sharp right": return "Turn sharp right";
        case "right": return "Turn right";
        case "slight right": return "Slight right";
        case "straight": return "Go straight";
        case "slight left": return "Slight left";
        case "left": return "Turn left";
        case "sharp left": return "Turn sharp left";
        default: return fallback;
    }
}

function osrmStepInstruction(step: {
    maneuver?: { type?: string; modifier?: string; instruction?: string };
    name?: string;
}): string {
    const m = step.maneuver;
    const road = (step.name ?? "").trim();
    const onto = road ? ` onto ${road}` : "";
    const existing = m?.instruction?.trim();
    if (existing && looksLikeTurn(existing)) return existing;

    const type = m?.type ?? "";
    const modifier = m?.modifier ?? "";

    switch (type) {
        case "depart":
            return road ? `Start on ${road}` : turnPhrase(modifier, "Head toward your route");
        case "arrive":
            return "You have arrived at your destination";
        case "turn":
        case "end of road":
            return `${turnPhrase(modifier)}${onto}`;
        case "fork":
            if (modifier.includes("left")) return `Keep left at the fork${onto}`;
            if (modifier.includes("right")) return `Keep right at the fork${onto}`;
            return `Keep straight at the fork${onto}`;
        case "merge":
            return `Merge${modifier.includes("left") ? " to the left" : modifier.includes("right") ? " to the right" : ""}${onto}`.trim();
        case "on ramp":
            return `Take the ramp${onto}`;
        case "off ramp":
            return `Take the exit${onto}`;
        case "roundabout":
        case "rotary":
        case "roundabout turn":
            if (modifier.includes("left")) return `At the roundabout, take the exit on the left${onto}`;
            if (modifier.includes("right")) return `At the roundabout, take the exit on the right${onto}`;
            return `Enter the roundabout${onto}`;
        case "exit roundabout":
        case "exit rotary":
            return `Exit the roundabout${onto}`;
        case "new name":
        case "continue":
        case "notification":
            if (modifier && modifier !== "straight") return `${turnPhrase(modifier)}${onto}`;
            return road ? `Go straight on ${road}` : "Go straight";
        default:
            if (existing) return existing;
            return road ? `Go straight on ${road}` : "Continue";
    }
}

// Proxies route requests to OpenRouteService with offline fallback
Deno.serve(async (req: Request) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const { start, end, profile = "driving-car" } = await req.json();

        if (!start || !end || !Array.isArray(start) || !Array.isArray(end)) {
            return new Response(
                JSON.stringify({ error: "start and end coordinates [lng, lat] are required." }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
            );
        }

        const startLng = Number(start[0]);
        const startLat = Number(start[1]);
        const endLng = Number(end[0]);
        const endLat = Number(end[1]);

        const apiKey = Deno.env.get("OPENROUTESERVICE_KEY");

        // If an API key is available, call OpenRouteService
        if (apiKey) {
            const orsUrl = `https://api.openrouteservice.org/v2/directions/${profile}/geojson`;
            const orsResponse = await fetch(orsUrl, {
                method: "POST",
                headers: {
                    Authorization: apiKey,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    coordinates: [
                        [startLng, startLat],
                        [endLng, endLat],
                    ],
                }),
            });

            if (orsResponse.ok) {
                const data = await orsResponse.json();
                const feature = data.features?.[0];
                if (feature) {
                    const segments = feature.properties?.segments ?? [];
                    const steps = segments.flatMap((segment: { steps?: unknown[] }) =>
                        (segment.steps ?? []).map((raw) => {
                            const step = raw as {
                                instruction?: string;
                                distance?: number;
                                name?: string;
                            };
                            const instruction = (step.instruction ?? "").trim();
                            return {
                                instruction: instruction && looksLikeTurn(instruction)
                                    ? instruction
                                    : (step.name ? `Go straight on ${step.name}` : "Go straight"),
                                distance_meters: Math.round(step.distance ?? 0),
                                road_name: step.name ?? "",
                            };
                        })
                    );
                    return new Response(
                        JSON.stringify({
                            coordinates: feature.geometry.coordinates,
                            distance_meters: Math.round(feature.properties.summary.distance),
                            duration_seconds: Math.round(feature.properties.summary.duration),
                            steps,
                            provider: "openrouteservice",
                        }),
                        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
                    );
                }
            }
        }

        const osrmCoords = `${startLng},${startLat};${endLng},${endLat}`;
        const osrmQuery = "?overview=full&geometries=geojson&steps=true&annotations=false";
        const osrmUrls = profile === "foot-walking"
            ? [
                `https://routing.openstreetmap.de/routed-foot/route/v1/foot/${osrmCoords}${osrmQuery}`,
                `https://router.project-osrm.org/route/v1/foot/${osrmCoords}${osrmQuery}`,
            ]
            : profile === "cycling-regular"
            ? [
                `https://routing.openstreetmap.de/routed-bike/route/v1/bike/${osrmCoords}${osrmQuery}`,
                `https://router.project-osrm.org/route/v1/bike/${osrmCoords}${osrmQuery}`,
            ]
            : [
                `https://routing.openstreetmap.de/routed-car/route/v1/driving/${osrmCoords}${osrmQuery}`,
                `https://router.project-osrm.org/route/v1/driving/${osrmCoords}${osrmQuery}`,
            ];

        try {
            let osrmResponse: Response | null = null;
            for (const osrmUrl of osrmUrls) {
                const attempt = await fetch(osrmUrl, {
                    headers: { Accept: "application/json" },
                });
                if (attempt.ok) {
                    osrmResponse = attempt;
                    break;
                }
            }
            if (!osrmResponse) {
                throw new Error("OSRM unreachable");
            }
            if (osrmResponse.ok) {
                const osrmData = await osrmResponse.json();
                const route = osrmData.routes?.[0];
                if (route?.geometry?.coordinates) {
                    const steps = (route.legs ?? []).flatMap(
                        (leg: { steps?: unknown[] }) =>
                            (leg.steps ?? []).map((raw) => {
                                const step = raw as {
                                    maneuver?: {
                                        type?: string;
                                        modifier?: string;
                                        instruction?: string;
                                    };
                                    name?: string;
                                    distance?: number;
                                };
                                const instruction = osrmStepInstruction(step);
                                return {
                                    instruction,
                                    distance_meters: Math.round(step.distance ?? 0),
                                    road_name: step.name ?? "",
                                    maneuver: step.maneuver ?? null,
                                };
                            }),
                    );
                    return new Response(
                        JSON.stringify({
                            coordinates: route.geometry.coordinates,
                            distance_meters: Math.round(route.distance ?? 0),
                            duration_seconds: Math.round(route.duration ?? 0),
                            steps,
                            provider: "osrm",
                        }),
                        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
                    );
                }
            }
        } catch {
            // Try estimated fallback below.
        }

        // Estimated fallback when all road routers are unreachable
        const straightMeters = Math.round(
            haversineDistanceMeters(startLat, startLng, endLat, endLng),
        );
        const distanceMeters = Math.round(straightMeters * 1.3);
        const speedMps = profile === "foot-walking"
            ? 1.33
            : profile === "cycling-regular"
            ? 4.2
            : 8.33;
        const durationSeconds = Math.round(distanceMeters / speedMps);

        // Generates a simple multi-point polyline route
        const midLng = (startLng + endLng) / 2;
        const midLat = (startLat + endLat) / 2;
        const fallbackCoords = [
            [startLng, startLat],
            [startLng, midLat],
            [midLng, midLat],
            [endLng, midLat],
            [endLng, endLat],
        ];

        const fallbackSteps = [
            { instruction: "Head toward destination", distance_meters: Math.round(distanceMeters * 0.2), road_name: "" },
            { instruction: "Turn right onto the main road", distance_meters: Math.round(distanceMeters * 0.25), road_name: "" },
            { instruction: "Go straight", distance_meters: Math.round(distanceMeters * 0.25), road_name: "" },
            { instruction: "Turn left toward the pharmacy", distance_meters: Math.round(distanceMeters * 0.15), road_name: "" },
            { instruction: "Arrive at the pharmacy", distance_meters: Math.round(distanceMeters * 0.15), road_name: "" },
        ];

        return new Response(
            JSON.stringify({
                coordinates: fallbackCoords,
                distance_meters: distanceMeters,
                duration_seconds: durationSeconds,
                steps: fallbackSteps,
                provider: "local_fallback",
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
    } catch (error) {
        return new Response(
            JSON.stringify({ error: (error as Error).message }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
    }
});

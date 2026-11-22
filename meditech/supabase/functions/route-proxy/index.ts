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
                    return new Response(
                        JSON.stringify({
                            coordinates: feature.geometry.coordinates,
                            distance_meters: feature.properties.summary.distance,
                            duration_seconds: feature.properties.summary.duration,
                            provider: "openrouteservice",
                        }),
                        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
                    );
                }
            }
        }

        // Local fallback when key is not set or remote service is unreachable
        const distanceMeters = Math.round(
            haversineDistanceMeters(startLat, startLng, endLat, endLng) * 1.3,
        );
        const durationSeconds = Math.round((distanceMeters / 8.33)); // Average city speed ~30 km/h

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

        return new Response(
            JSON.stringify({
                coordinates: fallbackCoords,
                distance_meters: distanceMeters,
                duration_seconds: durationSeconds,
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

/// <reference lib="deno.unstable" />

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GOOGLE_PLACES_API_KEY = Deno.env.get("GOOGLE_PLACES_API_KEY");

if (!GOOGLE_PLACES_API_KEY) {
  throw new Error("GOOGLE_PLACES_API_KEY must be set for google-places function");
}

type AutocompletePayload = {
  action: "autocomplete";
  input: string;
  sessionToken?: string;
};

type DetailsPayload = {
  action: "details";
  placeId: string;
  sessionToken?: string;
};

type PlacesPayload = AutocompletePayload | DetailsPayload;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  let payload: PlacesPayload;
  try {
    payload = await req.json();
  } catch (_) {
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  try {
    switch (payload.action) {
      case "autocomplete":
        return await handleAutocomplete(payload);
      case "details":
        return await handleDetails(payload);
      default:
        return new Response(JSON.stringify({ error: "Unsupported action" }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        });
    }
  } catch (error) {
    console.error("google-places error", error);
    return new Response(
      JSON.stringify({
        error: "Service indisponible pour le moment. Réessayez plus tard.",
      }),
      {
        status: 502,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});

async function handleAutocomplete(payload: AutocompletePayload) {
  const input = payload.input?.trim();
  if (!input) {
    return new Response(JSON.stringify({ error: "Champ input requis" }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  const url = new URL(
    "https://maps.googleapis.com/maps/api/place/autocomplete/json",
  );
  url.searchParams.set("input", input);
  url.searchParams.set("language", "fr");
  url.searchParams.set("types", "address");
  url.searchParams.set("key", GOOGLE_PLACES_API_KEY);
  if (payload.sessionToken) {
    url.searchParams.set("sessiontoken", payload.sessionToken);
  }

  const response = await fetch(url.toString());
  const json = await response.json();

  if (json.status !== "OK" && json.status !== "ZERO_RESULTS") {
    console.error("Google Places autocomplete error", json);
    return new Response(
      JSON.stringify({ error: "Impossible de récupérer les adresses." }),
      {
        status: 502,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }

  return new Response(
    JSON.stringify({
      predictions: json.predictions ?? [],
      status: json.status,
    }),
    {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

async function handleDetails(payload: DetailsPayload) {
  const placeId = payload.placeId?.trim();
  if (!placeId) {
    return new Response(JSON.stringify({ error: "Champ placeId requis" }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }

  const url = new URL(
    "https://maps.googleapis.com/maps/api/place/details/json",
  );
  url.searchParams.set("place_id", placeId);
  url.searchParams.set(
    "fields",
    "place_id,formatted_address,geometry/location,address_components",
  );
  url.searchParams.set("language", "fr");
  url.searchParams.set("key", GOOGLE_PLACES_API_KEY);
  if (payload.sessionToken) {
    url.searchParams.set("sessiontoken", payload.sessionToken);
  }

  const response = await fetch(url.toString());
  const json = await response.json();

  if (json.status !== "OK" || !json.result) {
    console.error("Google Places details error", json);
    return new Response(
      JSON.stringify({ error: "Impossible de récupérer les détails du lieu." }),
      {
        status: 502,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }

  const result = json.result;
  return new Response(
    JSON.stringify({
      placeId: result.place_id,
      formattedAddress: result.formatted_address,
      location: result.geometry?.location ?? null,
      addressComponents: result.address_components ?? [],
    }),
    {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

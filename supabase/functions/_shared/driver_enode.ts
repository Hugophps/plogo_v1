import { enodeFetch } from "./enode.ts";

export type ChargerActionKind = "START" | "STOP";

export class EnodeHttpError extends Error {
  constructor(
    readonly status: number,
    readonly body: string | null,
    readonly context: string,
  ) {
    super(`Erreur Enode (${context})`);
  }
}

export function extractEnodeActionId(action: unknown): string | null {
  if (action && typeof action === "object" && !Array.isArray(action)) {
    const id = (action as Record<string, unknown>)["id"];
    if (typeof id === "string" && id.trim().length > 0) {
      return id;
    }
  }
  return null;
}

export function mergeRawEnodePayload(
  current: Record<string, unknown> | null,
  patch: Record<string, unknown>,
): Record<string, unknown> {
  return {
    ...(current ?? {}),
    ...patch,
  };
}

export async function callEnodeChargingAction(params: {
  chargerId: string;
  action: ChargerActionKind;
  contextLabel: string;
}): Promise<Record<string, unknown> | null> {
  const response = await enodeFetch(
    `/chargers/${params.chargerId}/charging`,
    {
      method: "POST",
      body: JSON.stringify({ action: params.action }),
    },
  );

  const bodyText = await response.text();
  const safeBody = bodyText ?? "";
  console.log(
    `ENODE DEBUG → ${params.contextLabel} status: ${response.status} body: ${
      safeBody || "<empty>"
    }`,
  );

  if (!response.ok) {
    console.error(
      `ENODE ERROR → ${params.contextLabel} status: ${response.status} body: ${
        safeBody || "<empty>"
      }`,
    );
    throw new EnodeHttpError(response.status, safeBody || null, params.contextLabel);
  }

  if (!safeBody) {
    return null;
  }

  try {
    return JSON.parse(safeBody) as Record<string, unknown>;
  } catch (_) {
    return { raw: safeBody };
  }
}

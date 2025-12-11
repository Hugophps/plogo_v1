import { EnodeApiError } from "./enode.ts";
import { DriverChargingError } from "./driver_charging.ts";

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

export function handleDriverEnodeError(
  context: string,
  error: unknown,
  fallbackMessage: string,
): never {
  if (error instanceof EnodeApiError) {
    console.error(`${context} Enode error`, {
      status: error.status,
      body: error.body ?? null,
    });
    throw new DriverChargingError(
      error.message || fallbackMessage,
      error.status || 502,
    );
  }

  console.error(`${context} unexpected error`, error);
  throw new DriverChargingError(fallbackMessage, 500);
}

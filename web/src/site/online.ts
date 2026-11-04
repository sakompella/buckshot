import type { AggregateName } from "../arena-viewer/aggregates.ts";

/** The Cloudflare build (`vite build --mode online`): aggregate files only, no arena server behind it. */
export const isOnline = import.meta.env.MODE === "online";

export const aggregateUrl = (name: AggregateName): string => (isOnline ? `/data/${name}.json` : `/api/agg/${name}`);

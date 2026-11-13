import { configOfLabel } from "./model-names.ts";
import GROUPS from "./same-treatments.json" with { type: "json" };

// Configs that requested different efforts and ran the same: one model whose efforts billed the same reasoning per
// call. Each group counts as one config, its effort the requested efforts joined by "/", in every rating, table and
// analysis. Seat labels, logs and entrants keep the effort each match requested.

const EFFORT_OF: ReadonlyMap<string, string> = new Map(GROUPS.flatMap(({ model, efforts }) => efforts.map((effort) => [`${model}|${effort}`, efforts.join("/")] as const)));

/** The effort a model's config counts under: a same-treatment group's joined efforts, or the effort itself. */
export const configEffort = (model: string, effort: string): string => EFFORT_OF.get(`${model}|${effort}`) ?? effort;

/** A seat's label as the config it counts as. */
export const configOf = (label: string) => {
  const { model, effort } = configOfLabel(label);

  return { model, effort: configEffort(model, effort) };
};

/** The requested efforts a config's effort stands for: one, or a same-treatment group's. */
export const effortParts = (effort: string): ReadonlyArray<string> => effort.split("/");

/** Whether a config is a same-treatment group. */
export const isSameTreatment = (effort: string): boolean => effort.includes("/");

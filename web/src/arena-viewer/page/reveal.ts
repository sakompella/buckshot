/** Opens every fold around an element. */
export const reveal = (target: Element): void => {
  for (let fold = target.parentElement?.closest("details") ?? null; fold !== null; fold = fold.parentElement?.closest("details") ?? null) { fold.open = true; }
};

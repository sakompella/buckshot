/** Opens the folds around an element, and the fold of the page's last group when that group is the target, so a link into them lands on drawn content. */
export const reveal = (target: Element): void => {
  for (let fold = target.parentElement?.closest("details") ?? null; fold !== null; fold = fold.parentElement?.closest("details") ?? null) fold.open = true;

  const own = target.id === "tables" ? target.querySelector(":scope > details") : null;

  if (own instanceof HTMLDetailsElement) own.open = true;
};

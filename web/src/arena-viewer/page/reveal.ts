export const reveal = (target: Element): void => {
  for (let fold = target.parentElement?.closest("details") ?? null; fold !== null; fold = fold.parentElement?.closest("details") ?? null) fold.open = true;

  const own = target.id === "tables" ? target.querySelector(":scope > details") : null;

  if (own instanceof HTMLDetailsElement) own.open = true;
};

import { reveal } from "./reveal.ts";
import { stickyHeight } from "./view.ts";

// A jump the page is still settling. Aggregate files that arrive after the jump grow the sections above the
// target and move it, so each arrival re-lands the jump until the visitor scrolls somewhere else on their own.

let pending: string | null = null;

let landedY = 0;

/** Scrolls an element to just below the sticky bar, opening the folds around it, and remembers the jump. */
export const scrollToTarget = (id: string): void => {
  const target = document.getElementById(id);

  if (target === null) return;

  reveal(target);
  scrollTo(0, target.getBoundingClientRect().top + scrollY - stickyHeight() + 1);
  pending = id;
  landedY = scrollY;
};

/** Re-lands the jump that is still settling, unless a replay or the tour owns the page. */
export const relandJump = (): void => {
  if (pending === null) return;

  if (document.querySelector(".overlay, .tour-layer") !== null) {
    pending = null;

    return;
  }

  scrollToTarget(pending);
};

/** A scroll the visitor made: it ends the jump, unless the jump itself caused it. */
export const noteOwnScroll = (): void => {
  if (pending !== null && scrollY !== landedY) pending = null;
};

// Growth with no message of its own — a font swapping in, a fold opening — moves a settling jump too.
new ResizeObserver(() => relandJump()).observe(document.body);

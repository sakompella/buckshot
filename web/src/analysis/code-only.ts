export type Language = "js" | "sql";

/** Keywords after which a `/` starts a regular expression, not a division. */
const BEFORE_REGEX = new Set(["return", "typeof", "case", "in", "of", "delete", "void", "throw", "new", "else", "do", "instanceof", "yield", "await"]);

const isWord = (char: string | undefined): boolean => char !== undefined && (/[\w$]/.test(char) || char.charCodeAt(0) > 127);

const startsRegex = (previous: string | undefined): boolean => previous === undefined || (isWord(previous[0]) ? BEFORE_REGEX.has(previous) : !")]}'\"`".includes(previous.at(-1) ?? ""));

/**
 * The source with comments removed and each run of whitespace or comments between two tokens collapsed to one space. String, template and regular expression literals stay byte-exact, so any change to code, and nothing else, changes the result.
 * A minimal lexer, not a parser: a `/` is a regular expression after an operator or keyword and a division otherwise, and every operator character is its own token. Tokens with nothing between them stay adjacent, so `a++ + b` and `a + ++b` differ.
 * "js" covers TypeScript and JavaScript; "sql" has `--` comments and no templates or regular expressions.
 */
export const codeOnly = (source: string, language: Language): string => {
  const sql = language === "sql";
  let at = 0;

  const unterminated = (what: string): Error => new Error(`Unterminated ${what} at offset ${at}`);

  const quoted = (quote: string): string => {
    const start = at++;

    while (source[at] !== quote) {
      if (at >= source.length) throw unterminated("string");
      at += source[at] === "\\" && !sql ? 2 : 1;
    }

    return source.slice(start, ++at);
  };

  const regex = (): string => {
    const start = at++;
    let inClass = false;

    while (inClass || source[at] !== "/") {
      if (at >= source.length || source[at] === "\n") throw unterminated("regular expression");

      if (source[at] === "\\") at++;
      else if (source[at] === "[") inClass = true;
      else if (source[at] === "]") inClass = false;
      at++;
    }

    return source.slice(start, ++at);
  };

  const template = (): string => {
    let text = source[at++]!;

    while (source[at] !== "`") {
      if (at >= source.length) throw unterminated("template literal");

      if (source[at] === "\\") {
        text += source.slice(at, at + 2);
        at += 2;
      } else if (source.startsWith("${", at)) {
        at += 2;
        text += `\${${tokens(true)}}`;
      } else text += source[at++];
    }

    at++;

    return `${text}\``;
  };

  /** The tokens from here to the end of the source, or in a template's `${}`, to its closing brace. */
  const tokens = (inTemplate: boolean): string => {
    const out: Array<string> = [];
    let depth = 0;
    let gap = false;

    const push = (token: string): void => {
      out.push(gap && out.length > 0 ? ` ${token}` : token);
      gap = false;
    };

    const previous = (): string | undefined => out.at(-1)?.trimStart();

    while (at < source.length) {
      const char = source[at]!;

      if (/\s/.test(char)) {
        at++;
        gap = true;
      } else if (source.startsWith(sql ? "--" : "//", at)) {
        while (at < source.length && source[at] !== "\n") at++;
        gap = true;
      } else if (source.startsWith("/*", at)) {
        const end = source.indexOf("*/", at + 2);

        if (end < 0) throw unterminated("comment");
        at = end + 2;
        gap = true;
      } else if (char === "'" || char === '"') push(quoted(char));
      else if (char === "`" && !sql) push(template());
      else if (char === "/" && !sql && startsRegex(previous())) push(regex());
      else if (isWord(char)) {
        const start = at;

        while (isWord(source[at])) at++;
        push(source.slice(start, at));
      } else {
        at++;

        if (inTemplate && char === "}" && depth === 0) return out.join("");

        if (char === "{") depth++;
        else if (char === "}") depth--;

        push(char);
      }
    }

    if (inTemplate) throw unterminated("template substitution");

    return out.join("");
  };

  return tokens(false);
};

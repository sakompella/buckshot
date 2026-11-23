import { expect, test } from "bun:test";

import { codeOnly } from "../src/analysis/code-only.ts";

const base = `// header
const greeting = "hello // not a comment"; /* gone */
const tag = \`a \${count + 1} /* kept */ b\`;
const pattern = /["'\\/]+/g;
const half = total / 2; // half
`;

test("comments and whitespace do not change the code-only text, in TypeScript and SQL", () => {
  expect(codeOnly(base.replace("// header\n", "\n\n").replace("/* gone */", "").replace(" // half", ""), "js")).toBe(codeOnly(base, "js"));
  expect(codeOnly(base.replaceAll(" = ", "\n  =\n  ").replace("\n", "\n\n\n"), "js")).toBe(codeOnly(base, "js"));

  const sql = "CREATE TABLE t (a TEXT, -- note\n b INTEGER /* more */);";

  expect(codeOnly("CREATE TABLE t (a TEXT,\n\n b INTEGER );", "sql")).toBe(codeOnly(sql, "sql"));
  expect(codeOnly("  if (a)  {\n\n    run();   // go\n  }  \n", "js")).toBe(codeOnly("if (a) { run(); }", "js"));
});

test("tokens that touch stay adjacent, so moving an operator changes the code-only text", () => {
  expect(codeOnly("a++ + b", "js")).not.toBe(codeOnly("a + ++b", "js"));
  expect(codeOnly("a - -b", "js")).not.toBe(codeOnly("a -- b", "js"));
});

test("a changed string, template, regular expression, identifier or operator changes the code-only text", () => {
  const changed = [
    base.replace("hello // not", "hello // nope"),
    base.replace("kept", "lost"),
    base.replace("count + 1", "count - 1"),
    base.replace(String.raw`["'\/]+`, String.raw`["\/]+`),
    base.replace("greeting", "salutation"),
    base.replace("total / 2", "total * 2"),
  ];

  for (const source of changed) { expect(codeOnly(source, "js")).not.toBe(codeOnly(base, "js")); }

  expect(codeOnly("SELECT 'a b'", "sql")).not.toBe(codeOnly("SELECT 'a  b'", "sql"));
});

test("string, template and regular expression literals are kept byte-exact", () => {
  expect(codeOnly(base, "js")).toBe('const greeting = "hello // not a comment"; const tag = `a ${count + 1} /* kept */ b`; const pattern = /["\'\\/]+/g; const half = total / 2;');
});

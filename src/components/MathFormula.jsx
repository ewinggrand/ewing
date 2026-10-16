import React, { useMemo } from "react";
import katex from "katex";

// Native MathML keeps fractions, integrals and indices accessible and works in
// the standalone HTML without web fonts, stylesheets or network requests.
export default function MathFormula({ children, display = true }) {
  const markup = useMemo(
    () =>
      katex.renderToString(String(children), {
        output: "mathml",
        displayMode: display,
        throwOnError: false,
        strict: "ignore",
        trust: false,
      }),
    [children, display],
  );
  const Element = display ? "div" : "span";
  return (
    <Element
      className={display ? "math-formula" : "math-formula-inline"}
      dangerouslySetInnerHTML={{ __html: markup }}
    />
  );
}

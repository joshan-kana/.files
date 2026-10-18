// Parse arithmetic directly from launcher search without JavaScript or shell evaluation.
function calculate(input) {
  if (!input || input.length > 100) return null;

  const tokens = [];
  let offset = 0;
  while (offset < input.length) {
    const match = input
      .slice(offset)
      .match(/^\s*(\d+(?:\.\d*)?|\.\d+|[()+\-*/^])/);
    if (!match) return null;
    tokens.push(match[1]);
    offset += match[0].length;
    if (tokens.length > 100) return null;
  }
  let index = 0;
  function primary() {
    const token = tokens[index++];
    if (token === "(") {
      const value = expression();
      if (tokens[index++] !== ")") throw new Error("Unclosed expression");
      return value;
    }
    if (!token || !/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(token))
      throw new Error("Expected a number");
    return Number(token);
  }
  function unary() {
    if (tokens[index] === "+" || tokens[index] === "-") {
      const sign = tokens[index++];
      const value = unary();
      return sign === "-" ? -value : value;
    }
    return power();
  }
  function power() {
    const base = primary();
    if (tokens[index] === "^") {
      index++;
      return base ** unary();
    }
    return base;
  }
  function product() {
    let value = unary();
    while (tokens[index] === "*" || tokens[index] === "/") {
      const operator = tokens[index++];
      const right = unary();
      value = operator === "*" ? value * right : value / right;
    }
    return value;
  }
  function expression() {
    let value = product();
    while (tokens[index] === "+" || tokens[index] === "-") {
      const operator = tokens[index++];
      const right = product();
      value = operator === "+" ? value + right : value - right;
    }
    return value;
  }
  try {
    const result = expression();
    if (index !== tokens.length || !Number.isFinite(result)) return null;
    return String(Number(result.toPrecision(12)));
  } catch (error) {
    return null;
  }
}

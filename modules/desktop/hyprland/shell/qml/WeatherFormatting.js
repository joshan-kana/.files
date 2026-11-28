function temperature(value, units) {
  return Math.round(units === "imperial" ? (value * 9) / 5 + 32 : value) + "°";
}

function wind(value, units) {
  return (
    Math.round(units === "imperial" ? value / 1.609344 : value) +
    (units === "imperial" ? " mph" : " km/h")
  );
}

function coordinates(value) {
  const fields = value.split(",").map((part) => part.trim());
  if (fields.length !== 2 || fields.some((field) => !field.length)) return null;
  const numbers = fields.map(Number);
  return numbers.every(Number.isFinite) &&
    Math.abs(numbers[0]) <= 90 &&
    Math.abs(numbers[1]) <= 180
    ? numbers
    : null;
}

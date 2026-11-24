function minutesLabel(minutes) {
  const value = ((Math.floor(minutes) % 1440) + 1440) % 1440;
  const hour = Math.floor(value / 60);
  return (
    (hour % 12 || 12) +
    ":" +
    String(value % 60).padStart(2, "0") +
    (hour < 12 ? " AM" : " PM")
  );
}

function wallClock(date) {
  return minutesLabel(date.getHours() * 60 + date.getMinutes());
}

function displayTime(value) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value);
  return match ? minutesLabel(Number(match[1]) * 60 + Number(match[2])) : value;
}

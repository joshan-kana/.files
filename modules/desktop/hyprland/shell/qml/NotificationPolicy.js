// One presentation decision for live notifications, independent of their sender.
function mayShowToast(locked, presentation, fullscreen, silent, critical) {
  if (locked || presentation) return false;
  if (critical) return true;
  return !fullscreen && !silent;
}

function permittedUrl(value) {
  const url = String(value || "").trim();
  if (url.length > 2048 || /[\u0000-\u001f\u007f]/.test(url)) return "";
  return /^(https?:\/\/[^\s]+|mailto:[^\s@]+@[^\s@]+)$/i.test(url) ? url : "";
}

// Qt.StyledText receives only markup produced here, never untrusted HTML.
// Neither images nor embedded resources are accepted in notification bodies.
function safeBody(value) {
  const source = String(value || "").slice(0, 16384);
  const escaped = (text) =>
    text
      .replace(
        /&(?!(?:amp|lt|gt|quot|apos|#\d{1,6}|#x[\da-f]{1,6});)/gi,
        "&amp;",
      )
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  const tokens = source.split(/(<[^>]*>)/g);
  const stack = [];
  let result = "";
  for (const token of tokens) {
    if (!token.startsWith("<")) {
      result += escaped(token);
      continue;
    }
    if (/^<br\s*\/?\s*>$/i.test(token)) {
      result += "<br>";
      continue;
    }
    const open = token.match(/^<(b|i|u)>$/i);
    const link = token.match(/^<a\s+href\s*=\s*["']([^"']+)["']\s*>$/i);
    const close = token.match(/^<\/(b|i|u|a)\s*>$/i);
    if (open || link) {
      const name = open ? open[1].toLowerCase() : "a";
      if (stack.length > 8) continue;
      const href = link ? permittedUrl(link[1].replace(/&amp;/g, "&")) : "";
      if (link && !href) continue;
      stack.push(name);
      result += link
        ? `<a href="${href.replace(/&/g, "&amp;").replace(/"/g, "&quot;")}">`
        : `<${name}>`;
    } else if (close && stack[stack.length - 1] === close[1].toLowerCase()) {
      stack.pop();
      result += `</${close[1].toLowerCase()}>`;
    }
    // Unknown tags are ignored; no Qt rich-text resource loader is involved.
  }
  while (stack.length) result += `</${stack.pop()}>`;
  return result;
}

// Freedesktop `action-icons` uses the action identifier as a theme-icon name.
// Do not interpret untrusted identifiers as file paths.
function safeActionIcon(identifier, enabled) {
  const name = String(identifier || "");
  return enabled && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(name) ? name : "";
}

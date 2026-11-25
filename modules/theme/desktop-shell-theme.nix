{
  colors,
  fonts ? {
    sans = "sans-serif";
    serif = "serif";
    mono = "monospace";
  },
  wallpaper ? "",
  themeSet ? "",
}:
{
  theme = {
    background = colors.base00;
    surface = colors.base01;
    surfaceRaised = colors.base02;
    outline = colors.base03;
    textMuted = colors.base04;
    text = colors.base05;
    textStrong = colors.base06;
    textBright = colors.base07;
    critical = colors.base08;
    warning = colors.base0A;
    positive = colors.base0B;
    accent = colors.base0D;
    accentSecondary = colors.base0E;
    accentTertiary = colors.base0C;
    accentWarm = colors.base09;
    accentWorkspace = colors.base0D;
    accentUtility = colors.base0F;
    accentEnergy = colors.base0A;
    accentNature = colors.base0B;
  };
  # Interaction roles are shared across components. Feature roles identify
  # destination glyphs and data, not the controls within those destinations.
  roles = {
    command = colors.base0D;
    choice = colors.base0E;
    adjustment = colors.base0C;
    readback = colors.base09;
    utility = colors.base0F;
    search = colors.base0A;
    toggle = colors.base0B;
    progress = colors.base0C;
    focus = colors.base0D;
    theme = colors.base0D;
    media = colors.base0E;
    workspace = colors.base0D;
    attention = colors.base08;
    display = colors.base0D;
    connectivity = colors.base0C;
    warmth = colors.base09;
    capture = colors.base09;
    screenshot = colors.base0D;
    audio = colors.base0F;
    resources = colors.base0A;
    power = colors.base0D;
    notifications = colors.base0B;
    calendar = colors.base0B;
    wallpaper = colors.base0B;
    clipboard = colors.base0F;
    weather = colors.base09;
    daylight = colors.base0A;
    night = colors.base0E;
    temperature = colors.base09;
    wind = colors.base0B;
    cold = colors.base0D;
    motion = colors.base0E;
    spectrum = colors.base0E;
    reactive = colors.base0F;
    inhibition = colors.base0A;
    schedule = colors.base0E;
    precipitation = colors.base0C;
    positive = colors.base0B;
    warning = colors.base0A;
    critical = colors.base08;
  };
  # Theme-owned presentation values are injected into
  # the shell's theme data through its semantic app scope.
  visual = {
    panelOpacity = 1.0;
    focusOpacity = 0.96;
    scrimOpacity = 0.50;
    squircleExponent = 4.5;
  };
  inherit fonts wallpaper;
  tools = { inherit themeSet; };
}

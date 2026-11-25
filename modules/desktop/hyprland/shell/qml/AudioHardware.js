// PipeWire owns the graph and WirePlumber owns profile/route persistence.
// The native device remains selectable even when its profile is Off.
function hardwareSnapshot(output) {
  let graph;
  try {
    graph = JSON.parse(output);
  } catch (_) {
    return null;
  }
  if (!Array.isArray(graph)) return null;
  const props = (object) => object?.info?.props || {};
  const integer = (value) => Number.isSafeInteger(value) && value >= 0;
  const nodes = graph.filter(
    (object) =>
      object?.type === "PipeWire:Interface:Node" &&
      ["Audio/Sink", "Audio/Source"].includes(props(object)["media.class"]) &&
      integer(object.id) &&
      integer(props(object)["card.profile.device"]) &&
      typeof props(object)["node.name"] === "string",
  );
  return graph
    .filter(
      (object) =>
        object?.type === "PipeWire:Interface:Device" &&
        props(object)["media.class"] === "Audio/Device" &&
        integer(object.id) &&
        integer(props(object)["object.serial"]) &&
        typeof props(object)["device.name"] === "string",
    )
    .map((object) => {
      const p = props(object);
      const params = object.info.params || {};
      const profiles = Array.isArray(params.EnumProfile)
        ? params.EnumProfile
        : [];
      const profile = params.Profile?.[0];
      const routes = Array.isArray(params.EnumRoute) ? params.EnumRoute : [];
      const activeRoutes = Array.isArray(params.Route) ? params.Route : [];
      const choices = profiles
        .filter(
          (entry) => integer(entry.index) && typeof entry.name === "string",
        )
        .map((entry) => ({
          key: "profile:" + entry.index,
          type: "profile",
          index: entry.index,
          target: object.id,
          serial: p["object.serial"],
          label: entry.description || entry.name,
          active: profile?.index === entry.index,
          available: entry.available !== "no",
        }));
      for (const node of nodes.filter(
        (entry) => props(entry)["device.id"] === object.id,
      )) {
        const n = props(node);
        if (!integer(n["object.serial"])) continue;
        const direction =
          n["media.class"] === "Audio/Sink" ? "Output" : "Input";
        for (const route of routes) {
          if (
            !integer(route.index) ||
            route.direction !== direction ||
            !Array.isArray(route.devices) ||
            !route.devices.includes(n["card.profile.device"]) ||
            !Array.isArray(route.profiles) ||
            !route.profiles.includes(profile?.index)
          )
            continue;
          choices.push({
            key: "route:" + n["node.name"] + ":" + route.index,
            type: "route",
            index: route.index,
            target: node.id,
            serial: n["object.serial"],
            label:
              direction +
              " · " +
              (route.description || route.name) +
              " · " +
              (n["node.description"] || n["node.name"]),
            active: activeRoutes.some(
              (active) =>
                active.index === route.index &&
                active.device === n["card.profile.device"] &&
                active.direction === direction,
            ),
            available: route.available !== "no",
          });
        }
      }
      return {
        name: p["device.name"],
        serial: p["object.serial"],
        label: p["device.description"] || p["device.name"],
        profile: profile?.description || profile?.name || "Unknown profile",
        choices,
      };
    });
}

function pendingChoice(devices, request) {
  const device = devices.find(
    (item) =>
      item.name === request.device && item.serial === request.deviceSerial,
  );
  return (
    device?.choices.find(
      (choice) =>
        choice.key === request.key && choice.serial === request.serial,
    ) || null
  );
}

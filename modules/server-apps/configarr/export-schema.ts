import { z } from "zod";
import { InputConfigSchemaSchema } from "./src/types/config.types.ts";

// Generate directly from Configarr's Zod input schema at the flake-locked revision.
const schema = z.toJSONSchema(InputConfigSchemaSchema, {
  target: "draft-2020-12",
  io: "input",
  unrepresentable: "any",
});
process.stdout.write(JSON.stringify(schema));

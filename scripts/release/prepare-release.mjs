import { prepareVersionCommit } from "./release-policy-library.mjs";

export const pluginVersion = "1.2.0";

export async function prepare(_pluginConfig, context) {
  const prepared = prepareVersionCommit(context.cwd, context.nextRelease.version);
  context.logger.log(`Prepared ${prepared.subject}`);
}
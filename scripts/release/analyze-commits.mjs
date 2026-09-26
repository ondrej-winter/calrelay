import { selectFromCommits } from "./release-policy-library.mjs";

export const pluginVersion = "1.2.0";

export async function analyzeCommits(_pluginConfig, context) {
  const currentVersion = context.lastRelease.version || null;
  const bootstrap = context.env.CALRELAY_RELEASE_BOOTSTRAP === "1";
  return selectFromCommits({ commits: context.commits, currentVersion, bootstrap }).releaseType;
}
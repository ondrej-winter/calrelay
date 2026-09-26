import { releaseNotes, selectFromCommits } from "./release-policy-library.mjs";

export const pluginVersion = "1.2.0";

export async function generateNotes(_pluginConfig, context) {
  const selection = selectFromCommits({
    commits: context.commits,
    currentVersion: context.lastRelease.version || null,
    bootstrap: context.env.CALRELAY_RELEASE_BOOTSTRAP === "1",
  });
  return releaseNotes(selection, context.nextRelease.version);
}
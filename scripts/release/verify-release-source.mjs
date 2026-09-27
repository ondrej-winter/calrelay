import { spawnSync } from "node:child_process";

export const pluginVersion = "1.0.0";

const revisionPattern = /^[0-9a-f]{40}$/;

export async function verifyRelease(_pluginConfig, context) {
  const captured = context.env.CALRELAY_RELEASE_SOURCE_REVISION;
  if (!revisionPattern.test(captured ?? "")) {
    throw new Error("CALRELAY_RELEASE_SOURCE_REVISION must be a full lowercase Git revision.");
  }
  const repositoryUrl = context.env.CALRELAY_RELEASE_SOURCE_REMOTE || context.options.repositoryUrl;
  if (typeof repositoryUrl !== "string" || repositoryUrl.length === 0) {
    throw new Error("Release source verification requires a repository URL.");
  }
  const result = spawnSync(
    "/usr/bin/git",
    ["ls-remote", "--heads", "--", repositoryUrl, "master"],
    {
      cwd: context.cwd,
      encoding: "utf8",
      env: { ...process.env, ...context.env, GIT_TERMINAL_PROMPT: "0" },
    },
  );
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`Unable to inspect remote master before release preparation: ${(result.stderr || result.stdout).trim()}`);
  }
  const observed = result.stdout.trim().split(/\s+/, 1)[0] ?? "";
  if (observed !== captured) {
    throw new Error("Captured source revision no longer matches remote master; refusing release preparation.");
  }
}
#!/usr/bin/env node
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const versionPattern = /^1\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;
const previousVersionPattern = /^(?:0\.0\.0|1\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))$/;
const revisionPattern = /^[0-9a-f]{40}$/;

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function main(arguments_) {
  const options = parseOptions(arguments_);
  const candidateDirectory = resolve(required(options, "candidate-directory"));
  const artifactsDirectory = resolve(required(options, "artifacts-directory"));
  const manifestSource = resolve(required(options, "manifest"));
  const version = required(options, "version");
  const previousVersion = required(options, "previous-version");
  const sourceRevision = required(options, "source-revision");
  if (!versionPattern.test(version)) throw new Error("Candidate version must be a canonical 1.x release.");
  if (!previousVersionPattern.test(previousVersion)) throw new Error("Previous version must be 0.0.0 or a canonical 1.x release.");
  if (!revisionPattern.test(sourceRevision)) throw new Error("Source revision must be a full lowercase Git revision.");

  const cli = join(artifactsDirectory, `calrelay-${version}-arm64.tar.gz`);
  const app = join(artifactsDirectory, `CalRelay-${version}-arm64.zip`);
  for (const path of [cli, app]) {
    if (!existsSync(path)) throw new Error(`Release artifact does not exist at ${path}.`);
  }
  const releaseCommit = git(["rev-parse", "refs/heads/master"]);
  const tag = `v${version}`;
  if (git(["rev-parse", "HEAD"]) !== releaseCommit) {
    throw new Error("The checked-out release commit must be the master branch tip.");
  }
  if (git(["rev-parse", tag]) !== releaseCommit) {
    throw new Error(`Release tag ${tag} must identify the current release commit.`);
  }
  if (readFileSync(resolve("VERSION"), "utf8") !== version) {
    throw new Error("The release commit VERSION does not match the candidate version.");
  }
  if (git(["status", "--porcelain", "--untracked-files=no"]) !== "") {
    throw new Error("Candidate staging requires a clean tracked release worktree.");
  }
  verifyReleaseCommit(releaseCommit, sourceRevision, version);

  const retainedSourceBundle = join(candidateDirectory, "source.bundle");
  const notesContents = options["notes-file"]
    ? readFileSync(resolve(options["notes-file"]), "utf8")
    : `## CalRelay v${version}\n\nPublic-beta release.\n`;
  const normalizedNotes = notesContents.endsWith("\n") ? notesContents : `${notesContents}\n`;
  const releaseNotesSource = `${candidateDirectory}.release-notes-${process.pid}.md`;
  const manifestContents = readFileSync(manifestSource, "utf8");
  const manifest = JSON.parse(manifestContents);
  verifyManifest(
    manifest,
    {
      artifacts: {
        cli: { name: basename(cli), sha256: sha256(cli) },
        app: { name: basename(app), sha256: sha256(app) },
      },
    },
    version,
  );
  let sourceBundle = retainedSourceBundle;
  let removeSourceBundle = false;
  if (existsSync(releaseNotesSource)) throw new Error(`Temporary release notes already exist at ${releaseNotesSource}.`);
  writeFileSync(releaseNotesSource, normalizedNotes, { encoding: "utf8", mode: 0o600 });
  try {
    if (!existsSync(sourceBundle)) {
      sourceBundle = `${candidateDirectory}.source-${process.pid}.bundle`;
      if (existsSync(sourceBundle)) throw new Error(`Temporary source bundle already exists at ${sourceBundle}.`);
      removeSourceBundle = true;
      git(["bundle", "create", sourceBundle, "refs/heads/master", `refs/tags/${tag}`]);
    }
    verifySourceBundle(sourceBundle, releaseCommit, tag);
    runNode("release-state.mjs", [
      "create",
      "--directory", candidateDirectory,
      "--version", version,
      "--source-revision", sourceRevision,
      "--release-commit", releaseCommit,
      "--previous-version", previousVersion,
      "--cli-artifact", cli,
      "--app-artifact", app,
      "--source-bundle", sourceBundle,
      "--manifest", manifestSource,
      "--release-notes", releaseNotesSource,
    ]);
  } finally {
    if (removeSourceBundle) rmSync(sourceBundle, { force: true });
    rmSync(releaseNotesSource, { force: true });
  }

  const state = readState(candidateDirectory);
  const manifestPath = join(candidateDirectory, "candidate-manifest.json");
  verifyManifest(manifest, state, version);
  writeOrVerify(manifestPath, manifestContents, "candidate manifest");
  runNode("generate-homebrew-packages.mjs", [
    "--manifest", manifestPath,
    "--artifacts-directory", join(candidateDirectory, "artifacts"),
    "--output-directory", join(candidateDirectory, "packages"),
  ]);

  const sums = [state.artifacts.app, state.artifacts.cli]
    .sort((left, right) => left.name.localeCompare(right.name))
    .map((artifact) => `${artifact.sha256}  ${artifact.name}`)
    .join("\n");
  writeOrVerify(join(candidateDirectory, "SHA256SUMS"), `${sums}\n`, "candidate checksums");

  process.stdout.write(`Staged immutable release candidate ${version}.\n`);
}

function readState(directory) {
  return JSON.parse(readFileSync(join(directory, "release-state.json"), "utf8"));
}

function git(arguments_) {
  const result = spawnSync("/usr/bin/git", arguments_, processOptions());
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`git ${arguments_.join(" ")} failed: ${(result.stderr || result.stdout).trim()}`);
  return result.stdout.trim();
}

function verifySourceBundle(path, releaseCommit, tag) {
  git(["bundle", "verify", path]);
  const heads = git(["bundle", "list-heads", path]).split("\n").filter(Boolean);
  const expected = [
    `${releaseCommit} refs/heads/master`,
    `${releaseCommit} refs/tags/${tag}`,
  ].sort();
  if (JSON.stringify(heads.sort()) !== JSON.stringify(expected)) {
    throw new Error("Release source bundle must contain exactly master and the matching release tag.");
  }
}

function verifyReleaseCommit(releaseCommit, sourceRevision, version) {
  const parents = git(["rev-list", "--parents", "-n", "1", releaseCommit]).split(/\s+/);
  if (parents.length !== 2 || parents[0] !== releaseCommit || parents[1] !== sourceRevision) {
    throw new Error("The release commit must be directly based on the captured source revision.");
  }
  const changedFiles = git(["diff-tree", "--no-commit-id", "--name-only", "-r", releaseCommit])
    .split("\n")
    .filter(Boolean)
    .sort();
  const expectedFiles = ["Sources/CalRelayCLI/GeneratedReleaseVersion.swift", "VERSION"];
  if (JSON.stringify(changedFiles) !== JSON.stringify(expectedFiles)) {
    throw new Error("The release commit must change only the synchronized version files.");
  }
  if (git(["log", "-1", "--format=%s", releaseCommit]) !== `chore(release): v${version}`) {
    throw new Error("The release commit subject does not match the candidate version.");
  }
  if (git(["show", `${releaseCommit}:VERSION`]) !== version) {
    throw new Error("The bundled release commit VERSION does not match the candidate version.");
  }
  const generated = `enum GeneratedReleaseVersion {\n    static let value = "${version}"\n}`;
  if (git(["show", `${releaseCommit}:Sources/CalRelayCLI/GeneratedReleaseVersion.swift`]) !== generated) {
    throw new Error("The bundled release commit generated version does not match the candidate version.");
  }
}

function verifyManifest(manifest, state, version) {
  const expectedKeys = ["app", "architecture", "cli", "minimumMacOS", "schemaVersion", "sdk", "version"];
  if (
    !manifest
    || typeof manifest !== "object"
    || Array.isArray(manifest)
    || JSON.stringify(Object.keys(manifest).sort()) !== JSON.stringify(expectedKeys)
  ) {
    throw new Error("Production candidate manifest has an unexpected schema.");
  }
  if (
    manifest.schemaVersion !== 1
    || manifest.version !== version
    || manifest.architecture !== "arm64"
    || manifest.minimumMacOS !== "26.0"
    || typeof manifest.sdk !== "string"
    || !/^27(?:\.|$)/.test(manifest.sdk)
  ) {
    throw new Error("Production candidate manifest metadata conflicts with the release candidate.");
  }
  for (const label of ["cli", "app"]) {
    const artifact = manifest[label];
    if (
      !artifact
      || typeof artifact !== "object"
      || Array.isArray(artifact)
      || JSON.stringify(Object.keys(artifact).sort()) !== JSON.stringify(["name", "sha256"])
      || artifact.name !== state.artifacts[label].name
      || artifact.sha256 !== state.artifacts[label].sha256
    ) {
      throw new Error(`Production candidate manifest ${label} artifact conflicts with immutable release state.`);
    }
  }
}

function writeOrVerify(path, contents, label) {
  if (existsSync(path)) {
    if (readFileSync(path, "utf8") !== contents) throw new Error(`Existing ${label} conflicts with immutable release state.`);
    return;
  }
  writeFileSync(path, contents, { encoding: "utf8", mode: 0o600 });
}

function sha256(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function runNode(script, arguments_) {
  const path = join(scriptDirectory, script);
  const result = spawnSync(process.execPath, [path, ...arguments_], processOptions());
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${basename(path)} failed: ${(result.stderr || result.stdout).trim()}`);
}

function processOptions() {
  return { encoding: "utf8", env: { ...process.env, GIT_TERMINAL_PROMPT: "0" } };
}

function parseOptions(arguments_) {
  const allowed = new Set([
    "candidate-directory", "artifacts-directory", "manifest", "version", "previous-version", "source-revision", "notes-file",
  ]);
  const options = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const key = arguments_[index];
    const value = arguments_[index + 1];
    if (!key?.startsWith("--") || value === undefined || value.startsWith("--")) {
      throw new Error(`Invalid option near ${key ?? "end of arguments"}.`);
    }
    const name = key.slice(2);
    if (!allowed.has(name) || options[name] !== undefined) throw new Error(`Unexpected or duplicate option --${name}.`);
    options[name] = value;
  }
  return options;
}

function required(options, name) {
  const value = options[name];
  if (!value) throw new Error(`Missing required option --${name}.`);
  return value;
}
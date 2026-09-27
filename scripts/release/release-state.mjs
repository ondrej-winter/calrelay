#!/usr/bin/env node
import { createHash } from "node:crypto";
import { constants, copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

const stateFileName = "release-state.json";
const stageOrder = ["artifacts-staged", "source-published", "assets-published", "assets-verified", "tap-published", "complete"];
const canonicalVersionPattern = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;
const revisionPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function main(arguments_) {
  const [command, ...rest] = arguments_;
  const options = parseOptions(rest);
  switch (command) {
    case "create":
      printJson(createState(options));
      return;
    case "resume":
      printJson(findIncompleteState(required(options, "states-root")));
      return;
    case "advance":
      printJson(advanceState(options));
      return;
    case "disable":
      printJson(disableState(required(options, "directory")));
      return;
    case "corrective":
      printJson(correctivePolicy(required(options, "defective-version"), required(options, "next-version")));
      return;
    default:
      throw new Error("usage: release-state.mjs <create|resume|advance|disable|corrective> [options]");
  }
}

function createState(options) {
  const directory = resolve(required(options, "directory"));
  const version = parseVersion(required(options, "version")).value;
  const sourceRevision = validateRevision(required(options, "source-revision"), "captured source revision");
  const releaseCommit = validateRevision(required(options, "release-commit"), "release commit");
  const previousKnownGoodVersion = parseVersion(required(options, "previous-version")).value;
  const cliSource = resolve(required(options, "cli-artifact"));
  const appSource = resolve(required(options, "app-artifact"));
  const sourceBundleSource = resolve(required(options, "source-bundle"));
  const manifestSource = resolve(required(options, "manifest"));
  const releaseNotesSource = resolve(required(options, "release-notes"));
  const artifacts = {
    cli: describeArtifact(cliSource),
    app: describeArtifact(appSource),
  };
  if (!existsSync(sourceBundleSource)) throw new Error(`Source bundle does not exist at ${sourceBundleSource}.`);
  const sourceBundle = { name: "source.bundle", sha256: sha256File(sourceBundleSource) };
  const manifest = describeRetainedFile(manifestSource, "candidate-manifest.json", "Candidate manifest");
  const releaseNotes = describeRetainedFile(releaseNotesSource, "release-notes.md", "Release notes");

  if (existsSync(join(directory, stateFileName))) {
    const existing = readState(directory);
    assertImmutable(existing.version, version, "release version");
    assertImmutable(existing.sourceRevision, sourceRevision, "captured source revision");
    assertImmutable(existing.releaseCommit, releaseCommit, "release commit");
    assertImmutable(existing.previousKnownGoodVersion, previousKnownGoodVersion, "previous known-good version");
    assertArtifact(existing.artifacts.cli, artifacts.cli, "CLI artifact");
    assertArtifact(existing.artifacts.app, artifacts.app, "app artifact");
    assertArtifact(existing.sourceBundle, sourceBundle, "source bundle");
    assertArtifact(existing.manifest, manifest, "candidate manifest");
    assertArtifact(existing.releaseNotes, releaseNotes, "release notes");
    verifyStagedCandidate(existing, directory);
    return existing;
  }
  if (existsSync(directory)) {
    throw new Error(`Release directory ${directory} exists without immutable release state.`);
  }

  mkdirSync(dirname(directory), { recursive: true });
  const temporary = `${directory}.staging-${process.pid}`;
  rmSync(temporary, { force: true, recursive: true });
  try {
    mkdirSync(join(temporary, "artifacts"), { recursive: true });
    copyFileSync(cliSource, join(temporary, "artifacts", artifacts.cli.name), constants.COPYFILE_EXCL);
    copyFileSync(appSource, join(temporary, "artifacts", artifacts.app.name), constants.COPYFILE_EXCL);
    copyFileSync(sourceBundleSource, join(temporary, sourceBundle.name), constants.COPYFILE_EXCL);
    copyFileSync(manifestSource, join(temporary, manifest.name), constants.COPYFILE_EXCL);
    copyFileSync(releaseNotesSource, join(temporary, releaseNotes.name), constants.COPYFILE_EXCL);
    const state = {
      schemaVersion: 3,
      version,
      tag: `v${version}`,
      sourceRevision,
      previousKnownGoodVersion,
      knownGoodVersion: previousKnownGoodVersion,
      releaseCommit,
      stage: "artifacts-staged",
      artifacts,
      sourceBundle,
      manifest,
      releaseNotes,
      source: null,
      releaseAssets: null,
      tap: null,
      securityDisposition: "trusted",
      installable: false,
    };
    writeState(temporary, state);
    renameSync(temporary, directory);
    return state;
  } catch (error) {
    rmSync(temporary, { force: true, recursive: true });
    throw error;
  }
}

function findIncompleteState(statesRoot) {
  const root = resolve(statesRoot);
  if (!existsSync(root)) {
    return { version: null, directory: null, stage: null };
  }
  const incomplete = readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && existsSync(join(root, entry.name, stateFileName)))
    .map((entry) => ({ directory: join(root, entry.name), state: readState(join(root, entry.name)) }))
    .filter(({ state }) => state.stage !== "complete" && state.securityDisposition !== "disabled");
  if (incomplete.length > 1) {
    throw new Error(`Multiple incomplete releases exist: ${incomplete.map(({ state }) => state.version).join(", ")}.`);
  }
  if (incomplete.length === 0) {
    return { version: null, directory: null, stage: null };
  }
  const [{ directory, state }] = incomplete;
  verifyStagedCandidate(state, directory);
  return { version: state.version, directory, stage: state.stage };
}

function advanceState(options) {
  const directory = resolve(required(options, "directory"));
  const target = required(options, "to");
  const targetIndex = stageOrder.indexOf(target);
  if (targetIndex < 0) {
    throw new Error(`Unknown publication stage ${target}.`);
  }
  const state = readState(directory);
  if (state.securityDisposition === "disabled") {
    throw new Error("A security-disabled release cannot advance publication.");
  }
  verifyStagedCandidate(state, directory);
  const currentIndex = stageOrder.indexOf(state.stage);
  if (currentIndex < 0) {
    throw new Error(`Unknown persisted publication stage ${state.stage}.`);
  }
  if (targetIndex > currentIndex + 1) {
    throw new Error(`Cannot skip publication stage between ${state.stage} and ${target}.`);
  }

  switch (target) {
    case "artifacts-staged":
      break;
    case "source-published":
      validateSourcePublication(state, options);
      break;
    case "assets-published":
      validateAssetPublication(state, options);
      break;
    case "assets-verified":
      validateAssetPublication(state, options);
      break;
    case "tap-published":
      validateTapPublication(state, options);
      break;
    case "complete":
      if (currentIndex < stageOrder.indexOf("tap-published")) {
        throw new Error("A release cannot complete before the atomic tap publication succeeds.");
      }
      break;
  }

  if (targetIndex > currentIndex) {
    state.stage = target;
    if (target === "complete") {
      state.knownGoodVersion = state.version;
      state.installable = true;
    }
    writeState(directory, state);
  }
  return state;
}

function validateSourcePublication(state, options) {
  const remoteMaster = validateRevision(required(options, "remote-master"), "remote master revision");
  const publicationMode = required(options, "publication-mode");
  if (!["fresh", "resume"].includes(publicationMode)) {
    throw new Error("Source publication mode must be fresh or resume.");
  }
  if (publicationMode === "fresh" && remoteMaster !== state.sourceRevision) {
    throw new Error(`Captured source revision does not match remote master; refusing source publication.`);
  }
  const releaseCommit = validateRevision(required(options, "release-commit"), "release commit");
  assertImmutable(releaseCommit, state.releaseCommit, "release commit");
  const observed = {
    version: parseVersion(required(options, "observed-version")).value,
    releaseCommit: validateRevision(required(options, "observed-release-commit"), "observed release commit"),
    tag: required(options, "observed-tag"),
    tagTarget: validateRevision(required(options, "observed-tag-target"), "observed tag target"),
  };
  assertImmutable(observed.version, state.version, "published VERSION");
  assertImmutable(observed.releaseCommit, releaseCommit, "published release commit");
  assertImmutable(observed.tag, state.tag, "published tag");
  assertImmutable(observed.tagTarget, releaseCommit, "published tag target");
  if (state.source) {
    assertJsonImmutable(state.source, observed, "source publication");
  } else {
    state.source = observed;
  }
}

function validateAssetPublication(state, options) {
  const observed = {
    cliSha256: validateDigest(required(options, "observed-cli-sha256"), "observed CLI asset digest"),
    appSha256: validateDigest(required(options, "observed-app-sha256"), "observed app asset digest"),
  };
  assertImmutable(observed.cliSha256, state.artifacts.cli.sha256, "published CLI asset");
  assertImmutable(observed.appSha256, state.artifacts.app.sha256, "published app asset");
  if (state.releaseAssets) {
    assertJsonImmutable(state.releaseAssets, observed, "release assets");
  } else {
    state.releaseAssets = observed;
  }
}

function validateTapPublication(state, options) {
  const expected = {
    formulaSha256: validateDigest(required(options, "formula-sha256"), "formula content digest"),
    caskSha256: validateDigest(required(options, "cask-sha256"), "cask content digest"),
    commit: validateRevision(required(options, "tap-commit"), "tap commit"),
  };
  const observed = {
    formulaSha256: validateDigest(required(options, "observed-formula-sha256"), "observed formula content digest"),
    caskSha256: validateDigest(required(options, "observed-cask-sha256"), "observed cask content digest"),
    commit: validateRevision(required(options, "observed-tap-commit"), "observed tap commit"),
  };
  assertJsonImmutable(observed, expected, "atomic formula and cask publication");
  if (state.tap) {
    assertJsonImmutable(state.tap, expected, "tap publication");
  } else {
    state.tap = expected;
  }
}

function disableState(directory) {
  const resolved = resolve(directory);
  const state = readState(resolved);
  state.securityDisposition = "disabled";
  state.installable = false;
  writeState(resolved, state);
  return state;
}

function correctivePolicy(defectiveValue, nextValue) {
  const defective = parseVersion(defectiveValue);
  const next = parseVersion(nextValue);
  if (next.major !== defective.major || next.minor !== defective.minor || next.patch <= defective.patch) {
    throw new Error("A tap-published defective release requires a higher patch version in the same release line.");
  }
  return {
    defectiveVersion: defective.value,
    nextVersion: next.value,
    replacementAllowed: false,
    calendarRollback: false,
  };
}

function describeArtifact(path) {
  if (!existsSync(path)) {
    throw new Error(`Artifact does not exist at ${path}.`);
  }
  return { name: basename(path), sha256: sha256File(path) };
}

function describeRetainedFile(path, name, label) {
  if (!existsSync(path)) throw new Error(`${label} does not exist at ${path}.`);
  return { name, sha256: sha256File(path) };
}

function verifyStagedCandidate(state, directory) {
  for (const [label, artifact] of Object.entries(state.artifacts)) {
    const path = join(directory, "artifacts", artifact.name);
    if (!existsSync(path) || sha256File(path) !== artifact.sha256) {
      throw new Error(`Staged ${label} artifact no longer matches immutable release state.`);
    }
  }
  validateRevision(state.releaseCommit, "retained release commit");
  if (state.sourceBundle?.name !== "source.bundle" || !digestPattern.test(state.sourceBundle.sha256 ?? "")) {
    throw new Error("Retained source bundle metadata no longer matches immutable release state.");
  }
  const sourceBundle = join(directory, state.sourceBundle.name);
  if (!existsSync(sourceBundle) || sha256File(sourceBundle) !== state.sourceBundle.sha256) {
    throw new Error("Staged source bundle no longer matches immutable release state.");
  }
  verifyRetainedFile(state.manifest, directory, "candidate-manifest.json", "candidate manifest");
  verifyRetainedFile(state.releaseNotes, directory, "release-notes.md", "release notes");
}

function verifyRetainedFile(metadata, directory, expectedName, label) {
  if (metadata?.name !== expectedName || !digestPattern.test(metadata.sha256 ?? "")) {
    throw new Error(`Retained ${label} metadata no longer matches immutable release state.`);
  }
  const path = join(directory, expectedName);
  if (!existsSync(path) || sha256File(path) !== metadata.sha256) {
    throw new Error(`Staged ${label} no longer matches immutable release state.`);
  }
}

function readState(directory) {
  const path = join(directory, stateFileName);
  if (!existsSync(path)) {
    throw new Error(`Release state is missing at ${path}.`);
  }
  const state = JSON.parse(readFileSync(path, "utf8"));
  if (state.schemaVersion !== 3) {
    throw new Error(`Unsupported release-state schema ${state.schemaVersion}.`);
  }
  return state;
}

function writeState(directory, state) {
  mkdirSync(directory, { recursive: true });
  const path = join(directory, stateFileName);
  const temporary = `${path}.tmp-${process.pid}`;
  writeFileSync(temporary, `${JSON.stringify(state, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  renameSync(temporary, path);
}

function sha256File(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function parseVersion(value) {
  const match = canonicalVersionPattern.exec(value);
  if (!match) {
    throw new Error(`Invalid release version ${JSON.stringify(value)}; expected canonical X.Y.Z.`);
  }
  return { value, major: Number(match[1]), minor: Number(match[2]), patch: Number(match[3]) };
}

function validateRevision(value, label) {
  if (!revisionPattern.test(value)) {
    throw new Error(`${label} must be a full lowercase 40-character Git revision.`);
  }
  return value;
}

function validateDigest(value, label) {
  if (!digestPattern.test(value)) {
    throw new Error(`${label} must be a lowercase SHA-256 digest.`);
  }
  return value;
}

function assertArtifact(actual, expected, label) {
  assertImmutable(actual.name, expected.name, `${label} name`);
  assertImmutable(actual.sha256, expected.sha256, `${label} digest`);
}

function assertJsonImmutable(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Observed ${label} conflicts with immutable release state.`);
  }
}

function assertImmutable(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`Observed ${label} conflicts with immutable release state.`);
  }
}

function parseOptions(arguments_) {
  const options = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const key = arguments_[index];
    const value = arguments_[index + 1];
    if (!key?.startsWith("--") || value === undefined || value.startsWith("--")) {
      throw new Error(`Invalid option near ${key ?? "end of arguments"}.`);
    }
    options[key.slice(2)] = value;
  }
  return options;
}

function required(options, name) {
  const value = options[name];
  if (!value) {
    throw new Error(`Missing required option --${name}.`);
  }
  return value;
}

function printJson(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

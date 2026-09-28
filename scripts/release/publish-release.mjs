#!/usr/bin/env node
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  appendFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const stageOrder = ["artifacts-staged", "source-published", "assets-published", "assets-verified", "tap-published", "complete"];
let askpassPath = null;

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
} finally {
  if (askpassPath) rmSync(askpassPath, { force: true });
}

function main(arguments_) {
  const [command, ...rest] = arguments_;
  if (!["assets", "tap"].includes(command)) throw new Error("usage: publish-release.mjs <assets|tap> [options]");
  const options = parseOptions(rest);
  const candidateDirectory = resolve(required(options, "candidate-directory"));
  const sourceRepository = required(options, "source-repository");
  const tapRepository = required(options, "tap-repository");
  const sourceRemote = required(options, "source-remote");
  const tapRemote = required(options, "tap-remote");
  const workDirectory = resolve(required(options, "work-directory"));
  const gh = resolve(required(options, "gh"));
  validateRepositoryName(sourceRepository, "source repository");
  validateRepositoryName(tapRepository, "tap repository");
  let state = readState(candidateDirectory);
  verifyCandidate(candidateDirectory, state);
  setupAskpass(workDirectory);
  if (command === "assets") {
    publishSource(state, candidateDirectory, sourceRemote, workDirectory);
    state = readState(candidateDirectory);
    publishAndVerifyAssets(state, candidateDirectory, sourceRepository, workDirectory, gh);
    return;
  }
  publishTap(state, candidateDirectory, tapRepository, tapRemote, workDirectory);
}

function publishAndVerifyAssets(state, candidateDirectory, repository, workDirectory, gh) {
  const expectedNames = [state.artifacts.app.name, "SHA256SUMS", state.artifacts.cli.name].sort();
  let release = releaseView(gh, repository, state.tag);
  if (!release) {
    if (stageIndex(state.stage) > stageIndex("source-published")) {
      throw new Error("Release assets are missing after publication state advanced.");
    }
    run(gh, [
      "release", "create", state.tag,
      join(candidateDirectory, "artifacts", state.artifacts.cli.name),
      join(candidateDirectory, "artifacts", state.artifacts.app.name),
      join(candidateDirectory, "SHA256SUMS"),
      "--repo", repository,
      "--verify-tag",
      "--title", `CalRelay ${state.tag}`,
      "--notes-file", join(candidateDirectory, "release-notes.md"),
      "--latest=false",
    ]);
    log("release-created");
    release = releaseView(gh, repository, state.tag);
  }
  verifyReleaseMetadata(release, state.tag, expectedNames);
  if (stageIndex(state.stage) < stageIndex("assets-published")) {
    advance(candidateDirectory, "assets-published", state.artifacts.cli.sha256, state.artifacts.app.sha256);
    log("assets-published");
    state = readState(candidateDirectory);
  }

  const downloadDirectory = join(workDirectory, "release-download");
  rmSync(downloadDirectory, { force: true, recursive: true });
  mkdirSync(downloadDirectory, { recursive: true });
  run(gh, ["release", "download", state.tag, "--repo", repository, "--dir", downloadDirectory]);
  verifyFileDigest(join(downloadDirectory, state.artifacts.cli.name), state.artifacts.cli.sha256, "downloaded CLI SHA-256");
  verifyFileDigest(join(downloadDirectory, state.artifacts.app.name), state.artifacts.app.sha256, "downloaded app SHA-256");
  const expectedSums = readFileSync(join(candidateDirectory, "SHA256SUMS"), "utf8");
  const observedSums = readFileSync(join(downloadDirectory, "SHA256SUMS"), "utf8");
  if (observedSums !== expectedSums) throw new Error("Downloaded SHA256SUMS conflicts with immutable candidate state.");
  if (stageIndex(state.stage) < stageIndex("assets-verified")) {
    advance(candidateDirectory, "assets-verified", state.artifacts.cli.sha256, state.artifacts.app.sha256);
    log("assets-verified");
  }
}

function publishSource(state, candidateDirectory, remote, workDirectory) {
  const bundle = join(candidateDirectory, "source.bundle");
  if (!existsSync(bundle)) throw new Error("Immutable release candidate is missing source.bundle.");
  const heads = bundleHeads(bundle);
  const releaseCommit = heads.get("refs/heads/master");
  const tagCommit = heads.get(`refs/tags/${state.tag}`);
  if (
    !releaseCommit
    || releaseCommit !== state.releaseCommit
    || tagCommit !== releaseCommit
    || heads.size !== 2
  ) {
    throw new Error("Release source bundle must contain exactly master and the matching release tag.");
  }
  const remoteMaster = lsRemote(remote, "refs/heads/master");
  const remoteTag = lsRemote(remote, `refs/tags/${state.tag}`);
  let alreadyPublished = remoteTag === releaseCommit
    && remoteMaster !== ""
    && remoteMasterContains(remote, remoteMaster, releaseCommit, workDirectory);
  const publicationMode = alreadyPublished ? "resume" : "fresh";
  if (!alreadyPublished) {
    assertNoNewerReleaseTag(remote, state.version);
    if (remoteMaster !== state.sourceRevision || remoteTag !== "") {
      throw new Error("Remote master or release tag changed before source publication.");
    }
    const checkout = join(workDirectory, "source");
    rmSync(checkout, { force: true, recursive: true });
    mkdirSync(workDirectory, { recursive: true });
    run("/usr/bin/git", ["clone", "--branch", "master", "--single-branch", "--", bundle, checkout]);
    git(checkout, ["fetch", "--", bundle, `refs/tags/${state.tag}:refs/tags/${state.tag}`]);
    git(checkout, [
      "push", "--atomic", "--", remote,
      `${releaseCommit}:refs/heads/master`,
      `refs/tags/${state.tag}:refs/tags/${state.tag}`,
    ]);
    const publishedMaster = lsRemote(remote, "refs/heads/master");
    const publishedTag = lsRemote(remote, `refs/tags/${state.tag}`);
    alreadyPublished = publishedTag === releaseCommit
      && publishedMaster !== ""
      && remoteMasterContains(remote, publishedMaster, releaseCommit, workDirectory);
  }
  if (!alreadyPublished) {
    throw new Error("Published source branch and release tag do not match the immutable source bundle.");
  }
  if (stageIndex(state.stage) < stageIndex("source-published")) {
    runNode("release-state.mjs", [
      "advance", "--directory", candidateDirectory, "--to", "source-published",
      "--remote-master", remoteMaster,
      "--publication-mode", publicationMode,
      "--release-commit", releaseCommit,
      "--observed-version", state.version,
      "--observed-release-commit", releaseCommit,
      "--observed-tag", state.tag,
      "--observed-tag-target", releaseCommit,
    ]);
    log("source-published");
  }
}

function verifyCandidate(directory, state) {
  if (!state || state.schemaVersion !== 3) {
    throw new Error("Candidate release state has an unsupported schema.");
  }
  verifyRetainedCandidateFile(directory, state.manifest, "candidate-manifest.json", "manifest");
  verifyRetainedCandidateFile(directory, state.releaseNotes, "release-notes.md", "release notes");
  const manifest = JSON.parse(readFileSync(join(directory, "candidate-manifest.json"), "utf8"));
  for (const label of ["cli", "app"]) {
    if (
      manifest[label]?.name !== state.artifacts[label].name
      || manifest[label]?.sha256 !== state.artifacts[label].sha256
    ) {
      throw new Error(`Candidate manifest ${label} artifact conflicts with immutable release state.`);
    }
  }
  runNode("generate-homebrew-packages.mjs", [
    "--manifest", join(directory, "candidate-manifest.json"),
    "--artifacts-directory", join(directory, "artifacts"),
    "--output-directory", join(directory, "packages"),
  ]);
  const expectedSums = [state.artifacts.app, state.artifacts.cli]
    .sort((left, right) => left.name.localeCompare(right.name))
    .map((artifact) => `${artifact.sha256}  ${artifact.name}`)
    .join("\n") + "\n";
  if (readFileSync(join(directory, "SHA256SUMS"), "utf8") !== expectedSums) {
    throw new Error("Candidate SHA256SUMS conflicts with immutable release state.");
  }
  const bundle = join(directory, "source.bundle");
  if (
    state.sourceBundle?.name !== "source.bundle"
    || !/^[0-9a-f]{64}$/.test(state.sourceBundle.sha256 ?? "")
    || sha256(bundle) !== state.sourceBundle.sha256
  ) {
    throw new Error("Candidate source bundle conflicts with immutable release state.");
  }
  run("/usr/bin/git", ["bundle", "verify", bundle]);
  const heads = bundleHeads(bundle);
  if (
    heads.size !== 2
    || heads.get("refs/heads/master") !== state.releaseCommit
    || heads.get(`refs/tags/${state.tag}`) !== state.releaseCommit
  ) {
    throw new Error("Candidate source bundle refs conflict with immutable release state.");
  }
}

function verifyRetainedCandidateFile(directory, metadata, expectedName, label) {
  const path = join(directory, expectedName);
  if (
    metadata?.name !== expectedName
    || !/^[0-9a-f]{64}$/.test(metadata.sha256 ?? "")
    || !existsSync(path)
    || sha256(path) !== metadata.sha256
  ) {
    throw new Error(`Candidate ${label} conflicts with immutable release state.`);
  }
}

function publishTap(state, candidateDirectory, repository, remote, workDirectory) {
  state = readState(candidateDirectory);
  if (stageIndex(state.stage) < stageIndex("assets-verified")) {
    throw new Error("The tap cannot publish before release assets are verified.");
  }
  const checkout = join(workDirectory, "tap");
  rmSync(checkout, { force: true, recursive: true });
  mkdirSync(workDirectory, { recursive: true });
  run("/usr/bin/git", ["clone", "--branch", "master", "--single-branch", "--", remote, checkout]);
  git(checkout, ["config", "user.name", "calrelay-release[bot]"]);
  git(checkout, ["config", "user.email", "calrelay-release@example.invalid"]);

  const packageDirectory = join(candidateDirectory, "packages");
  verifyTapPredecessor(checkout, packageDirectory, state);
  for (const relativePath of ["Formula/calrelay.rb", "Casks/calrelay.rb"]) {
    const target = join(checkout, relativePath);
    mkdirSync(dirname(target), { recursive: true });
    cpSync(join(packageDirectory, relativePath), target);
  }
  const formulaDigest = sha256(join(checkout, "Formula/calrelay.rb"));
  const caskDigest = sha256(join(checkout, "Casks/calrelay.rb"));
  let tapTip;
  const changed = git(checkout, ["status", "--porcelain", "--", "Formula/calrelay.rb", "Casks/calrelay.rb"]);
  if (changed) {
    if (state.tap) throw new Error("Published tap content conflicts with immutable release state.");
    git(checkout, ["add", "--", "Formula/calrelay.rb", "Casks/calrelay.rb"]);
    git(checkout, ["commit", "-m", `chore: publish CalRelay ${state.tag}`]);
    tapTip = git(checkout, ["rev-parse", "HEAD"]);
    git(checkout, ["push", "origin", "HEAD:master"]);
  } else {
    tapTip = git(checkout, ["rev-parse", "HEAD"]);
  }
  const formulaCommit = git(checkout, ["log", "-1", "--format=%H", "--", "Formula/calrelay.rb"]);
  const caskCommit = git(checkout, ["log", "-1", "--format=%H", "--", "Casks/calrelay.rb"]);
  if (!formulaCommit || formulaCommit !== caskCommit) {
    throw new Error("Formula and cask must be published together by one tap commit.");
  }
  const packageCommit = formulaCommit;
  const remoteCommit = lsRemote(remote, "refs/heads/master");
  if (remoteCommit !== tapTip) throw new Error("Observed tap tip does not match the published branch.");
  if (state.tap) {
    if (
      state.tap.commit !== packageCommit
      || state.tap.formulaSha256 !== formulaDigest
      || state.tap.caskSha256 !== caskDigest
    ) {
      throw new Error("Observed tap state conflicts with immutable release state.");
    }
    const ancestry = spawnSync(
      "/usr/bin/git",
      ["-C", checkout, "merge-base", "--is-ancestor", packageCommit, tapTip],
      processOptions(),
    );
    if (ancestry.error) throw ancestry.error;
    if (ancestry.status !== 0) {
      throw new Error("Recorded tap publication is not an ancestor of the current protected branch.");
    }
  } else {
    runNode("release-state.mjs", [
      "advance", "--directory", candidateDirectory, "--to", "tap-published",
      "--formula-sha256", formulaDigest, "--cask-sha256", caskDigest, "--tap-commit", packageCommit,
      "--observed-formula-sha256", formulaDigest, "--observed-cask-sha256", caskDigest,
      "--observed-tap-commit", packageCommit,
    ]);
    log("tap-published");
    state = readState(candidateDirectory);
  }
  if (stageIndex(state.stage) < stageIndex("complete")) {
    runNode("release-state.mjs", ["advance", "--directory", candidateDirectory, "--to", "complete"]);
    log("complete");
  }
  process.stdout.write(`Published atomic Homebrew packages for ${state.version}.\n`);
}

function releaseView(gh, repository, tag) {
  const result = spawnSync(
    gh,
    ["release", "view", tag, "--repo", repository, "--json", "tagName,isDraft,isImmutable,assets"],
    processOptions(),
  );
  if (result.error) throw result.error;
  if (result.status !== 0) return null;
  return JSON.parse(result.stdout);
}

function verifyReleaseMetadata(release, tag, expectedNames) {
  if (!release || release.tagName !== tag || release.isDraft || release.isImmutable !== true) {
    throw new Error("GitHub release metadata does not match the immutable publication contract.");
  }
  const names = (release.assets ?? []).map(({ name }) => name).sort();
  if (JSON.stringify(names) !== JSON.stringify(expectedNames)) {
    throw new Error("GitHub release assets are incomplete or contain unexpected files.");
  }
}

function advance(directory, stage, cliDigest, appDigest) {
  runNode("release-state.mjs", [
    "advance", "--directory", directory, "--to", stage,
    "--observed-cli-sha256", cliDigest, "--observed-app-sha256", appDigest,
  ]);
}

function verifyFileDigest(path, expected, label) {
  if (!existsSync(path) || sha256(path) !== expected) throw new Error(`${label} does not match immutable release state.`);
}

function setupAskpass(workDirectory) {
  if (!process.env.CALRELAY_GIT_TOKEN) return;
  mkdirSync(dirname(workDirectory), { recursive: true });
  askpassPath = `${workDirectory}.askpass-${process.pid}`;
  writeFileSync(
    askpassPath,
    "#!/bin/sh\ncase \"$1\" in *Username*) printf '%s\\n' x-access-token ;; *) printf '%s\\n' \"$CALRELAY_GIT_TOKEN\" ;; esac\n",
    { encoding: "utf8", mode: 0o700 },
  );
}

function processOptions() {
  return {
    encoding: "utf8",
    env: {
      ...process.env,
      GIT_ASKPASS: askpassPath ?? process.env.GIT_ASKPASS,
      GIT_TERMINAL_PROMPT: "0",
    },
  };
}

function run(executable, arguments_) {
  const result = spawnSync(executable, arguments_, processOptions());
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const details = (result.stderr || result.stdout).trim();
    throw new Error(`${executable} ${arguments_.join(" ")} failed${details ? `: ${details}` : ""}.`);
  }
  return result.stdout.trim();
}

function git(repository, arguments_) {
  return run("/usr/bin/git", ["-C", repository, ...arguments_]);
}

function lsRemote(remote, ref) {
  const output = run("/usr/bin/git", ["ls-remote", "--", remote, ref]);
  return output.split(/\s+/, 1)[0] ?? "";
}

function assertNoNewerReleaseTag(remote, version) {
  const current = parseReleaseVersion(version);
  const output = run("/usr/bin/git", ["ls-remote", "--tags", "--refs", "--", remote, "refs/tags/v*"]);
  for (const line of output.split("\n").filter(Boolean)) {
    const [, ref] = line.split(/\s+/, 2);
    const match = /^refs\/tags\/v(1\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))$/.exec(ref ?? "");
    if (match && compareReleaseVersions(parseReleaseVersion(match[1]), current) > 0) {
      throw new Error(`A newer release tag ${match[1]} already exists; refusing older candidate resumption.`);
    }
  }
}

function verifyTapPredecessor(checkout, packageDirectory, state) {
  const paths = ["Formula/calrelay.rb", "Casks/calrelay.rb"];
  const existing = paths.map((relativePath) => join(checkout, relativePath));
  const present = existing.map((path) => existsSync(path));
  if (present[0] !== present[1]) {
    throw new Error("The tap must contain both CalRelay packages or neither before publication.");
  }
  if (!present[0]) {
    if (state.previousKnownGoodVersion !== "0.0.0") {
      throw new Error("The tap is missing the previous known-good CalRelay packages.");
    }
    return;
  }

  const versions = existing.map(readHomebrewVersion);
  if (versions[0] !== versions[1]) {
    throw new Error("The tap formula and cask versions diverge before publication.");
  }
  const observedVersion = versions[0];
  if (observedVersion === state.version) {
    const expected = paths.map((relativePath) => sha256(join(packageDirectory, relativePath)));
    const observed = existing.map(sha256);
    if (JSON.stringify(observed) !== JSON.stringify(expected)) {
      throw new Error("Existing same-version tap content conflicts with the immutable release candidate.");
    }
    return;
  }
  if (observedVersion !== state.previousKnownGoodVersion) {
    throw new Error(
      `Tap version ${observedVersion} does not match previous known-good version ${state.previousKnownGoodVersion}.`,
    );
  }
}

function readHomebrewVersion(path) {
  const matches = [...readFileSync(path, "utf8").matchAll(/^\s*version\s+"([^"]+)"\s*$/gm)];
  if (matches.length !== 1 || !/^1\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)$/.test(matches[0][1])) {
    throw new Error(`Unable to read one canonical CalRelay version from ${path}.`);
  }
  return matches[0][1];
}

function parseReleaseVersion(value) {
  const match = /^1\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/.exec(value);
  if (!match) throw new Error(`Invalid 1.x release version ${value}.`);
  return { minor: Number(match[1]), patch: Number(match[2]) };
}

function compareReleaseVersions(left, right) {
  return left.minor === right.minor ? left.patch - right.patch : left.minor - right.minor;
}

function remoteMasterContains(remote, remoteMaster, releaseCommit, workDirectory) {
  if (remoteMaster === releaseCommit) return true;
  const checkout = join(workDirectory, "source-observation");
  rmSync(checkout, { force: true, recursive: true });
  mkdirSync(workDirectory, { recursive: true });
  run("/usr/bin/git", ["clone", "--branch", "master", "--single-branch", "--", remote, checkout]);
  if (git(checkout, ["rev-parse", "HEAD"]) !== remoteMaster) {
    throw new Error("Remote master changed while verifying published release ancestry.");
  }
  const result = spawnSync(
    "/usr/bin/git",
    ["-C", checkout, "merge-base", "--is-ancestor", releaseCommit, remoteMaster],
    processOptions(),
  );
  if (result.error) throw result.error;
  if (result.status === 0) return true;
  if (result.status === 1) return false;
  throw new Error(`Unable to verify published release ancestry: ${(result.stderr || result.stdout).trim()}`);
}

function bundleHeads(bundle) {
  const heads = new Map();
  const output = run("/usr/bin/git", ["bundle", "list-heads", bundle]);
  for (const line of output.split("\n").filter(Boolean)) {
    const [revision, ref] = line.split(/\s+/, 2);
    heads.set(ref, revision);
  }
  return heads;
}

function runNode(script, arguments_) {
  return run(process.execPath, [join(scriptDirectory, script), ...arguments_]);
}

function readState(directory) {
  return JSON.parse(readFileSync(join(directory, "release-state.json"), "utf8"));
}

function sha256(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function stageIndex(stage) {
  const index = stageOrder.indexOf(stage);
  if (index < 0) throw new Error(`Unknown release stage ${stage}.`);
  return index;
}

function log(value) {
  const path = process.env.CALRELAY_RELEASE_OPERATION_LOG;
  if (path) appendFileSync(path, `${value}\n`, "utf8");
}

function parseOptions(arguments_) {
  const allowed = new Set([
    "candidate-directory", "source-repository", "tap-repository", "source-remote", "tap-remote", "work-directory", "gh",
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

function validateRepositoryName(value, label) {
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(value)) {
    throw new Error(`${label} must be an owner/repository name.`);
  }
}
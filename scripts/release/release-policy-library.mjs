import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const canonicalVersionPattern = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;
const releaseSubjectPattern = /^chore\(release\): v\d+\.\d+\.\d+$/;
const automatedReleaseMajor = 1;

export function parseVersion(value) {
  const match = canonicalVersionPattern.exec(value);
  if (!match) {
    throw new Error(`Invalid release version ${JSON.stringify(value)}; expected canonical X.Y.Z.`);
  }
  return { major: Number(match[1]), minor: Number(match[2]), patch: Number(match[3]), value };
}

export function selectFromCommits({ commits, currentVersion, bootstrap = false }) {
  if (!currentVersion) {
    if (!bootstrap) {
      return { releaseType: null, nextVersion: null, breakingWarning: false };
    }
    return { releaseType: "major", nextVersion: "1.0.0", breakingWarning: false };
  }

  if (bootstrap) {
    throw new Error("Bootstrap is allowed only before the first public release.");
  }

  const version = parseVersion(currentVersion);
  assertAutomatedReleaseVersion(version, "Automatic release selection");

  let releaseType = null;
  let breakingWarning = false;
  for (const commit of commits) {
    const subject = commit.subject ?? firstLine(commit.message ?? "");
    const body = commit.body ?? bodyFromMessage(commit.message ?? "");
    if (releaseSubjectPattern.test(subject)) {
      continue;
    }

    breakingWarning ||=
      /^[a-z]+(?:\([^\n)]+\))?!:\s+.+$/i.test(subject)
      || /(^|\n)BREAKING(?: |-)CHANGE:\s*\S/im.test(body);

    const parsed = /^(fix|feat)(?:\([^\n)]+\))?(!)?:\s+.+$/.exec(subject);
    if (!parsed) {
      continue;
    }

    if (parsed[1] === "feat") {
      releaseType = "minor";
    } else if (releaseType !== "minor") {
      releaseType = "patch";
    }
  }

  if (!releaseType) {
    return { releaseType: null, nextVersion: null, breakingWarning: false };
  }

  const nextVersion =
    releaseType === "minor"
      ? `${version.major}.${version.minor + 1}.0`
      : `${version.major}.${version.minor}.${version.patch + 1}`;
  assertAutomatedReleaseVersion(parseVersion(nextVersion), "Automatic release selection");
  return { releaseType, nextVersion, breakingWarning };
}

export function selectFromRepository(repository, { bootstrap = false } = {}) {
  const releaseTags = git(repository, ["tag", "--list", "v*"]).stdout
    .split("\n")
    .filter(Boolean)
    .map((tag) => ({ tag, version: parseTaggedVersion(tag) }))
    .filter(({ version }) => version !== null)
    .sort((left, right) => compareVersions(right.version, left.version));

  const latest = releaseTags[0] ?? null;
  if (bootstrap && latest) {
    throw new Error("Bootstrap is allowed only before the first public release.");
  }
  if (!latest) {
    return selectFromCommits({ commits: [], currentVersion: null, bootstrap });
  }

  const commits = readCommits(repository, `${latest.tag}..HEAD`);
  return selectFromCommits({ commits, currentVersion: latest.version.value });
}

export function releaseNotes(selection, version = selection.nextVersion) {
  if (!selection.releaseType || !version) {
    throw new Error("Release notes require a selected release.");
  }
  const summary =
    selection.releaseType === "major"
      ? "This initial public-beta release establishes the supported distribution channel."
      : `This ${selection.releaseType} public-beta release contains aggregate product and reliability improvements.`;
  const lines = [
    `## CalRelay v${version}`,
    "",
    summary,
  ];
  if (selection.breakingWarning) {
    lines.push("", "### Compatibility warning", "", "Review the public-beta upgrade guidance before installing this version.");
  }
  return `${lines.join("\n")}\n`;
}

export function prepareVersionCommit(repository, version) {
  const parsed = parseVersion(version);
  assertAutomatedReleaseVersion(parsed, "Release preparation");
  ensureClean(repository);

  writeFileSync(resolve(repository, "VERSION"), version, "utf8");
  writeFileSync(
    resolve(repository, "Sources/CalRelayCLI/GeneratedReleaseVersion.swift"),
    `enum GeneratedReleaseVersion {\n    static let value = "${version}"\n}\n`,
    "utf8",
  );
  git(repository, ["add", "--", "VERSION", "Sources/CalRelayCLI/GeneratedReleaseVersion.swift"]);

  const changedFiles = git(repository, ["diff", "--cached", "--name-only"]).stdout.split("\n").filter(Boolean).sort();
  const expectedFiles = ["Sources/CalRelayCLI/GeneratedReleaseVersion.swift", "VERSION"];
  if (JSON.stringify(changedFiles) !== JSON.stringify(expectedFiles)) {
    throw new Error(`Release preparation staged unexpected files: ${changedFiles.join(", ")}`);
  }

  const subject = `chore(release): v${version}`;
  git(repository, ["commit", "--no-verify", "-m", subject]);
  return { subject, gitHead: git(repository, ["rev-parse", "HEAD"]).stdout.trim() };
}

export function prepareRepositoryRelease(repository, { bootstrap = false, createTag = true } = {}) {
  const selection = selectFromRepository(repository, { bootstrap });
  if (!selection.nextVersion) {
    throw new Error("No release is selected for the current history.");
  }
  const tag = `v${selection.nextVersion}`;
  if (git(repository, ["tag", "--list", tag]).stdout.trim()) {
    throw new Error(`Release tag ${tag} already exists.`);
  }

  const commit = prepareVersionCommit(repository, selection.nextVersion);
  if (createTag) {
    git(repository, ["tag", tag, commit.gitHead]);
  }
  return { ...selection, ...commit, tag: createTag ? tag : null };
}

export function readRootVersion(repository) {
  const value = readFileSync(resolve(repository, "VERSION"), "utf8");
  return parseVersion(value).value;
}

function assertAutomatedReleaseVersion(version, operation) {
  if (version.major !== automatedReleaseMajor) {
    throw new Error(`${operation} accepts only public-beta 1.x versions; releasing 2.0.0 requires an explicit product decision.`);
  }
}

function readCommits(repository, range) {
  const recordSeparator = "\u001e";
  const fieldSeparator = "\u001f";
  const output = git(repository, ["log", `--format=${recordSeparator}%H${fieldSeparator}%s${fieldSeparator}%b`, range]).stdout;
  return output
    .split(recordSeparator)
    .filter(Boolean)
    .map((record) => {
      const [hash = "", subject = "", body = ""] = record.replace(/^\n/, "").split(fieldSeparator);
      return { hash: hash.trim(), subject, body: body.trimEnd() };
    });
}

function ensureClean(repository) {
  const status = git(repository, ["status", "--porcelain", "--untracked-files=all"]).stdout;
  if (status !== "") {
    throw new Error("Release preparation requires a clean repository.");
  }
}

function parseTaggedVersion(tag) {
  if (!tag.startsWith("v")) {
    return null;
  }
  try {
    return parseVersion(tag.slice(1));
  } catch {
    return null;
  }
}

function compareVersions(left, right) {
  return left.major - right.major || left.minor - right.minor || left.patch - right.patch;
}

function firstLine(message) {
  return message.split("\n", 1)[0];
}

function bodyFromMessage(message) {
  return message.split("\n").slice(1).join("\n");
}

function git(repository, arguments_) {
  const result = spawnSync("/usr/bin/git", ["-C", repository, ...arguments_], {
    encoding: "utf8",
    env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
  });
  if (result.error) {
    throw result.error;
  }
  if (result.status !== 0) {
    const details = (result.stderr || result.stdout).trim();
    throw new Error(`git ${arguments_.join(" ")} failed${details ? `: ${details}` : ""}`);
  }
  return result;
}
#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const versionPattern = /^1\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;

try {
  const options = parseOptions(process.argv.slice(2));
  const sourceVersion = required(options, "source-version");
  const tapDirectory = resolve(required(options, "tap-directory"));
  const source = parseVersion(sourceVersion, "source release version");
  const paths = ["Formula/calrelay.rb", "Casks/calrelay.rb"].map((path) => join(tapDirectory, path));
  const present = paths.map(existsSync);
  if (present[0] !== present[1]) {
    throw new Error("The public tap must contain both CalRelay packages or neither.");
  }
  if (!present[0]) {
    process.stdout.write(`${JSON.stringify({ caughtUp: false, sourceVersion, tapVersion: null })}\n`);
  } else {
    const versions = paths.map(readHomebrewVersion);
    if (versions[0] !== versions[1]) {
      throw new Error("The public tap formula and cask versions diverge.");
    }
    const tapVersion = versions[0];
    const comparison = compareVersions(parseVersion(tapVersion, "public tap version"), source);
    if (comparison > 0) {
      throw new Error(`The public tap version ${tapVersion} is newer than source release ${sourceVersion}.`);
    }
    process.stdout.write(`${JSON.stringify({ caughtUp: comparison === 0, sourceVersion, tapVersion })}\n`);
  }
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function readHomebrewVersion(path) {
  const matches = [...readFileSync(path, "utf8").matchAll(/^\s*version\s+"([^"]+)"\s*$/gm)];
  if (matches.length !== 1) {
    throw new Error(`Unable to read one canonical CalRelay version from ${path}.`);
  }
  parseVersion(matches[0][1], `CalRelay version in ${path}`);
  return matches[0][1];
}

function parseVersion(value, label) {
  const match = versionPattern.exec(value);
  if (!match) throw new Error(`${label} must be a canonical 1.x release.`);
  return { minor: Number(match[1]), patch: Number(match[2]) };
}

function compareVersions(left, right) {
  return left.minor === right.minor ? left.patch - right.patch : left.minor - right.minor;
}

function parseOptions(arguments_) {
  const allowed = new Set(["source-version", "tap-directory"]);
  const options = {};
  for (let index = 0; index < arguments_.length; index += 2) {
    const key = arguments_[index];
    const value = arguments_[index + 1];
    if (!key?.startsWith("--") || value === undefined || value.startsWith("--")) {
      throw new Error(`Invalid option near ${key ?? "end of arguments"}.`);
    }
    const name = key.slice(2);
    if (!allowed.has(name) || options[name] !== undefined) {
      throw new Error(`Unexpected or duplicate option --${name}.`);
    }
    options[name] = value;
  }
  return options;
}

function required(options, name) {
  const value = options[name];
  if (!value) throw new Error(`Missing required option --${name}.`);
  return value;
}
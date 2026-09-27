#!/usr/bin/env node
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

const canonicalVersionPattern = /^1\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$/;
const digestPattern = /^[0-9a-f]{64}$/;
const packageFiles = {
  formula: join("Formula", "calrelay.rb"),
  cask: join("Casks", "calrelay.rb"),
};

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function main(arguments_) {
  const options = parseOptions(arguments_);
  const manifestPath = resolve(required(options, "manifest"));
  const artifactsDirectory = resolve(required(options, "artifacts-directory"));
  const outputDirectory = resolve(required(options, "output-directory"));
  const manifest = validateManifest(JSON.parse(readFileSync(manifestPath, "utf8")));

  verifyArtifact(artifactsDirectory, manifest.cli);
  verifyArtifact(artifactsDirectory, manifest.app);

  const expected = renderPackages(manifest);
  if (existsSync(outputDirectory)) {
    verifyExistingOutput(outputDirectory, expected);
    process.stdout.write(`Verified existing Homebrew packages for ${manifest.version}.\n`);
    return;
  }

  writeAtomically(outputDirectory, expected);
  process.stdout.write(`Generated Homebrew packages for ${manifest.version}.\n`);
}

function validateManifest(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Candidate manifest must be a JSON object.");
  }
  assertExactKeys(
    value,
    ["app", "architecture", "cli", "minimumMacOS", "schemaVersion", "sdk", "version"],
    "Candidate manifest",
  );
  if (value.schemaVersion !== 1) {
    throw new Error(`Unsupported candidate-manifest schema ${value.schemaVersion}.`);
  }
  if (typeof value.version !== "string" || !canonicalVersionPattern.test(value.version)) {
    throw new Error("Candidate manifest version must be a canonical 1.x X.Y.Z release.");
  }
  if (value.architecture !== "arm64") {
    throw new Error("Candidate manifest architecture must be arm64.");
  }
  if (value.minimumMacOS !== "26.0") {
    throw new Error("Candidate manifest minimumMacOS must be 26.0.");
  }
  if (typeof value.sdk !== "string" || !/^27(?:\.|$)/.test(value.sdk)) {
    throw new Error("Candidate manifest SDK must be macOS 27.");
  }

  const expectedCLIName = `calrelay-${value.version}-arm64.tar.gz`;
  const expectedAppName = `CalRelay-${value.version}-arm64.zip`;
  return {
    version: value.version,
    cli: validateArtifact(value.cli, expectedCLIName, "CLI"),
    app: validateArtifact(value.app, expectedAppName, "app"),
  };
}

function validateArtifact(value, expectedName, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`Candidate manifest ${label} artifact must be an object.`);
  }
  assertExactKeys(value, ["name", "sha256"], `Candidate manifest ${label} artifact`);
  if (value.name !== expectedName || basename(value.name) !== value.name) {
    throw new Error(`Candidate manifest ${label} artifact must be named ${expectedName}.`);
  }
  if (typeof value.sha256 !== "string" || !digestPattern.test(value.sha256)) {
    throw new Error(`Candidate manifest ${label} SHA-256 must be a lowercase digest.`);
  }
  return { name: value.name, sha256: value.sha256 };
}

function verifyArtifact(directory, artifact) {
  const path = join(directory, artifact.name);
  if (!existsSync(path)) {
    throw new Error(`Release artifact does not exist at ${path}.`);
  }
  const observed = createHash("sha256").update(readFileSync(path)).digest("hex");
  if (observed !== artifact.sha256) {
    throw new Error(`Release artifact ${artifact.name} SHA-256 does not match the candidate manifest.`);
  }
}

function renderPackages(manifest) {
  const releaseRoot = `https://github.com/ondrej-winter/calrelay/releases/download/v${manifest.version}`;
  return {
    [packageFiles.formula]: `# frozen_string_literal: true\n\nclass Calrelay < Formula\n  desc "Relay availability blockers between calendars"\n  homepage "https://github.com/ondrej-winter/calrelay"\n  url "${releaseRoot}/${manifest.cli.name}"\n  version "${manifest.version}"\n  sha256 "${manifest.cli.sha256}"\n  license "MIT"\n\n  livecheck do\n    skip "Releases are published by the CalRelay release workflow"\n  end\n\n  depends_on arch: :arm64\n  depends_on macos: :tahoe\n\n  def install\n    bin.install "calrelay"\n  end\n\n  test do\n    assert_equal version.to_s, shell_output("#{bin}/calrelay --version").strip\n    assert_match "USAGE:", shell_output("#{bin}/calrelay --help")\n  end\nend\n`,
    [packageFiles.cask]: `cask "calrelay" do\n  version "${manifest.version}"\n  sha256 "${manifest.app.sha256}"\n\n  url "${releaseRoot}/${manifest.app.name}"\n  name "CalRelay"\n  desc "Relay availability blockers between calendars"\n  homepage "https://github.com/ondrej-winter/calrelay"\n\n  livecheck do\n    skip "Releases are published by the CalRelay release workflow"\n  end\n\n  depends_on arch: :arm64\n  depends_on macos: :tahoe\n\n  app "CalRelay.app"\nend\n`,
  };
}

function assertExactKeys(value, expected, label) {
  const observed = Object.keys(value).sort();
  if (JSON.stringify(observed) !== JSON.stringify([...expected].sort())) {
    throw new Error(`${label} fields must be exactly: ${expected.join(", ")}.`);
  }
}

function verifyExistingOutput(directory, expected) {
  const observedFiles = listFiles(directory).sort();
  const expectedFiles = Object.keys(expected).sort();
  if (JSON.stringify(observedFiles) !== JSON.stringify(expectedFiles)) {
    throw new Error("Existing Homebrew package output is incomplete or contains unexpected files.");
  }
  for (const [relativePath, contents] of Object.entries(expected)) {
    if (readFileSync(join(directory, relativePath), "utf8") !== contents) {
      throw new Error(`Existing Homebrew package ${relativePath} conflicts with generated content.`);
    }
  }
}

function listFiles(directory, prefix = "") {
  const files = [];
  for (const entry of readdirSync(join(directory, prefix), { withFileTypes: true })) {
    const relativePath = join(prefix, entry.name);
    if (entry.isDirectory()) {
      files.push(...listFiles(directory, relativePath));
    } else if (entry.isFile()) {
      files.push(relativePath);
    } else {
      throw new Error(`Existing Homebrew package output contains unsupported entry ${relativePath}.`);
    }
  }
  return files;
}

function writeAtomically(directory, expected) {
  mkdirSync(dirname(directory), { recursive: true });
  const temporary = `${directory}.staging-${process.pid}`;
  rmSync(temporary, { force: true, recursive: true });
  try {
    for (const [relativePath, contents] of Object.entries(expected)) {
      const path = join(temporary, relativePath);
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(path, contents, { encoding: "utf8", mode: 0o644 });
    }
    renameSync(temporary, directory);
  } finally {
    rmSync(temporary, { force: true, recursive: true });
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

#!/usr/bin/env node
import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  rmSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const tap = "ondrej-winter/tap";
const token = `${tap}/calrelay`;
const packageToken = "calrelay";
const packageFiles = [join("Formula", "calrelay.rb"), join("Casks", "calrelay.rb")];

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function main(arguments_) {
  const options = parseOptions(arguments_);
  const packagesDirectory = resolve(required(options, "packages-directory"));
  const previousPackagesDirectory = options["previous-packages-directory"]
    ? resolve(options["previous-packages-directory"])
    : null;
  const workDirectory = resolve(required(options, "work-directory"));
  const stateDirectory = resolve(required(options, "state-directory"));
  const brew = resolve(required(options, "brew"));

  validatePackageDirectory(packagesDirectory, "current");
  if (previousPackagesDirectory) {
    validatePackageDirectory(previousPackagesDirectory, "previous");
  }
  if (!existsSync(stateDirectory)) {
    throw new Error(`State directory does not exist at ${stateDirectory}.`);
  }
  if (existsSync(workDirectory)) {
    throw new Error(`Work directory already exists at ${workDirectory}.`);
  }

  const stateBefore = snapshotDirectory(stateDirectory);
  const tapSource = join(workDirectory, "tap-source");
  const appDirectory = join(workDirectory, "Applications");
  let tapped = false;
  let installedFormula = false;
  let installedCask = false;

  try {
    mkdirSync(appDirectory, { recursive: true });
    initializeTap(tapSource, previousPackagesDirectory ?? packagesDirectory);
    assertCleanHomebrewState(brew);

    run(brew, ["tap", "--custom-remote", tap, pathToFileURL(tapSource).href]);
    tapped = true;
    const tapCheckout = run(brew, ["--repo", tap]).trim();
    if (!tapCheckout) {
      throw new Error("Homebrew did not report the temporary tap checkout path.");
    }

    stagePackages(tapCheckout, packagesDirectory);
    run(brew, ["style", "--formula", token]);
    run(brew, ["style", "--cask", token]);
    run(brew, ["audit", "--strict", "--formula", "--except=version", token]);
    run(brew, ["audit", "--strict", "--cask", "--except=sha256_no_check_if_unversioned", token]);
    run(brew, ["fetch", "--retry", "--formula", token]);
    run(brew, ["fetch", "--retry", "--cask", token]);

    for (const order of ["formula-first", "cask-first"]) {
      stagePackages(tapCheckout, previousPackagesDirectory ?? packagesDirectory);
      for (const kind of order === "formula-first" ? ["formula", "cask"] : ["cask", "formula"]) {
        install(brew, kind, appDirectory);
        installedFormula ||= kind === "formula";
        installedCask ||= kind === "cask";
        assertInstalled(brew, kind);
      }
      assertInstalled(brew, "formula");
      assertInstalled(brew, "cask");
      run(brew, ["test", token]);

      stagePackages(tapCheckout, packagesDirectory);
      if (previousPackagesDirectory) {
        upgrade(brew, "formula", appDirectory);
        upgrade(brew, "cask", appDirectory);
      }
      reinstall(brew, "formula", appDirectory);
      reinstall(brew, "cask", appDirectory);
      assertInstalled(brew, "formula");
      assertInstalled(brew, "cask");

      uninstall(brew, "formula");
      installedFormula = false;
      assertNotInstalled(brew, "formula");
      assertInstalled(brew, "cask");
      uninstall(brew, "cask");
      installedCask = false;
      assertNotInstalled(brew, "cask");
    }
  } finally {
    if (installedFormula) {
      runForCleanup(brew, ["uninstall", "--formula", token]);
    }
    if (installedCask) {
      runForCleanup(brew, ["uninstall", "--cask", token]);
    }
    if (tapped) {
      runForCleanup(brew, ["untap", tap]);
    }
    rmSync(workDirectory, { force: true, recursive: true });
  }

  const stateAfter = snapshotDirectory(stateDirectory);
  if (stateAfter !== stateBefore) {
    throw new Error("Homebrew package validation modified retained user state.");
  }
  process.stdout.write("Validated Homebrew formula and cask lifecycle.\n");
}

function validatePackageDirectory(directory, label) {
  if (!existsSync(directory)) {
    throw new Error(`${label} package directory does not exist at ${directory}.`);
  }
  const observed = listFiles(directory).sort();
  if (JSON.stringify(observed) !== JSON.stringify([...packageFiles].sort())) {
    throw new Error(`${label} package directory must contain exactly Formula/calrelay.rb and Casks/calrelay.rb.`);
  }
}

function initializeTap(directory, packagesDirectory) {
  mkdirSync(directory, { recursive: true });
  stagePackages(directory, packagesDirectory);
  git(directory, ["init", "-b", "main"]);
  git(directory, ["config", "user.name", "CalRelay Release"]);
  git(directory, ["config", "user.email", "release@example.invalid"]);
  git(directory, ["add", "--", "Formula/calrelay.rb", "Casks/calrelay.rb"]);
  git(directory, ["commit", "-m", "chore: stage Homebrew packages"]);
}

function stagePackages(destination, source) {
  for (const relativePath of packageFiles) {
    const target = join(destination, relativePath);
    mkdirSync(dirname(target), { recursive: true });
    cpSync(join(source, relativePath), target);
  }
}

function assertCleanHomebrewState(brew) {
  if (isInstalled(brew, "formula") || isInstalled(brew, "cask")) {
    throw new Error("Homebrew lifecycle validation requires calrelay formula and cask to be absent initially.");
  }
  const taps = run(brew, ["tap"]);
  if (taps.split("\n").includes(tap)) {
    throw new Error(`Homebrew lifecycle validation requires ${tap} to be untapped initially.`);
  }
}

function install(brew, kind, appDirectory) {
  const arguments_ = ["install", `--${kind}`, token];
  if (kind === "cask") arguments_.push("--appdir", appDirectory);
  run(brew, arguments_);
}

function reinstall(brew, kind, appDirectory) {
  const arguments_ = ["reinstall", `--${kind}`, token];
  if (kind === "cask") arguments_.push("--appdir", appDirectory);
  run(brew, arguments_);
}

function upgrade(brew, kind, appDirectory) {
  const arguments_ = ["upgrade", `--${kind}`, token];
  if (kind === "cask") arguments_.push("--appdir", appDirectory);
  run(brew, arguments_);
}

function uninstall(brew, kind) {
  run(brew, ["uninstall", `--${kind}`, token]);
}

function assertInstalled(brew, kind) {
  if (!isInstalled(brew, kind)) {
    throw new Error(`Homebrew did not retain the installed ${kind}.`);
  }
}

function assertNotInstalled(brew, kind) {
  if (isInstalled(brew, kind)) {
    throw new Error(`Homebrew did not remove the uninstalled ${kind}.`);
  }
}

function isInstalled(brew, kind) {
  const result = spawnSync(brew, ["list", "--versions", `--${kind}`, packageToken], processOptions());
  if (result.error) throw result.error;
  return result.status === 0;
}

function run(executable, arguments_) {
  const result = spawnSync(executable, arguments_, processOptions());
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const details = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
    throw new Error(`${executable} ${arguments_.join(" ")} failed${details ? `: ${details}` : ""}.`);
  }
  return result.stdout ?? "";
}

function runForCleanup(executable, arguments_) {
  spawnSync(executable, arguments_, processOptions());
}

function git(repository, arguments_) {
  execFileSync("/usr/bin/git", ["-C", repository, ...arguments_], {
    encoding: "utf8",
    env: { ...process.env, GIT_TERMINAL_PROMPT: "0" },
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function processOptions() {
  return {
    encoding: "utf8",
    env: {
      ...process.env,
      HOMEBREW_NO_AUTO_UPDATE: "1",
      HOMEBREW_NO_INSTALL_CLEANUP: "1",
      HOMEBREW_NO_ANALYTICS: "1",
      HOMEBREW_NO_ENV_HINTS: "1",
    },
  };
}

function snapshotDirectory(directory) {
  const hash = createHash("sha256");
  for (const relativePath of listEntries(directory).sort()) {
    const path = join(directory, relativePath);
    const metadata = lstatSync(path);
    hash.update(relativePath);
    if (metadata.isSymbolicLink()) {
      hash.update("symlink");
      hash.update(readlinkSync(path));
    } else {
      hash.update("file");
      hash.update(readFileSync(path));
    }
  }
  return hash.digest("hex");
}

function listFiles(directory, prefix = "") {
  const files = [];
  for (const entry of readdirSync(join(directory, prefix), { withFileTypes: true })) {
    const relativePath = join(prefix, entry.name);
    if (entry.isDirectory()) files.push(...listFiles(directory, relativePath));
    else if (entry.isFile()) files.push(relativePath);
    else throw new Error(`Unsupported package entry ${relativePath}.`);
  }
  return files;
}

function listEntries(directory, prefix = "") {
  const entries = [];
  for (const entry of readdirSync(join(directory, prefix), { withFileTypes: true })) {
    const relativePath = join(prefix, entry.name);
    if (entry.isDirectory()) entries.push(...listEntries(directory, relativePath));
    else entries.push(relativePath);
  }
  return entries;
}

function parseOptions(arguments_) {
  const allowed = new Set([
    "packages-directory",
    "previous-packages-directory",
    "work-directory",
    "state-directory",
    "brew",
  ]);
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
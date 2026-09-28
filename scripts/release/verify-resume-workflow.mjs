#!/usr/bin/env node
import { appendFileSync, readFileSync } from "node:fs";

const revisionPattern = /^[0-9a-f]{40}$/;
const acceptedWorkflows = new Set([
  "CI/CD\0.github/workflows/ci-cd.yaml",
  "Public-beta release\0.github/workflows/release.yml",
]);

try {
  main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function main(arguments_) {
  const options = parseOptions(arguments_);
  const state = readJSON(required(options, "state"), "retained release state");
  const run = readJSON(required(options, "run"), "workflow run metadata");
  const repository = required(options, "repository");
  const runID = required(options, "run-id");
  const output = required(options, "output");

  if (
    state.schemaVersion !== 3
    || !revisionPattern.test(state.sourceRevision ?? "")
    || !revisionPattern.test(state.releaseCommit ?? "")
  ) {
    throw new Error("retained release source metadata is invalid");
  }
  if (state.tag !== `v${state.version}`) {
    throw new Error("retained release tag is invalid");
  }

  const workflowIdentity = `${run.name}\0${run.path}`;
  if (
    String(run.id) !== runID
    || !acceptedWorkflows.has(workflowIdentity)
    || !["push", "workflow_dispatch"].includes(run.event)
    || run.status !== "completed"
    || run.head_branch !== "master"
    || run.repository?.full_name !== repository
    || run.head_repository?.full_name !== repository
    || run.head_sha !== state.sourceRevision
  ) {
    throw new Error("resume candidate does not match its protected release workflow run");
  }

  appendFileSync(
    output,
    `source_revision=${state.sourceRevision}\nvalidation_revision=${state.releaseCommit}\nrelease_commit=${state.releaseCommit}\ntag=${state.tag}\n`,
  );
}

function readJSON(path, description) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`${description} is invalid: ${error.message}`);
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
    const name = key.slice(2);
    if (options[name] !== undefined) throw new Error(`Duplicate option --${name}.`);
    options[name] = value;
  }
  return options;
}

function required(options, name) {
  const value = options[name];
  if (!value) throw new Error(`Missing required --${name}.`);
  return value;
}
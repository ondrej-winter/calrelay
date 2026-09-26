#!/usr/bin/env node

import { prepareRepositoryRelease, releaseNotes, selectFromRepository } from "./release-policy-library.mjs";

try {
  const [command, ...arguments_] = process.argv.slice(2);
  const repository = optionValue(arguments_, "--repository") ?? process.cwd();
  const bootstrap = arguments_.includes("--bootstrap");

  if (command === "select") {
    process.stdout.write(`${JSON.stringify(selectFromRepository(repository, { bootstrap }))}\n`);
  } else if (command === "notes") {
    process.stdout.write(releaseNotes(selectFromRepository(repository, { bootstrap })));
  } else if (command === "prepare") {
    process.stdout.write(`${JSON.stringify(prepareRepositoryRelease(repository, { bootstrap }))}\n`);
  } else {
    throw new Error("Usage: release-policy.mjs <select|notes|prepare> [--repository PATH] [--bootstrap]");
  }
} catch (error) {
  process.stderr.write(`error: ${error.message}\n`);
  process.exitCode = 1;
}

function optionValue(arguments_, option) {
  const index = arguments_.indexOf(option);
  if (index === -1) {
    return null;
  }
  if (!arguments_[index + 1]) {
    throw new Error(`${option} requires a value.`);
  }
  return arguments_[index + 1];
}
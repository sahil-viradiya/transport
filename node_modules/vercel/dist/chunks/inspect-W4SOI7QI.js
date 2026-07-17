import { createRequire as __createRequire } from 'node:module';
import { fileURLToPath as __fileURLToPath } from 'node:url';
import { dirname as __dirname_ } from 'node:path';
const require = __createRequire(import.meta.url);
const __filename = __fileURLToPath(import.meta.url);
const __dirname = __dirname_(__filename);
import {
  repositoryPath
} from "./chunk-4QVAYRYH.js";
import {
  formatRelativeTime
} from "./chunk-6OMC3HOW.js";
import {
  emitVcrArgParseError,
  handleVcrApiError,
  requireVcrRepository,
  resolveVcrScope,
  validateVcrJsonOutput
} from "./chunk-VO6PK3ZA.js";
import "./chunk-BUZRVER7.js";
import "./chunk-XPKWKPWA.js";
import {
  inspectSubcommand
} from "./chunk-3VS4DTAU.js";
import "./chunk-GIL3VAUR.js";
import "./chunk-FYQPTH5C.js";
import "./chunk-RGOP4OYL.js";
import "./chunk-UDWRZXIT.js";
import "./chunk-ECCWJHC6.js";
import {
  parseArguments,
  printError
} from "./chunk-SZXT3PDQ.js";
import {
  getFlagsSpecification,
  isAPIError
} from "./chunk-KSSNLCL4.js";
import "./chunk-P4QNYOFB.js";
import "./chunk-52QYYTM5.js";
import {
  output_manager_default
} from "./chunk-OX7KI3LF.js";
import "./chunk-GGP5R3FU.js";
import {
  require_source
} from "./chunk-S7KYDPEM.js";
import {
  __toESM
} from "./chunk-TZ2YI2VH.js";

// src/commands/vcr/inspect.ts
var import_chalk = __toESM(require_source(), 1);
function printRepository(repository) {
  output_manager_default.print("\n");
  output_manager_default.print(`  ${import_chalk.default.cyan("Name")}			${repository.name}
`);
  output_manager_default.print(`  ${import_chalk.default.cyan("ID")}			${repository.id}
`);
  output_manager_default.print(`  ${import_chalk.default.cyan("Project ID")}		${repository.projectId}
`);
  output_manager_default.print(
    `  ${import_chalk.default.cyan("Created")}		${formatRelativeTime(repository.createdAt)}
`
  );
  output_manager_default.print(
    `  ${import_chalk.default.cyan("Updated")}		${formatRelativeTime(repository.updatedAt)}
`
  );
  output_manager_default.print("\n");
}
async function inspect(client, argv, telemetry) {
  let parsedArgs;
  try {
    parsedArgs = parseArguments(
      argv,
      getFlagsSpecification(inspectSubcommand.options)
    );
  } catch (err) {
    emitVcrArgParseError(
      client,
      err,
      "vcr inspect <repository> --project <name-or-id>"
    );
    printError(err);
    return 1;
  }
  const fr = validateVcrJsonOutput(client, parsedArgs.flags);
  if (typeof fr === "number") {
    return fr;
  }
  const repository = parsedArgs.args[0];
  const project = parsedArgs.flags["--project"];
  telemetry.trackCliOptionProject(project);
  telemetry.trackCliOptionFormat(parsedArgs.flags["--format"]);
  const missingRepository = requireVcrRepository(
    client,
    repository,
    fr.jsonOutput,
    "vcr inspect <repository>"
  );
  if (typeof missingRepository === "number") {
    return missingRepository;
  }
  const scope = await resolveVcrScope(client, {
    project,
    jsonOutput: fr.jsonOutput
  });
  if (typeof scope === "number") {
    return scope;
  }
  const path = repositoryPath(scope, repository);
  output_manager_default.spinner("Fetching repository...");
  try {
    const result = await client.fetch(path);
    if (fr.jsonOutput) {
      client.stdout.write(`${JSON.stringify(result.repository, null, 2)}
`);
    } else {
      output_manager_default.log(`${import_chalk.default.bold("Repository")} ${import_chalk.default.cyan(repository)}`);
      printRepository(result.repository);
    }
    return 0;
  } catch (err) {
    if (isAPIError(err)) {
      return handleVcrApiError(client, err, fr.jsonOutput);
    }
    throw err;
  } finally {
    output_manager_default.stopSpinner();
  }
}
export {
  inspect as default
};

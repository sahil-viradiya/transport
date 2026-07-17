import { createRequire as __createRequire } from 'node:module';
import { fileURLToPath as __fileURLToPath } from 'node:url';
import { dirname as __dirname_ } from 'node:path';
const require = __createRequire(import.meta.url);
const __filename = __fileURLToPath(import.meta.url);
const __dirname = __dirname_(__filename);
import {
  emitVcrArgParseError,
  handleVcrApiError,
  resolveVcrScope,
  validateVcrJsonOutput
} from "./chunk-VO6PK3ZA.js";
import {
  outputError
} from "./chunk-BUZRVER7.js";
import "./chunk-XPKWKPWA.js";
import {
  addSubcommand
} from "./chunk-3VS4DTAU.js";
import "./chunk-GIL3VAUR.js";
import "./chunk-FYQPTH5C.js";
import "./chunk-RGOP4OYL.js";
import {
  AGENT_REASON,
  buildCommandWithGlobalFlags,
  outputAgentError
} from "./chunk-UDWRZXIT.js";
import "./chunk-ECCWJHC6.js";
import {
  parseArguments,
  printError
} from "./chunk-SZXT3PDQ.js";
import {
  getFlagsSpecification,
  isAPIError,
  packageName
} from "./chunk-KSSNLCL4.js";
import "./chunk-P4QNYOFB.js";
import "./chunk-52QYYTM5.js";
import {
  output_manager_default
} from "./chunk-OX7KI3LF.js";
import "./chunk-GGP5R3FU.js";
import "./chunk-S7KYDPEM.js";
import "./chunk-TZ2YI2VH.js";

// src/commands/vcr/add.ts
async function add(client, argv, telemetry) {
  let parsedArgs;
  try {
    parsedArgs = parseArguments(
      argv,
      getFlagsSpecification(addSubcommand.options)
    );
  } catch (err) {
    emitVcrArgParseError(client, err, "vcr add <name> --project <name-or-id>");
    printError(err);
    return 1;
  }
  const fr = validateVcrJsonOutput(client, parsedArgs.flags);
  if (typeof fr === "number") {
    return fr;
  }
  const name = parsedArgs.args[0];
  const project = parsedArgs.flags["--project"];
  telemetry.trackCliOptionProject(project);
  telemetry.trackCliOptionFormat(parsedArgs.flags["--format"]);
  if (!name) {
    outputAgentError(
      client,
      {
        status: "error",
        reason: AGENT_REASON.MISSING_ARGUMENTS,
        message: `Missing repository name. Example: ${packageName} vcr add <name>`,
        next: [
          {
            command: buildCommandWithGlobalFlags(client.argv, "vcr add <name>"),
            when: "Replace <name> with the repository name to create"
          }
        ]
      },
      1
    );
    return outputError(
      client,
      fr.jsonOutput,
      "MISSING_ARGUMENTS",
      "Usage: `vercel vcr add <name>`"
    );
  }
  const scope = await resolveVcrScope(client, {
    project,
    jsonOutput: fr.jsonOutput
  });
  if (typeof scope === "number") {
    return scope;
  }
  const path = `/v1/vcr/repository?teamId=${encodeURIComponent(scope.teamId)}`;
  output_manager_default.spinner("Creating repository...");
  try {
    const created = await client.fetch(
      path,
      {
        method: "POST",
        body: { projectId: scope.projectId, name }
      }
    );
    if (fr.jsonOutput) {
      client.stdout.write(`${JSON.stringify(created, null, 2)}
`);
    } else {
      output_manager_default.success(`Created repository ${created.repository?.name ?? name}`);
    }
    return 0;
  } catch (err) {
    if (isAPIError(err)) {
      return handleVcrApiError(client, err, fr.jsonOutput, {
        retry: {
          command: buildCommandWithGlobalFlags(client.argv, "vcr ls"),
          when: "List existing repositories (a name conflict means it already exists)"
        }
      });
    }
    throw err;
  } finally {
    output_manager_default.stopSpinner();
  }
}
export {
  add as default
};

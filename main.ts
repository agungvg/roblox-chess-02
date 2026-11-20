// Chess Brainrot Battle Royale — roblox-brainrot-01 entry (Node 22, stdlib only).
// The game is this directory's Rojo project, built with
//   rojo build default.project.json --output game.rbxl
// and this program hands it in: it copies game.rbxl, PLAY.json, src/ and
// screenshots/ from beside this file to /output and writes /output/dossier.json
// with the vendored make.fun library, the summary the judge reads.
//
// Every name under /output must start with a letter, a digit or _ and hold
// only letters, digits, . _ and -; a dotted name anywhere under it (a .gitkeep,
// a .DS_Store) fails the entry, so src/ and screenshots/ are copied with a
// filter that drops dotted names at every depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

const here = fileURLToPath(new URL(".", import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// The grader's container always provides /output; a local run may not have
// created it yet, so make it first — copying into a missing directory fails.
mkdirSync(out, { recursive: true });

// cpSync filter: drop every file and directory whose name starts with a dot.
const notDotted = (path: string): boolean => !basename(path).startsWith(".");

copyFileSync(join(here, "game.rbxl"), join(out, "game.rbxl"));
copyFileSync(join(here, "PLAY.json"), join(out, "PLAY.json"));
cpSync(join(here, "src"), join(out, "src"), { recursive: true, filter: notDotted });
mkdirSync(join(out, "screenshots"), { recursive: true });
if (existsSync(join(here, "screenshots"))) {
	cpSync(join(here, "screenshots"), join(out, "screenshots"), { recursive: true, filter: notDotted });
}

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the
// bytes; the others refuse an entry the scorer would refuse (more than 4
// screenshots or one over 256 KiB; a place of more than 500000 instances,
// scripts over 8 MiB of source, or script paths over 1048576 characters).
writeFileSync(
	join(out, "dossier.json"),
	buildDossier(out, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

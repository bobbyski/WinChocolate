// Runs a ChocolateKit wasm executable under Node's WASI.
//
// Why this exists: the contract suite's real homes are Windows and the Linux
// container, and neither is reachable from a Mac without Docker. But the suite
// also builds for wasm32-unknown-wasip1, and `CHOCOLATE_BACKEND=inmemory`
// keeps the browser backend from ever initializing — so the same binary runs
// headless right here. That turns "I can only compile it" into "I can run it",
// which is the difference between believing a change works and knowing it.
//
// The JavaScriptKit imports are stubbed. That is safe ONLY because the
// in-memory backend never calls into JS: every stub records itself, and the
// runner reports any that actually fired, because a stub being reached means
// something took the DOM path and the run cannot be trusted.
//
// Usage (normally through Tools/run-contract-tests.sh):
//   node Tools/wasi-contract-runner.mjs <path-to.wasm> [scratch-dir]

import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';

const wasmPath = process.argv[2];
const scratch = process.argv[3] ?? process.env.WASI_TMP;

if (!wasmPath) {
    console.error('usage: node wasi-contract-runner.mjs <path-to.wasm> [scratch-dir]');
    process.exit(2);
}

const calledStubs = new Set();
const bytes = await readFile(wasmPath);
const module = await WebAssembly.compile(bytes);

const wasi = new WASI({
    version: 'preview1',
    args: ['contracttests', '--chocolate-backend=inmemory'],
    env: { CHOCOLATE_BACKEND: 'inmemory', TMPDIR: '/tmp', HOME: '/tmp' },
    // The suite writes real files (documents saved and read back), so it needs
    // a directory it is actually allowed to touch. WASI grants nothing by
    // default — that is the point of the sandbox — so one is preopened here.
    preopens: scratch ? { '/tmp': scratch } : {},
    returnOnExit: true,
});

const imports = wasi.getImportObject();
for (const descriptor of WebAssembly.Module.imports(module)) {
    if (descriptor.module === 'wasi_snapshot_preview1') continue;
    imports[descriptor.module] ||= {};
    if (imports[descriptor.module][descriptor.name]) continue;
    imports[descriptor.module][descriptor.name] = () => {
        calledStubs.add(`${descriptor.module}.${descriptor.name}`);
        return 0;
    };
}

const instance = await WebAssembly.instantiate(module, imports);

let code = 0;
try {
    code = wasi.start(instance);
} catch (error) {
    // A contract failure calls fatalError, which compiles to `unreachable` and
    // surfaces here as a trap. The assertion message was already printed.
    console.error(`\n[trapped: ${error.message}]`);
    code = 70;
}

if (calledStubs.size > 0) {
    console.error(`\n[WARNING] JavaScript stubs were called, so something took the DOM path`);
    console.error(`          and this run is NOT trustworthy: ${[...calledStubs].join(', ')}`);
    code = code || 71;
}

process.exit(code);

// Starts the local API server against the emulators, then runs the API tests.
import { spawn } from "node:child_process";

const server = spawn(process.execPath, ["build/src/devServer.js"], { stdio: ["ignore", "inherit", "inherit"], env: { ...process.env, PORT: "5055" } });
await new Promise((r) => setTimeout(r, 1500));
const tests = spawn(process.execPath, ["--test", "--test-concurrency=1", "rules-test/api.test.mjs"], { stdio: "inherit" });
const code = await new Promise((r) => tests.on("exit", r));
server.kill();
process.exit(code ?? 1);

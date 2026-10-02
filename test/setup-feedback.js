const assert = require("assert").strict;
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.join(__dirname, "..");
const pages = ["DefaultsPage.qml", "InstallPage.qml", "AgentsPage.qml"];

function extractFunction(source, name) {
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} exists`);
  const open = source.indexOf("{", start);
  let depth = 0;
  let quote = "";
  let escaped = false;

  for (let i = open; i < source.length; i += 1) {
    const character = source[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === quote) quote = "";
    } else if (character === "\"" || character === "'" || character === "`") {
      quote = character;
    } else if (character === "{") {
      depth += 1;
    } else if (character === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }

  throw new Error(`Could not extract ${name}`);
}

for (const file of pages) {
  const source = fs.readFileSync(path.join(root, "setup/qml", file), "utf8");
  const page = { busy: true, errorText: "" };
  page.page = page;
  const context = vm.createContext(page);
  const recordError = vm.runInContext(`(${extractFunction(source, "recordError")})`, context);
  const failureMessage = vm.runInContext(`(${extractFunction(source, "failureMessage")})`, context);
  const onFinished = vm.runInContext(`(${extractFunction(source, "onFinished")})`, context);
  page.failureMessage = result => failureMessage.call(page, result);
  page.recordError = result => recordError.call(page, result);

  page.errorText = "";
  page.recordError({ exitCode: 7, stdout: "catalog unavailable", stderr: "" });
  assert.equal(page.errorText, "catalog unavailable (exit code 7)", `${file} shows stdout and exit code`);

  page.errorText = "";
  onFinished.call(page, { exitCode: 23, stdout: "", stderr: "" });
  assert.equal(page.errorText, "Command failed with exit code 23", `${file} explains silent failure`);
  assert.equal(page.busy, false, `${file} clears busy after failure`);

  page.busy = true;
  let refreshed = false;
  page.loadGroups = () => {
    assert.equal(page.busy, true, `${file} stays busy during refresh`);
    refreshed = true;
  };
  page.loadApps = page.loadGroups;
  page.loadAgents = page.loadGroups;
  onFinished.call(page, { exitCode: 0, stdout: "", stderr: "" });
  assert.equal(refreshed, true, `${file} refreshes after success`);
  assert.equal(page.busy, false, `${file} clears busy after refresh`);
  console.log(`ok - ${file} surfaces failures and stays busy through refresh`);
}

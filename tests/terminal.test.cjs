const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { parseJsonc, configure } = require("../scripts/Configure-Terminals.cjs");
const root = path.join(__dirname, "../.test-work/terminal-" + Date.now());
test("JSONC preserves string contents, URLs, escapes and trailing-comma-like strings", () => {
  const actual = parseJsonc(String.raw`{
    // comment
    "url": "https://example.org/a//b",
    "text": "keep ,} and /* */ and \"quoted\"",
    "path": "C:\\tools\\nvim",
    /* comment */ "array": [1,2,],
  }`);
  assert.equal(actual.url, "https://example.org/a//b");
  assert.equal(actual.text, 'keep ,} and /* */ and "quoted"');
  assert.equal(actual.path, "C:\\tools\\nvim");
  assert.deepEqual(actual.array, [1,2]);
});
test("terminal edits preserve settings, create backups and remain idempotent", () => {
  const user = path.join(root, "user with space");
  const local = path.join(root, "local");
  const settings = path.join(local, "Microsoft/Windows Terminal/settings.json");
  fs.mkdirSync(path.dirname(settings), { recursive: true });
  fs.mkdirSync(user, { recursive: true });
  fs.writeFileSync(settings, '{"defaultProfile":"mine","profiles":{"defaults":{"font":{"size":15}},"list":[{"name":"mine","font":{"face":"old","size":17}}]}}');
  fs.writeFileSync(path.join(user, ".bash_profile"), 'echo "existing profile"\n');
  fs.writeFileSync(path.join(user, ".minttyrc"), "Font=Old\nFontHeight=12\n");
  configure("D:\\a space\\bin", local, user);
  configure("D:\\a space\\bin", local, user);
  const result = JSON.parse(fs.readFileSync(settings, "utf8"));
  assert.equal(result.defaultProfile, "mine");
  assert.equal(result.profiles.defaults.font.size, 15);
  assert.equal(result.profiles.list[0].font.size, 17);
  assert.equal(result.profiles.defaults.font.face, "FiraCode Nerd Font Mono");
  assert.equal(result.profiles.list[0].font.face, "FiraCode Nerd Font Mono");
  const profile = fs.readFileSync(path.join(user, ".bash_profile"), "utf8");
  assert.equal(profile.match(/# >>> nvim-windows >>>/g).length, 1);
  assert.ok(profile.includes('echo "existing profile"'));
  assert.ok(fs.readFileSync(path.join(user, ".minttyrc"), "utf8").includes("FontHeight=12"));
  assert.equal(fs.readdirSync(path.dirname(settings)).filter(p => p.includes(".backup-")).length, 1);
});
test("invalid JSONC fails before replacing the original file", () => {
  assert.throws(() => parseJsonc('{"x":/* unterminated'));
  assert.throws(() => parseJsonc('{"x":'));
});

test("skip-font leaves terminal settings unchanged and preserves the prior login profile", () => {
  const user = path.join(root, "skip-user");
  const local = path.join(root, "skip-local");
  fs.mkdirSync(user, { recursive: true });
  fs.writeFileSync(path.join(user, ".profile"), "echo existing\n");
  fs.writeFileSync(path.join(user, ".minttyrc"), "Font=Mine\n");
  configure("D:\\bin", local, user, false);
  assert.equal(fs.readFileSync(path.join(user, ".minttyrc"), "utf8"), "Font=Mine\n");
  assert.ok(fs.readFileSync(path.join(user, ".bash_profile"), "utf8").startsWith(". ~/.profile\n"));
});

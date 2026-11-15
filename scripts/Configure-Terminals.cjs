const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

// Strip JSONC comments and trailing commas with string-aware scanning.
// Never use eval: terminal settings are data.
function parseJsonc(text) {
  text = text.replace(/^\uFEFF/, "");
  let out = "", quoted = false, escaped = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i], next = text[i + 1];
    if (quoted) {
      out += c;
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === '"') quoted = false;
    } else if (c === '"') {
      quoted = true; out += c;
    } else if (c === "/" && next === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      out += "\n";
    } else if (c === "/" && next === "*") {
      i += 2;
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i++;
      if (i >= text.length) throw new Error("Unterminated JSONC comment");
      i++; out += " ";
    } else out += c;
  }
  let clean = ""; quoted = false; escaped = false;
  for (let i = 0; i < out.length; i++) {
    const c = out[i];
    if (quoted) {
      clean += c;
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === '"') quoted = false;
    } else if (c === '"') {
      quoted = true; clean += c;
    } else if (c !== "," || !/^\s*[}\]]/.test(out.slice(i + 1))) clean += c;
  }
  return JSON.parse(clean);
}

function writeBackedUp(file, content) {
  if (fs.existsSync(file)) {
    if (fs.readFileSync(file, "utf8") === content) return;
    const backup = file + ".backup-" + Date.now() + "-" + crypto.randomBytes(3).toString("hex");
    fs.copyFileSync(file, backup);
    console.log("Backup: " + backup);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temp = file + ".tmp-" + crypto.randomBytes(5).toString("hex");
  fs.writeFileSync(temp, content, "utf8");
  fs.renameSync(temp, file);
}

function updateTerminal(file) {
  const settings = parseJsonc(fs.readFileSync(file, "utf8"));
  settings.profiles ??= {};
  if (Array.isArray(settings.profiles)) {
    settings.profiles = { list: settings.profiles, defaults: {} };
  }
  settings.profiles.defaults ??= {};
  settings.profiles.defaults.font ??= {};
  settings.profiles.defaults.font.face = "FiraCode Nerd Font Mono";
  // Explicit per-profile font overrides take precedence over defaults.
  for (const profile of settings.profiles.list ?? []) {
    if (profile.font?.face) profile.font.face = "FiraCode Nerd Font Mono";
    if (profile.fontFace) profile.fontFace = "FiraCode Nerd Font Mono";
  }
  writeBackedUp(file, JSON.stringify(settings, null, 2) + "\n");
}

function configure(binDir, localAppData = process.env.LOCALAPPDATA, userProfile = process.env.USERPROFILE, setFont = true) {
  if (setFont) {
    const files = [
      "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
      "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
      "Microsoft/Windows Terminal/settings.json"
    ].map(p => path.join(localAppData, p)).filter(p => fs.existsSync(p));
    for (const file of files) updateTerminal(file);
    if (!files.length) console.log("No Windows Terminal settings found. Select FiraCode Nerd Font Mono in your terminal after first launch.");
    const mintty = path.join(userProfile, ".minttyrc");
    let lines = fs.existsSync(mintty) ? fs.readFileSync(mintty, "utf8").split(/\r?\n/) : [];
    lines = lines.filter(line => !/^Font=/.test(line));
    while (lines.length && !lines[lines.length - 1]) lines.pop();
    lines.push("Font=FiraCode Nerd Font Mono");
    writeBackedUp(mintty, lines.join("\n") + "\n");

  }

  // Git Bash login shells do not always inherit a newly updated Windows PATH.
  const profile = path.join(userProfile, ".bash_profile");
  let content = fs.existsSync(profile) ? fs.readFileSync(profile, "utf8") : "";
  if (!fs.existsSync(profile)) {
    const existing = [".bash_login", ".profile", ".bashrc"].find(name => fs.existsSync(path.join(userProfile, name)));
    if (existing) content = ". ~/" + existing + "\n";
  }
  const begin = "# >>> nvim-windows >>>", end = "# <<< nvim-windows <<<";
  const slashPath = binDir.replace(/\\/g, "/").replace(/'/g, "'\\''");
  const block = begin + "\nexport PATH=\"$(cygpath -u '" + slashPath + "'):$PATH\"\n" + end;
  const start = content.indexOf(begin), finish = content.indexOf(end);
  if ((start < 0) !== (finish < 0) || (start >= 0 && finish < start)) throw new Error("Incomplete nvim-windows block in .bash_profile");
  if (start >= 0) content = content.slice(0, start) + block + content.slice(finish + end.length);
  else content = content.replace(/\s*$/, "\n") + block + "\n";
  writeBackedUp(profile, content);
}
module.exports = { parseJsonc, updateTerminal, configure };
if (require.main === module) {
  try { configure(path.resolve(process.argv[2]), undefined, undefined, !process.argv.includes("--skip-font")); }
  catch (error) { console.error("Terminal configuration failed: " + error.message); process.exitCode = 1; }
}

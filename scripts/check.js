import { readdirSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

function files(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? files(path) : [path];
  });
}
function check(command, args) {
  const result = spawnSync(command, args, { stdio: "inherit" });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
check(process.execPath, ["scripts/build-styles.js", "--check"]);
check("ruby", ["scripts/validate-company-catalog.rb"]);
check("ruby", ["scripts/build-public-catalog.rb"]);
const sources = [...["scripts", "deploy/discourse", "frontend", "test", ".github"].flatMap(files), "playwright.config.js"];
for (const path of sources) {
  if (path.endsWith(".js")) check(process.execPath, ["--check", path]);
  if (path.endsWith(".rb")) check("ruby", ["-c", path]);
  if (path.endsWith(".sh")) check("bash", ["-n", path]);
  if (path.endsWith(".py")) check("python3", ["-c", "import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())", path]);
}
const yaml = sources.filter(path => /\.ya?ml$/.test(path));
check("ruby", ["-ryaml", "-e", "ARGV.each { |path| YAML.parse_file(path) }", ...yaml]);
console.log("Discourse source, shell and configuration checks passed.");

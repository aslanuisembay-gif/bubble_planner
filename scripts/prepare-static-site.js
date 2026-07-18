const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const source = path.join(root, "vercel-web");
const target = path.join(root, "site", "bubble-planner");

if (!fs.existsSync(source)) {
  throw new Error(`Bubble Planner web build not found at ${source}`);
}

fs.rmSync(target, { recursive: true, force: true });
fs.mkdirSync(target, { recursive: true });
fs.cpSync(source, target, { recursive: true });

const indexPath = path.join(target, "index.html");
let indexHtml = fs.readFileSync(indexPath, "utf8");
indexHtml = indexHtml
  .replace('<base href="/">', '<base href="/bubble-planner/">')
  .replace(
    '<meta name="description" content="Bubble Planner — задачи и голосовой ввод.">',
    '<meta name="description" content="Bubble Planner — task planning, voice input, reminders, notes, and productivity tools.">',
  )
  .replace("<title>Bubble Planner</title>", "<title>Bubble Planner | Boston Global</title>");
fs.writeFileSync(indexPath, indexHtml);

const manifestPath = path.join(target, "manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
manifest.name = "Bubble Planner";
manifest.short_name = "Bubble Planner";
manifest.start_url = "/bubble-planner/";
manifest.description = "Task planning, voice input, reminders, notes, and productivity tools.";
fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

console.log("Prepared static Boston Global site with Bubble Planner at /bubble-planner/");

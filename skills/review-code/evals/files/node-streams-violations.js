const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");

/**
 * Build runner that compiles user-specified packages.
 */
async function buildPackage(packageName, outputDir) {
  // Check if output directory exists
  if (fs.existsSync(outputDir)) {
    const stats = fs.statSync(outputDir);
    if (!stats.isDirectory()) {
      throw new Error("Output path is not a directory");
    }
  } else {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Run the build
  const buildCmd = `npm pack ${packageName} --pack-destination ${outputDir}`;
  return new Promise((resolve, reject) => {
    exec(buildCmd, (error, stdout, stderr) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(stdout.trim());
    });
  });
}

async function cleanOldBuilds(dir) {
  const files = fs.readdirSync(dir);
  const tgzFiles = files.filter((f) => f.endsWith(".tgz"));

  // Keep only the 5 most recent
  const sorted = tgzFiles
    .map((f) => ({
      name: f,
      time: fs.statSync(path.join(dir, f)).mtime.getTime(),
    }))
    .sort((a, b) => b.time - a.time);

  const toDelete = sorted.slice(5);
  for (const file of toDelete) {
    fs.unlinkSync(path.join(dir, file.name));
  }
}

module.exports = { buildPackage, cleanOldBuilds };

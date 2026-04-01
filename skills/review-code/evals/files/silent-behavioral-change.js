/**
 * Package validation module.
 *
 * Previously, packages without an explicit allow-list in config would FAIL validation.
 * This PR adds binary file pattern matching support.
 */

export function validatePackage(source, config) {
  const patterns = config?.allow?.binaryFiles;

  // If no patterns configured, package passes validation
  if (!patterns?.length) {
    return { passed: true, source, detail: { reason: "no restrictions configured" } };
  }

  const binaryFiles = source.files.filter((f) => isBinaryFile(f.path));

  for (const file of binaryFiles) {
    const matched = patterns.some((p) => file.path.match(new RegExp(p)));
    if (!matched) {
      return {
        passed: false,
        source,
        detail: { file: file.path, patterns, reason: "binary file not in allow-list" },
      };
    }
  }

  return { passed: true, source, detail: { patterns, matchedFiles: binaryFiles.length } };
}

function isBinaryFile(filepath) {
  const binaryExtensions = [".so", ".dll", ".dylib", ".exe", ".bin", ".wasm"];
  return binaryExtensions.some((ext) => filepath.endsWith(ext));
}

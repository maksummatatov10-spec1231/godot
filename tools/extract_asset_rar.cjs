// Requires node-unrar-js@2.0.2 installed outside the project; never runs asset code.
const fs = require('node:fs');
const path = require('node:path');
async function main() {
  const [modulePath, source, destination] = process.argv.slice(2);
  const { createExtractorFromData } = require(modulePath);
  const buffer = fs.readFileSync(source);
  const extractor = await createExtractorFromData({data: buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength)});
  const root = path.resolve(destination);
  if (fs.existsSync(root)) throw new Error('Destination must not exist');
  let total = 0;
  const seen = new Set();
  function target(name) {
    const normalized = name.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.includes(':') || normalized.split('/').includes('..') || normalized.includes('\0')) throw new Error('Unsafe path: ' + name);
    const out = path.resolve(root, normalized);
    if (out !== root && !out.startsWith(root + path.sep)) throw new Error('Escaping path');
    return out;
  }
  const listing = extractor.getFileList();
  if (listing.arcHeader.flags.volume || listing.arcHeader.flags.headerEncrypted) throw new Error('Unsupported archive');
  const headers = [...listing.fileHeaders];
  if (headers.length > 30000) throw new Error('Too many entries');
  for (const header of headers) {
    const out = target(header.name);
    if (seen.has(out) || header.flags.encrypted) throw new Error('Duplicate/encrypted entry');
    seen.add(out);
    total += header.unpSize;
    if (total > 2*1024**3 || header.unpSize > 512*1024**2) throw new Error('Size budget exceeded');
  }
  fs.mkdirSync(root, {recursive: true});
  for (const entry of extractor.extract().files) {
    const out = target(entry.fileHeader.name);
    if (entry.fileHeader.flags.directory) fs.mkdirSync(out, {recursive: true});
    else {
      fs.mkdirSync(path.dirname(out), {recursive: true});
      if (!entry.extraction || entry.extraction.length !== entry.fileHeader.unpSize) throw new Error('Size mismatch');
      fs.writeFileSync(out, entry.extraction, {flag:'wx', mode:0o644});
    }
  }
  console.log(JSON.stringify({entries:headers.length, bytes:total, headers}, null, 2));
}
main().catch(error => { console.error(error); process.exitCode = 1; });

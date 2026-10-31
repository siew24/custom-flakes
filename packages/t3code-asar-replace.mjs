// Replace one exact string in one file inside an asar archive, in place.
//
//   node t3code-asar-replace.mjs <app.asar> <path/in/archive> <find> <replace>
//
// Repacking with the asar CLI would need the unpacked set spelled out again;
// this rewrites only the one file and leaves every other entry as it was.
// Fails unless <find> occurs exactly once, so a new upstream build that moves
// the code breaks the build instead of shipping unpatched.
import { createHash } from "node:crypto";
import fs from "node:fs";

const [archive, target, find, replace] = process.argv.slice(2);
const buf = fs.readFileSync(archive);

// Layout: a pickle holding the header size, then a pickle holding the header
// JSON string, padded to 4 bytes, then the packed file data.
const headerSize = buf.readUInt32LE(4);
const jsonLength = buf.readUInt32LE(12);
const header = JSON.parse(buf.subarray(16, 16 + jsonLength).toString("utf8"));
const dataStart = 8 + headerSize;

const entries = [];
const walk = (node, prefix) => {
  for (const [name, entry] of Object.entries(node.files)) {
    const path = prefix ? `${prefix}/${name}` : name;
    if (entry.files) walk(entry, path);
    else entries.push([path, entry]);
  }
};
walk(header, "");

const file = entries.find(([path]) => path === target)?.[1];
if (!file || file.unpacked || file.link) throw new Error(`${target} is not a packed file in ${archive}`);

const offset = Number(file.offset);
const oldContent = buf.subarray(dataStart + offset, dataStart + offset + file.size);
const findBytes = Buffer.from(find, "utf8");
const at = oldContent.indexOf(findBytes);
if (at === -1 || oldContent.indexOf(findBytes, at + 1) !== -1) {
  throw new Error(`expected exactly one match in ${target}`);
}
const newContent = Buffer.concat([
  oldContent.subarray(0, at),
  Buffer.from(replace, "utf8"),
  oldContent.subarray(at + findBytes.length),
]);

const sha256 = (data) => createHash("sha256").update(data).digest("hex");
const delta = newContent.length - oldContent.length;
for (const [, entry] of entries) {
  if (entry !== file && !entry.unpacked && entry.offset !== undefined && Number(entry.offset) > offset) {
    entry.offset = String(Number(entry.offset) + delta);
  }
}
file.size = newContent.length;
if (file.integrity) {
  const { blockSize } = file.integrity;
  const blocks = [];
  for (let i = 0; i < newContent.length; i += blockSize) blocks.push(sha256(newContent.subarray(i, i + blockSize)));
  file.integrity = { ...file.integrity, hash: sha256(newContent), blocks };
}

const json = Buffer.from(JSON.stringify(header), "utf8");
const jsonPadded = Buffer.alloc(4 + json.length + ((4 - (json.length % 4)) % 4));
jsonPadded.writeUInt32LE(json.length, 0);
json.copy(jsonPadded, 4);
const prefix = Buffer.alloc(16);
prefix.writeUInt32LE(4, 0);
prefix.writeUInt32LE(jsonPadded.length + 4, 4);
prefix.writeUInt32LE(jsonPadded.length, 8);

fs.writeFileSync(
  archive,
  Buffer.concat([
    prefix.subarray(0, 12),
    jsonPadded,
    buf.subarray(dataStart, dataStart + offset),
    newContent,
    buf.subarray(dataStart + offset + oldContent.length),
  ]),
);

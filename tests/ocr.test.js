const test = require("node:test")
const assert = require("node:assert/strict")
const { execFileSync, spawnSync } = require("node:child_process")
const path = require("node:path")
const fs = require("node:fs")
const os = require("node:os")

const ocrScript = path.join(__dirname, "..", "bin", "omarchy-clipboard-ocr")

test("omarchy-clipboard-ocr reports missing language pack clearly", () => {
  const res = spawnSync(ocrScript, ["--langs", "amh", "--image", "/nonexistent.png", "--no-copy"], {
    encoding: "utf8"
  })
  assert.equal(res.status, 11)
  assert.match(res.stderr, /Missing OCR language data: amh/)
})

test("omarchy-clipboard-ocr extracts text from a rendered PNG using tesseract", () => {
  const tmpPng = path.join(os.tmpdir(), `ocr-test-${process.pid}.png`)
  try {
    execFileSync("magick", [
      "-background", "white",
      "-fill", "black",
      "-pointsize", "42",
      "label:COSMIC OCR 2026",
      "-bordercolor", "white",
      "-border", "20",
      tmpPng
    ])
    const out = execFileSync(ocrScript, ["--langs", "eng", "--image", tmpPng, "--no-copy"], {
      encoding: "utf8"
    })
    assert.match(out, /COSMIC/)
    assert.match(out, /2026/)
  } finally {
    if (fs.existsSync(tmpPng)) fs.unlinkSync(tmpPng)
  }
})

test("omarchy-clipboard-ocr handles blank image with exit code 3 (no text)", () => {
  const tmpPng = path.join(os.tmpdir(), `ocr-blank-${process.pid}.png`)
  try {
    execFileSync("magick", ["-size", "120x60", "xc:white", tmpPng])
    const res = spawnSync(ocrScript, ["--langs", "eng", "--image", tmpPng, "--no-copy"], {
      encoding: "utf8"
    })
    assert.equal(res.status, 3)
    assert.match(res.stderr, /No text recognized/)
  } finally {
    if (fs.existsSync(tmpPng)) fs.unlinkSync(tmpPng)
  }
})

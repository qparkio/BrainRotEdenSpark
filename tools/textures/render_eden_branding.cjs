// Rasterize the original vector mark without redrawing its shape or palette.
// Source: https://patchnotes.cdn.gaijin.net/eden/Images/art/logo_e-mark_32_sq.svg
const fs = require('node:fs');
const path = require('node:path');
const sharp = require(process.argv[2] || 'sharp');
const root = path.resolve(__dirname, '../..');

async function main() {
    const ref = path.join(__dirname, 'reference', 'eden_logo.svg');
    if (!fs.existsSync(ref)) {
        const response = await fetch('https://patchnotes.cdn.gaijin.net/eden/Images/art/logo_e-mark_32_sq.svg');
        if (!response.ok) throw new Error(`Logo download failed: ${response.status}`);
        fs.mkdirSync(path.dirname(ref), { recursive: true });
        fs.writeFileSync(ref, await response.text());
    }
    await sharp(ref, { density: 1152 })
        .resize(512, 512)
        .png()
        .toFile(path.join(root, 'assets/textures/eden_logo.png'));
    console.log('Rendered the official EdenSpark vector logo at 512 x 512.');
}

main().catch(error => { console.error(error); process.exitCode = 1; });


#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# 🐜 HormigasAIS — init_lbh_sdk_js.sh
# Inicializa la estructura completa del repo lbh-sdk-js:
#   - src/index.js        (librería principal)
#   - src/constants.js    (TYPE_CODES)
#   - src/exceptions.js   (errores personalizados)
#   - tests/test_sdk.js   (suite de conformidad)
#   - package.json        (configuración npm)
#   - README.md
#   - LICENSE (MIT)
#
# Ejecutar desde: ~/lbh-sdk-js
# ============================================================

set -uo pipefail

echo "🐜 Inicializando lbh-sdk-js — Fase III del SDK HormigasAIS"
echo "------------------------------------------------------------"

# ── 1. package.json ──────────────────────────────────────────
cat > package.json << 'PKGEOF'
{
  "name": "@hormigasais/lbh-sdk",
  "version": "0.3.0",
  "description": "SDK oficial de referencia del protocolo LBH (Lenguaje Binario HormigasAIS) para JavaScript/Node.js",
  "main": "src/index.js",
  "scripts": {
    "test": "node tests/test_sdk.js"
  },
  "keywords": [
    "lbh",
    "hormigasais",
    "protocol",
    "sdk",
    "edge-computing",
    "hmac",
    "binary-protocol",
    "iot",
    "m2m"
  ],
  "author": "Cristhiam Leonardo Hernández Quiñonez (CLHQ) <clhq@hormigasais.com>",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/Thrumanshow/lbh-sdk-js.git"
  },
  "homepage": "https://hormigasais.com",
  "engines": {
    "node": ">=14.0.0"
  }
}
PKGEOF
echo "✅ package.json creado"

# ── 2. src/constants.js ──────────────────────────────────────
mkdir -p src
cat > src/constants.js << 'CONSTEOF'
/**
 * constants.js — TYPE_CODEs oficiales LBH v2.0
 * Propuesta formal de estandarización según LBH_SPEC_v2.0.md
 * En v1.x el campo es libre; en v2.0 se estandariza este enum.
 */

const TYPE_CODES = {
  SEAL: '5345414c', // Emisión de sello criptográfico
  VERI: '56455249', // Verificación de activo sellado
  SYNC: '53594e43', // Sincronización entre nodos
  PING: '50494e47', // Latido / health check
  FUEL: '4655454c', // Feromona de activación
  ACKK: '41434b4b', // Confirmación de recepción
  ERRR: '45525252', // Error / rechazo
};

const TYPE_CODES_REVERSE = Object.fromEntries(
  Object.entries(TYPE_CODES).map(([k, v]) => [v, k])
);

module.exports = { TYPE_CODES, TYPE_CODES_REVERSE };
CONSTEOF
echo "✅ src/constants.js creado"

# ── 3. src/exceptions.js ─────────────────────────────────────
cat > src/exceptions.js << 'EXCEOF'
/**
 * exceptions.js — Errores personalizados LBH SDK
 */

class InvalidPacketError extends Error {
  constructor(message) {
    super(message);
    this.name = 'InvalidPacketError';
  }
}

class InvalidPayloadError extends Error {
  constructor(message) {
    super(message);
    this.name = 'InvalidPayloadError';
  }
}

module.exports = { InvalidPacketError, InvalidPayloadError };
EXCEOF
echo "✅ src/exceptions.js creado"

# ── 4. src/index.js ──────────────────────────────────────────
cat > src/index.js << 'INDEXEOF'
/**
 * lbh-sdk — Lenguaje Binario HormigasAIS SDK (JavaScript)
 * =========================================================
 *
 * SDK de referencia para el Protocolo LBH v2.0.
 * Permite codificar, decodificar, validar y firmar
 * paquetes LBH sin acceso al nodo A16.
 *
 * Especificación: LBH_SPEC_v2.0.md
 * Repo spec:      github.com/Thrumanshow/Lenguaje-Binario-HormigasAIS-
 * Repo SDK JS:    github.com/Thrumanshow/lbh-sdk-js
 * Autor:          Cristhiam Leonardo Hernández Quiñonez (CLHQ)
 * Web:            https://hormigasais.com
 * DOI:            10.5281/zenodo.19177759
 */

'use strict';

const crypto = require('crypto');
const { TYPE_CODES, TYPE_CODES_REVERSE } = require('./constants');
const { InvalidPacketError, InvalidPayloadError } = require('./exceptions');

const VERSION     = '0.3.0';
const SPEC        = 'LBH_SPEC_v2.0';
const AUTHOR      = 'CLHQ — HormigasAIS';

// ─────────────────────────────────────────────────────────────
// ENCODER
// ─────────────────────────────────────────────────────────────
/**
 * Codifica un paquete LBH v2.0.
 *
 * @param {string} header    - 8 chars hex — ID nodo + versión
 * @param {string} typeCode  - 8 chars hex — tipo de operación
 * @param {string} payload   - string UTF-8 — contenido JSON
 * @returns {string} Frame completo como string hexadecimal
 * @throws {InvalidPacketError} si header o typeCode son inválidos
 */
function encodePacket(header, typeCode, payload) {
  if (header.length !== 8) {
    throw new InvalidPacketError(
      `header debe tener 8 chars hex, tiene ${header.length}`
    );
  }
  if (typeCode.length !== 8) {
    throw new InvalidPacketError(
      `typeCode debe tener 8 chars hex, tiene ${typeCode.length}`
    );
  }

  const payloadHex = Buffer.from(payload, 'utf-8').toString('hex');
  const length     = (payloadHex.length / 2).toString(16).padStart(8, '0');
  return `${header}${typeCode}${length}${payloadHex}`;
}

// ─────────────────────────────────────────────────────────────
// DECODER
// ─────────────────────────────────────────────────────────────
/**
 * Decodifica un paquete LBH v2.0.
 *
 * @param {string} frame - string hexadecimal completo
 * @returns {object} { header, typeCode, typeName, length, payload }
 *                   o { error: string } si el frame es inválido
 */
function decodePacket(frame) {
  try {
    if (frame.length < 24) {
      return { error: `Frame demasiado corto: ${frame.length} chars (mínimo 24)` };
    }

    const header      = frame.slice(0, 8);
    const typeCode    = frame.slice(8, 16);
    const lengthHex   = frame.slice(16, 24);
    const payloadHex  = frame.slice(24);

    const payload  = Buffer.from(payloadHex, 'hex').toString('utf-8');
    const length   = parseInt(lengthHex, 16);
    const typeName = TYPE_CODES_REVERSE[typeCode] || null;

    return { header, typeCode, typeName, length, payload };
  } catch (e) {
    return { error: e.message };
  }
}

// ─────────────────────────────────────────────────────────────
// VALIDADOR
// ─────────────────────────────────────────────────────────────
/**
 * Valida un paquete LBH v2.0 según LBH_SPEC_v2.0 §6.
 *
 * @param {string} frame - string hexadecimal completo
 * @returns {{ valid: boolean, reason: string|null }}
 */
function validatePacket(frame) {
  if (frame.length < 24) {
    return { valid: false, reason: `Longitud mínima no cumplida: ${frame.length} < 24` };
  }

  let declaredLength;
  try {
    declaredLength = parseInt(frame.slice(16, 24), 16);
  } catch (e) {
    return { valid: false, reason: 'Campo LENGTH no es hex válido' };
  }

  let payloadBytes;
  try {
    payloadBytes = Buffer.from(frame.slice(24), 'hex');
  } catch (e) {
    return { valid: false, reason: 'PAYLOAD no es hex válido' };
  }

  try {
    payloadBytes.toString('utf-8');
  } catch (e) {
    return { valid: false, reason: 'PAYLOAD no decodifica como UTF-8' };
  }

  if (declaredLength !== payloadBytes.length) {
    return {
      valid: false,
      reason: `LENGTH declarado (${declaredLength}) no coincide con bytes reales (${payloadBytes.length})`
    };
  }

  return { valid: true, reason: null };
}

// ─────────────────────────────────────────────────────────────
// SEGURIDAD — HMAC-SHA256
// ─────────────────────────────────────────────────────────────
/**
 * Genera HMAC-SHA256 para un mensaje LBH.
 *
 * @param {string} message   - frame o mensaje a firmar
 * @param {string} secretKey - clave secreta (cargar desde env LBH_SECRET)
 * @returns {string} hexdigest de 64 chars
 */
function generateHmac(message, secretKey) {
  const key = secretKey || process.env.LBH_SECRET;
  if (!key) {
    throw new Error(
      'Se requiere secretKey o la variable de entorno LBH_SECRET. ' +
      'Nunca hardcodees la clave.'
    );
  }
  return crypto
    .createHmac('sha256', key)
    .update(message, 'utf-8')
    .digest('hex');
}

/**
 * Valida un HMAC-SHA256 usando comparación segura (timing-safe).
 *
 * @param {string} message      - mensaje original
 * @param {string} secretKey    - clave secreta
 * @param {string} receivedHmac - HMAC a validar
 * @returns {boolean}
 */
function validateHmac(message, secretKey, receivedHmac) {
  const expected = generateHmac(message, secretKey);
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'hex'),
      Buffer.from(receivedHmac, 'hex')
    );
  } catch (e) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────
// SELLO DE ACTIVOS
// ─────────────────────────────────────────────────────────────
/**
 * Genera un sello LBH para un activo digital.
 *
 * @param {Buffer|string} content - contenido binario del activo
 * @param {string} owner          - propietario (ej: "CLHQ")
 * @param {string} secretKey      - clave HMAC (o usa LBH_SECRET del env)
 * @returns {object} sello con sha256, timestamp, firma, owner
 */
function sealAsset(content, owner, secretKey) {
  const key = secretKey || process.env.LBH_SECRET;
  if (!key) {
    throw new Error('Se requiere secretKey o LBH_SECRET en el entorno.');
  }

  const buf       = Buffer.isBuffer(content) ? content : Buffer.from(content);
  const sha256    = crypto.createHash('sha256').update(buf).digest('hex');
  const timestamp = Math.floor(Date.now() / 1000);
  const payloadFirma = `${sha256}|${owner}|${timestamp}`;

  const firma = crypto
    .createHmac('sha256', key)
    .update(payloadFirma, 'utf-8')
    .digest('hex');

  return {
    sha256,
    owner,
    timestamp,
    payloadFirma,
    firma,
    versionLbh: SPEC,
    autoridad:  'CLHQ',
  };
}

/**
 * Verifica la integridad y autenticidad de un sello LBH.
 *
 * @param {Buffer|string} content - contenido original del activo
 * @param {object} sello          - objeto retornado por sealAsset()
 * @param {string} secretKey      - clave HMAC
 * @returns {{ valid: boolean, reason: string|null }}
 */
function verifySeal(content, sello, secretKey) {
  const key = secretKey || process.env.LBH_SECRET;
  if (!key) {
    throw new Error('Se requiere secretKey o LBH_SECRET en el entorno.');
  }

  const buf         = Buffer.isBuffer(content) ? content : Buffer.from(content);
  const sha256Actual = crypto.createHash('sha256').update(buf).digest('hex');

  if (sha256Actual !== sello.sha256) {
    return { valid: false, reason: 'SHA256 no coincide — activo modificado' };
  }

  const firmaEsperada = crypto
    .createHmac('sha256', key)
    .update(sello.payloadFirma, 'utf-8')
    .digest('hex');

  try {
    const match = crypto.timingSafeEqual(
      Buffer.from(firmaEsperada, 'hex'),
      Buffer.from(sello.firma, 'hex')
    );
    if (!match) {
      return { valid: false, reason: 'HMAC inválido — firma no auténtica' };
    }
  } catch (e) {
    return { valid: false, reason: 'Error comparando firmas' };
  }

  return { valid: true, reason: null };
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
/**
 * Genera un HEADER LBH de 8 chars hex.
 *
 * @param {string} nodeId  - ID del nodo (ej: "A16")
 * @param {string} version - versión (ej: "00")
 * @returns {string} 8 chars hex
 */
function makeHeader(nodeId = 'A16', version = '00') {
  const idHex  = Buffer.from(nodeId,  'utf-8').toString('hex').slice(0, 4).padEnd(4, '0');
  const verHex = Buffer.from(version, 'utf-8').toString('hex').slice(0, 4).padEnd(4, '0');
  return `${idHex}${verHex}`;
}

/**
 * Retorna el hex de un TYPE_CODE por nombre.
 *
 * @param {string} name - "SEAL", "VERI", "SYNC", etc.
 * @returns {string} 8 chars hex
 * @throws {Error} si el nombre no está en TYPE_CODES
 */
function typeCode(name) {
  if (!TYPE_CODES[name]) {
    throw new Error(
      `TYPE_CODE '${name}' no reconocido. Válidos: ${Object.keys(TYPE_CODES).join(', ')}`
    );
  }
  return TYPE_CODES[name];
}

// ─────────────────────────────────────────────────────────────
// EXPORTS
// ─────────────────────────────────────────────────────────────
module.exports = {
  VERSION,
  SPEC,
  AUTHOR,
  TYPE_CODES,
  TYPE_CODES_REVERSE,
  encodePacket,
  decodePacket,
  validatePacket,
  generateHmac,
  validateHmac,
  sealAsset,
  verifySeal,
  makeHeader,
  typeCode,
  InvalidPacketError,
  InvalidPayloadError,
};
INDEXEOF
echo "✅ src/index.js creado"

# ── 5. tests/test_sdk.js ─────────────────────────────────────
mkdir -p tests
cat > tests/test_sdk.js << 'TESTEOF'
/**
 * test_sdk.js — Suite de conformidad LBH_SPEC_v2.0 (JavaScript)
 * Verifica que lbh-sdk-js cumple la especificación formal.
 */

'use strict';

const sdk = require('../src/index');

let passed = 0;
let failed = 0;

function assert(condition, testName, detail = '') {
  if (condition) {
    console.log(`✅ ${testName}`);
    passed++;
  } else {
    console.log(`❌ ${testName}${detail ? ': ' + detail : ''}`);
    failed++;
  }
}

// ── Tests de encoding ────────────────────────────────────────
function test_encode_decode_roundtrip() {
  const header  = '41313600';
  const tc      = sdk.TYPE_CODES.SEAL;
  const payload = '{"asset":"test.pdf","owner":"CLHQ"}';
  const frame   = sdk.encodePacket(header, tc, payload);
  const decoded = sdk.decodePacket(frame);

  assert(decoded.header   === header,  'encode_decode: header correcto');
  assert(decoded.typeCode === tc,      'encode_decode: typeCode correcto');
  assert(decoded.typeName === 'SEAL',  'encode_decode: typeName correcto');
  assert(decoded.payload  === payload, 'encode_decode: payload correcto');
}

// ── Tests de validación ──────────────────────────────────────
function test_validate_valid_packet() {
  const frame  = sdk.encodePacket('41313600', sdk.TYPE_CODES.PING, 'ping');
  const result = sdk.validatePacket(frame);
  assert(result.valid === true, 'validate: paquete válido aceptado');
}

function test_validate_short_frame() {
  const result = sdk.validatePacket('41313600');
  assert(result.valid === false, 'validate: frame corto rechazado');
  assert(result.reason.includes('24'), 'validate: reason menciona mínimo 24');
}

function test_validate_length_mismatch() {
  // LENGTH declara 1 byte pero payload tiene más
  const result = sdk.validatePacket('4131360053594e430000000141');
  assert(result.valid === false, 'validate: length mismatch rechazado');
}

// ── Tests de TYPE_CODES ──────────────────────────────────────
function test_type_codes() {
  assert(sdk.typeCode('SEAL') === '5345414c', 'typeCode: SEAL correcto');
  assert(sdk.typeCode('VERI') === '56455249', 'typeCode: VERI correcto');
  assert(sdk.typeCode('PING') === '50494e47', 'typeCode: PING correcto');
  assert(sdk.typeCode('SYNC') === '53594e43', 'typeCode: SYNC correcto');
}

function test_type_code_invalid() {
  try {
    sdk.typeCode('INVALID');
    assert(false, 'typeCode: inválido debería lanzar error');
  } catch (e) {
    assert(true, 'typeCode: inválido lanza error correctamente');
  }
}

// ── Tests de makeHeader ──────────────────────────────────────
function test_make_header() {
  const h = sdk.makeHeader('A16', '00');
  assert(h.length === 8, `makeHeader: longitud 8 chars (tiene ${h.length})`);
}

// ── Tests de HMAC ────────────────────────────────────────────
function test_hmac_generate_validate() {
  const key     = 'test-secret-lbh';
  const message = 'frame-lbh-test';
  const digest  = sdk.generateHmac(message, key);

  assert(digest.length === 64, 'hmac: digest tiene 64 chars');
  assert(sdk.validateHmac(message, key, digest), 'hmac: validación correcta');
  assert(!sdk.validateHmac(message, key, '0'.repeat(64)), 'hmac: digest incorrecto rechazado');
}

function test_hmac_no_key() {
  delete process.env.LBH_SECRET;
  try {
    sdk.generateHmac('test', null);
    assert(false, 'hmac: sin clave debería lanzar error');
  } catch (e) {
    assert(true, 'hmac: sin clave lanza error correctamente');
  }
}

// ── Tests de sello ───────────────────────────────────────────
function test_seal_and_verify() {
  const key     = 'test-secret-lbh';
  const content = Buffer.from('documento de prueba HormigasAIS');
  const sello   = sdk.sealAsset(content, 'CLHQ', key);

  assert(sello.sha256.length === 64, 'seal: sha256 tiene 64 chars');
  assert(sello.firma.length  === 64, 'seal: firma tiene 64 chars');
  assert(sello.owner         === 'CLHQ', 'seal: owner correcto');

  const result = sdk.verifySeal(content, sello, key);
  assert(result.valid === true, 'seal: verificación correcta');
}

function test_verify_tampered_content() {
  const key      = 'test-secret-lbh';
  const content  = Buffer.from('contenido original');
  const sello    = sdk.sealAsset(content, 'CLHQ', key);
  const tampered = Buffer.from('contenido modificado');

  const result = sdk.verifySeal(tampered, sello, key);
  assert(result.valid  === false,    'seal: contenido modificado rechazado');
  assert(result.reason.includes('SHA256'), 'seal: reason menciona SHA256');
}

// ── Tests de excepciones ─────────────────────────────────────
function test_invalid_packet_error() {
  try {
    sdk.encodePacket('1234', sdk.TYPE_CODES.SEAL, 'payload');
    assert(false, 'exception: header corto debería lanzar error');
  } catch (e) {
    assert(
      e instanceof sdk.InvalidPacketError,
      'exception: InvalidPacketError lanzado correctamente'
    );
  }
}

// ── Correr todos los tests ───────────────────────────────────
console.log('');
console.log('🐜 Suite de conformidad LBH_SPEC_v2.0 — JavaScript SDK');
console.log('------------------------------------------------------------');

test_encode_decode_roundtrip();
test_validate_valid_packet();
test_validate_short_frame();
test_validate_length_mismatch();
test_type_codes();
test_type_code_invalid();
test_make_header();
test_hmac_generate_validate();
test_hmac_no_key();
test_seal_and_verify();
test_verify_tampered_content();
test_invalid_packet_error();

console.log('');
console.log('------------------------------------------------------------');
console.log(`Resultado: ${passed}/${passed + failed} tests pasaron`);
if (failed === 0) {
  console.log('✅ SDK conforme con LBH_SPEC_v2.0');
  process.exit(0);
} else {
  console.log(`❌ ${failed} test(s) fallaron — revisar antes de publicar`);
  process.exit(1);
}
TESTEOF
echo "✅ tests/test_sdk.js creado"

# ── 6. README.md ─────────────────────────────────────────────
cat > README.md << 'READMEOF'
# lbh-sdk-js 🐜

**SDK oficial del Protocolo LBH v2.0 para JavaScript/Node.js — HormigasAIS**

Implementación pública basada en la especificación LBH_SPEC_v2.0.md.

## Instalación

```bash
npm install @hormigasais/lbh-sdk
```

O sin npm:
```bash
git clone https://github.com/Thrumanshow/lbh-sdk-js.git
```

## Uso rápido

```javascript
const sdk = require('@hormigasais/lbh-sdk');

// Codificar un paquete SEAL
const frame = sdk.encodePacket(
  sdk.makeHeader('A16', '00'),
  sdk.typeCode('SEAL'),
  '{"asset":"documento.pdf","owner":"CLHQ"}'
);

// Decodificar
const decoded = sdk.decodePacket(frame);
console.log(decoded.typeName);  // → "SEAL"
console.log(decoded.payload);   // → '{"asset":"documento.pdf",...}'

// Validar
const { valid } = sdk.validatePacket(frame);
console.log(valid);  // → true

// Sellar un activo
const fs    = require('fs');
const sello = sdk.sealAsset(fs.readFileSync('documento.pdf'), 'CLHQ', 'tu_clave');

// Verificar
const { valid: ok } = sdk.verifySeal(fs.readFileSync('documento.pdf'), sello, 'tu_clave');
```

## Tests

```bash
node tests/test_sdk.js
```

## Documentación relacionada

- **Especificación LBH_SPEC_v2.0**: [Lenguaje-Binario-HormigasAIS-](https://github.com/Thrumanshow/Lenguaje-Binario-HormigasAIS-)
- **SDK Python**: [lbh-sdk](https://github.com/Thrumanshow/lbh-sdk) — `pip install lbh-sdk`
- **Web**: [hormigasais.com](https://hormigasais.com)
- **DOI**: 10.5281/zenodo.19177759

## Autor

**Cristhiam Leonardo Hernández Quiñonez (CLHQ)**
Fundador de HormigasAIS — Nodo A16 · San Miguel · El Salvador

CERT::LBH-SDK-JS-V2-CLHQ
READMEOF
echo "✅ README.md creado"

# ── 7. LICENSE ────────────────────────────────────────────────
cat > LICENSE << 'LICEOF'
MIT License

Copyright (c) 2026 Cristhiam Leonardo Hernández Quiñonez (CLHQ)
HormigasAIS — Nodo A16-SanMiguel-SV

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICEOF
echo "✅ LICENSE creado"

# ── 8. .gitignore ─────────────────────────────────────────────
cat > .gitignore << 'GITEOF'
node_modules/
.npmrc
*.log
GITEOF
echo "✅ .gitignore creado"

# ── 9. Correr tests ──────────────────────────────────────────
echo ""
echo "------------------------------------------------------------"
echo "🔍 Corriendo tests de conformidad..."
echo "------------------------------------------------------------"
node tests/test_sdk.js

EXIT_TESTS=$?
if [ $EXIT_TESTS -ne 0 ]; then
  echo "❌ Tests fallaron. NO se hará commit hasta que pasen."
  exit 1
fi

# ── 10. Commit y push ────────────────────────────────────────
echo ""
echo "🚀 Tests OK — haciendo commit..."

git config user.email "clhq@hormigasais.com"
git config user.name "CLHQ — HormigasAIS"

git add .
git commit -m "🐜 INIT: lbh-sdk-js v0.3.0 — SDK JavaScript conforme LBH_SPEC_v2.0 (encode/decode/validate/hmac/seal)"
git push origin main

echo ""
echo "------------------------------------------------------------"
echo "✅ lbh-sdk-js publicado en github.com/Thrumanshow/lbh-sdk-js"
echo ""
echo "Estructura:"
echo "  src/"
echo "    index.js       ← módulo principal"
echo "    constants.js   ← TYPE_CODES"
echo "    exceptions.js  ← errores personalizados"
echo "  tests/"
echo "    test_sdk.js    ← suite de conformidad"
echo "  package.json"
echo "  README.md"
echo "  LICENSE (MIT)"
echo "------------------------------------------------------------"


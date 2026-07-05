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
  const result = sdk.validatePacket('4131360053594e430000000541');
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

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

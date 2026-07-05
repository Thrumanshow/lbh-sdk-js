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

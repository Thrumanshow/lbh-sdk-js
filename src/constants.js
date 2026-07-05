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

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

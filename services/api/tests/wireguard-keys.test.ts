import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  deriveWireGuardPublicKey,
  generateWireGuardKeyPair,
} from '../src/common/vpn/wireguard-keys.js';

describe('WireGuard X25519 key derivation', () => {
  it('matches the RFC 7748 Alice public-key test vector', () => {
    const privateKey = Buffer.from(
      '77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a',
      'hex',
    ).toString('base64');
    const expectedPublicKey = Buffer.from(
      '8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a',
      'hex',
    ).toString('base64');

    assert.equal(deriveWireGuardPublicKey(privateKey), expectedPublicKey);
  });

  it('generates a 32-byte private key and a matching derived public key', () => {
    const pair = generateWireGuardKeyPair();
    assert.equal(Buffer.from(pair.privateKey, 'base64').length, 32);
    assert.equal(Buffer.from(pair.publicKey, 'base64').length, 32);
    assert.equal(
      deriveWireGuardPublicKey(pair.privateKey),
      pair.publicKey,
    );
  });

  it('rejects non-canonical or incorrectly sized private keys', () => {
    assert.throws(() => deriveWireGuardPublicKey('not-a-key'));
    assert.throws(() => deriveWireGuardPublicKey(Buffer.alloc(31).toString('base64')));
  });
});

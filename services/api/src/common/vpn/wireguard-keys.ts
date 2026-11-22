import { createPrivateKey, createPublicKey, randomBytes } from 'node:crypto';

const X25519_PKCS8_PREFIX = Buffer.from('302e020100300506032b656e04220420', 'hex');
const X25519_SPKI_PREFIX = Buffer.from('302a300506032b656e032100', 'hex');

export type WireGuardKeyPair = {
  privateKey: string;
  publicKey: string;
};

/**
 * Derive the WireGuard-compatible X25519 public key from a raw 32-byte
 * private key. Node's X25519 implementation applies RFC 7748 scalar
 * clamping during key derivation.
 */
export function deriveWireGuardPublicKey(privateKeyBase64: string): string {
  const privateKeyBytes = Buffer.from(privateKeyBase64, 'base64');
  if (
    privateKeyBytes.length !== 32 ||
    privateKeyBytes.toString('base64') !== privateKeyBase64
  ) {
    throw new Error('A WireGuard private key must be canonical base64 for 32 bytes.');
  }

  const privateKey = createPrivateKey({
    key: Buffer.concat([X25519_PKCS8_PREFIX, privateKeyBytes]),
    format: 'der',
    type: 'pkcs8',
  });
  const publicDer = createPublicKey(privateKey).export({
    format: 'der',
    type: 'spki',
  }) as Buffer;

  if (
    publicDer.length !== X25519_SPKI_PREFIX.length + 32 ||
    !publicDer.subarray(0, X25519_SPKI_PREFIX.length).equals(X25519_SPKI_PREFIX)
  ) {
    throw new Error('Unexpected X25519 public key encoding.');
  }

  return publicDer.subarray(X25519_SPKI_PREFIX.length).toString('base64');
}

export function generateWireGuardKeyPair(): WireGuardKeyPair {
  const privateKey = randomBytes(32).toString('base64');
  return {
    privateKey,
    publicKey: deriveWireGuardPublicKey(privateKey),
  };
}

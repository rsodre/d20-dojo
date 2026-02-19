import { BigNumberish, shortString } from "starknet";

export const bigintToHex = (v: BigNumberish): `0x${string}` => (!v ? '0x0' : `0x${BigInt(v).toString(16)}`)
export const bigintToHex64 = (v: BigNumberish): `0x${string}` => (!v ? '0x0' : `0x${BigInt(v).toString(16).padStart(16, '0')}`)
export const bigintToHex128 = (v: BigNumberish): `0x${string}` => (!v ? '0x0' : `0x${BigInt(v).toString(16).padStart(32, '0')}`)
export const bigintToAddress = (v: BigNumberish): `0x${string}` => (!v ? '0x0' : `0x${BigInt(v).toString(16).padStart(64, '0')}`)
export const bigintEquals = (a: BigNumberish | undefined, b: BigNumberish | undefined): boolean => (a != undefined && b != undefined && BigInt(a) == BigInt(b))

export const stringToFelt = (v: string): BigNumberish => (v ? shortString.encodeShortString(v) : '0x0')
export const feltToString = (v: BigNumberish): string => (BigInt(v) > 0n ? shortString.decodeShortString(bigintToHex(v)) : '')

export const isPositiveBigint = (v: BigNumberish | null | undefined): boolean => {
  try { return (v != null && BigInt(v) > 0n) } catch { return false }
}

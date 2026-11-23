# Wire fixtures

Golden bodies of every control message in [PROTOCOL.md](../PROTOCOL.md) §5, one file per type, exactly as the
producing side emits them today. Both implementations test against the same files, so a change on one side that
the other cannot read fails a test instead of a call:

- Android (the phone): `android/core/src/test/java/app/tether/core/ContractTest.kt` checks that every body a client
  sends has the fields and JSON types `Hub` reads, that the bodies built by `Sms`, `Contact`, `CallEntry`, `CallInfo`
  and `idRanges` equal their fixtures, and that `T` and §5 name the same types.
- iPhone: `ios/TetherCore/Tests/TetherCoreTests/ContractTests.swift` decodes every body the iPhone receives, encodes
  every body it sends back to the fixture, and checks that `MsgType`, Kotlin `T`, §5 and the fixtures agree.

## Format

```json
{ "t": "audio.start", "dir": "phone-to-client", "variants": { "full": { ... }, "old": { ... } } }
```

`dir` is `phone-to-client`, `client-to-phone` or `both`. Variants hold the body (`b`) only:

- `full`: a current producer, every optional field set.
- `old`: an older producer without the optional fields. Kept so that newer apps still read older ones.
- `unknown`: a body with an extra field from some future producer; receivers must ignore it.
- other names: further shapes of the same message (`ended`, `thread`, `mute`, ...).

Numbers are `+1000000000x`, names made up.

## Rules

- Change a body: update its fixture and PROTOCOL.md in the same commit.
- A new type: add it to `T`, `MsgType`, §5 and a fixture here (the parity tests fail until all four agree).
- Never delete or rewrite an `old` variant while an installed app may still send it; add a new variant instead.

# godot-storekit

Native iOS StoreKit plugin for Oil Due unlock (same Taptico Godot 4.6 layout).

## Product ID

`unlock_oil_due`

## Build (macOS only)

```bash
cd native/godot-storekit
python3 build.py
```

Outputs `ios/plugins/storekit/StoreKit.xcframework`.

## Godot integration

Enable the **StoreKit** plugin in the iOS export preset. Use the `Purchase` autoload.

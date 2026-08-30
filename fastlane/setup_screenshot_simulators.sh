#!/usr/bin/env bash
set -euo pipefail

# App Store screenshot sizes: iPhone 6.9" + iPad 13".
# Uses dedicated simulator names so Snapshot does not collide with other devices.

IOS_RUNTIME="${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-0}"
IPHONE_DEVICE_TYPE="${IPHONE_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max}"
IPAD_DEVICE_TYPE="${IPAD_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB}"
IPHONE_NAME="Postal Screenshots iPhone"
IPAD_NAME="Postal Screenshots iPad"

delete_simulator_by_name() {
  local name="$1"
  local udid

  udid="$(xcrun simctl list devices -j | python3 -c "
import json, sys

name = sys.argv[1]
for devices in json.load(sys.stdin).get('devices', {}).values():
    for device in devices:
        if device.get('name') == name and not device.get('isUnavailable', False):
            print(device['udid'])
            raise SystemExit(0)
" "$name" 2>/dev/null || true)"

  if [[ -n "${udid:-}" ]]; then
    echo "Deleting existing simulator: ${name} (${udid})"
    xcrun simctl delete "${udid}"
  fi
}

create_simulator() {
  local name="$1"
  local device_type="$2"

  echo "Creating ${name} (${device_type}) on ${IOS_RUNTIME}"
  xcrun simctl create "${name}" "${device_type}" "${IOS_RUNTIME}"
}

delete_simulator_by_name "${IPHONE_NAME}"
delete_simulator_by_name "${IPAD_NAME}"
create_simulator "${IPHONE_NAME}" "${IPHONE_DEVICE_TYPE}"
create_simulator "${IPAD_NAME}" "${IPAD_DEVICE_TYPE}"

echo "Screenshot simulators ready."

Connect to Android device wirelessly via ADB.

User input: $ARGUMENTS

Parse the input to extract:
- **Pairing code**: 6-digit number
- **IP:port**: the device's pairing address (e.g., 192.168.1.100:37123)

Then execute these steps in order:

1. Kill existing ADB server to avoid stale connections:
   ```
   adb kill-server
   adb start-server
   ```

2. Pair with the device using the pairing code and address:
   ```
   adb pair <ip:port> <pairing-code>
   ```
   Wait for "Successfully paired" confirmation.

3. After successful pairing, ask the user for the **connect port** (this is different from the pairing port — shown on the device's wireless debugging main screen).

4. Connect to the device:
   ```
   adb connect <ip:connect-port>
   ```

5. Verify connection:
   ```
   adb devices
   ```

6. Report the result — show connected device info or error details.

**Example usage:** `/connect-device 123456 192.168.1.100:37123`

If the user only provides partial info, ask for the missing parts.
If pairing fails, suggest the user to:
- Check that wireless debugging is enabled on the device
- Verify the pairing code hasn't expired (codes refresh periodically)
- Ensure both devices are on the same network

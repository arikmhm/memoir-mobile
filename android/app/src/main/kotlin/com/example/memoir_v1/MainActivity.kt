package com.example.memoir_v1

import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

/**
 * Custom MethodChannel for efficient Bluetooth thermal printing.
 *
 * Bypasses [print_bluetooth_thermal]'s O(n²) `writeBytes` which builds
 * a ByteArray via `+=` in a forEach loop (57 K iterations → ~1.6 GB
 * intermediate allocations → ART GC storms → print stuttering).
 *
 * This channel receives `Uint8List` from Dart which arrives as a native
 * `ByteArray` (zero-copy via Flutter's StandardMethodCodec), then writes
 * it to the Bluetooth socket in 16 KB chunks — O(n) with no boxing.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val BT_CHANNEL = "memoir/bluetooth_print"
        private const val USB_CHANNEL = "memoir/usb_print"
        private const val SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
        private const val CHUNK_SIZE = 8 * 1024 // 8 KB — keeps printer buffer fed
        private const val INTER_CHUNK_MS = 2L  // minimal pacing; RFCOMM flow-control does the rest
        private const val USB_TIMEOUT_MS = 5000
        private const val ACTION_USB_PERMISSION = "com.example.memoir_v1.USB_PERMISSION"
    }

    // ── Bluetooth state ──
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    // ── Bluetooth discovery state ──
    private val discoveredPrinters = mutableListOf<Map<String, String>>()
    private var discoveryResult: MethodChannel.Result? = null
    private var discoveryReceiver: BroadcastReceiver? = null

    // ── USB state ──
    private var usbConnection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var usbEndpointOut: UsbEndpoint? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Bluetooth SPP channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val mac = call.argument<String>("mac")
                        if (mac == null) {
                            result.success(false)
                        } else {
                            connectPrinter(mac, result)
                        }
                    }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.success(false)
                        } else {
                            writeBytes(bytes, result)
                        }
                    }
                    "disconnect" -> disconnectPrinter(result)
                    "pairedDevices" -> bluetoothPairedDevices(result)
                    "discoverPrinters" -> bluetoothDiscoverPrinters(result)
                    "quickPing" -> {
                        val mac = call.argument<String>("mac")
                        if (mac == null) result.success(false)
                        else bluetoothQuickPing(mac, result)
                    }
                    "isEnabled" -> bluetoothIsEnabled(result)
                    else -> result.notImplemented()
                }
            }

        // ── USB Host channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listDevices" -> usbListDevices(result)
                    "listAllDevices" -> usbListAllDevices(result)
                    "connect" -> {
                        val vendorProductId = call.argument<String>("vendorProductId")
                        if (vendorProductId == null) {
                            result.success(false)
                        } else {
                            usbConnect(vendorProductId, result)
                        }
                    }
                    "write" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.success(false)
                        } else {
                            usbWrite(bytes, result)
                        }
                    }
                    "disconnect" -> usbDisconnect(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun connectPrinter(mac: String, result: MethodChannel.Result) {
        Thread {
            try {
                // Close stale connections.
                closeSilently()

                val adapter = BluetoothAdapter.getDefaultAdapter()
                adapter?.cancelDiscovery()
                val device = adapter?.getRemoteDevice(mac)
                val socket = device?.createRfcommSocketToServiceRecord(
                    UUID.fromString(SPP_UUID)
                )
                socket?.connect()
                bluetoothSocket = socket
                outputStream = socket?.outputStream
                runOnUiThread { result.success(socket?.isConnected == true) }
            } catch (e: Exception) {
                closeSilently()
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    /**
     * Write raw bytes to the Bluetooth socket with pacing.
     *
     * [bytes] arrives as a native ByteArray from Dart's Uint8List —
     * no boxing, no intermediate copies, no O(n²) concatenation.
     *
     * Data is written in 2 KB chunks with 8 ms pacing between chunks.
     * This matches the BT SPP throughput (~200 KB/s) so data arrives
     * at the printer at a rate the thermal head can consume it.
     *
     * Without pacing, the OS BT buffer fills instantly and the RFCOMM
     * layer drains it in bursts — causing the printer to receive data
     * unevenly, leading to thermal head stalls and horizontal lines.
     *
     * After the last chunk, a 50 ms drain delay ensures the BT stack
     * finishes transmitting the final ~2 KB before the caller proceeds.
     */
    private fun writeBytes(bytes: ByteArray, result: MethodChannel.Result) {
        val os = outputStream
        if (os == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                var offset = 0
                while (offset < bytes.size) {
                    val end = minOf(offset + CHUNK_SIZE, bytes.size)
                    os.write(bytes, offset, end - offset)
                    os.flush()
                    offset = end
                    // Pace: let BT radio transmit this chunk before
                    // queuing the next. 2 KB / 200 KB/s = 10 ms;
                    // 8 ms keeps the buffer topped off without gaps.
                    if (offset < bytes.size) {
                        Thread.sleep(INTER_CHUNK_MS)
                    }
                }
                // Final drain: wait for last 2 KB to leave the radio.
                // 2 KB / 200 KB/s worst-case = ~10 ms; 50 ms is safe.
                Thread.sleep(50L)

                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                closeSilently()
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    private fun disconnectPrinter(result: MethodChannel.Result) {
        closeSilently()
        result.success(true)
    }

    private fun closeSilently() {
        try { outputStream?.close() } catch (_: Exception) {}
        try { bluetoothSocket?.close() } catch (_: Exception) {}
        outputStream = null
        bluetoothSocket = null
    }

    /**
     * Return Bluetooth devices paired in Android settings that are likely
     * printers — filtered to IMAGING major class (thermal printers, label
     * printers, POS printers all register as IMAGING = 0x0600).
     *
     * Excluding phones, headsets, speakers etc. prevents false positives
     * where a non-printer device accepts RFCOMM connections and passes
     * the validation step.
     *
     * Devices with UNCATEGORIZED major class (0x0000) are also included
     * as a fallback for cheap printers that don't set their class properly.
     */
    @Suppress("MissingPermission")
    private fun bluetoothPairedDevices(result: MethodChannel.Result) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val devices = adapter?.bondedDevices
                ?.filter { device ->
                    val major = device.bluetoothClass?.majorDeviceClass
                    major == BluetoothClass.Device.Major.IMAGING ||
                    major == BluetoothClass.Device.Major.UNCATEGORIZED
                }
                ?.map { device ->
                    mapOf("name" to (device.name ?: "Unknown"), "mac" to device.address)
                } ?: emptyList()
            result.success(devices)
        } catch (e: Exception) {
            result.success(emptyList<Any>())
        }
    }

    /**
     * Real Bluetooth discovery — broadcasts inquiry and collects devices
     * that are actively responding (~12 s). Only returns IMAGING and
     * UNCATEGORIZED class devices (thermal printers).
     *
     * Unlike pairedDevices() this only shows printers that are physically
     * on and in range — not stale bonded entries.
     */
    @Suppress("MissingPermission")
    private fun bluetoothDiscoverPrinters(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.success(emptyList<Any>())
            return
        }

        // Cancel any ongoing discovery and clean up stale state.
        if (adapter.isDiscovering) adapter.cancelDiscovery()
        discoveryReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            discoveryReceiver = null
        }
        discoveredPrinters.clear()
        discoveryResult = result

        discoveryReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        @Suppress("DEPRECATION")
                        val device: BluetoothDevice? =
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                intent.getParcelableExtra(
                                    BluetoothDevice.EXTRA_DEVICE,
                                    BluetoothDevice::class.java,
                                )
                            } else {
                                intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                            }
                        device?.let { d ->
                            val major = d.bluetoothClass?.majorDeviceClass
                            if (major == BluetoothClass.Device.Major.IMAGING ||
                                major == BluetoothClass.Device.Major.UNCATEGORIZED
                            ) {
                                val mac = d.address
                                if (discoveredPrinters.none { it["mac"] == mac }) {
                                    discoveredPrinters.add(
                                        mapOf("name" to (d.name ?: "Unknown"), "mac" to mac)
                                    )
                                }
                            }
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        unregisterReceiver(this)
                        discoveryReceiver = null
                        runOnUiThread {
                            discoveryResult?.success(discoveredPrinters.toList())
                            discoveryResult = null
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        registerReceiver(discoveryReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        adapter.startDiscovery()
    }

    /**
     * Quick BT reachability check with a hard 5-second timeout.
     *
     * Android's default RFCOMM connect() timeout is 12–30 s, which is too
     * long for a page-open check. We force a 5 s limit by closing the socket
     * from a timeout thread — closing unblocks connect() with IOException,
     * giving us a reliable "not reachable" result without waiting forever.
     *
     * Returns true only if RFCOMM connects within 5 s; false otherwise.
     */
    @Suppress("MissingPermission")
    private fun bluetoothQuickPing(mac: String, result: MethodChannel.Result) {
        Thread {
            try {
                val adapter = BluetoothAdapter.getDefaultAdapter()
                adapter?.cancelDiscovery()
                val device = adapter?.getRemoteDevice(mac)
                val socket = device?.createRfcommSocketToServiceRecord(
                    UUID.fromString(SPP_UUID)
                )

                // Close socket after 5 s to unblock connect() if no response.
                val timeoutThread = Thread {
                    try {
                        Thread.sleep(5_000L)
                        socket?.close()
                    } catch (_: InterruptedException) {}
                }
                timeoutThread.isDaemon = true
                timeoutThread.start()

                try {
                    socket?.connect()
                    timeoutThread.interrupt()   // Connected — cancel the timeout.
                    try { socket?.close() } catch (_: Exception) {}
                    runOnUiThread { result.success(true) }
                } catch (_: Exception) {
                    runOnUiThread { result.success(false) }
                }
            } catch (_: Exception) {
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    /** Return true if the device Bluetooth adapter is currently enabled. */
    private fun bluetoothIsEnabled(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        result.success(adapter?.isEnabled == true)
    }

    // ════════════════════════════════════════════════════════════════
    // USB Host API — Bulk Transfer for thermal printers via OTG
    // ════════════════════════════════════════════════════════════════

    /**
     * List USB devices that look like printers (class 7) or have
     * a bulk OUT endpoint we can write ESC/POS data to.
     *
     * Returns a list of maps: {deviceId, vendorId, productId, deviceName}.
     */
    private fun usbListDevices(result: MethodChannel.Result) {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        val printers = mutableListOf<Map<String, Any>>()

        for ((_, device) in manager.deviceList) {
            // Accept USB Printer Class (7) or any device with bulk OUT
            if (isPrinterDevice(device)) {
                printers.add(mapOf(
                    "deviceId" to device.deviceId.toString(),
                    "vendorId" to device.vendorId.toString(),
                    "productId" to device.productId.toString(),
                    "deviceName" to (device.productName ?: "USB Printer"),
                ))
            }
        }
        result.success(printers)
    }

    /**
     * Diagnostic: list ALL USB devices visible to Android, regardless of class.
     *
     * Use this to distinguish two failure modes:
     *   - Empty result → OS never enumerated the device (OTG adapter not activating
     *     USB host mode — hardware/firmware issue on this specific tablet).
     *   - Non-empty but not in listDevices → isPrinterDevice filter rejected it
     *     (check the class/interfaceClass fields to diagnose).
     *
     * Fields: deviceId, vendorId, productId, deviceName, deviceClass, interfaceCount,
     *         interfaceClasses (comma-separated list of each interface class code).
     */
    private fun usbListAllDevices(result: MethodChannel.Result) {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        val all = manager.deviceList.values.map { device ->
            val ifaceClasses = (0 until device.interfaceCount)
                .map { device.getInterface(it).interfaceClass }
                .joinToString(",")
            mapOf(
                "deviceId"       to device.deviceId.toString(),
                "vendorId"       to device.vendorId.toString(),
                "productId"      to device.productId.toString(),
                "deviceName"     to (device.productName ?: "Unknown"),
                "deviceClass"    to device.deviceClass.toString(),
                "interfaceCount" to device.interfaceCount.toString(),
                "interfaceClasses" to ifaceClasses,
            )
        }
        result.success(all)
    }

    /**
     * Check if a USB device is likely a printer.
     * USB Printer Class = 7, or has an interface with class 7.
     */
    private fun isPrinterDevice(device: UsbDevice): Boolean {
        if (device.deviceClass == UsbConstants.USB_CLASS_PRINTER) return true
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return true
            // Some cheap printers expose vendor-specific class with bulk OUT
            for (e in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(e)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    ep.direction == UsbConstants.USB_DIR_OUT) {
                    return true
                }
            }
        }
        return false
    }

    /**
     * Connect to a USB printer by vendorId-productId (e.g. "1208-514").
     *
     * Using vendorId+productId instead of deviceId makes the saved address
     * stable across unplug/replug cycles — Android reassigns deviceId on
     * every enumeration, but vendorId+productId are burned into the hardware.
     *
     * Requests permission if needed, then claims the printer interface
     * and finds the bulk OUT endpoint for data transfer.
     */
    private fun usbConnect(vendorProductId: String, result: MethodChannel.Result) {
        val manager = getSystemService(Context.USB_SERVICE) as UsbManager
        val parts = vendorProductId.split("-")
        val targetVendor = parts.getOrNull(0)?.toIntOrNull()
        val targetProduct = parts.getOrNull(1)?.toIntOrNull()

        val device = if (targetVendor != null && targetProduct != null) {
            manager.deviceList.values.firstOrNull {
                it.vendorId == targetVendor && it.productId == targetProduct
            }
        } else null

        if (device == null) {
            result.success(false)
            return
        }

        if (!manager.hasPermission(device)) {
            // Request permission and wait via broadcast receiver.
            //
            // Android 14+ (targetSdk 34) disallows implicit intents in mutable
            // PendingIntents. USB permission requires FLAG_MUTABLE so the system
            // can attach EXTRA_DEVICE / EXTRA_PERMISSION_GRANTED — make the intent
            // explicit by setting the package to our own.
            val permissionIntent = PendingIntent.getBroadcast(
                this, 0,
                Intent(ACTION_USB_PERMISSION).setPackage(packageName),
                PendingIntent.FLAG_MUTABLE,
            )
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context, intent: Intent) {
                    unregisterReceiver(this)
                    val granted = intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED, false
                    )
                    if (granted) {
                        val success = openUsbDevice(manager, device)
                        result.success(success)
                    } else {
                        result.success(false)
                    }
                }
            }
            registerReceiver(
                receiver,
                IntentFilter(ACTION_USB_PERMISSION),
                Context.RECEIVER_NOT_EXPORTED,
            )
            manager.requestPermission(device, permissionIntent)
        } else {
            val success = openUsbDevice(manager, device)
            result.success(success)
        }
    }

    /**
     * Open a USB device connection, claim the printer interface,
     * and locate the bulk OUT endpoint.
     */
    private fun openUsbDevice(manager: UsbManager, device: UsbDevice): Boolean {
        usbCloseSilently()

        // Find printer interface (class 7) or first interface with bulk OUT
        var targetIface: UsbInterface? = null
        var targetEndpoint: UsbEndpoint? = null

        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            for (e in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(e)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                    ep.direction == UsbConstants.USB_DIR_OUT) {
                    // Prefer printer class interface if available
                    if (targetIface == null ||
                        iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                        targetIface = iface
                        targetEndpoint = ep
                    }
                }
            }
        }

        if (targetIface == null || targetEndpoint == null) return false

        val connection = manager.openDevice(device) ?: return false

        if (!connection.claimInterface(targetIface, true)) {
            connection.close()
            return false
        }

        usbConnection = connection
        usbInterface = targetIface
        usbEndpointOut = targetEndpoint
        return true
    }

    /**
     * Write raw ESC/POS bytes to the USB printer via bulk transfer.
     *
     * Unlike Bluetooth, USB bulk transfer is fast enough (~12 MB/s)
     * that no chunking or pacing is needed. The entire payload is
     * sent in one call and arrives at the printer almost instantly.
     */
    private fun usbWrite(bytes: ByteArray, result: MethodChannel.Result) {
        val conn = usbConnection
        val ep = usbEndpointOut
        if (conn == null || ep == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                // USB bulk transfer: send entire payload at once.
                // maxPacketSize is typically 64 bytes for Full Speed or
                // 512 bytes for High Speed — the OS handles segmentation.
                var offset = 0
                while (offset < bytes.size) {
                    val remaining = bytes.size - offset
                    val chunk = minOf(remaining, ep.maxPacketSize * 64)
                    val sent = conn.bulkTransfer(
                        ep,
                        bytes,
                        offset,
                        chunk,
                        USB_TIMEOUT_MS,
                    )
                    if (sent < 0) {
                        runOnUiThread { result.success(false) }
                        return@Thread
                    }
                    offset += sent
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                usbCloseSilently()
                runOnUiThread { result.success(false) }
            }
        }.start()
    }

    private fun usbDisconnect(result: MethodChannel.Result) {
        usbCloseSilently()
        result.success(true)
    }

    private fun usbCloseSilently() {
        try { usbConnection?.releaseInterface(usbInterface) } catch (_: Exception) {}
        try { usbConnection?.close() } catch (_: Exception) {}
        usbConnection = null
        usbInterface = null
        usbEndpointOut = null
    }
}

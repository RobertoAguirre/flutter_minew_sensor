import CoreBluetooth
import Flutter

public class SwiftMinewBeaconPlusFlutterPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, FlutterStreamHandler {
    private var centralManager: CBCentralManager!
    private var eventSink: FlutterEventSink?
    private var discoveredDevices: [String: [String: Any]] = [:]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "minew_beacon_plus_flutter", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "minew_beacon_devices_scan", binaryMessenger: registrar.messenger())
        
        let instance = SwiftMinewBeaconPlusFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startScan":
            startScan(result: result)
        case "stopScan":
            stopScan(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startScan(result: @escaping FlutterResult) {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            result(true)
        } else {
            result(false)
        }
    }
    
    private func stopScan(result: @escaping FlutterResult) {
        centralManager?.stopScan()
        discoveredDevices.removeAll()
        result(true)
    }
    
    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else { return }
        
        if let parsedData = MinewBeaconParser.parseManufacturerData(manufacturerData) {
            let deviceData: [String: Any] = [
                "name": peripheral.name ?? "Unknown",
                "advFrames": parsedData["advFrames"] ?? []
            ]
            
            discoveredDevices[peripheral.identifier.uuidString] = deviceData
            notifyDevicesUpdate()
        }
    }
    
    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    private func notifyDevicesUpdate() {
        eventSink?(Array(discoveredDevices.values))
    }
} 
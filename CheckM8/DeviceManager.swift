import Foundation

struct DeviceInfo {
    var udid: String = ""
    var productType: String = ""
    var modelName: String = ""
    var serialNumber: String = ""
    var iosVersion: String = ""
    var buildVersion: String = ""
    var activationState: String = ""
    var imei: String = ""
    var ecid: String = ""
    var iccid: String = ""
    var simStatus: String = ""
    var wifiAddress: String = ""
    var bluetoothAddress: String = ""
    var basebandVersion: String = ""
    var region: String = ""
}

protocol DeviceManagerDelegate: AnyObject {
    func deviceConnected(_ info: DeviceInfo)
    func deviceDisconnected()
}

class DeviceManager {
    weak var delegate: DeviceManagerDelegate?
    private var pollTimer: Timer?
    private var isConnected = false
    private let toolPath: String

    init() {
        toolPath = Bundle.main.resourceURL!.appendingPathComponent("Tools").path
    }

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkDevice()
        }
        checkDevice()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkDevice() {
        let udid = runTool("idevice_id", args: ["-l"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if udid.isEmpty || udid.contains("ERROR") {
            if isConnected {
                isConnected = false
                DispatchQueue.main.async { self.delegate?.deviceDisconnected() }
            }
            return
        }
        let firstUDID = udid.components(separatedBy: "\n").first(where: { !$0.isEmpty }) ?? ""
        if firstUDID.isEmpty { return }

        var info = DeviceInfo()
        info.udid             = firstUDID
        info.productType      = runTool("ideviceinfo", args: ["-k", "ProductType"]).trimmed()
        info.modelName        = friendlyModel(info.productType)
        info.serialNumber     = runTool("ideviceinfo", args: ["-k", "SerialNumber"]).trimmed()
        info.iosVersion       = runTool("ideviceinfo", args: ["-k", "ProductVersion"]).trimmed()
        info.buildVersion     = runTool("ideviceinfo", args: ["-k", "BuildVersion"]).trimmed()
        info.activationState  = runTool("ideviceinfo", args: ["-k", "ActivationState"]).trimmed()
        info.imei             = runTool("ideviceinfo", args: ["-k", "InternationalMobileEquipmentIdentity"]).trimmed()
        info.ecid             = runTool("ideviceinfo", args: ["-k", "UniqueChipID"]).trimmed()
        info.iccid            = runTool("ideviceinfo", args: ["-k", "IntegratedCircuitCardIdentity"]).trimmed()
        info.simStatus        = runTool("ideviceinfo", args: ["-k", "SIMStatus"]).trimmed()
        info.wifiAddress      = runTool("ideviceinfo", args: ["-k", "WiFiAddress"]).trimmed()
        info.bluetoothAddress = runTool("ideviceinfo", args: ["-k", "BluetoothAddress"]).trimmed()
        info.basebandVersion  = runTool("ideviceinfo", args: ["-k", "BasebandVersion"]).trimmed()
        info.region           = runTool("ideviceinfo", args: ["-k", "RegionInfo"]).trimmed()

        isConnected = true
        DispatchQueue.main.async { self.delegate?.deviceConnected(info) }
    }

    private func runTool(_ name: String, args: [String]) -> String {
        let path = (toolPath as NSString).appendingPathComponent(name)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func friendlyModel(_ productType: String) -> String {
        let map: [String: String] = [
            // iPhone
            "iPhone1,1": "iPhone",         "iPhone1,2": "iPhone 3G",
            "iPhone2,1": "iPhone 3GS",     "iPhone3,1": "iPhone 4",
            "iPhone3,3": "iPhone 4",        "iPhone4,1": "iPhone 4S",
            "iPhone5,1": "iPhone 5",        "iPhone5,2": "iPhone 5",
            "iPhone5,3": "iPhone 5C",       "iPhone5,4": "iPhone 5C",
            "iPhone6,1": "iPhone 5S",       "iPhone6,2": "iPhone 5S",
            "iPhone7,1": "iPhone 6 Plus",   "iPhone7,2": "iPhone 6",
            "iPhone8,1": "iPhone 6S",       "iPhone8,2": "iPhone 6S Plus",
            "iPhone8,4": "iPhone SE",       "iPhone9,1": "iPhone 7",
            "iPhone9,2": "iPhone 7 Plus",   "iPhone9,3": "iPhone 7",
            "iPhone9,4": "iPhone 7 Plus",   "iPhone10,1": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus",  "iPhone10,3": "iPhone X",
            "iPhone10,4": "iPhone 8",       "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,6": "iPhone X",       "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",  "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",      "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",  "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,8": "iPhone SE (2nd gen)", "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",      "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max", "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",      "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone15,2": "iPhone 14 Pro",  "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 14",      "iPhone15,5": "iPhone 14 Plus",
            "iPhone16,1": "iPhone 15",      "iPhone16,2": "iPhone 15 Plus",
            "iPhone16,3": "iPhone 15 Pro",  "iPhone16,4": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",  "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",      "iPhone17,4": "iPhone 16 Plus",
            // iPad
            "iPad1,1": "iPad",              "iPad2,1": "iPad 2",
            "iPad2,2": "iPad 2",            "iPad2,3": "iPad 2",
            "iPad2,4": "iPad 2",            "iPad3,1": "iPad (3rd gen)",
            "iPad3,2": "iPad (3rd gen)",    "iPad3,3": "iPad (3rd gen)",
            "iPad3,4": "iPad (4th gen)",    "iPad3,5": "iPad (4th gen)",
            "iPad3,6": "iPad (4th gen)",    "iPad4,1": "iPad Air",
            "iPad4,2": "iPad Air",          "iPad5,3": "iPad Air 2",
            "iPad5,4": "iPad Air 2",        "iPad6,11": "iPad (5th gen)",
            "iPad7,5": "iPad (6th gen)",    "iPad7,6": "iPad (6th gen)",
            "iPad7,11": "iPad (7th gen)",   "iPad11,6": "iPad (8th gen)",
            "iPad12,1": "iPad (9th gen)",   "iPad13,18": "iPad (10th gen)",
            // iPad mini
            "iPad2,5": "iPad mini",         "iPad2,6": "iPad mini",
            "iPad2,7": "iPad mini",         "iPad4,4": "iPad mini 2",
            "iPad4,5": "iPad mini 2",       "iPad4,6": "iPad mini 2",
            "iPad4,7": "iPad mini 3",       "iPad4,8": "iPad mini 3",
            "iPad4,9": "iPad mini 3",       "iPad5,1": "iPad mini 4",
            "iPad5,2": "iPad mini 4",       "iPad11,1": "iPad mini (5th gen)",
            "iPad11,2": "iPad mini (5th gen)", "iPad14,1": "iPad mini (6th gen)",
            "iPad14,2": "iPad mini (6th gen)",
            // iPad Pro
            "iPad6,3": "iPad Pro 9.7\"",   "iPad6,4": "iPad Pro 9.7\"",
            "iPad6,7": "iPad Pro 12.9\"",   "iPad6,8": "iPad Pro 12.9\"",
            "iPad7,1": "iPad Pro 12.9\" (2nd)", "iPad7,2": "iPad Pro 12.9\" (2nd)",
            "iPad7,3": "iPad Pro 10.5\"",   "iPad7,4": "iPad Pro 10.5\"",
            "iPad8,1": "iPad Pro 11\"",     "iPad8,2": "iPad Pro 11\"",
            "iPad8,3": "iPad Pro 11\"",     "iPad8,4": "iPad Pro 11\"",
            "iPad8,9": "iPad Pro 11\" (2nd)", "iPad8,10": "iPad Pro 11\" (2nd)",
            "iPad8,11": "iPad Pro 12.9\" (4th)", "iPad8,12": "iPad Pro 12.9\" (4th)",
            "iPad13,4": "iPad Pro 11\" (3rd)", "iPad13,8": "iPad Pro 12.9\" (5th)",
            // iPod
            "iPod1,1": "iPod touch",        "iPod2,1": "iPod touch (2nd gen)",
            "iPod3,1": "iPod touch (3rd gen)", "iPod4,1": "iPod touch (4th gen)",
            "iPod5,1": "iPod touch (5th gen)", "iPod7,1": "iPod touch (6th gen)",
            "iPod9,1": "iPod touch (7th gen)"
        ]
        return map[productType] ?? productType
    }
}

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

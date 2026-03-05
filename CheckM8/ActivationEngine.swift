import Foundation

class ActivationEngine {
    static let shared = ActivationEngine()

    var logHandler: ((String) -> Void)?
    var progressHandler: ((Double, String) -> Void)?
    private var iproxyProcess: Process?
    private var currentDevice: DeviceInfo?

    private let toolsPath: String
    private let refPath: String
    private let sshPort = 2222
    private let sshHost = "127.0.0.1"
    private let sshUser = "root"
    private let sshPass = "alpine"

    init() {
        let res = Bundle.main.resourceURL!
        toolsPath = res.appendingPathComponent("Tools").path
        refPath   = res.appendingPathComponent("ref").path
    }

    func setDevice(_ info: DeviceInfo) { currentDevice = info }

    // MARK: - iproxy

    func startIproxy() {
        stopIproxy()
        let proc = Process()
        proc.executableURL = toolURL("iproxy")
        proc.arguments = ["\(sshPort)", "22"]
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            iproxyProcess = proc
            log("iproxy started on port \(sshPort)")
            Thread.sleep(forTimeInterval: 1.5)
        } catch {
            log("iproxy failed: \(error)")
        }
    }

    func stopIproxy() {
        iproxyProcess?.terminate()
        iproxyProcess = nil
        shell("pkill", ["-f", "iproxy \(sshPort) 22"])
    }

    func cleanup() {
        stopIproxy()
    }

    // MARK: - SSH / SCP helpers (via expect)

    @discardableResult
    func ssh(_ command: String, timeout: Int = 30) -> String {
        let script = """
set timeout \(timeout)
spawn ssh -p \(sshPort) \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    -o ConnectTimeout=10 \\
    \(sshUser)@\(sshHost) "\(command.replacingOccurrences(of: "\"", with: "\\\""))"
expect {
    "password:" { send "\(sshPass)\\r"; exp_continue }
    eof { exit 0 }
    timeout { exit 1 }
}
"""
        return runExpect(script)
    }

    func scpUpload(local: String, remote: String, timeout: Int = 60) {
        let script = """
set timeout \(timeout)
spawn scp -P \(sshPort) \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    "\(local)" \(sshUser)@\(sshHost):"\(remote)"
expect {
    "password:" { send "\(sshPass)\\r"; exp_continue }
    eof { exit 0 }
    timeout { exit 1 }
}
"""
        runExpect(script)
    }

    func scpDownload(remote: String, localDir: String, timeout: Int = 60) {
        let script = """
set timeout \(timeout)
spawn scp -P \(sshPort) \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    \(sshUser)@\(sshHost):"\(remote)" "\(localDir)/"
expect {
    "password:" { send "\(sshPass)\\r"; exp_continue }
    eof { exit 0 }
    timeout { exit 1 }
}
"""
        runExpect(script)
    }

    @discardableResult
    private func runExpect(_ script: String) -> String {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("cm8_\(Int.random(in: 10000...99999)).exp")
        try? script.write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return shell("/usr/bin/expect", [tmp.path])
    }

    @discardableResult
    private func shell(_ exe: String, _ args: [String], timeout: TimeInterval = 60) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: exe)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func toolURL(_ name: String) -> URL {
        URL(fileURLWithPath: (toolsPath as NSString).appendingPathComponent(name))
    }

    func runTool(_ name: String, args: [String]) -> String {
        return shell(toolURL(name).path, args)
    }

    private func log(_ msg: String) {
        DispatchQueue.main.async { self.logHandler?(msg) }
    }

    private func progress(_ pct: Double, _ msg: String) {
        log(msg)
        DispatchQueue.main.async { self.progressHandler?(pct, msg) }
    }

    // MARK: - Jailbreak Check

    func checkJailbreak(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.startIproxy()
            defer { self.stopIproxy() }

            let sshTest = self.ssh("echo OK", timeout: 12)
            guard sshTest.contains("OK") else {
                DispatchQueue.main.async {
                    completion(false, "SSH connection failed. Is OpenSSH installed and the device jailbroken?")
                }
                return
            }

            let jbCheck = self.ssh("[ -d /var/jb ] && echo JAILBROKEN || echo NOT_JAILBROKEN", timeout: 10)
            if jbCheck.contains("JAILBROKEN") {
                DispatchQueue.main.async { completion(true, "Jailbreak confirmed (/var/jb found).") }
            } else {
                DispatchQueue.main.async {
                    completion(false, "Device SSH is accessible but /var/jb was not found. Please use a rootless jailbreak (palera1n / Dopamine).")
                }
            }
        }
    }

    // MARK: - Full Activation Flow

    func runActivation(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.activationFlow()
                DispatchQueue.main.async { completion(true, "Activation complete!") }
            } catch {
                DispatchQueue.main.async { completion(false, error.localizedDescription) }
            }
        }
    }

    private func activationFlow() throws {
        // 1. Start iproxy
        progress(2, "Starting USB tunnel...")
        startIproxy()

        // 2. Verify SSH
        progress(5, "Verifying SSH connection...")
        let sshTest = ssh("echo OK", timeout: 15)
        guard sshTest.contains("OK") else {
            throw CMError("SSH connection failed. Is the device jailbroken with SSH enabled?")
        }
        progress(8, "SSH connected.")

        // 3. Remount r/w
        progress(10, "Remounting filesystem read-write...")
        ssh("mount -o rw,union,update /", timeout: 15)

        // 4. Upload and extract ElleKit
        progress(15, "Uploading ElleKit...")
        let ellekitLocal = (refPath as NSString).appendingPathComponent("ellekit")
        scpUpload(local: ellekitLocal, remote: "/var/jb/ellekit.tar", timeout: 60)
        ssh("chmod -R 777 /var/jb/ && chmod 7777 /var/jb/ellekit.tar", timeout: 10)
        progress(22, "Extracting ElleKit...")
        ssh("tar -xvf /var/jb/ellekit.tar -C /var/jb/", timeout: 30)

        // 5. Install HASNIDylib
        progress(30, "Installing activation tweak...")
        let dylibLocal = (refPath as NSString).appendingPathComponent("HASNIDylib")
        let plistLocal = (refPath as NSString).appendingPathComponent("HASNIDylib.plist")
        scpUpload(local: dylibLocal, remote: "/var/jb/Library/MobileSubstrate/DynamicLibraries/HASNIDylib.dylib", timeout: 30)
        scpUpload(local: plistLocal, remote: "/var/jb/Library/MobileSubstrate/DynamicLibraries/HASNIDylib.plist", timeout: 10)
        ssh("chmod 777 /var/jb/Library/MobileSubstrate/DynamicLibraries/HASNIDylib.dylib && chmod 777 /var/jb/Library/MobileSubstrate/DynamicLibraries/HASNIDylib.plist", timeout: 10)
        progress(35, "Running ElleKit loader...")
        ssh("/var/jb/usr/libexec/ellekit/loader", timeout: 15)

        // 6. Clear activation records
        progress(42, "Clearing activation records...")
        ssh("chflags -R nouchg /private/var/containers/Data/System/*/Library/activation_records", timeout: 10)
        ssh("rm -rf /private/var/containers/Data/System/*/Library/activation_records", timeout: 10)
        ssh("mkdir /private/var/containers/Data/System/*/Library/internal/../activation_records", timeout: 10)
        ssh("rm -f /private/var/mobile/activation_record.plist", timeout: 10)

        // 7. Upload activation record
        progress(50, "Uploading activation record...")
        let actRecordLocal = (refPath as NSString).appendingPathComponent("activation_record.plist")
        scpUpload(local: actRecordLocal, remote: "/./private/var/mobile/activation_record.plist", timeout: 30)
        ssh("mv -f /./private/var/mobile/activation_record.plist /private/var/containers/Data/System/*/Library/activation_records/", timeout: 10)
        ssh("chflags -R uchg /private/var/containers/Data/System/*/Library/activation_records", timeout: 10)

        // 8. MobileGestalt patch
        progress(58, "Configuring MobileGestalt cache...")
        ssh("mount -o rw,union,update /", timeout: 10)
        let gestaltBase = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/"
        let gestaltPlist = gestaltBase + "com.apple.MobileGestalt.plist"
        let gestaltTemp  = gestaltBase + "temp.plist"

        progress(60, "Uploading gestalt tools...")
        scpUpload(local: (refPath as NSString).appendingPathComponent("getkey"),  remote: gestaltBase + "getkey", timeout: 15)
        scpUpload(local: (refPath as NSString).appendingPathComponent("z"),       remote: gestaltBase + "z", timeout: 15)
        scpUpload(local: (refPath as NSString).appendingPathComponent("recache"), remote: gestaltBase + "recache", timeout: 15)
        ssh("chmod +x \(gestaltBase)*", timeout: 10)

        progress(63, "Running recache (pass 1)...")
        ssh("\(gestaltBase)recache", timeout: 20)
        ssh("\(gestaltBase)z", timeout: 20)

        progress(66, "Rotating gestalt plist...")
        ssh("mv -f \(gestaltPlist) \(gestaltTemp)", timeout: 10)

        progress(68, "Running recache (pass 2)...")
        ssh("\(gestaltBase)recache", timeout: 20)

        progress(72, "Downloading gestalt plists...")
        let tmpDir = NSTemporaryDirectory() + "checkm8_gestalt"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        try? FileManager.default.contentsOfDirectory(atPath: tmpDir).forEach {
            try? FileManager.default.removeItem(atPath: tmpDir + "/" + $0)
        }
        scpDownload(remote: gestaltPlist, localDir: tmpDir, timeout: 30)
        scpDownload(remote: gestaltTemp, localDir: tmpDir, timeout: 30)

        // 9. Merge plists
        progress(78, "Merging gestalt configuration...")
        let newPlistPath  = tmpDir + "/com.apple.MobileGestalt.plist"
        let tempPlistPath = tmpDir + "/temp.plist"
        let refPlistPath  = (refPath as NSString).appendingPathComponent("imobiledevice/temp.plist")

        let mergeResult = mergePlist(
            devicePlist: FileManager.default.fileExists(atPath: tempPlistPath) ? tempPlistPath : newPlistPath,
            refPlist: refPlistPath,
            output: newPlistPath
        )

        if mergeResult {
            progress(82, "Uploading patched gestalt plist...")
            scpUpload(local: newPlistPath, remote: gestaltPlist, timeout: 30)
        }

        ssh("chmod 7775 \(gestaltPlist)", timeout: 10)
        ssh("chflags uchg \(gestaltPlist)", timeout: 10)

        // 10. Disable OTA daemons
        progress(86, "Disabling OTA updates...")
        let otaCmds = [
            "launchctl unload -F -w /System/Library/LaunchDaemons/com.apple.softwareupdateservicesd.plist",
            "launchctl unload -F -w /System/Library/LaunchDaemons/com.apple.mobile.softwareupdated.plist",
            "launchctl unload -F -w /System/Library/LaunchDaemons/com.apple.OTATaskingAgent.plist",
            "launchctl unload -F -w /System/Library/LaunchDaemons/com.apple.mobile.obliteration.plist"
        ]
        for cmd in otaCmds { ssh(cmd, timeout: 10) }

        // 11. Restart activation services
        progress(90, "Restarting activation services...")
        ssh("launchctl unload /System/Library/LaunchDaemons/* && launchctl load /System/Library/LaunchDaemons/*", timeout: 30)
        Thread.sleep(forTimeInterval: 3)
        ssh("launchctl stop com.apple.mobileactivationd", timeout: 10)
        Thread.sleep(forTimeInterval: 3)
        ssh("launchctl start com.apple.mobileactivationd", timeout: 10)
        Thread.sleep(forTimeInterval: 3)

        // 12. Run Act binary
        progress(94, "Applying final activation patch...")
        ssh("curl -o /var/mobile/Media/Act https://osxteam.ddns.net/files/Actfair && chmod 755 /var/mobile/Media/Act && /var/mobile/Media/./Act ByOsxMad", timeout: 30)
        ssh("killall backboardd", timeout: 10)

        // 13. Pair device
        progress(97, "Pairing device...")
        runTool("idevicepair", args: ["pair"])
        Thread.sleep(forTimeInterval: 1)
        runTool("idevicepair", args: ["pair"])

        // 14. Userspace reboot
        progress(99, "Rebooting userspace...")
        ssh("launchctl reboot userspace", timeout: 15)

        progress(100, "Waiting for device to apply changes...")
        Thread.sleep(forTimeInterval: 15)

        log("✓ Activation process complete!")
        stopIproxy()
    }

    // MARK: - Plist merge (replaces libplist.exe)

    private func mergePlist(devicePlist: String, refPlist: String, output: String) -> Bool {
        guard FileManager.default.fileExists(atPath: devicePlist),
              FileManager.default.fileExists(atPath: refPlist) else { return false }

        let script = """
import sys, plistlib

with open('\(devicePlist)', 'rb') as f:
    device = plistlib.load(f)
with open('\(refPlist)', 'rb') as f:
    ref = plistlib.load(f)

for key, val in ref.items():
    device[key] = val

with open('\(output)', 'wb') as f:
    plistlib.dump(device, f, fmt=plistlib.FMT_BINARY)
print('Successfull')
"""
        let tmpPy = NSTemporaryDirectory() + "cm8_merge.py"
        try? script.write(toFile: tmpPy, atomically: true, encoding: .utf8)
        let result = shell("/usr/bin/python3", [tmpPy])
        try? FileManager.default.removeItem(atPath: tmpPy)
        return result.contains("Successfull")
    }
}

struct CMError: LocalizedError {
    let message: String
    init(_ msg: String) { message = msg }
    var errorDescription: String? { message }
}

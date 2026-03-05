import Cocoa

class MainViewController: NSViewController {

    // MARK: - UI Elements

    private let deviceImageView = NSImageView()

    private let modelLabel     = infoLabel("Model:")
    private let modelValue     = valueLabel("—")
    private let typeLabel      = infoLabel("Product Type:")
    private let typeValue      = valueLabel("—")
    private let serialLabel    = infoLabel("Serial:")
    private let serialValue    = valueLabel("—")
    private let iosLabel       = infoLabel("iOS:")
    private let iosValue       = valueLabel("—")
    private let buildLabel     = infoLabel("Build:")
    private let buildValue     = valueLabel("—")
    private let statusLabel    = infoLabel("Status:")
    private let statusValue    = valueLabel("—")
    private let udidLabel      = infoLabel("UDID:")
    private let udidValue      = valueLabel("—")
    private let ecidLabel      = infoLabel("ECID:")
    private let ecidValue      = valueLabel("—")
    private let imeiLabel      = infoLabel("IMEI:")
    private let imeiValue      = valueLabel("—")
    private let iccidLabel     = infoLabel("ICCID:")
    private let iccidValue     = valueLabel("—")
    private let simLabel       = infoLabel("SIM:")
    private let simValue       = valueLabel("—")
    private let wifiLabel      = infoLabel("WiFi:")
    private let wifiValue      = valueLabel("—")
    private let btLabel        = infoLabel("Bluetooth:")
    private let btValue        = valueLabel("—")
    private let bbLabel        = infoLabel("Baseband:")
    private let bbValue        = valueLabel("—")
    private let regionLabel    = infoLabel("Region:")
    private let regionValue    = valueLabel("—")

    private let activateButton = actionButton(title: "Activate iDevice", icon: "lock.open")

    private let logScrollView  = NSScrollView()
    private let logTextView    = NSTextView()
    private let progressBar    = NSProgressIndicator()
    private let progressLabel  = NSTextField(labelWithString: "")

    private var deviceManager  = DeviceManager()
    private var currentDevice  = DeviceInfo()
    private var isBusy         = false

    // MARK: - View Lifecycle

    override func loadView() {
        let bg = NSColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 680))
        view.wantsLayer = true
        view.layer?.backgroundColor = bg.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        ActivationEngine.shared.logHandler = { [weak self] msg in
            self?.appendLog(msg)
        }
        ActivationEngine.shared.progressHandler = { [weak self] pct, _ in
            DispatchQueue.main.async {
                self?.progressBar.doubleValue = pct
                self?.progressLabel.stringValue = "\(Int(pct))%"
            }
        }
        deviceManager.delegate = self
        deviceManager.startPolling()
        showNoDevice()
    }

    // MARK: - Layout

    private func buildLayout() {
        // Device image (left side)
        deviceImageView.imageScaling = .scaleProportionallyUpOrDown
        deviceImageView.translatesAutoresizingMaskIntoConstraints = false
        deviceImageView.image = deviceSymbolImage("iphone")
        view.addSubview(deviceImageView)

        // Info rows
        let infoRows: [(NSTextField, NSTextField)] = [
            (modelLabel,  modelValue),
            (typeLabel,   typeValue),
            (serialLabel, serialValue),
            (iosLabel,    iosValue),
            (buildLabel,  buildValue),
            (statusLabel, statusValue),
            (udidLabel,   udidValue),
            (ecidLabel,   ecidValue),
            (imeiLabel,   imeiValue),
            (iccidLabel,  iccidValue),
            (simLabel,    simValue),
            (wifiLabel,   wifiValue),
            (btLabel,     btValue),
            (bbLabel,     bbValue),
            (regionLabel, regionValue)
        ]

        let infoStack = NSStackView()
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 6
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        for (lbl, val) in infoRows {
            let row = NSStackView(views: [lbl, val])
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .centerY
            NSLayoutConstraint.activate([lbl.widthAnchor.constraint(equalToConstant: 100)])
            infoStack.addArrangedSubview(row)
        }
        view.addSubview(infoStack)

        // Activate button
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.target = self
        activateButton.action = #selector(activateTapped)
        view.addSubview(activateButton)

        // Progress bar (determinate)
        progressBar.style = .bar
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.controlSize = .small
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true
        view.addSubview(progressBar)

        // Progress percentage label
        progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        progressLabel.textColor = NSColor(white: 0.55, alpha: 1)
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.isHidden = true
        view.addSubview(progressLabel)

        // Log area
        logScrollView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.hasVerticalScroller = true
        logScrollView.borderType = .noBorder
        logScrollView.wantsLayer = true
        logScrollView.layer?.cornerRadius = 6
        logScrollView.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.backgroundColor = .clear
        logTextView.textColor = NSColor(white: 0.6, alpha: 1)
        logTextView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        logTextView.textContainerInset = NSSize(width: 6, height: 6)
        logScrollView.documentView = logTextView
        view.addSubview(logScrollView)

        // Constraints
        NSLayoutConstraint.activate([
            // Device image - top left
            deviceImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            deviceImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            deviceImageView.widthAnchor.constraint(equalToConstant: 170),
            deviceImageView.heightAnchor.constraint(equalToConstant: 200),

            // Info stack - right of image
            infoStack.leadingAnchor.constraint(equalTo: deviceImageView.trailingAnchor, constant: 30),
            infoStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            infoStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Activate button
            activateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            activateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            activateButton.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 16),
            activateButton.heightAnchor.constraint(equalToConstant: 38),

            // Progress bar + label side by side
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBar.topAnchor.constraint(equalTo: activateButton.bottomAnchor, constant: 8),
            progressBar.trailingAnchor.constraint(equalTo: progressLabel.leadingAnchor, constant: -8),

            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressLabel.widthAnchor.constraint(equalToConstant: 36),

            // Log
            logScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logScrollView.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            logScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func activateTapped() {
        guard !isBusy else { return }
        guard !currentDevice.udid.isEmpty else {
            showAlert("No Device", "Connect a jailbroken device with SSH enabled.")
            return
        }
        guard currentDevice.activationState != "Activated" else {
            showAlert("Already Activated", "This device is already activated.")
            return
        }

        setBusy(true)
        appendLog("─── Checking jailbreak for \(currentDevice.modelName) ───")
        ActivationEngine.shared.setDevice(currentDevice)

        ActivationEngine.shared.checkJailbreak { [weak self] jailbroken, msg in
            guard let self = self else { return }
            if !jailbroken {
                self.appendLog("✗ " + msg)
                self.setBusy(false)
                self.showAlert("Not Jailbroken", msg)
                return
            }
            self.appendLog("✓ " + msg)
            self.appendLog("─── Starting activation ───")
            ActivationEngine.shared.runActivation { [weak self] success, result in
                self?.setBusy(false)
                self?.appendLog(success ? "✓ " + result : "✗ " + result)
                if success {
                    self?.showAlert("Success", "Activation complete for \(self?.currentDevice.modelName ?? "device").")
                } else {
                    self?.showAlert("Error", result)
                }
            }
        }
    }

    // MARK: - UI Updates

    func appendLog(_ msg: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let line = "[\(ts)] \(msg)\n"
            let storage = self.logTextView.textStorage!
            let attr = NSAttributedString(
                string: line,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor(white: 0.65, alpha: 1)
                ]
            )
            storage.append(attr)
            self.logTextView.scrollToEndOfDocument(nil)
        }
    }

    private func setBusy(_ busy: Bool) {
        isBusy = busy
        progressBar.isHidden = !busy
        progressLabel.isHidden = !busy
        if !busy {
            progressBar.doubleValue = 0
            progressLabel.stringValue = ""
        }
        activateButton.isEnabled = !busy
    }

    private func showNoDevice() {
        modelValue.stringValue  = "—"
        typeValue.stringValue   = "—"
        serialValue.stringValue = "—"
        iosValue.stringValue    = "—"
        buildValue.stringValue  = "—"
        statusValue.stringValue = "No Device"
        statusValue.textColor   = NSColor(white: 0.5, alpha: 1)
        udidValue.stringValue   = "—"
        ecidValue.stringValue   = "—"
        imeiValue.stringValue   = "—"
        iccidValue.stringValue  = "—"
        simValue.stringValue    = "—"
        wifiValue.stringValue   = "—"
        btValue.stringValue     = "—"
        bbValue.stringValue     = "—"
        regionValue.stringValue = "—"
        activateButton.title    = "No Device Connected"
        deviceImageView.image   = deviceSymbolImage("iphone")
    }

    private func updateDeviceUI(_ info: DeviceInfo) {
        modelValue.stringValue  = info.modelName.isEmpty        ? "—" : info.modelName
        typeValue.stringValue   = info.productType.isEmpty      ? "—" : info.productType
        serialValue.stringValue = info.serialNumber.isEmpty     ? "—" : info.serialNumber
        iosValue.stringValue    = info.iosVersion.isEmpty       ? "—" : info.iosVersion
        buildValue.stringValue  = info.buildVersion.isEmpty     ? "—" : info.buildVersion
        udidValue.stringValue   = info.udid.isEmpty             ? "—" : info.udid
        ecidValue.stringValue   = info.ecid.isEmpty             ? "—" : info.ecid
        imeiValue.stringValue   = info.imei.isEmpty             ? "—" : info.imei
        iccidValue.stringValue  = info.iccid.isEmpty            ? "—" : info.iccid
        simValue.stringValue    = info.simStatus.isEmpty        ? "—" : info.simStatus
        wifiValue.stringValue   = info.wifiAddress.isEmpty      ? "—" : info.wifiAddress
        btValue.stringValue     = info.bluetoothAddress.isEmpty ? "—" : info.bluetoothAddress
        bbValue.stringValue     = info.basebandVersion.isEmpty  ? "—" : info.basebandVersion
        regionValue.stringValue = info.region.isEmpty           ? "—" : info.region

        let activated = info.activationState.lowercased() == "activated"
        statusValue.stringValue = activated ? "Activated" : (info.activationState.isEmpty ? "Unknown" : info.activationState)
        statusValue.textColor   = activated ? NSColor(red: 0.3, green: 0.85, blue: 0.35, alpha: 1)
                                            : NSColor(red: 0.9, green: 0.4, blue: 0.3, alpha: 1)

        activateButton.title = activated ? "Device Already Activated" : "Activate iDevice"

        let symName = info.productType.hasPrefix("iPad") ? "ipad" : "iphone"
        deviceImageView.image = deviceSymbolImage(symName)
    }

    private func deviceSymbolImage(_ name: String) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: 120, weight: .thin)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
    }

    private func showAlert(_ title: String, _ msg: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = msg
        alert.alertStyle = title == "Error" ? .critical : .informational
        alert.runModal()
    }
}

// MARK: - DeviceManagerDelegate

extension MainViewController: DeviceManagerDelegate {
    func deviceConnected(_ info: DeviceInfo) {
        currentDevice = info
        updateDeviceUI(info)
        appendLog("Device connected: \(info.modelName) (\(info.productType))")
    }

    func deviceDisconnected() {
        currentDevice = DeviceInfo()
        showNoDevice()
        appendLog("Device disconnected.")
    }
}

// MARK: - Factory helpers

private func infoLabel(_ text: String) -> NSTextField {
    let f = NSTextField(labelWithString: text)
    f.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    f.textColor = NSColor(white: 0.55, alpha: 1)
    f.translatesAutoresizingMaskIntoConstraints = false
    return f
}

private func valueLabel(_ text: String) -> NSTextField {
    let f = NSTextField(labelWithString: text)
    f.font = NSFont.systemFont(ofSize: 11, weight: .regular)
    f.textColor = NSColor(white: 0.88, alpha: 1)
    f.lineBreakMode = .byTruncatingMiddle
    f.translatesAutoresizingMaskIntoConstraints = false
    return f
}

private func actionButton(title: String, icon: String) -> NSButton {
    let b = NSButton(title: title, target: nil, action: nil)
    b.bezelStyle = .rounded
    b.wantsLayer = true
    b.layer?.cornerRadius = 8
    b.layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
    b.contentTintColor = NSColor(white: 0.8, alpha: 1)
    if #available(macOS 12.0, *) {
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            b.image = img
            b.imagePosition = .imageLeading
        }
    }
    b.font = NSFont.systemFont(ofSize: 14, weight: .medium)
    return b
}

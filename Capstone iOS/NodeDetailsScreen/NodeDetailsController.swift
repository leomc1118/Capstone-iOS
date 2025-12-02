//
//  HomeViewController.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/9/25.
//

import UIKit
import CoreBluetooth
import Alamofire
import CoreLocation

class NodeDetailsController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UIGestureRecognizerDelegate, CLLocationManagerDelegate {

    var node: Node?
    var lastNetError: Int = 0

    private let detailView = NodeDetailsView()
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var uartTX: CBCharacteristic?
    private var uartRX: CBCharacteristic?
    private var pendingNodeForPost: Node?
    private var hasRequestedLocation = false
    private var hasReceivedLocation = false

    private let locationManager = CLLocationManager()
    
    private let uartService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txChar     = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxChar     = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    var currentLatitude: CLLocationDegrees?
    var currentLongitude: CLLocationDegrees?
    
    override func loadView() {
        view = detailView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = node?.advName ?? "Node"
        detailView.updateStatus("Initializing Bluetooth...")
        detailView.sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        central = CBCentralManager(delegate: self, queue: nil)
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization() // Or requestAlwaysAuthorization()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasRequestedLocation = false
        hasReceivedLocation = false
        currentLatitude = nil
        currentLongitude = nil
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        detailView.setKeyboardInset(0)
        central?.stopScan()
        if let peripheral = targetPeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    @objc private func sendTapped() {
        let text = detailView.consumeInputText()
        guard !text.isEmpty else { return }
        guard let peripheral = targetPeripheral,
              let tx = uartTX,
              let data = text.data(using: .utf8) else {
            detailView.appendLog("⚠️ Unable to send: no active connection.")
            return
        }
        peripheral.writeValue(data, for: tx, type: .withResponse)
        detailView.appendLog("➡️ \(text)")
        detailView.inputField.becomeFirstResponder()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func connectToNode() {
        guard central.state == .poweredOn else { return }
        guard let uuidString = node?.UUID, let uuid = UUID(uuidString: uuidString) else {
            detailView.updateStatus("Missing node identifier.")
            return
        }

        if let cached = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            prepare(peripheral: cached)
            detailView.updateStatus("Connecting to \(cached.name ?? "device")...")
            central.connect(cached, options: nil)
            return
        }

        detailView.updateStatus("Scanning for \(node?.advName ?? "device")...")
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        central.scanForPeripherals(withServices: nil, options: options)
    }

    private func prepare(peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        peripheral.delegate = self
    }

    private func appendStatus(_ text: String) {
        detailView.appendLog(text)
        detailView.updateStatus(text)
    }

    @objc private func handleKeyboard(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let durationNumber = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let curveNumber = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber,
              let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }

        let keyboardFrameInView = view.convert(frameValue.cgRectValue, from: nil)
        let intersection = keyboardFrameInView.intersection(view.bounds)
        let inset = max(0, intersection.height - view.safeAreaInsets.bottom)
        detailView.setKeyboardInset(inset)

        let options = UIView.AnimationOptions(rawValue: UInt(curveNumber.intValue << 16))
        UIView.animate(withDuration: durationNumber.doubleValue,
                       delay: 0,
                       options: options.union(.beginFromCurrentState),
                       animations: { self.view.layoutIfNeeded() })
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: detailView.inputField) == true { return false }
        if touch.view?.isDescendant(of: detailView.sendButton) == true { return false }
        return true
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectToNode()
            requestLocationIfNeeded()
        case .poweredOff:
            detailView.updateStatus("Please turn Bluetooth on.")
        case .unauthorized:
            detailView.updateStatus("Bluetooth permission denied.")
        case .unsupported:
            detailView.updateStatus("Bluetooth unsupported on this device.")
        default:
            detailView.updateStatus("Bluetooth unavailable (state: \(central.state.rawValue)).")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        guard peripheral.identifier.uuidString == node?.UUID else { return }
        central.stopScan()
        prepare(peripheral: peripheral)
        detailView.updateStatus("Connecting to \(peripheral.name ?? "device")...")
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        appendStatus("Connected. Discovering services...")
        requestLocationIfNeeded()
        peripheral.discoverServices([uartService])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        let message = "Failed to connect: \(error?.localizedDescription ?? "unknown error")."
        detailView.appendLog("⚠️ \(message)")
        connectToNode()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        let reason = error?.localizedDescription ?? "Disconnected"
        detailView.appendLog("ℹ️ \(reason).")
        uartTX = nil
        uartRX = nil
        targetPeripheral = nil
        connectToNode()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            detailView.appendLog("⚠️ Service discovery failed: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        if let uart = services.first(where: { $0.uuid == uartService }) {
            peripheral.discoverCharacteristics([txChar, rxChar], for: uart)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            detailView.appendLog("⚠️ Characteristic discovery failed: \(error.localizedDescription)")
            return
        }

        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case txChar:
                uartTX = characteristic
                detailView.appendLog("✅ TX ready")
            case rxChar:
                uartRX = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                detailView.appendLog("✅ RX ready")
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            detailView.appendLog("⚠️ Update failed: \(error.localizedDescription)")
            return
        }

        guard characteristic.uuid == rxChar,
              let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }

        let intValues = text
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        detailView.appendLog("⬅️ \(intValues)")

        let node = Node(UUID: peripheral.identifier.uuidString,
                        advName: peripheral.name ?? "Unknown",
                        sensorData: intValues)
        pendingNodeForPost = node

        if currentLatitude != nil && currentLongitude != nil {
            tryPostPendingNode()
        } else {
            detailView.appendLog("ℹ️ Waiting for location...")
            requestLocationIfNeeded()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            if hasReceivedLocation { return }
            hasReceivedLocation = true

            self.currentLatitude = location.coordinate.latitude
            self.currentLongitude = location.coordinate.longitude
            
            print("Received one-time location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            tryPostPendingNode()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location request failed with error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            print("Authorization granted. Requesting location...")
            requestLocationIfNeeded()
        case .denied, .restricted:
            print("Authorization denied or restricted. Cannot get location.")
            // Guide the user to enable location services in settings
        case .notDetermined:
            print("Authorization status not determined.")
        default:
            break
        }
    }
    
    private func requestLocationIfNeeded() {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        if !hasRequestedLocation {
            hasRequestedLocation = true
            locationManager.requestLocation()
        }
    }

    private func tryPostPendingNode() {
        guard let node = pendingNodeForPost,
              let lat = currentLatitude,
              let lon = currentLongitude else { return }
        postNode(node, lat: lat, lon: lon)
        pendingNodeForPost = nil
    }

    func postNode(_ node: Node, lat: CLLocationDegrees, lon: CLLocationDegrees){
        self.detailView.appendLog("ℹ️ Web POST in progress...")
        if let url = URL(string: APIConfigs.baseURL+"post"){
            // Safely map sensorData into structured fields; default to 0 if missing
            let values = node.sensorData + Array(repeating: 0, count: max(0, 6 - node.sensorData.count))
            let payload: [String: Any] = [
                "UUID": node.UUID,
                "advertisingName": node.advName,
                "latitude": lat,
                "longitude": lon,
                "data": [
                    "temp": [values[0]],
                    "humidity": [values[1]],
                    "gas": [values[2]],
                    "accelX": [values[3]],
                    "accelY": [values[4]],
                    "accelZ": [values[5]]
                ]
            ]

            AF.request(url, method:.post, parameters: payload, encoding: JSONEncoding.default)
                .responseString(completionHandler: { response in
                    //MARK: retrieving the status code...
                    let status = response.response?.statusCode
                    
                    switch response.result{
                    case .success(let data):
                        //MARK: there was no network error...
                        
                        //MARK: status code is Optional, so unwrapping it...
                        if let uwStatusCode = status{
                            switch uwStatusCode{
                                case 200...299:
                                //MARK: the request was valid 200-level...
                                    self.detailView.appendLog("✅ Web POST success")
                                    print(node)
                                    break
                        
                                case 400...499:
                                //MARK: the request was not valid 400-level...
                                    print(data)
                                    self.lastNetError = uwStatusCode
                                    break
                        
                                default:
                                //MARK: probably a 500-level error...
                                    print(data)
                                    self.lastNetError = uwStatusCode
                                    break
                        
                            }
                        }
                        break
                        
                    case .failure(let error):
                        //MARK: there was a network error...
                        print(error)
                        if let uwStatusCode = status {
                            self.lastNetError = uwStatusCode
                        }
                        break
                    }
                })
        }else{
            print("Invalid URL for method add")
        }
    }
}

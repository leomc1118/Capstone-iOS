//
//  HomeViewController.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/9/25.
//

import UIKit
import CoreBluetooth
import Alamofire

class NodeDetailsController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UIGestureRecognizerDelegate {

    var node: Node?
    var lastNetError: Int = 0

    private let detailView = NodeDetailsView()
    private var central: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var uartTX: CBCharacteristic?
    private var uartRX: CBCharacteristic?

    private let uartService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txChar     = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let rxChar     = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        detailView.appendLog("⬅️ \(text)")
        
        let node = Node(UUID: peripheral.identifier.uuidString, advName: peripheral.name ?? "Unknown", sensorData: text)
        postNode(node)
    }
    
    func postNode(_ node: Node){
        self.detailView.appendLog("ℹ️ Web POST in progress...")
        if let url = URL(string: APIConfigs.baseURL+"post"){
            
            AF.request(url, method:.post, parameters:
                        [
                            "UUID": node.UUID,
                            "advertisingName": node.advName,
                            "data": node.sensorData
                        ], encoding: JSONEncoding.default)
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

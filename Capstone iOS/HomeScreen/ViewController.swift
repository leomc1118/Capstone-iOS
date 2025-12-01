//
//  ViewController.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/8/25.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    let homeScreen = HomeView()
    let notificationCenter = NotificationCenter.default
    
    var nodes = [Node]()
    private var central: CBCentralManager!
    private var rakPeripheral: CBPeripheral?
    private var uartTX: CBCharacteristic?
    private var uartRX: CBCharacteristic?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    
    private let uartService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txChar     = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // phone -> RAK
    private let rxChar     = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // RAK -> phone
    
    override func loadView() {
        view = homeScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        central = CBCentralManager(delegate: self, queue: nil)
        self.title = "Clampa Viewer"
        
        startScanning()
        
        homeScreen.nodeTable.dataSource = self
        homeScreen.nodeTable.delegate = self
        homeScreen.nodeTable.separatorStyle = .none
        
        homeScreen.nodeTable.reloadData()
        
//        navigationItem.rightBarButtonItem = UIBarButtonItem(
//            barButtonSystemItem: .refresh, target: self,
//            action: #selector(refreshNodes)
//        )
        
        let endEditingTapGesture = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        endEditingTapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(endEditingTapGesture)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }
        startScanning()
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let displayName = peripheral.name ?? advName ?? ""
        guard displayName.contains("RAK4631") else { return } 

        discoveredPeripherals[peripheral.identifier] = peripheral

        if !nodes.contains(where: { $0.UUID == peripheral.identifier.uuidString }) {
            nodes.append(Node(UUID: peripheral.identifier.uuidString, advName: displayName, sensorData: ""))
            homeScreen.nodeTable.reloadData()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([uartService])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier == rakPeripheral?.identifier {
            rakPeripheral = nil
        }
        startScanning()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == uartService }) else { return }
        peripheral.discoverCharacteristics([txChar, rxChar], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case txChar: uartTX = characteristic
            case rxChar:
                uartRX = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == rxChar,
              let data = characteristic.value,
              let text = String(data: data, encoding: .utf8) else { return }
        // Update your UI here (e.g. append to a table view)
    }

    func send(_ string: String) {
        guard let peripheral = rakPeripheral,
              let tx = uartTX,
              let data = string.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: tx, type: .withResponse)
    }

//    @objc func refreshNodes(){
//        
//    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "advName", for: indexPath) as! NodesTableViewCell
        cell.labelName.text = nodes[indexPath.row].advName
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let BluetoothViewController = NodeDetailsController()
        BluetoothViewController.node = nodes[indexPath.row]
        navigationController?.pushViewController(BluetoothViewController, animated: true)

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func startScanning() {
        guard central.state == .poweredOn else { return }
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        central.scanForPeripherals(withServices: nil, options: options)
    }
}

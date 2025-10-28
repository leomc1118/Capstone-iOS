//
//  ViewController.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/8/25.
//

import UIKit

class ViewController: UIViewController {

    let homeScreen = HomeView()
    let notificationCenter = NotificationCenter.default
    
    var nodes = [Node]()
    
    override func loadView() {
        view = homeScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.title = "Clampa Viewer"
        
        let testNode = Node(UUID: "1234xdsa", advName: "Test")
        nodes.append(testNode)
        
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
}

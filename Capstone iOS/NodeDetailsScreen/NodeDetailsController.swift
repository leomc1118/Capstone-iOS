//
//  HomeViewController.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/9/25.
//

import UIKit

class NodeDetailsController: UIViewController {

    var node: Node?
    var queueBLE = [Packet]()
    var lastNetError: Int = 0

    // using UUID in node (passed from home screen), initiate connection to selected Node.
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

}

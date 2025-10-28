//
//  HomeView.swift
//  Capstone iOS
//
//  Created by Leo Chen on 10/9/25.
//

import UIKit

class HomeView: UIView {
    var nodeTable: UITableView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        
        nodeTable = UITableView()
        nodeTable.register(NodesTableViewCell.self, forCellReuseIdentifier: "advName")
        nodeTable.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(nodeTable)
        
        initConstraints()
    }
    
    func initConstraints() {
        NSLayoutConstraint.activate([
            nodeTable.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            nodeTable.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor),
            nodeTable.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor),
            nodeTable.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor)
            ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

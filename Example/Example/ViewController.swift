//
//  ViewController.swift
//  Example
//
//  Created by David Ask on 2019-10-03.
//  Copyright © 2019 Bintrail AB. All rights reserved.
//

import Bintrail
import UIKit

class ViewController: UIViewController {

    private var tapCounter: Int = 1

    @IBAction
    func buttonAction(sender: UIButton) {
        bt_log("Button tapped", type: .trace)
        bt_event_register("Button tapped") { event in
            event.add(attribute: sender.titleLabel?.text, for: "Button title")
        }

        let detailController = UINavigationController(
            rootViewController: DetailViewController(nibName: nil, bundle: nil)
        )

        bt_log("Presenting detail controller", detailController, type: .info)

        present(detailController, animated: true) {

        }

        tapCounter += 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        bt_log("Received memory warning", type: .error)
    }

}


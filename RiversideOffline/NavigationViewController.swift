//
//  NavigationViewController.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2019.
//

import UIKit


class NavigationViewController: UINavigationController {

    @objc dynamic var navBarIsHidden: Bool = true

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // watch for nav bar hidden changes and alert the delegate, this allows it to e.g. show extra transparent views to bring them back
        let newIsHidden = true
        if newIsHidden == self.navBarIsHidden {
            return
        }
        self.navBarIsHidden = newIsHidden
    }
}

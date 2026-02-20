//
//  ConsoleViewController.swift
//  BleBrowser
//
//  Created by David Park on 18/09/2018.
//  Copyright © 2018 David Park. All rights reserved.
//

import UIKit

class ConsoleViewController: UIViewController {

    var logManager: WBLogManager! {
        willSet {
            self._unobserveLM()
            self._unobserveAllLogs()
        }
        didSet {
            self._observeLM()
        }
    }
    var consoleView: ConsoleView {
        get {
            return self.view as! ConsoleView
        }
    }
    @MainActor
    deinit {
        self._unobserveLM()
        self._unobserveAllLogs()
    }

    // MARK: - Methods
    func insertLog(log: WBLog, at index: Int) {
        self._observeLog(log)

        let clvc: ConsoleLogViewController = ConsoleLogViewController(nibName: "ConsoleLogView", bundle: nil)
        self.addChild(clvc)
        clvc.log = log
        let clv = clvc.view as! ConsoleLogView
        clv.configureWithLog(log)
        self.consoleView.insertLogView(clv, at: index)
    }


    // MARK: - UIViewController overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        self.consoleView.removeAllLogViews()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    // MARK: - Internal
    private func _observeLM() {
        guard let lm = self.logManager else {
            return
        }
        lm.addObserver(self, forKeyPath: "logs", options: [.initial, .new], context: nil)
    }
    private func _observeLog(_ log: WBLog) {
        log.addObserver(self, forKeyPath: "isSelected", options: [.initial, .new], context: nil)
    }
    private func _unobserveAllLogs() {
        guard let lm = self.logManager else { return }
        for log in lm.logs {
            self._unobserveLog(log)
        }
    }
    private func _unobserveLM() {
        guard let lm = self.logManager else { return }
        lm.removeObserver(self, forKeyPath: "logs")
    }
    private func _unobserveLog(_ log: WBLog) {
        log.removeObserver(self, forKeyPath: "isSelected")
    }
}

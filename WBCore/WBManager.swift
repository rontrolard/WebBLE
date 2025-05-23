//
//  WebBluetooth.swift
//  BasicBrowser
//
//  Copyright 2016-2017 Paul Theriault and David Park. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Foundation
import CoreBluetooth
import WebKit
import Network

protocol WBPicker {
    func showPicker()
    func updatePicker()
}

private var studentGuid : CBUUID =  CBUUID(string: "cafebabe-57ee-7033-f00f-a11ca75ea723")
private var service : CBUUID =   CBUUID(string: "cafebabe-57ee-7033-f00f-a11ca75ea722")


class NetworkingHandler: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        // Indicate network status, e.g., offline mode
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest: URLRequest, completionHandler: (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        // Indicate network status, e.g., back to online
    }
}

open class WBManager: NSObject,
                        CBCentralManagerDelegate,
                        CBPeripheralManagerDelegate,
                        WKScriptMessageHandler,
                        WBPopUpPickerViewDelegate
{
    private var monitor = NWPathMonitor();
    private var requestCounter : Int = 0;
    private var lastData : String?;
    private var currentWebView: WKWebView?;
    private var bleService : CBMutableService?;
    private var studentCharacteristic: CBMutableCharacteristic = CBMutableCharacteristic(type: studentGuid,
                                                                                         properties: [.notify, .read, .write ],
                                                                                         value: nil, permissions: [.readable, .writeable ]);

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
            case .poweredOff:
                peripheralManager.stopAdvertising();
                break;
            case .unknown:
                print("Unknown")
                break;
            case .resetting:
                print("Resetting")
                break;
            case .unsupported:
                print("Unsurported")
            return;
            case .unauthorized:
                print("Unauthorized")
            return;
            case .poweredOn:
                print("Powered On")
                break;
            @unknown default:
                print("Something else" + peripheral.state.rawValue.description)
            return;
        }
        print("Current state");
        print(peripheral.state);
                
        let myService =  CBMutableService(type: service, primary: true)
        
        myService.characteristics = [studentCharacteristic]
        self.bleService = myService;
        peripheralManager.add(myService)
        
        peripheralManager.publishL2CAPChannel(withEncryption: true)
        startAdvertising()
        
    }
    public func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        print("Opened channel");
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("Got read request " + request.description);
        if let webView = self.currentWebView {
            webView.evaluateJavaScript("window.bluetoothEnabled = true; window.serverConnection.externalBluetoothConnected = true;");
        }
        requestCounter+=1;
        if let lastString = lastData {
            request.value = lastString.data(using: .utf8);
            peripheral.respond(to: request, withResult: .success)
            lastData = nil;
            return;
        }
        /*let response = ("Message from \(UIDevice.current.name) \(UIDevice.current.systemName) - \(self.requestCounter) battery: \(UIDevice.current.batteryLevel)").data(using: .utf8);
        
        request.value = response;*/
        //peripheral.respond(to: request, withResult: .attributeNotFound)
    }
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                               central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        peripheral.setDesiredConnectionLatency(.low, for: central);
    }
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        print("Got Add request" + service.description);
        if let webView = self.currentWebView {
            webView.evaluateJavaScript("window.bluetoothEnabled = false; window.serverConnection.externalBluetoothConnected = false;");

        }
        //self.currentWebView.evaluateJavaScript("")
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        //print("Got write request" + requests.description);
        if let webView = self.currentWebView {
            webView.evaluateJavaScript("window.bluetoothEnabled = true; window.serverConnection.externalBluetoothConnected = true;");

        }
        var matchedRequest: CBATTRequest? = nil;
        for req in requests {
            if(req.characteristic != studentCharacteristic) {
                continue;
            }
            guard let value = req.value else {
                continue
            }
            matchedRequest = req;
            print(" Got good request")
            //assert(req.offset == 0 && value.count == 1)
            //ctrlCharacteristic.value = value
            let recievedData = String(data: value, encoding: .utf8)!
            if let webView = self.currentWebView {
                webView.evaluateJavaScript("window.serverConnection.dispatchMessage(JSON.parse('" + recievedData + "'))")
                //webView.evaluateJavaScript("alert('" + realData + "')");
            }
            print("received data: " + recievedData);
            /*let array = value.withUnsafeBytes {
                $0.load(as: UInt8.self)
                //[UInt8](UnsafeBufferPointer(start: $0, count: value.count))
            }
            let recievedData = String(bytes: array, encoding: String.Encoding.utf8);*/
            /*
            if let realData = recievedData {
                if let webView = self.currentWebView {
                    webView.evaluateJavaScript("window.serverConnection.dispatchMessage(JSON.parse('" + realData + "'))")
                    //webView.evaluateJavaScript("alert('" + realData + "')");
                }
                print(realData);
            }
            */
            //_delegate.sending(byte != 0)
        }
        if let match = matchedRequest {
            peripheral.respond(to: match, withResult: .success)
        }
        else {
            peripheral.respond(to: requests[0], withResult: .writeNotPermitted)
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        if let error = error {
            print("Advertising fail: \(error)")
            return;
        }
        print("Advertising working?")
        
        
    }
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didPublishL2CAPChannel PSM: CBL2CAPPSM,
        error: (any Error)?
    ) {
        
    }
    func startAdvertising() {
        //messageLabel.text = "Advertising Data"
        
        peripheralManager.startAdvertising([CBAdvertisementDataLocalNameKey : "RSI Student Side", CBAdvertisementDataServiceUUIDsKey :     [service], description: "RSI Student"])
        print("Started Advertising " + service.uuidString)
    }

    // MARK: - Embedded types
    enum ManagerRequests: String {
        case device, requestDevice, getAvailability, examineeReadMessage, postMessage
    }

    // MARK: - Properties
    let debug = true
    let centralManager = CBCentralManager(delegate: nil, queue: nil)
    var peripheralManager = CBPeripheralManager(delegate: nil, queue: nil);
    
    var devicePicker: WBPicker

    /*! @abstract The devices selected by the user for use by this manager. Keyed by the UUID provided by the system. */
    var devicesByInternalUUID = [UUID: WBDevice]()

    /*! @abstract The devices selected by the user for use by this manager. Keyed by the UUID we create and pass to the web page. This seems to be for security purposes, and seems sensible. */
    var devicesByExternalUUID = [UUID: WBDevice]()

    /*! @abstract The outstanding request for a device from the web page, if one is outstanding. Ony one may be outstanding at any one time and should be policed by a modal dialog box. TODO: how modal is the current solution?
     */
    var requestDeviceTransaction: WBTransaction? = nil

    /*! @abstract Filters in use on the current device request transaction.  If nil, that means we are accepting all devices.
     */
    var filters: [[String: AnyObject]]? = nil
    var pickerDevices = [WBDevice]()

    var bluetoothAuthorized: Bool {
        get {
            switch CBCentralManager.authorization {
            case CBManagerAuthorization.allowedAlways:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Constructors / destructors
    init(devicePicker: WBPicker) {
        self.devicePicker = devicePicker
        super.init()
        self.centralManager.delegate = self
        self.peripheralManager.delegate = self
        monitor.start(queue: .global());
    }
    // MARK: - Public API
    public func selectDeviceAt(_ index: Int) {
        let device = self.pickerDevices[index]
        device.view = self.requestDeviceTransaction?.webView
        self.requestDeviceTransaction?.resolveAsSuccess(withObject: device)
        self.deviceWasSelected(device)
    }
    public func cancelDeviceSearch() {
        NSLog("User cancelled device selection")
        // ⚠️ The user cancelled message is detected by the javascript layer to send the right
        // error to the application, so it will need to be changed there as well if changing here.
        self.requestDeviceTransaction?.resolveAsFailure(withMessage: "User cancelled")
        self.stopScanForPeripherals()
        self._clearPickerView()
    }
    
    // MARK: - WKScriptMessageHandler
    open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let trans = WBTransaction(withMessage: message) else {
            /* The transaction will have handled the error */
            return
        }
        self.triage(transaction: trans)
    }

    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("Bluetooth is \(central.state == CBManagerState.poweredOn ? "ON" : "OFF")")
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {

        if let filters = self.filters,
            !self._peripheral(peripheral, isIncludedBy: filters) {
            return
        }

        guard self.pickerDevices.first(where: {$0.peripheral == peripheral}) == nil else {
            return
        }

        NSLog("New peripheral \(peripheral.name ?? "<no name>") discovered")
        let device = WBDevice(
            peripheral: peripheral, advertisementData: advertisementData,
            RSSI: RSSI, manager: self)
        if !self.pickerDevices.contains(where: {$0 == device}) {
            self.pickerDevices.append(device)
            self.updatePickerData()
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard
            let device = self.devicesByInternalUUID[peripheral.identifier]
        else {
            NSLog("Unexpected didConnect notification for \(peripheral.name ?? "<no-name>") \(peripheral.identifier)")
            return
        }
        device.didConnect()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard
            let device = self.devicesByInternalUUID[peripheral.identifier]
            else {
                NSLog("Unexpected didDisconnect notification for unknown device \(peripheral.name ?? "<no-name>") \(peripheral.identifier)")
                return
        }
        if let webView = self.currentWebView {
            webView.evaluateJavaScript("window.bluetoothEnabled = false; window.serverConnection.externalBluetoothConnected = false;");

        }

        device.didDisconnect(error: error)
        self.devicesByInternalUUID[peripheral.identifier] = nil
        self.devicesByExternalUUID[device.deviceId] = nil
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("FAILED TO CONNECT PERIPHERAL UNHANDLED \(error?.localizedDescription ?? "<no error>")")
    }

    // MARK: - UIPickerViewDelegate
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        // dummy response for making screen shots from the simulator
        // return row == 0 ? "Puck.js 69c5 (82DF60A5-3C0B..." : "Puck.js c728 (9AB342DA-4C27..."
        return self._pv(pickerView, titleForRow: row, forComponent: component)
    }
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        // dummy response for making screen shots from the simulator
        // return 2
        return self.pickerDevices.count
    }
    
    // MARK: - Private
    private func triage(transaction: WBTransaction){

        guard
            transaction.key.typeComponents.count > 0,
            let managerMessageType = ManagerRequests(
                rawValue: transaction.key.typeComponents[0])
        else {
            transaction.resolveAsFailure(withMessage: "Request type components not recognised \(transaction.key)")
            return
        }

        switch managerMessageType
        {
        case .device:

            guard let view = WBDevice.DeviceTransactionView(transaction: transaction) else {
                transaction.resolveAsFailure(withMessage: "Bad device request")
                break
            }

            let devUUID = view.externalDeviceUUID
            guard let device = self.devicesByExternalUUID[devUUID]
            else {
                transaction.resolveAsFailure(
                    withMessage: "No known device for device transaction \(transaction)"
                )
                break
            }
            device.triage(view)
        case .getAvailability:
            transaction.resolveAsSuccess(withObject: self.bluetoothAuthorized)
        case .postMessage:
            if let webView = transaction.webView {
                self.currentWebView = webView;
                //webView.evaluateJavaScript("window.serverConnection.dispatchMessage(JSON.parse(`\(transaction.messageData)`))");
                let currentData = "\(transaction.jsonData)";
                let sval = currentData.data(using: .utf8);
                if let goodData = sval {
                    
                    self.peripheralManager.updateValue(goodData, for: studentCharacteristic, onSubscribedCentrals: nil);
                }
                //readCharacteristic.value = sval;
                //writeCharacteristic.value = sval;
                
                lastData = currentData;
                print(currentData);
            }

        case .examineeReadMessage:
            if let wbview = transaction.webView {
                self.currentWebView = wbview;
            }
            print("Examinee read message");
        case .requestDevice:
            guard transaction.key.typeComponents.count == 1
            else {
                transaction.resolveAsFailure(withMessage: "Invalid request type \(transaction.key)")
                break
            }
            let acceptAllDevices = transaction.messageData["acceptAllDevices"] as? Bool ?? false

            let filters = transaction.messageData["filters"] as? [[String: AnyObject]]

            // PROTECT force unwrap see below
            guard acceptAllDevices || filters != nil
            else {
                transaction.resolveAsFailure(withMessage: "acceptAllDevices false but no filters passed: \(transaction.messageData)")
                break
            }
            guard self.requestDeviceTransaction == nil
            else {
                transaction.resolveAsFailure(withMessage: "Previous device request is still in progress")
                break
            }

            if self.debug {
                NSLog("Requesting device with filters \(filters?.description ?? "nil")")
            }

            self.requestDeviceTransaction = transaction
            if acceptAllDevices {
                self.scanForAllPeripherals()
            }
            else {
                // force unwrap, but protected by guard above marked PROTECT
                self.scanForPeripherals(with: filters!)
            }
            transaction.addCompletionHandler {_, _ in
                self.stopScanForPeripherals()
                self.requestDeviceTransaction = nil
            }
            self.devicePicker.showPicker()
        }
    }

    func clearState() {
        NSLog("WBManager clearState()")
        self.stopScanForPeripherals()
        self.requestDeviceTransaction?.abandon()
        self.requestDeviceTransaction = nil
        // the external and internal devices are the same, but tidier to do this in one loop; calling clearState on a device twice is OK.
        for var devMap in [self.devicesByExternalUUID, self.devicesByInternalUUID] {
            for (_, device) in devMap {
                device.clearState()
            }
            devMap.removeAll()
        }
        self._clearPickerView()
    }

    private func deviceWasSelected(_ device: WBDevice) {
        // TODO: think about whether overwriting any existing device is an issue.
        self.devicesByExternalUUID[device.deviceId] = device;
        self.devicesByInternalUUID[device.internalUUID] = device;
    }

    func scanForAllPeripherals() {
        self._clearPickerView()
        self.filters = nil
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func scanForPeripherals(with filters:[[String: AnyObject]]) {

        let services = filters.reduce([String](), {
            (currReduction, nextValue) in
            if let nextServices = nextValue["services"] as? [String] {
                return currReduction + nextServices
            }
            return currReduction
        })

        let servicesCBUUID = self._convertServicesListToCBUUID(services)

        if (self.debug) {
            NSLog("Scanning for peripherals... (services: \(servicesCBUUID))")
        }
        
        self._clearPickerView();
        self.filters = filters
        centralManager.scanForPeripherals(withServices: servicesCBUUID, options: nil)
    }
    private func stopScanForPeripherals() {
        if self.centralManager.state == .poweredOn {
            self.centralManager.stopScan()
        }
        self._clearPickerView()

    }
    
    func updatePickerData(){
        self.pickerDevices.sort(by: {
            if $0.name != nil && $1.name == nil {
                // $1 is "bigger" in that its name is nil
                return true
            }
            // cannot be sorting ids that we haven't discovered
            if $0.name == $1.name {
                return $0.internalUUID.uuidString < $1.internalUUID.uuidString
            }
            if $0.name == nil {
                // $0 is "bigger" as it's nil and the other isn't
                return false
            }
            // forced unwrap protected by logic above
            return $0.name! < $1.name!
        })
        self.devicePicker.updatePicker()
    }

    private func _convertServicesListToCBUUID(_ services: [String]) -> [CBUUID] {
        return services.map {
            servStr -> CBUUID? in
            guard let uuid = UUID(uuidString: servStr.uppercased()) else {
                return nil
            }
            return CBUUID(nsuuid: uuid)
            }.filter{$0 != nil}.map{$0!};
    }

    private func _peripheral(_ peripheral: CBPeripheral, isIncludedBy filters: [[String: AnyObject]]) -> Bool {
        for filter in filters {

            if let name = filter["name"] as? String {
                guard peripheral.name == name else {
                    continue
                }
            }
            if let namePrefix = filter["namePrefix"] as? String {
                guard
                    let pname = peripheral.name,
                    pname.hasPrefix(namePrefix)
                else {
                    continue
                }
            }
            // All the checks passed, don't need to check another filter.
            return true
        }
        return false
    }

    private func _pv(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String {

        let dev = self.pickerDevices[row]
        let id = dev.internalUUID
        guard let name = dev.name
        else {
            return "(\(id))"
        }
        return "\(name) (\(id))"
    }
    private func _clearPickerView() {
        self.pickerDevices = []
        self.updatePickerData()
    }
}

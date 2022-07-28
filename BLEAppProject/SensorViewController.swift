//
//  SensorViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-20.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit
import UserNotifications

let heartRateCharacteristic = CharacteristicIdentifier(
    uuid: "044DDFD6-FBA4-4D94-B9E2-FB2AE619DFC7",
    service: ServiceIdentifier(uuid: "79D97F61-CD63-4365-B0BB-CEB84F7A190B")
)

let activityDict = [ 0: "error",
                     1: "cut",
                     2: "engrave",
                     3: "idle",
                     4: "route",
                     5: "sand"]


class SensorViewController: UITableViewController {

    var sensor: PeripheralIdentifier?
    var heartRate: HeartRateMeasurement?
    static var measurements: [Int] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        bluejay.register(connectionObserver: self)
        bluejay.register(serviceObserver: self)
    }

    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            bluejay.disconnect(immediate: true) { result in
                switch result {
                case .disconnected:
                    debugLog("Immediate disconnect is successful")
                case .failure(let error):
                    debugLog("Immediate disconnect failed with error: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        debugLog("Deinit SensorViewController")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        } else {
            return 5
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)

            if indexPath.row == 0 {
                cell.textLabel?.text = "Device Name"
                cell.detailTextLabel?.text = sensor?.name ?? ""
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Status"
                cell.detailTextLabel?.text = bluejay.isConnected ? "Connected" : "Disconnected"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Heart Rate"
                cell.detailTextLabel?.text = String(heartRate?.measurement ?? 0)
            } else {
                cell.textLabel?.text = "Activity Type"
                cell.detailTextLabel?.text = activityDict[heartRate?.measurement ?? 0]
            }

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath)

            if indexPath.row == 0 {
                cell.textLabel?.text = "Connect"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Disconnect"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Listen to heart rate"
            } else if indexPath.row == 3 {
                cell.textLabel?.text = "End listen to heart rate"
            } else if indexPath.row == 4 {
                cell.textLabel?.text = "Show Live Chart"
            } else if indexPath.row == 5 {
                cell.textLabel?.text = "Clear Chart"
            } else if indexPath.row == 6 {
                cell.textLabel?.text = "Save Session"
            } else if indexPath.row == 7 {
                cell.textLabel?.text = "Show History"
            } else if indexPath.row == 8 {
                cell.textLabel?.text = "Terminate app"
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedSensor = sensor else {
            debugLog("No sensor found")
            return
        }

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
                    switch result {
                    case .success:
                        debugLog("Connection attempt to: \(selectedSensor.description) is successful")
                    case .failure(let error):
                        debugLog("Failed to connect to: \(selectedSensor.description) with error: \(error.localizedDescription)")
                    }
                }
            } else if indexPath.row == 1 {
                bluejay.disconnect()
            } else if indexPath.row == 2 {
                listen(to: heartRateCharacteristic)
            } else if indexPath.row == 3 {
                endListen(to: heartRateCharacteristic)
            } else if indexPath.row == 4 {
                performSegue(withIdentifier: "showChart", sender: self)
            } else if indexPath.row == 5 {
                SensorViewController.measurements = []
            } else if indexPath.row == 6 {
                saveHistory()
            } else if indexPath.row == 7 {
                performSegue(withIdentifier: "showChart", sender: self)
            } else if indexPath.row == 8 {
                kill(getpid(), SIGKILL)
            }

            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    private func saveHistory(){
        SensorViewController.measurements = []
    }

    private func listen(to characteristic: CharacteristicIdentifier) {
        if characteristic == heartRateCharacteristic {
            bluejay.listen(
                to: heartRateCharacteristic,
                multipleListenOption: .replaceable) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
                    guard let weakSelf = self else {
                        return
                    }

                    switch result {
                    case .success(let heartRate):
                        weakSelf.heartRate = heartRate
                        weakSelf.tableView.reloadData()
                    case .failure(let error):
                        debugLog("Failed to listen to heart rate with error: \(error.localizedDescription)")
                    }
            }
        }
    }

    private func endListen(to characteristic: CharacteristicIdentifier) {
        bluejay.endListen(to: characteristic) { result in
            switch result {
            case .success:
                debugLog("End listen to \(characteristic.description) is successful")
            case .failure(let error):
                debugLog("End listen to \(characteristic.description) failed with error: \(error.localizedDescription)")
            }
        }
    }
}

extension SensorViewController: ConnectionObserver {
    func bluetoothAvailable(_ available: Bool) {
        debugLog("SensorViewController - Bluetooth available: \(available)")

        tableView.reloadData()
    }

    func connected(to peripheral: PeripheralIdentifier) {
        debugLog("SensorViewController - Connected to: \(peripheral.description)")

        sensor = peripheral
        listen(to: heartRateCharacteristic)

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Connected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func disconnected(from peripheral: PeripheralIdentifier) {
        debugLog("SensorViewController - Disconnected from: \(peripheral.description)")

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Disconnected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension SensorViewController: ServiceObserver {
    func didModifyServices(from peripheral: PeripheralIdentifier, invalidatedServices: [ServiceIdentifier]) {
        debugLog("SensorViewController - Invalidated services: \(invalidatedServices.debugDescription)")
    }
}

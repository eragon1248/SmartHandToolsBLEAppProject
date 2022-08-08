//
//  ChartController.swift
//  BLEAppProject
//
//  Created by Raksheet Kota on 7/28/22.
//

import UIKit
import Charts

class ChartController: UIViewController, ChartViewDelegate {
    
    var lineChart = LineChartView()
    var currentIndex = 0
    var entries = [ChartDataEntry] ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        lineChart.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateChartView), userInfo: nil, repeats: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        lineChart.frame = CGRect(x: 0, y: 0,
                                width: self.view.frame.size.width,
                                height: self.view.frame.size.width)
        lineChart.center = view.center
        view.addSubview(lineChart)
        
        let currentData = SensorViewController.measurements
        for x in 0..<currentData.count{
            entries.append(ChartDataEntry(x: Double(x),
                                          y: Double(currentData[x])))
            currentIndex = x
        }
        let set = LineChartDataSet(entries: entries)
        set.colors = ChartColorTemplates.material()
        let data = LineChartData(dataSet: set)
        lineChart.data = data
    }

    @objc func updateChartView(){
        let currentMeasurements = SensorViewController.measurements
        if (currentIndex < currentMeasurements.count){
            for x in currentIndex..<currentMeasurements.count{
                let entry = ChartDataEntry(x: Double(currentIndex), y: Double(currentMeasurements[x]))
                entries.append(entry)
                lineChart.data?.appendEntry(entry, toDataSet: 0)
            }
            currentIndex = currentMeasurements.count
            lineChart.notifyDataSetChanged()
            lineChart.moveViewToX(Double(currentIndex))
        }
    }

}

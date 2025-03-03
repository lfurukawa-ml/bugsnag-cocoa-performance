//
//  ManualUIViewLoadScenario.swift
//  Fixture
//
//  Created by Karl Stenerud on 14.02.23.
//

import BugsnagPerformance

class ManualUIViewLoadScenario: Scenario {

    override func run() {
        let controller = UIViewController()
        let options = BugsnagPerformanceSpanOptions()
        options.startTime = Date()
        BugsnagPerformance.startViewLoadSpan(controller: controller, options: options)
        BugsnagPerformance.endViewLoadSpan(controller: controller, endTime: Date())
        waitForCurrentBatch()
    }
}

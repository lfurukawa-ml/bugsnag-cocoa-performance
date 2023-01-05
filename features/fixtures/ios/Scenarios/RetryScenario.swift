//
//  RetryScenario.swift
//  Fixture
//
//  Created by Karl Stenerud on 08.11.22.
//

import BugsnagPerformance

class RetryScenario: Scenario {
    
    override func run() {
        waitForCurrentBatch()
        BugsnagPerformance.startSpan(name: "WillRetry").end()
        waitForCurrentBatch()
        BugsnagPerformance.startSpan(name: "Success").end()
    }
}

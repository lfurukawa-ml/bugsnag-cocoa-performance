Feature: Sampling

  Scenario: No spans should be sent when samplingProbability is zero
    Given I set the sampling probability to "0.0"
    And I run "SamplingProbabilityZeroScenario" and discard the initial p-value request
    Then I should receive no traces

  Scenario: But if the server changes the probability, we must honor that
    Given I set the sampling probability to "1.0"
    And I run "SamplingProbabilityZeroScenario" and discard the initial p-value request
    And I wait for 1 span
    * all span name equals "Post-start"

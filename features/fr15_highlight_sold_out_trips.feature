Feature: FR-15 Highlight sold-out trips and disable purchase
  As a user
  I want sold-out trips to be highlighted and purchase disabled
  So that I do not waste time trying to buy unavailable tickets

  Context: HighlightSoldOutTripsContext

  # Positive Scenario
  Scenario: Normal trip with tickets is not highlighted as sold-out
    Given a trip with available tickets exists from "Tartu" to "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should NOT see sold-out highlighting
    And the purchase button should be enabled

  # Negative Scenario
  Scenario: Sold-out trip is highlighted and purchase button is disabled
    Given I am logged in as a normal user
    And a sold-out future trip exists from "Tartu" to "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see the sold-out trip highlighted
    And the purchase button should be disabled for that trip

  # Edge Case
  Scenario: Trip with some sold-out instances but available dates is not fully highlighted
    Given a trip with mixed sold-out and available instances exists from "Tartu" to "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should NOT see sold-out highlighting
    And the purchase button should be enabled

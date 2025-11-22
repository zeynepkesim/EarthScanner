Feature: FR-15 Highlight sold-out trips and disable purchase
  As a user
  I want sold-out trips to be highlighted and purchase disabled
  So that I do not waste time trying to buy unavailable tickets

  Context: TripSearchContext

  Scenario: Sold-out trip is highlighted and purchase button is disabled
    Given a sold-out future trip exists from "Tartu" to "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see the sold-out trip highlighted
    And the purchase button should be disabled for that trip

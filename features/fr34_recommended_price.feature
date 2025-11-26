Feature: FR-34 Recommended Price
  As a user
  I want to see a recommended price on a trip's detail page based on similar trips

  Scenario: Positive - recommended price shown
    Given a trip exists with source "Tartu" destination "Tallinn" transport "bus" duration_minutes 60 price "20.00"
    And 3 similar trips exist for "Tartu" to "Tallinn"
    When I visit the trip page for the first trip
    Then I should see the recommended price

  Scenario: Negative - no similar trips
    Given a trip exists with source "Nowhere" destination "NowhereElse" transport "bus" duration_minutes 60 price "100.00"
    When I visit the trip page for the first trip
    Then I should not see a recommended price

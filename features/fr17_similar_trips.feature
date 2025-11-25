Feature: FR-17 Similar Trips
  As a user
  I want to see similar trips on a trip's page

  Scenario: Positive - similar trips shown
    Given a trip exists with source "Tartu" destination "Tallinn" transport "bus" duration_minutes 60 price "20.00"
    And 5 similar trips exist for "Tartu" to "Tallinn"
    When I visit the trip page for the first trip
    Then I should see similar trips

  Scenario: Negative - no similar trips
    Given a trip exists with source "FarAway" destination "Alone" transport "plane" duration_minutes 180 price "300.00"
    When I visit the trip page for the first trip
    Then I should not see a recommended price

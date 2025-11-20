Feature: FR-08 Filter Results
  As a user
  I want to filter search results by price, CO2, duration, and times
  So that I can narrow down results.

  Context: TripSearchContext

  Scenario: Filter by price range
    Given a set of future trips with varying prices exist
    When I search for trips from "Tartu" to "Tallinn" with min price "10" and max price "30"
    Then I should only see trips priced between 10 and 30

  Scenario: Filter by CO2
    Given a set of future trips with varying CO2 exist
    When I search for trips from "Tartu" to "Tallinn" with max co2 "200"
    Then I should only see trips with CO2 <= 200

  Scenario: Combined filters
    Given a set of future trips with various attributes exist
    When I search with multiple filters applied
    Then I should only see trips matching all conditions

Feature: FR-11 Exclude past trips
  As a user
  I want past trips to be excluded from the search results
  So that I only see upcoming or active trips

  Context: ExcludePastTripsContext

  # Positive Scenario  
  Scenario: Only future trips appear in search results
    Given a past trip exists between "Tartu" and "Tallinn"
    And a future trip exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see 1 trip in the results
    And I should not see past trips in the results

  # Negative Scenario
  Scenario: No results when only past trips exist
    Given only past trips exist between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see 0 trips in the results

  # Edge Case
  Scenario: Trip departing exactly now is treated as past
    Given a trip departing exactly now exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should not see the "NowTrip" in the results

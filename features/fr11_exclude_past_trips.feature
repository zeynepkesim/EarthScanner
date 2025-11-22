Feature: FR-11 Exclude past trips from search
  As a user
  I want past trips to be excluded from the search results
  So that I only see upcoming or active trips

  Context: TripSearchContext

  Scenario: Trip departing exactly now is treated as past
    Given a trip departing exactly now exists between "Tartu" and "Tallinn"
    When I search for trips from "Tartu" to "Tallinn"
    Then I should not see the "NowTrip" in the results

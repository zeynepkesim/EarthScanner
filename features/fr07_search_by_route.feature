Feature: FR-07 Search by Route
  As an authenticated user
  I want to search for trips by selecting source and destination cities
  So that I can find available future trips.

  Context: TripSearchContext

  Scenario: Successful search with valid source and destination
    Given a set of future trips exist
    When I search for trips from "Tartu" to "Tallinn"
    Then I should see at least 1 trip in the results

  Scenario: Missing source gives validation redirect
    When I search for trips from "" to "Tallinn"
    Then I should be redirected back to the search page

  Scenario: Only future trips are shown
    Given a set of past and future trips exist
    When I search for trips from "Tartu" to "Parnu"
    Then I should not see past trips in the results

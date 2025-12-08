Feature: FR-07 Search by Route
  # nfr-08: BDD - ensures search requires authentication and validates search behaviors
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
  
  # Add these negative scenarios

  Scenario: Search fails without source city
    When I search without providing source
    Then I should be redirected back to the search page
    And I should see "Source and destination are required"

  Scenario: Search fails without destination city
    When I search without providing destination
    Then I should be redirected back to the search page

  Scenario: Unauthenticated user cannot search
    When I try to search as an unauthenticated user
    Then I should be blocked with authentication error

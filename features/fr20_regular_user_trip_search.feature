Feature: FR-20 Search trips for regular users
  In order to find trips quickly
  As a logged-in regular user
  I want to see a search box on the home page that supports source and destination

  Background:
    Given a user exists
    And a set of future trips exist

  Scenario: Authenticated regular user sees search box on homepage
    Given I am on the login page
    When I submit correct login credentials
    And I visit the homepage
    Then I should see a Phoenix welcome message
    # The following step asserts a search box is visible only to regular users;
    # selector-based checks are implemented in the step definitions.
    Then I should see the search box on the homepage

  Scenario: Visitor (not logged in) does not see the search box
    Given I am a visitor
    When I visit the homepage
    Then I should not see the search box on the homepage

  Scenario: Admin does not see the regular user search box on homepage
    Given I am logged in as an admin
    When I visit the homepage
    Then I should not see the search box on the homepage

  Scenario: Search by source and destination yields results
    Given I am on the login page
    And a set of future trips with various attributes exist
    When I submit correct login credentials
    And I search for trips from "Tartu" to "Tallinn"
    Then I should see at least 1 trip in the results

  Scenario: Empty source input should redirect back to the search page (validation)
    Given I am on the login page
    And a set of future trips exist
    When I submit correct login credentials
    And I search for trips from "" to "Tallinn"
    Then I should be redirected back to the search page
  
  Scenario: Admin user cannot see or use regular user search box
    Given I am logged in as an admin
    When I visit the homepage
    Then I should not see the search box on the homepage
    And I should not be able to access search results

  Scenario: Search with special characters is handled safely
    Given I am logged in as a regular user
    When I search for trips with special characters in source
    Then the search should handle it gracefully without errors

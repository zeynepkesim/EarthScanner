Feature: FR-22 Regular user access to purchased trips
  As a logged-in regular user
  I want to see my upcoming and past purchased trips with one click
  So I can review or manage my bookings

  Background:
    Given the test database is clean for FR-22 scenarios

  Scenario: Logged-in user sees upcoming and past purchases
    Given a regular user has upcoming and past trip purchases
    When I log in as that user and visit the My Trips page
    Then I should see my upcoming trip listed
    And I should see my past trip listed after switching tabs

  Scenario: Guest is redirected when accessing My Trips
    Given I am not logged in for FR-22
    When I visit the My Trips page without authenticating
    Then I should be redirected to the login form for FR-22

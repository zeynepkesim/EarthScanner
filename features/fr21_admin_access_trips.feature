Feature: FR-21 Admin access to created trips
  In order to manage trips efficiently
  As a logged-in admin
  I want one-click access to the list of trips I created (separating past and future)

  Background:
    Given I am logged in as an admin
    And a set of future trips exist
    And a set of past and future trips exist

  Scenario: Admin can open "My Trips" page and see future and past lists
    When I visit "/admin/my-trips"
    Then I should see "Future Trips"
    And I should see "Past Trips"

  Scenario: Admin's "My Trips" lists only their own trips
    When I visit "/admin/my-trips"
    Then I should see at least 1 trip in the results

  Scenario: Non-admin cannot access my-trips
    Given I am on the login page
    And a user exists
    When I submit correct login credentials
    And I visit "/admin/my-trips"
    Then I should be redirected back to the home page

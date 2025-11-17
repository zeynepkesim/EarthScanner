Feature: View Trip Details (FR-35)
  As an Admin
  I want to view all details of a trip I created
  So that I can evaluate all trip information clearly.

  Background:
    Given an admin user exists and is logged in

  @future_trip_details
  Scenario: Admin views details of a future trip
    Given a future trip exists owned by the admin
    When the admin visits the trip details page
    Then the admin should see all trip attributes displayed
    And the admin should see the Edit button
    And the admin should see the Delete button

  @past_trip_details
  Scenario: Admin views details of a past trip
    Given a past trip exists owned by the admin
    When the admin visits the trip details page
    Then the admin should see all trip attributes displayed
    And the admin should NOT see the Edit button
    And the admin should NOT see the Delete button
    And the admin should see read-only booking statistics

  @unauthorized
  Scenario: Unauthorized user cannot view details
    Given a future trip exists owned by another admin
    And a normal user is logged in
    When the user visits the trip details page
    Then the user should see "You are not authorized to view this trip."

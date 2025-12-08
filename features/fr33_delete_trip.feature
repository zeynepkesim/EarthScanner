Feature: Delete Trip (FR-33)
  As an Admin
  I want to delete a future trip I created
  So that I can eliminate cancelled or incorrect travels.

  Background:
    Given an admin user exists and is logged in

  # ========== POSITIVE CASES ==========

  @future_trip_no_tickets
  Scenario: Admin deletes a future trip with NO sold tickets
    Given a future trip exists owned by the admin
    And the trip has 0 sold tickets
    When the admin visits the trip details page
    And the admin clicks the Delete Trip button
    Then the admin should see a success message "Trip deleted successfully."
    And the trip should no longer appear in the admin trip list

  @future_trip_force_delete
  Scenario: Admin force deletes a trip with sold tickets
    Given a future trip exists owned by the admin
    And the trip has sold tickets
    And the admin is on the delete confirmation page
    When the admin confirms force delete
    Then the admin should see "Trip deleted successfully (including all sold tickets)."
    And the trip and its purchases should be removed

  # ========== NEGATIVE CASES ==========

  @future_trip_with_tickets
  Scenario: Admin tries to delete a future trip WITH sold tickets (requires confirmation)
    Given a future trip exists owned by the admin
    And the trip has sold tickets
    When the admin tries to delete the trip
    Then the admin should see a warning message "This trip has sold tickets."
    And the admin should be redirected to the delete confirmation page

  @past_trip
  Scenario: Admin cannot delete a past trip
    Given a past trip exists owned by the admin
    When the admin tries to delete the trip
    Then the admin should see an error message "Cannot delete past trips."

  @unauthorized
  Scenario: Unauthorized admin cannot delete another admin's trip
    Given a future trip exists owned by another admin
    When the admin tries to delete the trip
    Then the admin should see "You are not authorized to delete this trip."

  @nonexistent_trip
  Scenario: Cannot delete a trip that doesn't exist
    When the admin tries to delete trip with ID 999999
    Then the admin should see "Trip not found."
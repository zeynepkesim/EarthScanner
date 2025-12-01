Feature: FR-27 Notifications Reminders
  As a user I want to see upcoming trip reminders in the in-app notifications page

  Scenario: User sees reminder for a purchased trip within 24 hours
    Given a trip is scheduled within the next 24 hours
    And I am logged in as a normal user
    And I purchase that trip date
    When I visit the notifications page
    Then I should see a reminder for the trip

  Scenario: Logged in user without purchase does not see a reminder
    Given a trip is scheduled within the next 24 hours
    And I am logged in as a normal user
    When I visit the notifications page
    Then I should not see a reminder for the trip

  Scenario: Trip scheduled exactly 24 hours away should show a reminder after purchase (edge case)
    Given a trip is scheduled exactly 24 hours from now
    And I am logged in as a normal user
    And I purchase that trip date
    When I visit the notifications page
    Then I should see a reminder for the trip

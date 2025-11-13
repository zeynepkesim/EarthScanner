Feature: Change Password
  As a logged-in user
  I want to update my password
  So that I can secure my account

  Background:
    Given I am logged in as a normal user

  Scenario: Successfully change password
    When I visit the change password page
    And I submit valid password change information
    Then I should see "Password changed successfully"

  Scenario: Fail due to incorrect current password
    When I visit the change password page
    And I submit an invalid current password
    Then I should see "Current password is incorrect"

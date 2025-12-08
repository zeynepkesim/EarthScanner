Feature: Change Password (FR-05)
  As a logged-in user
  I want to update my password
  So that I can secure my account

  Background:
    Given I am logged in as a normal user

  # ========== POSITIVE CASES ==========

  Scenario: Successfully change password
    When I visit the change password page
    And I submit valid password change information
    Then DEBUG_SHOW_PAGE
    And I should be on the profile page
    And my session should be renewed

  Scenario: Change password and verify I can login with new password
    When I visit the change password page
    And I change my password to a new one
    And I log out
    And I try to login with the new password
    Then I should successfully log in

  # ========== NEGATIVE CASES ==========

  Scenario: Fail due to incorrect current password
    When I visit the change password page
    And I submit an invalid current password
    Then I should see "Current password is incorrect"
    And I should still be on the change password page

  Scenario: Fail due to password confirmation mismatch
    When I visit the change password page
    And I submit mismatched new passwords
    Then I should see "Password confirmation does not match"

  Scenario: Fail due to new password too short
    When I visit the change password page
    And I submit a new password shorter than 8 characters
    Then I should see "Password must be at least 8 characters"

  Scenario: Fail when leaving current password empty
    When I visit the change password page
    And I leave the current password field empty
    And I submit the form
    Then I should see an error message

  Scenario: Fail when leaving new password empty
    When I visit the change password page
    And I leave the new password field empty
    And I submit the form
    Then I should see an error message

  Scenario: Unauthenticated user cannot access change password page
    Given I am logged out
    When I try to visit the change password page
    Then I should be redirected to the login page

  Scenario: Old password no longer works after change
    When I visit the change password page
    And I change my password successfully
    And I log out
    And I try to login with the old password
    Then I should see a login error
Feature: FR-06 Delete account & data (regular)
  As a logged-in user
  I want to delete my account
  So that I can leave the platform

  Scenario: Successful deletion
    Given a user exists and I am logged in
    And I navigate to the delete account page
    Then I should see an irreversible warning
    When I submit deletion with the correct password
    Then I should be redirected to the homepage
    And the user should not exist

  Scenario: Wrong password
    Given a user exists and I am logged in
    And I navigate to the delete account page
    Then I should see an irreversible warning
    When I submit deletion with a wrong password
    Then I should see a delete error

  Scenario: Deleted user cannot log in
    Given a user exists and I am logged in
    And I navigate to the delete account page
    And I submit deletion with the correct password
    When I attempt to log in with the deleted credentials
    Then I should see a login error

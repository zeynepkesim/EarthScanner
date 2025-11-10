Feature: Delete Account
  As a logged-in user
  I want to delete my account
  So that I can leave the platform

  Scenario: Wrong password
    Given a user exists and I am logged in
    And I navigate to the delete account page
    Then I should see an irreversible warning
    When I submit deletion with a wrong password
    Then I should see a delete error

  Scenario: Successful deletion
    Given a user exists and I am logged in
    And I navigate to the delete account page
    Then I should see an irreversible warning
    When I submit deletion with the correct password
    Then I should be redirected to the homepage

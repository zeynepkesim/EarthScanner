Feature: Edit profile
  As a registered user
  I want to update my profile information
  So that my data is up-to-date

  Scenario: Successful profile update
    Given I am logged in as a user
    And I am on the edit profile page
    When I change my username to "NewUsername"
    And I submit the profile form
    Then I should see a success message
    And my username should be updated

  Scenario: Invalid profile update
    Given I am logged in as a user
    And I am on the edit profile page
    When I leave the username blank
    And I submit the profile form
    Then I should see an error message

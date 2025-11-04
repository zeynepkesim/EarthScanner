Feature: Login and Logout
  As a user
  I want to log in and out
  So that I can access my account securely

  Scenario: Successful login
    Given a user exists
    And I am on the login page
    When I submit correct login credentials
    Then I should see the home page

  Scenario: Wrong password
    Given a user exists
    And I am on the login page
    When I submit a wrong password
    Then I should see a login error

  Scenario: Unknown email
    Given I am on the login page
    When I attempt login with unknown email
    Then I should see a login error

  Scenario: Logout after login
    Given a user exists
    And I am on the login page
    When I submit correct login credentials
    And I click log out
    Then I should see the login page

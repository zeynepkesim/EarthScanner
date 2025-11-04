Feature: User Registration
  As a visitor
  I want to register for an account
  So that I can sign in and use EarthScanner

  Scenario: Successful registration
    Given I am on the registration page
    When I submit a valid registration
    Then I should see the login page

  Scenario: Mismatched passwords
    Given I am on the registration page
    When I submit a registration with mismatched passwords
    Then I should see a registration error

  Scenario: Invalid registration
    Given I am on the registration page
    When I submit an invalid registration
    Then I should see a registration error

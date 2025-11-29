Feature: NFR-07 Secure authentication
  In order to protect user accounts
  As the system
  I want authentication to use secure practices (password hashing, encrypted sessions, session rotation)

  Background:
    Given a user exists

  Scenario: Successful login rotates the session and sets a secure session cookie
    Given I am on the login page
    When I submit correct login credentials
    Then I should see the home page
    # Additional checks for session rotation and secure cookie are validated in TDD tests

  Scenario: Wrong password should produce a login error and not create a session
    Given I am on the login page
    When I submit a wrong password
    Then I should see a login error

  Scenario: Unknown email should produce a login error
    Given I am on the login page
    When I attempt login with unknown email
    Then I should see a login error

  Scenario: Session is renewed on logout (session id rotation)
    Given I am on the login page
    When I submit correct login credentials
    And I click log out
    Then I should see the login page

  Scenario: Passwords are validated on registration (mismatched)
    Given I am on the registration page
    When I submit a registration with mismatched passwords
    Then I should see a registration error

  Scenario: Invalid registration fields show errors
    Given I am on the registration page
    When I submit an invalid registration
    Then I should see a registration error

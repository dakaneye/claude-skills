package service

import (
	"errors"
	"fmt"
	"log"
)

// UserService handles user operations.
type UserService struct {
	repo UserRepository
}

// UserRepository defines data access.
type UserRepository interface {
	FindByID(id string) (*User, error)
	FindByEmail(email string) (*User, error)
	Save(user *User) error
	Delete(id string) error
	List() ([]*User, error)
	Count() (int, error)
	FindActive() ([]*User, error)
	FindInactive() ([]*User, error)
	FindByRole(role string) ([]*User, error)
	FindByDepartment(dept string) ([]*User, error)
	Search(query string) ([]*User, error)
	UpdateEmail(id, email string) error
	UpdateRole(id, role string) error
	Deactivate(id string) error
}

// User is a user record.
type User struct {
	ID    string
	Email string
	Name  string
	Role  string
}

// GetUser retrieves a user by ID.
func (s *UserService) GetUser(id string) (*User, error) {
	user, err := s.repo.FindByID(id)
	if err != nil {
		return nil, fmt.Errorf("failed to get user: %s", err)
	}
	return user, nil
}

// UpdateUserEmail changes a user's email address.
func (s *UserService) UpdateUserEmail(id string, email string) error {
	_, err := s.repo.FindByID(id)
	if err != nil {
		log.Printf("failed to find user: %s", err)
		return errors.New("user not found")
	}

	err = s.repo.UpdateEmail(id, email)
	if err != nil {
		log.Printf("failed to update email: %s", err)
		return errors.New("update failed")
	}

	return nil
}

// DeleteUser removes a user.
func (s UserService) DeleteUser(id string) error {
	err := s.repo.Delete(id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %s", err)
	}
	return nil
}

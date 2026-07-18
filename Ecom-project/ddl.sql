-- ============================================================
-- HR Sample Database - DDL (MySQL)
-- Tables: departments, employees, managers, projects, employee_projects
-- ============================================================

CREATE DATABASE IF NOT EXISTS hr_db;
USE hr_db;

-- Drop existing tables (FK checks disabled so drop order doesn't matter)
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS employee_projects;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS managers;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS departments;

SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------
-- departments
-- ------------------------------------------------------------
CREATE TABLE departments (
    department_id   INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL,
    location        VARCHAR(100),
    budget          DECIMAL(12,2)
);

-- ------------------------------------------------------------
-- employees
-- (manager_id self-references employees; added as a separate
--  ALTER below since the table must exist first)
-- ------------------------------------------------------------
CREATE TABLE employees (
    employee_id     INT PRIMARY KEY,
    first_name      VARCHAR(50) NOT NULL,
    last_name       VARCHAR(50) NOT NULL,
    email           VARCHAR(150) UNIQUE,
    job_title       VARCHAR(100),
    hire_date       DATE,
    salary          DECIMAL(10,2),
    department_id   INT,
    manager_id      INT,
    CONSTRAINT fk_emp_department
        FOREIGN KEY (department_id) REFERENCES departments(department_id),
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- managers
-- (subset of employees who hold a management role,
--  with the department they manage and their tenure start)
-- ------------------------------------------------------------
CREATE TABLE managers (
    manager_id      INT PRIMARY KEY,
    employee_id     INT NOT NULL,
    department_id   INT,
    start_date      DATE,
    CONSTRAINT fk_mgr_employee
        FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT fk_mgr_department
        FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- ------------------------------------------------------------
-- projects
-- ------------------------------------------------------------
CREATE TABLE projects (
    project_id      INT PRIMARY KEY,
    project_name    VARCHAR(150) NOT NULL,
    department_id   INT,
    start_date      DATE,
    end_date        DATE,
    budget          DECIMAL(12,2),
    CONSTRAINT fk_proj_department
        FOREIGN KEY (department_id) REFERENCES departments(department_id)
);

-- ------------------------------------------------------------
-- employee_projects (junction table, many-to-many)
-- ------------------------------------------------------------
CREATE TABLE employee_projects (
    employee_id     INT NOT NULL,
    project_id      INT NOT NULL,
    role            VARCHAR(100),
    hours_allocated INT,
    PRIMARY KEY (employee_id, project_id),
    CONSTRAINT fk_ep_employee
        FOREIGN KEY (employee_id) REFERENCES employees(employee_id),
    CONSTRAINT fk_ep_project
        FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

-- pg-init.sql

-- Keycloak
CREATE USER keycloak WITH PASSWORD 'o22Cve0sIurpZvdP3u2SC0wjVflITf';
CREATE DATABASE keycloak OWNER keycloak;

-- SonarQube
CREATE USER sonarqube WITH PASSWORD 'Q9Cjts96us87hVw1PC8dEWZuj';
CREATE DATABASE sonarqube OWNER sonarqube;

-- Jenkins
-- CREATE USER jenkins WITH PASSWORD 'jenkins_pass';
-- CREATE DATABASE jenkins OWNER jenkins_user;

-- Vault
-- CREATE USER vault WITH PASSWORD 'vault_pass';
-- CREATE DATABASE vault OWNER vault_user;

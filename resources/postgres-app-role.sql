\getenv app_role_name POSTGRES_APP_USER
\getenv app_role_password POSTGRES_APP_PASSWORD

CREATE ROLE :"app_role_name"
    WITH LOGIN
    CREATEDB
    PASSWORD :'app_role_password'
    NOSUPERUSER
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

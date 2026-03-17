Summary of Actions Taken to Get Invenio RDM Running

admin@example.org
admin123

1. Initial Setup
Cloned the Invenio RDM starter repo and ran docker compose up.
The containers (web, database, search, etc.) started, but the website was not available and returned a 500 Internal Server Error.
2. Database and Indices Initialization
Ran the commands to create and initialize the database:
docker exec -it invenio-rdm-starter-worker-1 bash
invenio db create
invenio db init
invenio index init
These steps set up the PostgreSQL database and OpenSearch indices.
3. User Creation
Tried to create an admin user (admin@local.test) with the command:
invenio users create admin@local.test --password admin --active --confirm
However, it failed with an invalid email address error.
You switched to using admin@example.com to successfully create the user.
4. Role Assignment
Attempted to assign the administration role to the admin@example.com user by running:
invenio roles add admin@example.com administration
This led to an error stating "Cannot find user" since the user wasn't fully created or confirmed yet.
5. Manually Confirmed the User
Confirmed the user using the Invenio shell to update the confirmed_at field manually.
You ran Python code to assign the administration role to the user in the database, but the administration role was missing from the system.
6. Role Creation
Manually created the administration role by running:
Role.query.filter_by(name='administration').first() to check if it existed.
If not, created it and committed to the database.
7. Role Assignment
Assigned the administration role to the admin@example.com user manually, but still faced issues with login permissions due to a missing role configuration.
8. Final Troubleshooting
After ensuring the administration role was created and assigned, restarted the containers to apply changes.
Logged in using admin@example.com but encountered the "You do not have sufficient permissions" message because the role/permissions weren't fully configured.
Next Steps:
Check if the user has the correct role in the system.
Manually assign the role if necessary, using the Invenio shell.
Restart and test again.
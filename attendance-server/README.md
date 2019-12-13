# attendance-server

This node.js server uses Parse Server and serves as the backend for the Attendance app.

## Installation

### Dependencies

- node.js
- PostgreSQL server

To set up the server, run the following command to install NodeJS and PostgreSQL server:

```sh
sh setup.sh

# Install node packages
npm install
```

Start the PostgreSQL service

```sh
sudo service postgresql start
```

Set up postgres database password

```sh
sudo -u postgres psql
```

```sql
ALTER USER postgres PASSWORD 'password';
\q
```

Start node.js server and run python script to initialise database schema and create master admin account

```sh
sudo -u postgres node index.js
python setup.py
```

This creates a master admin:

- Username: 12345678
- Password: adminpassword123

## Usage

Start node.js server

```sh
sudo -u postgres node index.js
```

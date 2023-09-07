[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/christopherlouet/defectdojo-install/blob/main/LICENSE)

## About The Project

`ddadmin.sh`, an all-in-one bash script for easy installation of the DefectDojo project with the docker-compose method.

Features:

* Manager a defect-dojo instance, with a local profile file
* Facilitate the installation of the DefectDojo application
* View application status, environment variables, api token and logs
* Update new app version
* Change api token and credentials

## Getting Started

### Prerequisites

A linux machine with docker, docker-compose, and jq installed:

* docker installation : https://docs.docker.com/engine/install/
* docker-compose installation (not the plugin) : https://docs.docker.com/compose/install/standalone/
* jq : https://jqlang.github.io/jq/download/

To install the bash completion:

```bash
sudo cp bash_completion/ddadmin /etc/bash_completion.d/ddadmin
```

## Usage

### Starting/installing the application

At the first installation, the DefectDojo project will be cloned to the latest version.

If no profile file is configured yet, the script will generate it according to the user's choices.

Run this command to start application containers in manual mode:

```bash
./ddadmin.sh start
```

To automatically install the latest version, with the default "postgres-redis" profile file, run this command:

```bash
./ddadmin.sh start --install-auto
```

Once the installation is complete, you can access to the web interface at http://localhost:8080.

### Stopping/remove the application

To stop application containers:

```bash
./ddadmin.sh stop
```

Or to remove containers and volumes from the application:

```bash
./ddadmin.sh stop --remove
```

### Show app information

To show the app status:

```bash
./ddadmin.sh show status
```

Get information about DefectDojo releases:

```bash
./ddadmin.sh show release
```

Show the environment variables:

```bash
./ddadmin.sh show env
```

Display the API token:

```bash
./ddadmin.sh show token
```

View application logs:

```bash
./ddadmin.sh show logs
```

### Update app or credentials

To update the latest version of the application:

```bash
./ddadmin.sh update release
```

To update the API token:

```bash
./ddadmin.sh update token
```

To update the admin password:

```bash
./ddadmin.sh update password
```

## Tests

The pytest framework is used to run the unit tests of bash functions.
We will use a Docker container based on a Python environment to run the tests.

To launch the tests, we will use the command:

```bash
./tests.sh
```

## License

Distributed under the MIT License.

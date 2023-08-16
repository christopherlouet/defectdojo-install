## About The Project

The `ddadmin.sh` helper script, based on the DefectDojo project, is a simple bash script to facilitate
installing the django-DefectDojo application, with the docker-compose method.

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

```sh
sudo cp bash_completion/ddadmin /etc/bash_completion.d/ddadmin
```

## Usage

### Starting/installing the application

At the first installation, the DefectDojo project will be cloned to the latest version.

If no profile file is configured yet, the script will generate it according to the user's choices.

Run this command to start application containers in manual mode:

```sh
./ddadmin.sh start
```

To automatically install the latest version, with the default "postgres-redis" profile file, run this command:

```sh
./ddadmin.sh start --install-auto
```

Once the installation is complete, you can access to the web interface at http://localhost:8080.

### Stopping/remove the application

To stop application containers:

```sh
./ddadmin.sh stop
```

Or to remove containers and volumes from the application:

```sh
./ddadmin.sh stop --remove
```

### Show app information

To show the app status:

```sh
./ddadmin.sh show status
```

Get information about DefectDojo releases:

```sh
./ddadmin.sh show release
```

Show the environment variables:

```sh
./ddadmin.sh show env
```

Display the API token:

```sh
./ddadmin.sh show token
```

View application logs:

```sh
./ddadmin.sh show logs
```

### Update app or credentials

To update the latest version of the application:

```sh
./ddadmin.sh update release
```

To update the API token:

```sh
./ddadmin.sh update token
```

To update the admin password:

```sh
./ddadmin.sh update password
```

## License

Distributed under the MIT License.

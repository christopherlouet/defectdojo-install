<br/>
<p align="center">
  <h3 align="center">Defect dojo tools</h3>
  <p align="center">
    A sandbox project to play with DefectDojo.
    <br/>
    <br/>
  </p>
</p>

## About The Project

The helper script `ddadmin.sh`, based on the DefectDojo project, is a simple exploit tool making it easier 
installation of the django-DefectDojo application, with the docker-compose method.

Generates a profile.env file in the current project folder to more easily control the deployment of the application.

Features :

* Manager a defect-dojo instance.
* Set the profile and release
* Show application status, environment variables, api token and logs
* Update release
* Change api token and credentials
* Configuring the DefectDojo app (WIP)
* Backup and restore (TODO)

## Getting Started

### Prerequisites

A linux machine with docker, docker-compose, and jq installed :

* docker installation : https://docs.docker.com/engine/install/
* docker-compose installation (not the plugin) : https://docs.docker.com/compose/install/standalone/
* jq : https://jqlang.github.io/jq/download/

### Usage

```sh
./ddadmin.sh {start|stop|show|update}
```

```sh
./ddadmin.sh stop [--remove]
```

```sh
./ddadmin.sh show {status|release|env|token|logs}
```

```sh
./ddadmin.sh update {token|credential}
```

# (todo: complete documentation...)

## License

Distributed under the MIT License.

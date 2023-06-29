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

This project contains a suite of tools to play with DefectDojo.

Todo :
- Deploy DefectDojo on a server
- Scan the source code of a project
- Integration of a pipeline in gitlab, github
- ...

## Getting Started

### Prerequisites

A linux machine with docker and docker-compose installed, and that's all.

## dc.sh script

A helper script, based on the DefectDojo project, making it easier to manage and configure the installation of the 
django-DefectDojo application.

Generates a profile.env file in the current project folder to more easily control the deployment of the application.

### Usage

```sh
./dc.sh {start|down|stop|init|env|status|credentials|log}
```

# (todo: complete documentation...)

## License

Distributed under the MIT License.

# web2py development environment

[web2py python framework](https://www.web2py.com/)

- Ubuntu 22.04 (jammy)
- Python 3.10
- pip 22
- nginx (stable)
- uWSGI (latest)
- PostgreSQL 14
- locale pt_BR.UTF-8

## Prerequisites

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [Git](https://git-scm.com/downloads)

## Usage

Clone or download this repo and enter in project dir.

```SHELL
git clone https://github.com/santosleonardo/web2py_dev.git
cd web2py_dev
```

Use the table below for reference to run the commands:

| string | version |
|--------|---------|
| v2     | v2.27.1 |
| v3     | v3.0.11 |

### Config/start environment

```SHELL
vagrant up [string]
```

### Enter environment console

```SHELL
vagrant ssh [string]
```

### Shutdown environment

```SHELL
vagrant halt [string]
```

Apps folder: `/vagrant/[version]/web2py/applications`

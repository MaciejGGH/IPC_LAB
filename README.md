## IPC LAB

### Getting started
Copy Informatica 10.2 installation binnaries to `informatica/software`

Build `ipc:software` and `ipc:final` images
```bash
$ ./bake build ipc:software
$ ./bake build ipc:final
```

Make a copy of `.env.example`
```bash
$ cp .env.example .env
```

Run `docker-compose`\
**IMPORTANT:** Provided `docker-compose.yml` file requires you to have `oracle/database:12.2.0.1-ee` image. 
```bash
$ docker-compose up
```


### Informatica images
* ipc_lab/ipc:software
* ipc_lab/ipc:os
* ipc_lab/ipc:installer
* ipc_lab/ipc:installed
* ipc_lab/ipc:final


### Building intermediate images
```bash
# To build ipc_lab/ipc:software
$ ./bake build ipc:software

# To build ipc_lab/ipc:os
$ ./bake build ipc:os

# To build ipc_lab/ipc:installer
$ ./bake build ipc:installer

# To build ipc_lab/ipc:installed
$ ./bake build ipc:installed

# To build ipc_lab/ipc:final
$ ./bake build ipc:final
```
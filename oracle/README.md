# Oracle Database 12.2.0.1 EE on Docker

Experimental Oracle Database 12.2.0.1 EE Docker image that should start in less than a 60s.

## Info
Starting original image provided by Oracle takes a lot of time (>10min). On slow machine it can take over 40min.
To reduce it to bare minimum, the most time consuming process which is creating database (CDB) is executed while building image. 
However this creates another problem - size of the final image is ~2.8GB bigger than original one. To mitigate it, whole `oradata` directory is compressed, which makes final image only ~500MB larger than original.

Image build this way can be started in less than 60s.

In comparinson to solution proposed in this[[3]] article, it allows to use external volumes, can be started (right now only in theory**) with different parameters (PDB names, passwords etc.), and doesn't require any manual operations.


[3]: https://medium.com/@ggajos/drop-db-startup-time-from-45-to-3-minutes-in-dockerized-oracle-19-3-0-552068593deb


**Currently CDB/PDB names and all passwords are hardcoded.



## Building image
```bash
# build image with software binaries
$ ./build.sh software

# build image with os
$ ./build.sh base-os

# build builder image
$ ./build.sh builder

# build final image
$ ./build.sh final
```


## Resources
1. https://blog.dbi-services.com/some-ideas-about-oracle-database-on-docker/
2. https://github.com/oracle/docker-images
3. https://medium.com/@ggajos/drop-db-startup-time-from-45-to-3-minutes-in-dockerized-oracle-19-3-0-552068593deb
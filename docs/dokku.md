# Dokku, Local

Trying to set up dokku so it works in a local development environment, allowing dev to attempt realistic deployments on their local machine.

Dokku will be installed in a container, which itself will create additional containers through plugins and deployed apps.

Got dokku starting in a container using the dokku/dokku image, podman, and some volume+port mapping.

Found a docker install example [here](https://dokku.com/docs/getting-started/install/docker/) and modified it to use podman and bind a volume to my home dir.

```
podman pull docker.io/dokku/dokku:0.28.4
podman container run \
  --env DOKKU_HOSTNAME=dokku.me \
  --env DOKKU_HOST_ROOT=/var/lib/dokku/home/dokku \
  --name dokku \
  --publish 3022:22 \
  --publish 8080:80 \
  --publish 8443:443 \
  --volume /home/carl/.local/dokku:/mnt/dokku \
  --volume /run/user/1000/podman/podman.sock:/var/run/docker.sock \
  dokku/dokku:0.28.4
```

Enter the container to run dokku commands and manage:

```
podman exec -it dokku bash
dokku plugin:install https://github.com/dokku/dokku-redis.git
dokku plugin:install https://github.com/dokku/dokku-postgres.git
```

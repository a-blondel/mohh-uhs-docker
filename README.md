# Medal of Honor Heroes UHS in Docker
A docker wrapper for the [User Hosted Server](https://planetmedalofhonor.gamespy.com/View5e40.html?view=MoHHeroesFiles.Detail&id=1) ([backup](https://www.mediafire.com/file/gdx9eglhjfv1wfn/MOHHServerSetupNA.rar/file)) binary.

It features a way to run multiple instances of the server on a docker container. The instances will automatically restart when it crashes or when the container is restarted.

## Usage
The image is available on the [GitHub packages](https://github.com/a-blondel/mohh-uhs-docker/packages) of this repository, so you can pull it directly from there and you don't need to build the image.

When running the container, you need to specify the following environment variables:
- `UHS_NAME`: The name of the account used to run the server
- `UHS_PWD`: The password of the account used to run the server
- `UHS_ADMIN_PWD`: The password to access the admin menu in the game
- `UHS_PORT`: The base port of the server, defaults to 3658. Every instance will use a port starting from this one
- `UHS_LOC`: The location of the server. This will affect the game names of `maplist.txt` by overriding the "[LOC]" placeholder on the fly. E.g. with UHS_LOC = US and -gname:"[LOC] TEAM MIX", it will appear as "[US] TEAM MIX".

The container will use the embedded `maplist.txt` file. This way, the file is updated at each map rotation, preventing to start over the rotation on game crash.  

## Edit maplist

To update the map rotation (or any game parameter), open a bash into the container, edit the `maplist.txt` file, then manually kill mohz.exe instances that needs to be restarted with updated parameters. The process will restart automatically with updated parameters thanks to the periodic service.  

Detailed commands to achieve this :
```
docker exec -it mohh-uhs /bin/bash
apt-get update
apt-get install nano
cd /var/www/mohh-uhs
nano maplist.txt
pgrep -fla "mohz.exe"
kill {process-id}
```

Where {process-id} matches the process id (that you find using the pgrep command) of the uhs instance that needs to be restarted.  
Don't forget that the first instance use UHS_PORT port and each additional instance (each new line of maplist.txt) increments UHS_PORT's value by one.  

## Build the image manually
In order to do so, you need to create a `bin` folder at the root of this project and put the installation files from the UHS installer in it (which includes `mohz.exe`, ...).

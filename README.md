# Docker 4 Feel++

## What can you generate with this repository ?

Using docker and docker-compose, you will currently generate the following images:
- feelpp/feelpp-env:latest
- feelpp/feelpp-env:minimal
- feelpp/develop:latest
- feelpp/develop:insitu
- feelpp/develop:novtk
- feelpp/develop:models-fluid
- feelpp/develop:models-solid
- feelpp/develop:models-fsi
- feelpp/develop:crb

To generate those images, use the following command at the base of the repository:
```
docker-compose build
```

## In-situ visulization with ParaView

### In a nutshell

```
# This setup is valid if you are launching ParaView 
# and docker on the same computer.
# You must ensure that your ParaView version matches the one used in docker
# (It should be the latest available)

# Download Feel++ docker image
shell> docker pull feelpp/develop
```

From here, you have 2 ways to proceed:   
   
* Directly use the network of the host:

```
# Launch a pvserver
shell> pvserver
# Launch ParaView, connect to the pvserver and enable Catalyst in the interface 
shell> paraview

# Run the feelpp image
shell> docker run -ti --net=host feelpp/develop

# Run the application
dockershell> mpirun -np 2 feelpp_qs_laplacian_2d --config-file src/feelpp/quickstart/laplacian/qs_laplacian_2d.cfg --exporter.format vtk --exporter.vtk.insitu.enable 1
```

* Use the port export feature from docker (safer regarding to security):

```
# Run feelpp image
shell> docker run -ti -P 11111:11111 feelpp/develop

# Launch tmux to multiplex terminals
dockershell> tmux
# Launch a pvserver in the first terminal
dockershell1> pvserver

# Launch ParaView and connect to the pvserver
shell> paraview

dockershell2> mpirun -np 2 feelpp_qs_laplacian_2d --config-file src/feelpp/quickstart/laplacian/qs_laplacian_2d.cfg --exporter.format vtk --exporter.vtk.insitu.enable 1
```

### Full description
The dev-env image builds the latest stable version of ParaView with Catalyst enabled for In-Situ visualization.
The develop image uses the dev-env base image and enables In-Situ visualization.

To use In-Situ visulization with a Feel++ application that you build in a container based on the develop image, you first have to configure the container to export ports.   
The first time you launch the container with `docker run`, you must use the `-p` option to redirect a container port to the host machine. The option syntax is as follows in the simple case: `-p hostPost:containerPort`. In this case, you will redirect the `containerPort` port to the `hostPort` port.   
We advise you to use a pvserver to use In-Situ. The default port pvserver uses is 11111, thus to export this port when running the container, you can do:
```
docker run -ti -p 11111:11111  feelpp/develop
```

*Useful tip*: the feelpp/dev-env image packages the `tmux`and `screen` terminal multiplexers, so you can launch several virtual terminals inside the container.

Once you have launcher the container with the exported port, you can launch a pvserver inside the connect and setup your ParaView to use Catalyst and connect to the pvserver, by specifying the host and hostPort.
You can then launch sample Feel++ apps and use In-Situ visualization. For example:
```
mpirun -np 2 feelpp_qs_laplacian_2d --config-file src/feelpp/quickstart/laplacian/qs_laplacian_2d.cfg --exporter.format vtk --exporter.vtk.insitu.enable 1
```

If you encounter problems regarding infiniband on supercomputers, you can add the following option to mpirun to use tcp: ` -mca btl tcp,self`

For more information about In-Situ visualization in Feel++, please refer to [https://github.com/feelpp/feelpp/wiki/In-Situ-Visualization](https://github.com/feelpp/feelpp/wiki/In-Situ-Visualization)

# docker
Docker 4 Feel++

## In-situ visulization with ParaView

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

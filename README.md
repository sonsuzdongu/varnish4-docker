# Docker file for Varnish4 on ubuntu 14.04


## you can pull docker

<pre>docker pull yuxel/varnish4</pre>

## or you can build it

<pre>./bin build</pre>


## To run varnish in docker instance

<pre>./bin run</pre>

## To run varnish on port 80

<pre>VARNISH_PORT="-p 80:6081" ./bin run</pre>

## Configuration file

Configuraion file is on data directory. Feel free to edit this file

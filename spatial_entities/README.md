# Spatial entities

This folder contains most of the boilerplate code required by spatial entities.

While there are a few additions specific to this demo such as showing the axis and labels, this is designed to be used as a template for any spatial entities implementation.

## Spatial entities manager

This is the heart of the implementation of this system.

Add this node to your `XROrigin3D` node and it will automatically instantiate scenes for each type of supported spatial entity and placed correctly into the world.

As the spatial entities system is build ontop of Godots XR tracker system, this implementation can easily be extended to support additional spatial entity types as they are made available either in core or through plugins.

## Spatial UUID db

When anchors are made persistent, a UUID is assigned to them so we can recognise them next time our application starts and those anchors are recreated.

The UUID DB implementation is a simple example that allows storing meta data alongside the UUID so the correct scene can be reproduced.

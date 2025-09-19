# Spatial Entities Demo

This is a demo project to showcase the spatial entities implementation in Godot.

Requires a build of Godot with [spatial entities support](https://github.com/godotengine/godot/pull/107391).

## Deploying

For deployment to android devices, please ensure to install the [Godot OpenXR Vendors plugin](https://github.com/GodotVR/godot_openxr_vendors)
and properly configure the export presets (see [documentation](https://docs.godotengine.org/en/stable/tutorials/xr/deploying_to_android.html)).
Note that for some devices you will need a custom build which adds requires spatial entities permissions.

## Grab logic

This demo uses the hand interaction profile to detect a pinch motion by the user.
This allows you to grab various objects in the scene.

> [!NOTE]
> The pinch input is used because it is more reliable on many devices at this point in time.
> In the future we may switch to the more natural grab input.

The grab logic itself is a simple implementation that uses an area node to detect which physics object is within reach.
Then when the user makes a grab motion we take control of the positioning of that object.

When the object is let go and it was a RigidBody3D node, physics simulation will be enabled.

## Controller fallback

If controllers are used and inferred hand tracking is not supported, we fall back to normal controller tracking.

## Anchors

Most objects we can grab have anchor logic implemented. Note that the logic does require spatial anchors to be supported.
If persistent anchors are supported we'll store the associated scene in a meta data file so we can reconstruct the objects
when the application starts again.

When an object is dropped, we have different behavior depending on the object.

For any object that was already part of an anchor, a new anchor is created and the previous one removed.
Anchors do not have functionality to let us update their position so we perform a replacement.

For the inventory board and the trash can, we'll create anchors and remove the previous scene.
This ensures only one such scene exists.

For objects on the inventory board, an anchored clone is created and the object is returned to the inventory board.

## Plane tracking

If plane tracking is available, we'll create slightly transparent objects to visualise the planes shape
and create a static physics body for the plane allowing us to interact with the surface.

## Marker tracking

In the folder `markers` you'll find markers you can print out and test with the demo.

## Manual implementation

The folder `Manual implementation` contains sample code for custom implementations of each discovery process.
Note that these are untested at this point in time.
The demo assumes the built-in logic is used.

> [!NOTE]
> This implementation is not fully tested and currently purely intended as a reference.

## Wrist UI

There is a wrist UI implementation that shows a simple UI on the users hands that can be interacted with through touch.
This works through an area that detects physics objects in a dedicated UI physics layer and emulates mouse events
as these objects interact with the area.

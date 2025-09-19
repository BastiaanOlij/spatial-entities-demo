extends XROrigin3D

# Get some handy links
@onready var hand_tracking_msg = $XRCamera3D/HandTrackingMsg
@onready var left_grab_handler = $LeftHand/LeftHandHumanoid2/LeftHandHumanoid/Skeleton3D/HandRootAttachment/GrabHandler
@onready var right_grab_handler = $RightHand/RightHandHumanoid2/RightHandHumanoid/Skeleton3D/HandRootAttachment/GrabHandler
@onready var left_wrist_ui = $LeftHand/LeftHandHumanoid2/LeftHandHumanoid/Skeleton3D/HandRootAttachment/WristUI
@onready var right_wrist_ui = $RightHand/RightHandHumanoid2/RightHandHumanoid/Skeleton3D/HandRootAttachment/WristUI
@onready var left_touch_ui = $LeftHand/LeftHandHumanoid2/LeftHandHumanoid/Skeleton3D/IndexTipAttachment/TouchUI
@onready var right_touch_ui = $RightHand/RightHandHumanoid2/RightHandHumanoid/Skeleton3D/IndexTipAttachment/TouchUI

func _on_start_vr_focus_gained():
	var interface : OpenXRInterface = $StartVR.get_interface()
	if interface:
		interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND

func _process(_delta):
	# Show our hand tracking message if we can't see either hand
	hand_tracking_msg.visible = not $LeftHand.visible and not $RightHand.visible

	left_grab_handler.enabled = $LeftHand.visible
	right_grab_handler.enabled = $RightHand.visible
	left_wrist_ui.enabled = $LeftHand.visible
	right_wrist_ui.enabled = $RightHand.visible
	left_touch_ui.enabled = $LeftHand.visible
	right_touch_ui.enabled = $RightHand.visible

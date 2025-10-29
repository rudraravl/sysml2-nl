// Design a robot arm that can rotate 360 degrees and has a gripper to pick up small objects.
package 'Robot Arm System' {
	private import ISQ::*;
	private import SI::*;

	part def RobotArm {
		attribute rotationAngle : PlaneAngleValue[1];
		part gripper : Gripper;

		assert constraint { rotationAngle >= 0['°'] and rotationAngle <= 360['°'] }

		req 'PickUpSmallObjects' {
			text "The robot arm's gripper shall be able to pick up small objects.";
		}
	}

	part def Gripper;
}

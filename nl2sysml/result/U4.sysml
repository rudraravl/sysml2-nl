// Design a robot arm that can rotate 360 degrees and has a gripper to pick up small objects.
```sysml
package RobotArm {

  // Define units and types
  unit degree;
  type Angle = Scalar.Real { unit degree; }; // Define Angle type with degree unit
  type Boolean = Scalar.Boolean; // Use built-in Scalar.Boolean
  type Power = Scalar.Real { unit watt; }; // Example power type

  part RobotArm {
    // Parts of the robot arm
    part base: Base;
    part armSegment: ArmSegment;
    part gripper: Gripper;

    // Flows for the overall arm's external interface
    flow in powerIn: Power; // Power input for the whole arm
    flow in baseRotateCmd: Angle; // Command to rotate the base
    flow in gripperGripCmd: Boolean; // Command to open/close gripper
    flow out gripperObjectDetected: Boolean; // Sensor feedback from gripper

    // Bindings to connect the top-level flows to internal parts
    bind baseRotateCmd = base.rotateCmd;
    bind gripperGripCmd = gripper.gripCmd;
    bind gripperObjectDetected = gripper.objectDetected;
  }

  part Base {
    attribute rotationAngle: Angle; // Current angle of rotation
    constraint rotationRange {
      0.degree <= rotationAngle and rotationAngle <= 360.degree;
    }
    flow in rotateCmd: Angle; // Command to rotate the base
  }

  part ArmSegment {
    // Placeholder for arm segments, could be further decomposed
    // For this problem, it's a structural part without specific behavior requested.
  }

  part Gripper {
    flow in gripCmd: Boolean; // Command to open/close gripper (true for close, false for open)
    flow out objectDetected: Boolean; // Sensor feedback (true if object detected)
  }

  // Requirements
  requirement Rotate360Degrees {
    text "The robot arm base shall be capable of rotating 360 degrees.";
    // Satisfied by the Base part's rotationRange constraint
    satisfy base;
  }

  requirement PickUpSmallObjects {
    text "The robot arm gripper shall be capable of picking up small objects.";
    // Satisfied by the Gripper part
    satisfy gripper;
  }

}
```

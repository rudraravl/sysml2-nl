// Define a drone that has the ability to pick up objects from a structure.
package DroneSystem {

  part def Drone {
    ref gripper: Gripper;
  }

  part def Gripper {
    // A mechanism designed to grasp and release objects.
  }

  part def Object {
    // An item that can be picked up.
  }

  part def Structure {
    // A physical construction from which objects can be picked up.
  }

  capability def PickUpObject {
    ref performer: Drone;
    ref objectToPickUp: Object;
    ref sourceStructure: Structure;
  }

}

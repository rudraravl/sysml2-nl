// Define a drone that has the ability to pick up objects from a structure.
package DroneSystem {
    part def Drone {
        behavior pickUpCapability : PickUpBehavior;
    }
    part def Structure;
    part def Object;

    behavior def PickUpBehavior {
        in objectToPick : Object;
        in fromStructure : Structure;
    }
}

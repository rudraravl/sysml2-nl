// Define a drone that has the ability to pick up objects from a structure.
package PickupDrone {
    private import ISQ::*;
    private import SI::*;
    private import Systems;
    private import StateMachines;

    package DataTypes {
        item def Payload {
            attribute mass: MassValue;
        }

        enum GripperStatus {
            open,
            closed,
            gripping,
            error
        }

        value def PositionCoordinates {
            attribute x: LengthValue;
            attribute y: LengthValue;
            attribute z: LengthValue;
        }
    }

    package Components {
        import DataTypes::*;

        port def ActuatorControl {
            in command: String;
            out status: GripperStatus;
        }

        port def SensorData<T> {
            out value: T;
        }

        part def Gripper {
            port control: ActuatorControl;
            attribute status: GripperStatus;
            attribute maxLoad: MassValue = 0.5 [kg];

            bind control.status = status;

            state machine GripperLifecycle {
                initial state Open;

                state Open {
                    entry { status = GripperStatus::open; }
                }
                state Closing;
                state Closed {
                    entry { status = GripperStatus::closed; }
                }
                state Gripping {
                    entry { status = GripperStatus::gripping; }
                }
                state Opening;

                transition from Open to Closing on control.command == "close";
                transition from Closing to Closed;
                transition from Closed to Opening on control.command == "open";
                transition from Opening to Open;
                transition from Closed to Gripping on control.command == "grip";
            }
        }

        part def RoboticArm {
            port control: ActuatorControl;
            attribute currentPosition: PositionCoordinates;
            attribute reach: LengthValue = 0.3 [m];
        }

        part def ProximitySensor {
            port data: SensorData<LengthValue>;
        }

        part def FlightController {
            port armCmd: ActuatorControl;
            port gripperCmd: ActuatorControl;
            port sensorIn: SensorData<LengthValue>;
        }

        part def Drone {
            part gripper: Gripper;
            part arm: RoboticArm;
            part sensor: ProximitySensor;
            part controller: FlightController;

            connect controller.armCmd to arm.control;
            connect controller.gripperCmd to gripper.control;
            connect sensor.data to controller.sensorIn;
        }
    }

    package Behaviors {
        import DataTypes::*;
        import Components::*;

        action def PickupPayload {
            inout drone: Drone;
            in targetPayload: Payload;
            in targetLocation: PositionCoordinates;

            step approach {
                doc /* Drone flies to the target location. */
            }
            step alignArm(targetLocation) {
                doc /* Controller commands arm to move to target coordinates. */
                send drone.controller.armCmd { command = "move"; }
            }
            step waitForArm {
                accept drone.controller.armCmd { status == GripperStatus::closed; }
            }
            step grasp {
                doc /* Controller commands gripper to close on the payload. */
                send drone.controller.gripperCmd { command = "grip"; }
            }
            step verifyGrasp {
                doc /* Controller verifies the gripper status. */
                accept drone.controller.gripperCmd { status == GripperStatus::gripping; }
            }
            step lift {
                doc /* Drone ascends with the payload. */
            }

            flow approach to alignArm;
            flow alignArm to waitForArm;
            flow waitForArm to grasp;
            flow grasp to verifyGrasp;
            flow verifyGrasp to lift;
        }
    }

    package Requirements {
        import Systems::*;
        import RequirementDerivation::*;
        import Components::*;
        import DataTypes::*;

        requirement <'R-01'> PickupCapability {
            doc /* The drone system shall be capable of picking up a specified payload
                 * from a stationary structure. */
            subject system: System;
        }

        requirement <'R-01.1'> GripperStrength {
            doc /* The gripper shall be capable of securely lifting a payload
                 * with a mass up to 500 grams. */
            subject g: Gripper;
            assert constraint { g.maxLoad >= 500 [g] }
        }

        requirement <'R-01.2'> ArmReach {
            doc /* The robotic arm shall have sufficient reach to access payloads
                 * up to 30 cm from the drone's center. */
            subject a: RoboticArm;
            assert constraint { a.reach >= 30 [cm] }
        }

        #derivation {
            end #original ::> PickupCapability;
            end #derive ::> GripperStrength;
            end #derive ::> ArmReach;
        }
    }

    package SystemContext {
        import Components::*;
        import DataTypes::*;
        import Requirements::*;

        part def GroundStructure {
            part payloadMount;
        }

        part missionContext {
            part drone: Drone;
            part structure: GroundStructure;
            part payload: Payload on structure.payloadMount {
                attribute :>> mass = 400 [g];
            }
        }

        satisfy PickupCapability by missionContext.drone {
            doc /* The Drone part definition, with its components and behaviors,
                 * satisfies the pickup capability requirement. */
        }

        satisfy GripperStrength by missionContext.drone.gripper;
        satisfy ArmReach by missionContext.drone.arm;
    }
}

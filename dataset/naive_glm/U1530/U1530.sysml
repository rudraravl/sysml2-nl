package WaterMill {
    import ScalarValues::*;

    unit m3_per_s;
    unit kg_per_s;
    unit rpm;
    unit Nm;
    unit kg;

    attribute def VolFlowRate :> Real { unit m3_per_s; }
    attribute def MassFlowRate :> Real { unit kg_per_s; }
    attribute def RotSpeed :> Real { unit rpm; }
    attribute def TorqueValue :> Real { unit Nm; }
    attribute def MassValue :> Real { unit kg; }

    item def Water;
    item def Grain;
    item def Flour;

    port def WaterFlowPort {
        attr flowRate : VolFlowRate;
        item water : Water;
    }

    port def MechPowerPort {
        attr torque : TorqueValue;
        attr speed : RotSpeed;
    }

    port def GrainFlowPort {
        attr flowRate : MassFlowRate;
        item grain : Grain;
    }

    port def FlourFlowPort {
        attr flowRate : MassFlowRate;
        item flour : Flour;
    }

    part def WaterChannel {
        out port waterOut : WaterFlowPort;
        attribute currentFlow : VolFlowRate;
        attribute gateOpen : Boolean;
    }

    part def WaterWheel {
        in port waterIn : WaterFlowPort;
        out port mechOut : MechPowerPort;
        attribute currentSpeed : RotSpeed;
        attribute currentTorque : TorqueValue;

        part def WheelBucket {
            attribute capacity : MassValue = 10 [kg];
        }
        part buckets : WheelBucket[20];
    }

    part def DriveShaft {
        in port mechIn : MechPowerPort;
        out port mechOut : MechPowerPort;
        attribute shaftSpeed : RotSpeed;
        attribute shaftTorque : TorqueValue;
    }

    part def MillstoneAssembly {
        in port mechIn : MechPowerPort;
        in port grainIn : GrainFlowPort;
        out port flourOut : FlourFlowPort;
        attribute grindingSpeed : RotSpeed;

        part def UpperMillstone {
            in port mechIn : MechPowerPort;
            in port grainIn : GrainFlowPort;
            out port flourOut : FlourFlowPort;
            attribute speed : RotSpeed;
            attribute weight : MassValue = 500 [kg];
        }

        part def LowerMillstone {
            attribute weight : MassValue = 500 [kg];
            attribute isStationary : Boolean = true;
        }

        part upper : UpperMillstone;
        part lower : LowerMillstone;

        connection mechPass connect mechIn to upper.mechIn;
        connection grainPass connect grainIn to upper.grainIn;
        connection flourPass connect upper.flourOut to flourOut;
    }

    part def GrainHopper {
        out port grainOut : GrainFlowPort;
        attribute grainMass : MassValue;
        attribute feedRate : MassFlowRate = 0.5 [kg_per_s];
    }

    part def FlourCollector {
        in port flourIn : FlourFlowPort;
        attribute flourMass : MassValue;
    }

    part def MillController {
        attribute waterFlow : VolFlowRate;
        attribute grainAvailable : Boolean;
        attribute currentSpeed : RotSpeed;
        attribute minOpSpeed : RotSpeed = 20 [rpm];
        attribute safetyStopActive : Boolean = false;
    }

    requirement def MillRequirements {
        subject sys : WaterMillSystem;
        requirement OperateUsingWater {
            doc /* The system shall use water flow to rotate the wheel. */
        }
        requirement GrindGrainIntoFlour {
            doc /* The system shall grind grain into flour between millstones. */
        }
        requirement AutoShutdownOnNoWater {
            doc /* If water flow stops, the system shall decelerate to a stop to prevent damage. */
        }
    }

    part def WaterMillSystem {
        part channel : WaterChannel;
        part wheel : WaterWheel;
        part shaft : DriveShaft;
        part millstones : MillstoneAssembly;
        part hopper : GrainHopper;
        part collector : FlourCollector;
        part controller : MillController;

        connection waterCon connect channel.waterOut to wheel.waterIn;
        connection mechCon1 connect wheel.mechOut to shaft.mechIn;
        connection mechCon2 connect shaft.mechOut to millstones.mechIn;
        connection grainCon connect hopper.grainOut to millstones.grainIn;
        connection flourCon connect millstones.flourOut to collector.flourIn;

        bind controller.waterFlow = channel.currentFlow;
        bind controller.currentSpeed = wheel.currentSpeed;
        bind controller.grainAvailable = hopper.grainMass > 0.0 [kg];
        bind shaft.shaftSpeed = wheel.currentSpeed;
        bind millstones.grindingSpeed = shaft.shaftSpeed;
        bind millstones.upper.speed = shaft.shaftSpeed;

        state machine MillStateMachine {
            state idle;
            state starting;
            state grinding;
            state shuttingDown;

            transition idle -> starting when controller.waterFlow > 0.0 [m3_per_s] {
                action { controller.safetyStopActive = false; }
            }
            transition starting -> grinding when controller.currentSpeed >= controller.minOpSpeed && controller.grainAvailable;
            transition starting -> shuttingDown when controller.waterFlow == 0.0 [m3_per_s] {
                action { controller.safetyStopActive = true; }
            }
            transition grinding -> shuttingDown when controller.waterFlow == 0.0 [m3_per_s] {
                action { controller.safetyStopActive = true; }
            }
            transition shuttingDown -> idle when controller.currentSpeed == 0.0 [rpm];
        }
    }
}

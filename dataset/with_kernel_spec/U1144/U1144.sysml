package NecroboticGripperSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import SI::Pa;
    private import SI::N;
    private import SI::kg;
    private import SI::s;

    enum def CommandType {
        ACTUATE;
        RELEASE;
        HOLD;
    }

    item def Air;

    item def GripCommand {
        attribute commandType : CommandType;
    }

    item def ContactSignal {
        attribute touchDetected : Boolean = false;
        attribute contactForce : Real [N] = 0.0;
    }

    item def DelicateObject {
        attribute mass : Real [kg];
        attribute fragilityThreshold : Real [N];
    }

    port def PneumaticPort {
        out item air : Air;
        attribute pressure : Real [Pa];
    }

    port def PneumaticInPort {
        in item air : Air;
        attribute pressure : Real [Pa];
    }

    port def CommandPort {
        out item command : GripCommand;
    }

    port def CommandInPort {
        in item command : GripCommand;
    }

    port def ContactSensorPort {
        out item contact : ContactSignal;
    }

    port def ContactSensorInPort {
        in item contact : ContactSignal;
    }

    part def AirPump {
        port pressureOut : PneumaticPort;
        attribute maxPressure : Real [Pa] = 100000;
        attribute flowRate : Real = 0.0001;
    }

    part def PressureRegulator {
        port pressureIn : PneumaticInPort;
        port pressureOut : PneumaticPort;
        attribute regulatedPressure : Real [Pa];
    }

    part def SolenoidValve {
        port pressureIn : PneumaticInPort;
        port pressureOut : PneumaticPort;
        port commandIn : CommandInPort;
        attribute valveOpen : Boolean = false;
    }

    part def PneumaticActuationSystem {
        port commandIn : CommandInPort;
        port pressureOut : PneumaticPort;

        part airPump : AirPump;
        part pressureRegulator : PressureRegulator;
        part solenoidValve : SolenoidValve;

        flow of air : Air
            from airPump.pressureOut.air to pressureRegulator.pressureIn.air;
        flow of air : Air
            from pressureRegulator.pressureOut.air to solenoidValve.pressureIn.air;
        flow of air : Air
            from solenoidValve.pressureOut.air to pressureOut.air;
        bind commandIn = solenoidValve.commandIn;
    }

    part def ContactSensor {
        port dataOut : ContactSensorPort;
        attribute contactThreshold : Real [N] = 0.01;
        attribute measuredForce : Real [N] = 0.0;
        attribute touchDetected : Boolean = false;

        action sense {
            first start;
            then action sendSignal send new ContactSignal() to dataOut;
            then sendSignal;
        }
    }

    part def SpiderCarcassGripper {
        port pressureIn : PneumaticInPort;
        port contactOut : ContactSensorPort;
        part contactSensor : ContactSensor;

        attribute bodyMass : Real [kg] = 0.003;
        attribute legExtensionPressure : Real [Pa] = 60000;
        attribute legsExtended : Boolean = false;
        attribute gripping : Boolean = false;
        attribute currentGripForce : Real [N] = 0.0;
        item heldObject : DelicateObject[0..1];

        bind contactSensor.dataOut = contactOut;

        action gripAction {
            first start;
            then action receiveAir accept Air via pressureIn;
            then decide;
                if pressureIn.pressure >= legExtensionPressure then action extendLegs;
                else action curlLegs;
            then done;
        }
    }

    part def MicrocontrollerUnit {
        port commandOut : CommandPort;
        port sensorIn : ContactSensorInPort;
        port operatorCommandIn : CommandInPort;

        attribute desiredGripForce : Real [N] = 0.05;
        attribute maxSafeForce : Real [N] = 0.15;
        attribute maxOperationCycles : Integer = 1000;
        attribute cycleCount : Integer = 0;
        attribute currentForce : Real [N] = 0.0;
        attribute contactDetected : Boolean = false;

        action controlLoop {
            first start;
            then merge cycleStart;
            then action openGripper send new GripCommand() to commandOut;
            then action waitForContact accept ContactSignal via sensorIn;
            then action closeGripper send new GripCommand() to commandOut;
            then action holdObject accept GripCommand via operatorCommandIn;
            then action releaseGripper send new GripCommand() to commandOut;
            then cycleStart;
        }
    }

    part def TargetObject {
        attribute mass : Real [kg] = 0.0035;
        attribute fragilityThreshold : Real [N] = 0.12;
    }

    requirement def MassHandling {
        attribute spiderBodyMass : Real [kg] = 0.003;
        attribute minPayloadMass : Real [kg] = 0.0035;
    }

    requirement def CycleDurability {
        attribute minCycles : Integer = 1000;
    }

    requirement def GentleGrip {
        attribute desiredForce : Real [N] = 0.05;
        attribute maxSafeForce : Real [N] = 0.15;
    }

    part necroboticGripperSystem {
        part microcontroller : MicrocontrollerUnit;
        part pneumaticSystem : PneumaticActuationSystem;
        part spiderGripper : SpiderCarcassGripper;
        part targetObject : TargetObject;
        port operatorCommandIn : CommandInPort;

        flow of command : GripCommand
            from microcontroller.commandOut.command to pneumaticSystem.commandIn.command;
        flow of air : Air
            from pneumaticSystem.pressureOut.air to spiderGripper.pressureIn.air;
        flow of contact : ContactSignal
            from spiderGripper.contactOut.contact to microcontroller.sensorIn.contact;
        bind operatorCommandIn = microcontroller.operatorCommandIn;

        requirement massHandling : MassHandling;
        requirement cycleDurability : CycleDurability;
        requirement gentleGrip : GentleGrip;
    }
}

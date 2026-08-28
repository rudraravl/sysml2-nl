package NecroboticGripperSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============================================================
    // Value Types (with units)
    // ============================================================
    value type ForceValue :> Real {
        attribute unit : String = "N";
        attribute min : ForceValue = 0.0;
        attribute max : ForceValue = 5.0;
    }
    value type PressureValue :> Real {
        attribute unit : String = "Pa";
        attribute min : PressureValue = 0.0;
        attribute max : PressureValue = 300000.0;
    }
    value type MassValue :> Real {
        attribute unit : String = "g";
        attribute min : MassValue = 0.0;
    }
    value type VolumeValue :> Real {
        attribute unit : String = "mL";
        attribute min : VolumeValue = 0.0;
    }
    value type FlowRateValue :> Real {
        attribute unit : String = "mL/s";
        attribute min : FlowRateValue = 0.0;
    }
    value type VoltageValue :> Real {
        attribute unit : String = "V";
    }
    value type CurrentValue :> Real {
        attribute unit : String = "A";
    }
    value type TimeValue :> Real {
        attribute unit : String = "s";
        attribute min : TimeValue = 0.0;
    }
    value type CycleCount :> Integer {
        attribute min : CycleCount = 0;
    }
    value type Dimensionless :> Real;

    // ============================================================
    // Item Types
    // ============================================================
    item def Air;

    enum def GripMode {
        enum actuate;
        enum release;
        enum hold;
    }

    item def GripCommand {
        attribute mode : GripMode;
        attribute targetForce : ForceValue = 0.5;
        attribute timestamp : TimeValue;
    }

    item def SensorReading {
        attribute contactDetected : Boolean;
        attribute measuredForce : ForceValue;
        attribute timestamp : TimeValue;
    }

    item def PressureFeedback {
        attribute chamberPressure : PressureValue;
        attribute timestamp : TimeValue;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def PneumaticPort {
        inout item air : Air;
        out item pressureFeedback : PressureFeedback;
    }

    port def CommandPort {
        out item command : GripCommand;
    }

    port def FeedbackPort {
        out item reading : SensorReading;
    }

    port def ElectricalPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }

    // ============================================================
    // Spider Carcass Gripper
    // ============================================================
    part def SpiderCarcassGripper {
        attribute species : String = "WolfSpider";
        attribute bodyMass : MassValue = 0.5;
        attribute chamberVolume : VolumeValue = 0.2;
        attribute extendThreshold : PressureValue = 80000.0;
        attribute curlThreshold : PressureValue = 20000.0;
        attribute maxGripForce : ForceValue = 3.0;
        attribute maxCycles : CycleCount = 1000;

        port pneumaticPort : PneumaticPort;
        port contactPort : FeedbackPort;

        part prosoma : PneumaticChamber {
            attribute volume : VolumeValue = 0.2;
            attribute currentPressure : PressureValue = 0.0;
            inout port chamberPort : PneumaticPort;
        }

        part legs : LegAssembly {
            attribute legCount : Integer = 8;
            attribute legState : String;
            inout port legPort : PneumaticPort;
            out port contactPort : FeedbackPort;
        }

        connection pneumaticConnection connect prosoma.chamberPort to legs.legPort;

        exhibit GripperStateMachine {
            state closed;
            state opening;
            state open;
            state closing;

            transition closed -> opening
                when prosoma.currentPressure > prosoma.volume * 0.0
                if prosoma.currentPressure >= extendThreshold;
            transition opening -> open
                if prosoma.currentPressure >= extendThreshold;
            transition open -> closing
                if prosoma.currentPressure < extendThreshold;
            transition closing -> closed
                if prosoma.currentPressure <= curlThreshold;

            state entry closed { /* legs naturally curled, gripping */ }
            state entry open { /* legs extended, gripper open */ }
        }
    }

    part def PneumaticChamber {
        attribute volume : VolumeValue;
        attribute currentPressure : PressureValue;
        inout port chamberPort : PneumaticPort;
    }

    part def LegAssembly {
        attribute legCount : Integer = 8;
        attribute legState : String;
        inout port legPort : PneumaticPort;
        out port contactPort : FeedbackPort;
    }

    // ============================================================
    // Pneumatic Actuation System
    // ============================================================
    part def PneumaticActuationSystem {
        attribute maxPressure : PressureValue = 250000.0;
        attribute regulatedPressure : PressureValue = 120000.0;
        attribute responseTime : TimeValue = 0.05;

        port commandPort : CommandPort;
        port pneumaticOut : PneumaticPort;
        port powerPort : ElectricalPort;

        part airPump : AirPump {
            attribute flowRate : FlowRateValue = 50.0;
            attribute maxPressure : PressureValue = 300000.0;
            in port powerPort : ElectricalPort;
            out port pumpOut : PneumaticPort;
        }

        part pressureRegulator : PressureRegulator {
            attribute setPressure : PressureValue = 120000.0;
            attribute tolerance : PressureValue = 2000.0;
            inout port regulatorIn : PneumaticPort;
            out port regulatorOut : PneumaticPort;
        }

        part solenoidValve : SolenoidValve {
            attribute position : String = "closed";
            in port commandPort : CommandPort;
            inout port valveIn : PneumaticPort;
            out port valveOut : PneumaticPort;
        }

        connection pumpToRegulator connect airPump.pumpOut to pressureRegulator.regulatorIn;
        connection regulatorToValve connect pressureRegulator.regulatorOut to solenoidValve.valveIn;
        connection valveToOutput connect solenoidValve.valveOut to pneumaticOut;

        exhibit PneumaticStateMachine {
            state idle;
            state pressurizing;
            state holding;
            state venting;

            transition idle -> pressurizing
                when commandPort.command.mode == GripMode::actuate;
            transition pressurizing -> holding
                when pneumaticOut.pressureFeedback.chamberPressure >= regulatedPressure;
            transition holding -> venting
                when commandPort.command.mode == GripMode::release;
            transition venting -> idle
                when pneumaticOut.pressureFeedback.chamberPressure <= curlThreshold;
        }
    }

    part def AirPump {
        attribute flowRate : FlowRateValue;
        attribute maxPressure : PressureValue;
        in port powerPort : ElectricalPort;
        out port pumpOut : PneumaticPort;
    }

    part def PressureRegulator {
        attribute setPressure : PressureValue;
        attribute tolerance : PressureValue;
        inout port regulatorIn : PneumaticPort;
        out port regulatorOut : PneumaticPort;
    }

    part def SolenoidValve {
        attribute position : String;
        in port commandPort : CommandPort;
        inout port valveIn : PneumaticPort;
        out port valveOut : PneumaticPort;
    }

    // ============================================================
    // Contact Sensor
    // ============================================================
    part def ContactSensor {
        attribute sensingRange : ForceValue = 5.0;
        attribute resolution : ForceValue = 0.01;
        attribute samplingRate : TimeValue = 0.01;

        port sensorOut : FeedbackPort;
        port powerPort : ElectricalPort;

        exhibit SensingAction {
            action sampleForce;
            action evaluateContact;
            action emitReading;

            flow sampleForce.rawForce -> evaluateContact.force;
            flow evaluateContact.reading -> emitReading.reading;
            flow emitReading.reading -> sensorOut.reading;
        }
    }

    // ============================================================
    // Microcontroller Unit
    // ============================================================
    part def MicrocontrollerUnit {
        attribute clockFrequency : TimeValue = 0.001;
        attribute desiredGripForce : ForceValue = 0.5;
        attribute safeForceMargin : ForceValue = 0.2;
        attribute controlGain : Dimensionless = 0.8;

        port commandOut : CommandPort;
        port sensorIn : FeedbackPort;
        port powerPort : ElectricalPort;

        exhibit ControlStateMachine {
            state idle;
            state opening;
            state approaching;
            state contactDetected;
            state gripping;
            state holding;
            state releasing;

            transition idle -> opening
                if true; // begin control loop
            transition opening -> approaching
                when commandOut.command.mode == GripMode::actuate;
            transition approaching -> contactDetected
                when sensorIn.reading.contactDetected == true;
            transition contactDetected -> gripping
                if sensorIn.reading.measuredForce < desiredGripForce;
            transition gripping -> holding
                when sensorIn.reading.measuredForce >= desiredGripForce - safeForceMargin
                and sensorIn.reading.measuredForce <= desiredGripForce + safeForceMargin;
            transition holding -> releasing
                when commandOut.command.mode == GripMode::release;
            transition releasing -> idle
                when sensorIn.reading.contactDetected == false;
        }

        exhibit ControlLoop {
            action readSensor;
            action computeError {
                in currentForce : ForceValue;
                in targetForce : ForceValue;
                out error : ForceValue;
            }
            action decideCommand {
                in error : ForceValue;
                in contact : Boolean;
                out command : GripCommand;
            }
            action sendCommand;

            flow sensorIn.reading -> readSensor.reading;
            flow readSensor.force -> computeError.currentForce;
            flow desiredGripForce -> computeError.targetForce;
            flow computeError.error -> decideCommand.error;
            flow readSensor.contact -> decideCommand.contact;
            flow decideCommand.command -> sendCommand.command;
            flow sendCommand.command -> commandOut.command;
        }
    }

    // ============================================================
    // Power Supply
    // ============================================================
    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 5.0;
        attribute maxCurrent : CurrentValue = 2.0;
        out port powerOut : ElectricalPort;
    }

    // ============================================================
    // Top-Level System
    // ============================================================
    part def NecroboticGripperSystem {
        attribute systemMass : MassValue = 50.0;
        attribute maxObjectMass : MassValue = 1.0;
        attribute designCycleLife : CycleCount = 1000;

        part spiderGripper : SpiderCarcassGripper;
        part pneumaticSystem : PneumaticActuationSystem;
        part microcontroller : MicrocontrollerUnit;
        part contactSensor : ContactSensor;
        part powerSupply : PowerSupply;

        connection commandLink connect microcontroller.commandOut to pneumaticSystem.commandPort;
        connection pneumaticLink connect pneumaticSystem.pneumaticOut to spiderGripper.pneumaticPort;
        connection sensorLink connect contactSensor.sensorOut to microcontroller.sensorIn;
        connection gripperSensorLink connect spiderGripper.contactPort to microcontroller.sensorIn;
        connection powerToPneumatic connect powerSupply.powerOut to pneumaticSystem.powerPort;
        connection powerToController connect powerSupply.powerOut to microcontroller.powerPort;
        connection powerToSensor connect powerSupply.powerOut to contactSensor.powerPort;

        exhibit SystemOperation {
            action initialize;
            action openGripper;
            action approachTarget;
            action detectContact;
            action secureGrip;
            action holdObject;
            action releaseObject;

            flow initialize.done -> openGripper.start;
            flow openGripper.done -> approachTarget.start;
            flow approachTarget.done -> detectContact.start;
            flow detectContact.done -> secureGrip.start;
            flow secureGrip.done -> holdObject.start;
            flow holdObject.done -> releaseObject.start;
            flow releaseObject.done -> openGripper.start;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def GripForceControlRequirement {
        attribute targetForce : ForceValue = 0.5;
        attribute tolerance : ForceValue = 0.2;
        objective {
            doc "The system shall maintain grip force within tolerance of target without crushing the object.";
            assert MicrocontrollerUnit.desiredGripForce == targetForce;
        }
    }

    requirement def ObjectMassCapacityRequirement {
        attribute maxObjectMass : MassValue = 1.0;
        attribute spiderBodyMass : MassValue = 0.5;
        objective {
            doc "The system shall handle objects with mass slightly greater than the spider's body mass.";
            assert maxObjectMass > spiderBodyMass;
        }
    }

    requirement def CycleLifeRequirement {
        attribute minCycles : CycleCount = 1000;
        objective {
            doc "The system shall operate for a significant number of grip-and-release cycles.";
            assert SpiderCarcassGripper.maxCycles >= minCycles;
        }
    }

    requirement def PressureRangeRequirement {
        attribute minExtendPressure : PressureValue = 80000.0;
        attribute maxSafePressure : PressureValue = 250000.0;
        objective {
            doc "The pneumatic system shall deliver pressure sufficient to extend legs but not exceed safe limits.";
            assert PneumaticActuationSystem.maxPressure <= maxSafePressure;
            assert SpiderCarcassGripper.extendThreshold >= minExtendPressure;
        }
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : TimeValue = 0.1;
        objective {
            doc "The system shall respond to commands within the specified time.";
            assert PneumaticActuationSystem.responseTime <= maxResponseTime;
        }
    }

    requirement def NecroboticGripperSystemRequirements {
        requirement gripForceControl : GripForceControlRequirement;
        requirement objectMassCapacity : ObjectMassCapacityRequirement;
        requirement cycleLife : CycleLifeRequirement;
        requirement pressureRange : PressureRangeRequirement;
        requirement responseTime : ResponseTimeRequirement;

        satisfy gripForceControl by MicrocontrollerUnit;
        satisfy objectMassCapacity by NecroboticGripperSystem;
        satisfy cycleLife by SpiderCarcassGripper;
        satisfy pressureRange by PneumaticActuationSystem;
        satisfy responseTime by PneumaticActuationSystem;
    }
}

package NecroboticHandlingSystem {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Mass :> ISQ::mass {
        unit = SI::gram;
    }

    attribute def Time :> ISQ::time {
        unit = SI::second;
    }

    attribute def Length :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Probability :> ScalarValues::Real;

    enum def BioActuatorCondition {
        enum fresh;
        enum hydrated;
        enum degrading;
        enum expired;
        enum sealedForDisposal;
    }

    enum def ManipulatorMode {
        enum standby;
        enum calibrating;
        enum ready;
        enum grasping;
        enum holding;
        enum releasing;
        enum sanitizing;
        enum faulted;
    }

    item def PneumaticEnergy {
        attribute supplyPressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : ISQ::electricCurrent;
    }

    item def ControlCommand {
        attribute targetMode : ManipulatorMode;
        attribute requestedGripForce : Force;
        attribute requestedHoldTime : Time;
    }

    item def TelemetryPacket {
        attribute measuredPressure : Pressure;
        attribute measuredGripForce : Force;
        attribute actuatorCondition : BioActuatorCondition;
        attribute contaminationRisk : Probability;
        attribute mode : ManipulatorMode;
    }

    item def SpecimenPayload {
        attribute payloadMass : Mass;
        attribute maximumAllowedCompression : Force;
        attribute nominalDiameter : Length;
    }

    item def DisinfectantMist {
        attribute mistFlowRate : FlowRate;
        attribute contactTime : Time;
    }

    port def PneumaticPort {
        out item pneumaticEnergy : PneumaticEnergy;
    }

    port def VacuumPort {
        in item pneumaticEnergy : PneumaticEnergy;
    }

    port def ElectricalPort {
        in item electricalEnergy : ElectricalEnergy;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
    }

    port def PayloadPort {
        inout item payload : SpecimenPayload;
    }

    port def SanitationPort {
        out item disinfectant : DisinfectantMist;
    }

    action def RegulatePressure {
        in targetGripForce : Force;
        in currentGripForce : Force;
        in maximumPressure : Pressure;
        out commandedPressure : Pressure;

        constraint pressureLimit {
            commandedPressure <= maximumPressure
        }
    }

    action def EstimateBioActuatorCondition {
        in cycleCount : ScalarValues::Integer;
        in hydrationLevel : ScalarValues::Real;
        in measuredResponseTime : Time;
        out condition : BioActuatorCondition;
        out contaminationRisk : Probability;
    }

    action def ExecuteGentleGrasp {
        in payload : SpecimenPayload;
        in desiredForce : Force;
        out achievedForce : Force;
        out graspSuccessful : ScalarValues::Boolean;

        constraint payloadProtection {
            achievedForce <= payload.maximumAllowedCompression
        }
    }

    action def SanitizeEndEffector {
        in exposureTime : Time;
        in mist : DisinfectantMist;
        out sanitationComplete : ScalarValues::Boolean;

        constraint minimumContact {
            exposureTime >= 20 [SI::second]
        }
    }

    state def NecroboticManipulatorStates {
        entry; then standby;

        state standby;
        state calibrating;
        state ready;
        state grasping;
        state holding;
        state releasing;
        state sanitizing;
        state faulted;

        transition standby_to_calibrating
            first standby
            accept ControlCommand
            if command.targetMode == ManipulatorMode::calibrating
            then calibrating;

        transition calibration_complete
            first calibrating
            if self.calibrationValid
            then ready;

        transition ready_to_grasping
            first ready
            accept ControlCommand
            if command.targetMode == ManipulatorMode::grasping
            then grasping;

        transition grasp_established
            first grasping
            if self.payloadDetected and self.gripForceStable
            then holding;

        transition hold_to_release
            first holding
            accept ControlCommand
            if command.targetMode == ManipulatorMode::releasing
            then releasing;

        transition release_complete
            first releasing
            if not self.payloadDetected
            then sanitizing;

        transition sanitation_complete
            first sanitizing
            if self.sanitationComplete
            then ready;

        transition degradation_fault
            first ready
            if self.bioActuatorCondition == BioActuatorCondition::expired
            then faulted;

        transition pressure_fault
            first grasping
            if self.pressure > self.maximumSafePressure
            then faulted;
    }

    part def PressureSupplyUnit {
        attribute nominalPressure : Pressure = 65000 [SI::pascal];
        attribute maximumPressure : Pressure = 85000 [SI::pascal];
        attribute nominalFlowRate : FlowRate = 0.000015 [SI::cubicMetrePerSecond];

        port pneumaticOut : PneumaticPort;
        port electricalIn : ElectricalPort;
    }

    part def Microcontroller {
        attribute controlLoopPeriod : Time = 0.02 [SI::second];
        attribute commandTimeout : Time = 2.0 [SI::second];

        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port electricalIn : ElectricalPort;
    }

    part def PressureRegulator {
        attribute responseTime : Time = 0.08 [SI::second];
        attribute pressureSetpoint : Pressure;
        attribute maximumAllowedPressure : Pressure = 80000 [SI::pascal];

        port pneumaticIn : VacuumPort;
        port pneumaticOut : PneumaticPort;

        perform action regulatePressure : RegulatePressure;
    }

    part def BioActuator {
        attribute condition : BioActuatorCondition = BioActuatorCondition::hydrated;
        attribute legSpan : Length = 38 [SI::millimetre];
        attribute bodyChamberVolume : ISQ::volume = 0.00000008 [SI::cubicMetre];
        attribute hydrationLevel : ScalarValues::Real = 0.85;
        attribute cycleCount : ScalarValues::Integer = 0;
        attribute maximumServiceCycles : ScalarValues::Integer = 700;
        attribute maximumSafePressure : Pressure = 80000 [SI::pascal];

        port pneumaticIn : VacuumPort;
        port payloadInterface : PayloadPort;

        perform action estimateCondition : EstimateBioActuatorCondition;
    }

    part def NecroboticGripperHead {
        attribute nominalGripForce : Force = 0.0018 [SI::newton];
        attribute maximumGripForce : Force = 0.0040 [SI::newton];
        attribute minimumPayloadMass : Mass = 0.005 [SI::gram];
        attribute maximumPayloadMass : Mass = 0.180 [SI::gram];

        part actuator : BioActuator;
        port pneumaticIn : VacuumPort;
        port payloadPort : PayloadPort;

        bind pneumaticIn = actuator.pneumaticIn;
        bind payloadPort = actuator.payloadInterface;

        perform action grasp : ExecuteGentleGrasp;
    }

    part def ForceSensor {
        attribute measurementRange : Force = 0.01 [SI::newton];
        attribute resolution : Force = 0.00005 [SI::newton];

        port payloadPort : PayloadPort;
        port telemetryOut : TelemetryPort;
        port electricalIn : ElectricalPort;
    }

    part def VisionSensor {
        attribute fieldOfViewWidth : Length = 55 [SI::millimetre];
        attribute fieldOfViewHeight : Length = 40 [SI::millimetre];
        attribute framePeriod : Time = 0.033 [SI::second];

        port telemetryOut : TelemetryPort;
        port electricalIn : ElectricalPort;
    }

    part def SanitationModule {
        attribute reservoirVolume : ISQ::volume = 0.00005 [SI::cubicMetre];
        attribute sanitationExposureTime : Time = 25 [SI::second];
        attribute storageTemperature : Temperature = 277 [SI::kelvin];

        port sanitationOut : SanitationPort;
        port electricalIn : ElectricalPort;

        perform action sanitize : SanitizeEndEffector;
    }

    part def ContainmentEnclosure {
        attribute internalWidth : Length = 180 [SI::millimetre];
        attribute internalDepth : Length = 140 [SI::millimetre];
        attribute internalHeight : Length = 160 [SI::millimetre];
        attribute leakProbabilityPerCycle : Probability = 0.0001;

        port payloadAccess : PayloadPort;
    }

    part def PowerSubsystem {
        attribute supplyVoltage : Voltage = 12 [SI::volt];
        port electricalOut : ElectricalPort;
    }

    part def NecroboticMicromanipulatorSystem {
        doc /* Primary function: use a pneumatically actuated biological gripper made from a deceased spider body as a compliant end effector for gentle pick, hold, move, and release operations on fragile millimeter-scale specimens inside a contained laboratory workspace. */

        attribute currentMode : ManipulatorMode = ManipulatorMode::standby;
        attribute pressure : Pressure;
        attribute maximumSafePressure : Pressure = 80000 [SI::pascal];
        attribute gripForceStable : ScalarValues::Boolean;
        attribute payloadDetected : ScalarValues::Boolean;
        attribute calibrationValid : ScalarValues::Boolean;
        attribute sanitationComplete : ScalarValues::Boolean;
        attribute bioActuatorCondition : BioActuatorCondition;

        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port payloadPort : PayloadPort;

        part power : PowerSubsystem;
        part controller : Microcontroller;
        part pressureSupply : PressureSupplyUnit;
        part regulator : PressureRegulator;
        part gripper : NecroboticGripperHead;
        part forceSensor : ForceSensor;
        part visionSensor : VisionSensor;
        part sanitation : SanitationModule;
        part enclosure : ContainmentEnclosure;

        connect power.electricalOut to controller.electricalIn;
        connect power.electricalOut to pressureSupply.electricalIn;
        connect power.electricalOut to forceSensor.electricalIn;
        connect power.electricalOut to visionSensor.electricalIn;
        connect power.electricalOut to sanitation.electricalIn;

        connect commandIn to controller.commandIn;
        connect controller.telemetryOut to telemetryOut;

        connect pressureSupply.pneumaticOut to regulator.pneumaticIn;
        connect regulator.pneumaticOut to gripper.pneumaticIn;

        connect gripper.payloadPort to payloadPort;
        connect gripper.payloadPort to forceSensor.payloadPort;
        connect payloadPort to enclosure.payloadAccess;

        exhibit state behavior manipulatorStates : NecroboticManipulatorStates;
    }

    requirement def GentleHandlingRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.gripper.nominalGripForce <= 0.002 [SI::newton]
        }
    }

    requirement def PressureSafetyRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.pressure <= system.maximumSafePressure
        }
    }

    requirement def PayloadCapacityRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.gripper.maximumPayloadMass >= 0.150 [SI::gram]
        }
    }

    requirement def BioActuatorServiceLifeRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.gripper.actuator.cycleCount <= system.gripper.actuator.maximumServiceCycles
        }
    }

    requirement def ContainmentRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.enclosure.leakProbabilityPerCycle <= 0.0001
        }
    }

    requirement def SanitationRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.sanitation.sanitationExposureTime >= 20 [SI::second]
        }
    }

    requirement def ControlResponsivenessRequirement {
        subject system : NecroboticMicromanipulatorSystem;
        require constraint {
            system.controller.controlLoopPeriod <= 0.025 [SI::second]
        }
    }

    satisfy GentleHandlingRequirement by NecroboticMicromanipulatorSystem;
    satisfy PressureSafetyRequirement by NecroboticMicromanipulatorSystem;
    satisfy PayloadCapacityRequirement by NecroboticMicromanipulatorSystem;
    satisfy BioActuatorServiceLifeRequirement by NecroboticMicromanipulatorSystem;
    satisfy ContainmentRequirement by NecroboticMicromanipulatorSystem;
    satisfy SanitationRequirement by NecroboticMicromanipulatorSystem;
    satisfy ControlResponsivenessRequirement by NecroboticMicromanipulatorSystem;

    part system : NecroboticMicromanipulatorSystem;

}
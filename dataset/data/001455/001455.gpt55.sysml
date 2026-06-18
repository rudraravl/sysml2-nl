package HoneybeeRoboticsInspiredPlanetarySamplingSystem {

    import ScalarValues::*;

    attribute def Meter :> Real {
        attribute unitSymbol : String = "m";
        attribute quantityKind : String = "length";
    }

    attribute def Millimeter :> Real {
        attribute unitSymbol : String = "mm";
        attribute quantityKind : String = "length";
    }

    attribute def Kilogram :> Real {
        attribute unitSymbol : String = "kg";
        attribute quantityKind : String = "mass";
    }

    attribute def Gram :> Real {
        attribute unitSymbol : String = "g";
        attribute quantityKind : String = "mass";
    }

    attribute def Newton :> Real {
        attribute unitSymbol : String = "N";
        attribute quantityKind : String = "force";
    }

    attribute def NewtonMeter :> Real {
        attribute unitSymbol : String = "N*m";
        attribute quantityKind : String = "torque";
    }

    attribute def Watt :> Real {
        attribute unitSymbol : String = "W";
        attribute quantityKind : String = "power";
    }

    attribute def Volt :> Real {
        attribute unitSymbol : String = "V";
        attribute quantityKind : String = "electric potential";
    }

    attribute def Ampere :> Real {
        attribute unitSymbol : String = "A";
        attribute quantityKind : String = "electric current";
    }

    attribute def DegreeCelsius :> Real {
        attribute unitSymbol : String = "degC";
        attribute quantityKind : String = "temperature";
    }

    attribute def RadianPerSecond :> Real {
        attribute unitSymbol : String = "rad/s";
        attribute quantityKind : String = "angular speed";
    }

    attribute def RevolutionPerMinute :> Real {
        attribute unitSymbol : String = "rpm";
        attribute quantityKind : String = "rotational speed";
    }

    attribute def Second :> Real {
        attribute unitSymbol : String = "s";
        attribute quantityKind : String = "time";
    }

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
        attribute quantityKind : String = "ratio";
    }

    attribute def BitPerSecond :> Real {
        attribute unitSymbol : String = "bit/s";
        attribute quantityKind : String = "data rate";
    }

    enum def OperatingMode {
        enum off;
        enum safe;
        enum standby;
        enum preCheck;
        enum approachSurface;
        enum drill;
        enum sampleCapture;
        enum retract;
        enum transferSample;
        enum fault;
    }

    enum def CommandKind {
        enum powerOn;
        enum powerOff;
        enum initialize;
        enum startSampling;
        enum pauseSampling;
        enum resumeSampling;
        enum abortSampling;
        enum runSelfTest;
        enum clearFault;
        enum transferSample;
    }

    enum def FaultKind {
        enum none;
        enum overCurrent;
        enum overTemperature;
        enum excessiveTorque;
        enum bitStall;
        enum failedDeployment;
        enum sampleTubeNotSeated;
        enum communicationLoss;
        enum positionSensorDisagreement;
    }

    enum def SampleState {
        enum absent;
        enum cuttingsInAuger;
        enum coreInTube;
        enum sealed;
        enum delivered;
        enum lost;
    }

    attribute def TemperatureRange {
        attribute minimum : DegreeCelsius;
        attribute maximum : DegreeCelsius;
    }

    attribute def DepthRange {
        attribute minimum : Meter;
        attribute maximum : Meter;
    }

    attribute def PowerRange {
        attribute nominal : Watt;
        attribute peak : Watt;
    }

    attribute def MotorSetPoint {
        attribute rotationRate : RevolutionPerMinute;
        attribute feedRate : Millimeter;
        attribute percussionEnabled : Boolean;
        attribute percussionDutyCycle : Percent;
        attribute axialForceLimit : Newton;
        attribute torqueLimit : NewtonMeter;
    }

    attribute def DrillTelemetryValues {
        attribute measuredDepth : Meter;
        attribute bitTemperature : DegreeCelsius;
        attribute motorTemperature : DegreeCelsius;
        attribute rotationRate : RevolutionPerMinute;
        attribute axialForce : Newton;
        attribute torque : NewtonMeter;
        attribute motorCurrent : Ampere;
        attribute sampleMassEstimate : Gram;
        attribute sampleCaptureConfidence : Percent;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute availablePower : Watt;
    }

    item def RegulatedPower {
        attribute voltage : Volt;
        attribute currentLimit : Ampere;
        attribute powerLimit : Watt;
    }

    item def CommandMessage {
        attribute commandId : Integer;
        attribute kind : CommandKind;
        attribute requestedDepth : Meter;
        attribute requestedSampleMass : Gram;
        attribute maximumDuration : Second;
    }

    item def TelemetryMessage {
        attribute packetId : Integer;
        attribute mode : OperatingMode;
        attribute fault : FaultKind;
        attribute drillValues : DrillTelemetryValues;
        attribute healthPercent : Percent;
    }

    item def MotorDriveSignal {
        attribute setPoint : MotorSetPoint;
        attribute enable : Boolean;
    }

    item def PositionSignal {
        attribute extension : Meter;
        attribute velocity : Millimeter;
        attribute valid : Boolean;
    }

    item def ForceTorqueSignal {
        attribute axialForce : Newton;
        attribute torque : NewtonMeter;
        attribute valid : Boolean;
    }

    item def TemperatureSignal {
        attribute temperature : DegreeCelsius;
        attribute valid : Boolean;
    }

    item def SampleCore {
        attribute state : SampleState;
        attribute length : Millimeter;
        attribute diameter : Millimeter;
        attribute mass : Gram;
        attribute estimatedWaterIcePercent : Percent;
        attribute containmentIntegrity : Percent;
    }

    item def MechanicalLoad {
        attribute axialLoad : Newton;
        attribute torsionalLoad : NewtonMeter;
        attribute lateralLoad : Newton;
    }

    item def HeatFlow {
        attribute thermalPower : Watt;
        attribute interfaceTemperature : DegreeCelsius;
    }

    port def SpacecraftPowerPort {
        in item power : ElectricalPower;
    }

    port def RegulatedPowerOutputPort {
        out item power : RegulatedPower;
    }

    port def RegulatedPowerInputPort {
        in item power : RegulatedPower;
    }

    port def CommandTelemetryPort {
        in item command : CommandMessage;
        out item telemetry : TelemetryMessage;
    }

    port def MotorControlPort {
        in item driveSignal : MotorDriveSignal;
        out item forceTorqueFeedback : ForceTorqueSignal;
    }

    port def SensorDataPort {
        out item position : PositionSignal;
        out item forceTorque : ForceTorqueSignal;
        out item temperature : TemperatureSignal;
    }

    port def DrillMechanicalPort {
        in item appliedLoad : MechanicalLoad;
        out item reactionLoad : MechanicalLoad;
    }

    port def ThermalPort {
        inout item heat : HeatFlow;
    }

    port def SampleOutputPort {
        out item sample : SampleCore;
    }

    port def SampleInputPort {
        in item sample : SampleCore;
    }

    action def InitializeSamplingSystem {
        in item startupCommand : CommandMessage;
        out item initializationTelemetry : TelemetryMessage;

        first startInitialization;
        then verifyInputPower;
        then zeroPositionSensors;
        then checkMotorController;
        then verifySampleTubePresence;
        then reportStandbyReady;
    }

    action def AcquireSubsurfaceSample {
        in attribute targetDepth : Meter;
        in attribute targetSampleMass : Gram;
        out item acquiredSample : SampleCore;
        out item acquisitionTelemetry : TelemetryMessage;

        first receiveSamplingCommand;
        then latchToSurface;
        then applyControlledAxialPreload;
        then rotatePercussiveBit;
        then advanceAugerToTargetDepth;
        then monitorTorqueTemperatureAndCurrent;
        then captureCoreInSampleTube;
        then stopDrillRotation;
        then retractBitAndTube;
        then verifySampleContainment;
        then publishAcquisitionTelemetry;
    }

    action def TransferCapturedSample {
        in item capturedSample : SampleCore;
        out item deliveredSample : SampleCore;
        out item transferTelemetry : TelemetryMessage;

        first alignSampleTubeWithTransferChute;
        then openContainmentGate;
        then pushSampleToInstrumentInterface;
        then confirmSampleDelivery;
        then resealSamplingPath;
    }

    action def FaultProtectionResponse {
        in attribute detectedFault : FaultKind;
        out item safeTelemetry : TelemetryMessage;

        first inhibitDrillMotor;
        then removePercussionCommand;
        then holdOrRetractDependingOnDepth;
        then preserveSampleIfPresent;
        then reportFaultToSpacecraft;
    }

    state def SamplingOperationalStateMachine {
        attribute currentMode : OperatingMode;
        attribute activeFault : FaultKind;

        state off;
        state safe;
        state standby;
        state preCheck;
        state approachSurface;
        state drilling;
        state sampleCapture;
        state retracting;
        state transferring;
        state fault;

        transition initial then off;
        transition off to standby accept CommandMessage if command.kind == CommandKind::powerOn;
        transition standby to preCheck accept CommandMessage if command.kind == CommandKind::startSampling;
        transition preCheck to approachSurface if activeFault == FaultKind::none;
        transition approachSurface to drilling if currentMode == OperatingMode::approachSurface;
        transition drilling to sampleCapture if currentMode == OperatingMode::drill;
        transition sampleCapture to retracting if currentMode == OperatingMode::sampleCapture;
        transition retracting to transferring accept CommandMessage if command.kind == CommandKind::transferSample;
        transition transferring to standby if currentMode == OperatingMode::transferSample;
        transition standby to safe accept CommandMessage if command.kind == CommandKind::powerOff;
        transition preCheck to fault if activeFault != FaultKind::none;
        transition approachSurface to fault if activeFault != FaultKind::none;
        transition drilling to fault if activeFault != FaultKind::none;
        transition sampleCapture to fault if activeFault != FaultKind::none;
        transition retracting to fault if activeFault != FaultKind::none;
        transition transferring to fault if activeFault != FaultKind::none;
        transition fault to safe accept CommandMessage if command.kind == CommandKind::clearFault;
        transition safe to standby accept CommandMessage if command.kind == CommandKind::initialize;
    }

    part def PowerConditioningUnit {
        attribute inputVoltageNominal : Volt = 28.0;
        attribute regulatedMotorVoltage : Volt = 48.0;
        attribute regulatedAvionicsVoltage : Volt = 12.0;
        attribute peakPowerCapability : Watt = 180.0;
        attribute conversionEfficiency : Percent = 91.0;

        port spacecraftPower : SpacecraftPowerPort;
        port motorPower : RegulatedPowerOutputPort;
        port avionicsPower : RegulatedPowerOutputPort;
        port heaterPower : RegulatedPowerOutputPort;
        port thermal : ThermalPort;
    }

    part def AvionicsController {
        attribute processorHealth : Percent = 100.0;
        attribute dataRate : BitPerSecond = 1000000.0;
        attribute commandTimeout : Second = 5.0;
        attribute currentMode : OperatingMode = OperatingMode::off;
        attribute activeFault : FaultKind = FaultKind::none;

        port spacecraftData : CommandTelemetryPort;
        port internalMotorCommand : MotorControlPort;
        port internalSensorData : SensorDataPort;
        port power : RegulatedPowerInputPort;
        port thermal : ThermalPort;

        perform action initialize : InitializeSamplingSystem;
        perform action acquireSample : AcquireSubsurfaceSample;
        perform action transferSample : TransferCapturedSample;
        perform action faultProtection : FaultProtectionResponse;

        state operationalStates : SamplingOperationalStateMachine;
    }

    part def BrushlessDrillMotor {
        attribute continuousTorque : NewtonMeter = 1.2;
        attribute peakTorque : NewtonMeter = 3.5;
        attribute maximumSpeed : RevolutionPerMinute = 850.0;
        attribute motorMass : Kilogram = 0.85;
        attribute windingTemperatureLimit : DegreeCelsius = 105.0;

        port power : RegulatedPowerInputPort;
        port control : MotorControlPort;
        port shaftMechanical : DrillMechanicalPort;
        port thermal : ThermalPort;
    }

    part def PercussiveActuator {
        attribute impactEnergy : NewtonMeter = 0.8;
        attribute maximumDutyCycle : Percent = 50.0;
        attribute actuationFrequency : RevolutionPerMinute = 3000.0;
        attribute actuatorMass : Kilogram = 0.55;

        port power : RegulatedPowerInputPort;
        port control : MotorControlPort;
        port mechanicalOutput : DrillMechanicalPort;
        port thermal : ThermalPort;
    }

    part def RotaryPercussiveDrillString {
        attribute bitDiameter : Millimeter = 18.0;
        attribute augerOuterDiameter : Millimeter = 16.0;
        attribute maximumDepth : Meter = 2.0;
        attribute nominalFeedPerRevolution : Millimeter = 0.35;
        attribute bitMaterial : String = "tungsten carbide coated steel";
        attribute designHeritage : String = "Honeybee Robotics style rotary-percussive planetary drill";

        port rotaryInput : DrillMechanicalPort;
        port percussionInput : DrillMechanicalPort;
        port sampleOutput : SampleOutputPort;
        port thermal : ThermalPort;
    }

    part def LinearFeedStage {
        attribute stroke : Meter = 2.15;
        attribute positioningAccuracy : Millimeter = 0.5;
        attribute maximumAxialForce : Newton = 450.0;
        attribute retractionForce : Newton = 300.0;
        attribute stageMass : Kilogram = 4.2;

        port power : RegulatedPowerInputPort;
        port control : MotorControlPort;
        port positionSensorOutput : SensorDataPort;
        port drillLoadInterface : DrillMechanicalPort;
        port mountingInterface : DrillMechanicalPort;
    }

    part def SensorSuite {
        attribute depthResolution : Millimeter = 0.1;
        attribute torqueResolution : NewtonMeter = 0.02;
        attribute forceResolution : Newton = 2.0;
        attribute temperatureAccuracy : DegreeCelsius = 1.5;
        attribute redundantDepthSensors : Integer = 2;

        port power : RegulatedPowerInputPort;
        port sensorData : SensorDataPort;
        port measuredMechanicalInterface : DrillMechanicalPort;
        port thermal : ThermalPort;
    }

    part def SampleTubeAndSeal {
        attribute tubeInternalDiameter : Millimeter = 14.0;
        attribute tubeUsableLength : Millimeter = 120.0;
        attribute maximumSampleMass : Gram = 35.0;
        attribute sealLeakageLimit : Percent = 1.0;
        attribute containedSampleState : SampleState = SampleState::absent;

        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port tubeHealthData : SensorDataPort;
        port thermal : ThermalPort;
    }

    part def SampleTransferChute {
        attribute transferPathLength : Millimeter = 180.0;
        attribute deliveryAlignmentTolerance : Millimeter = 1.0;
        attribute deliverySuccessProbability : Percent = 98.0;

        port sampleIn : SampleInputPort;
        port sampleOut : SampleOutputPort;
        port power : RegulatedPowerInputPort;
        port thermal : ThermalPort;
    }

    part def ThermalControlAssembly {
        attribute survivalHeaterPower : Watt = 18.0;
        attribute operatingTemperature : TemperatureRange {
            minimum = -40.0;
            maximum = 70.0;
        }
        attribute survivalTemperature : TemperatureRange {
            minimum = -80.0;
            maximum = 85.0;
        }

        port heaterPower : RegulatedPowerInputPort;
        port avionicsThermal : ThermalPort;
        port motorThermal : ThermalPort;
        port drillThermal : ThermalPort;
        port sampleThermal : ThermalPort;
        port spacecraftThermal : ThermalPort;
    }

    part def PlanetarySampleAcquisitionDrillSystem {
        attribute systemName : String = "Honeybee Robotics Inspired Planetary Sample Acquisition Drill";
        attribute primaryFunction : String = "Acquire, contain, and transfer subsurface planetary regolith or ice-bearing material to spacecraft science instruments using a compact robotic rotary-percussive drill.";
        attribute totalMass : Kilogram = 12.8;
        attribute stowedLength : Meter = 0.72;
        attribute deployedDepthCapability : Meter = 2.0;
        attribute nominalSamplingPower : Watt = 95.0;
        attribute peakSamplingPower : Watt = 180.0;
        attribute minimumSampleMass : Gram = 10.0;
        attribute designOperatingTemperature : TemperatureRange {
            minimum = -40.0;
            maximum = 70.0;
        }

        port spacecraftPower : SpacecraftPowerPort;
        port spacecraftCommandTelemetry : CommandTelemetryPort;
        port deliveredSample : SampleOutputPort;
        port spacecraftThermalInterface : ThermalPort;
        port landerMountInterface : DrillMechanicalPort;

        part powerConditioner : PowerConditioningUnit;
        part avionics : AvionicsController;
        part motor : BrushlessDrillMotor;
        part percussion : PercussiveActuator;
        part drillString : RotaryPercussiveDrillString;
        part feedStage : LinearFeedStage;
        part sensors : SensorSuite;
        part sampleTube : SampleTubeAndSeal;
        part transferChute : SampleTransferChute;
        part thermalControl : ThermalControlAssembly;

        connect spacecraftPower to powerConditioner.spacecraftPower;
        connect spacecraftCommandTelemetry to avionics.spacecraftData;
        connect powerConditioner.avionicsPower to avionics.power;
        connect powerConditioner.motorPower to motor.power;
        connect powerConditioner.motorPower to percussion.power;
        connect powerConditioner.motorPower to feedStage.power;
        connect powerConditioner.avionicsPower to sensors.power;
        connect powerConditioner.heaterPower to thermalControl.heaterPower;
        connect powerConditioner.avionicsPower to transferChute.power;

        connect avionics.internalMotorCommand to motor.control;
        connect avionics.internalMotorCommand to percussion.control;
        connect avionics.internalMotorCommand to feedStage.control;
        connect sensors.sensorData to avionics.internalSensorData;
        connect feedStage.positionSensorOutput to avionics.internalSensorData;

        connect motor.shaftMechanical to drillString.rotaryInput;
        connect percussion.mechanicalOutput to drillString.percussionInput;
        connect feedStage.drillLoadInterface to drillString.rotaryInput;
        connect feedStage.mountingInterface to landerMountInterface;
        connect sensors.measuredMechanicalInterface to drillString.rotaryInput;

        connect drillString.sampleOutput to sampleTube.sampleIn;
        connect sampleTube.sampleOut to transferChute.sampleIn;
        connect transferChute.sampleOut to deliveredSample;

        connect powerConditioner.thermal to thermalControl.avionicsThermal;
        connect avionics.thermal to thermalControl.avionicsThermal;
        connect motor.thermal to thermalControl.motorThermal;
        connect percussion.thermal to thermalControl.motorThermal;
        connect drillString.thermal to thermalControl.drillThermal;
        connect sampleTube.thermal to thermalControl.sampleThermal;
        connect transferChute.thermal to thermalControl.sampleThermal;
        connect spacecraftThermalInterface to thermalControl.spacecraftThermal;

        perform action systemInitialization : InitializeSamplingSystem;
        perform action highLevelSampleAcquisition : AcquireSubsurfaceSample;
        perform action highLevelSampleTransfer : TransferCapturedSample;
        perform action autonomousFaultResponse : FaultProtectionResponse;

        state samplingStateBehavior : SamplingOperationalStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The system shall provide the high-level Honeybee Robotics inspired primary function of robotically acquiring subsurface planetary material and delivering a contained sample to spacecraft science instruments."

        require constraint {
            samplingSystem.deployedDepthCapability >= 2.0
        }

        require constraint {
            samplingSystem.minimumSampleMass >= 10.0
        }
    }

    requirement def PlanetaryEnvironmentRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The sampling system shall operate in a cold planetary surface environment while maintaining avionics, motor, drill, and sample containment temperatures within allowable limits."

        require constraint {
            samplingSystem.designOperatingTemperature.minimum <= -40.0
        }

        require constraint {
            samplingSystem.designOperatingTemperature.maximum >= 70.0
        }
    }

    requirement def PowerRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The sampling system shall limit nominal sampling power to a level compatible with a small lander or rover electrical bus."

        require constraint {
            samplingSystem.nominalSamplingPower <= 100.0
        }

        require constraint {
            samplingSystem.peakSamplingPower <= 180.0
        }
    }

    requirement def MassRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The complete drill, feed, sample containment, control electronics, thermal control, and transfer hardware shall remain suitable for robotic spacecraft accommodation."

        require constraint {
            samplingSystem.totalMass <= 13.0
        }
    }

    requirement def FaultProtectionRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The system shall autonomously inhibit drilling and report a fault when over-current, over-temperature, excessive torque, bit stall, deployment failure, or sample tube seating failure is detected."
    }

    requirement def SampleContainmentRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The sample tube shall contain a captured core or cuttings sample with sufficient integrity for delivery to downstream science instruments."

        require constraint {
            samplingSystem.sampleTube.maximumSampleMass >= 35.0
        }

        require constraint {
            samplingSystem.sampleTube.sealLeakageLimit <= 1.0
        }
    }

    requirement def DepthControlRequirement {
        subject samplingSystem : PlanetarySampleAcquisitionDrillSystem;

        doc "The linear feed stage and sensor suite shall control penetration depth accurately enough to support stratified subsurface sampling."

        require constraint {
            samplingSystem.feedStage.stroke >= 2.15
        }

        require constraint {
            samplingSystem.feedStage.positioningAccuracy <= 0.5
        }

        require constraint {
            samplingSystem.sensors.depthResolution <= 0.1
        }
    }

    part planetarySamplingPayload : PlanetarySampleAcquisitionDrillSystem;

    satisfy PrimaryFunctionRequirement by planetarySamplingPayload;
    satisfy PlanetaryEnvironmentRequirement by planetarySamplingPayload;
    satisfy PowerRequirement by planetarySamplingPayload;
    satisfy MassRequirement by planetarySamplingPayload;
    satisfy FaultProtectionRequirement by planetarySamplingPayload;
    satisfy SampleContainmentRequirement by planetarySamplingPayload;
    satisfy DepthControlRequirement by planetarySamplingPayload;
}

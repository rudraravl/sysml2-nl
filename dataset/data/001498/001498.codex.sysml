package MicroboticsSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    doc /* 
     * System: Microbotics
     * Primary high-level function: a coordinated swarm of miniature mobile robotic agents
     * senses a confined operating environment, navigates to assigned microscopic work sites,
     * performs precision manipulation or inspection tasks, and reports verified task status
     * to a supervisory controller.
     */

    attribute def Percent :> Real {
        doc /* Ratio expressed from 0 to 100. */
    }

    attribute def Millimeter :> LengthValue {
        unit = mm;
    }

    attribute def Micrometer :> LengthValue {
        unit = um;
    }

    attribute def Milligram :> MassValue {
        unit = mg;
    }

    attribute def Millisecond :> TimeValue {
        unit = ms;
    }

    attribute def Milliwatt :> PowerValue {
        unit = mW;
    }

    attribute def Millivolt :> ElectricPotentialValue {
        unit = mV;
    }

    attribute def NanoNewton :> ForceValue {
        unit = nN;
    }

    attribute def DegreesCelsius :> TemperatureValue {
        unit = degC;
    }

    attribute def Hertz :> FrequencyValue {
        unit = Hz;
    }

    attribute def DataRateMbps :> Real {
        doc /* Megabits per second. */
    }

    attribute def RobotIdentifier :> String;
    attribute def MissionIdentifier :> String;
    attribute def CoordinateFrameName :> String;

    item def EnergyPacket {
        attribute voltage : Millivolt;
        attribute availablePower : Milliwatt;
        attribute chargePercent : Percent;
    }

    item def TelemetryPacket {
        attribute robotId : RobotIdentifier;
        attribute missionId : MissionIdentifier;
        attribute positionX : Micrometer;
        attribute positionY : Micrometer;
        attribute positionZ : Micrometer;
        attribute batteryCharge : Percent;
        attribute temperature : DegreesCelsius;
        attribute localizationConfidence : Percent;
        attribute manipulationForce : NanoNewton;
    }

    item def CommandPacket {
        attribute missionId : MissionIdentifier;
        attribute targetX : Micrometer;
        attribute targetY : Micrometer;
        attribute targetZ : Micrometer;
        attribute requestedManipulationForce : NanoNewton;
        attribute maximumTransitTime : Millisecond;
    }

    item def SensorObservation {
        attribute frame : CoordinateFrameName;
        attribute range : Micrometer;
        attribute featureSize : Micrometer;
        attribute confidence : Percent;
        attribute sampleTime : Millisecond;
    }

    item def Workpiece {
        attribute featureDiameter : Micrometer;
        attribute targetDisplacement : Micrometer;
        attribute allowedForce : NanoNewton;
    }

    item def ManipulationResult {
        attribute achievedDisplacement : Micrometer;
        attribute appliedPeakForce : NanoNewton;
        attribute successConfidence : Percent;
    }

    port def PowerInputPort {
        in item energy : EnergyPacket;
    }

    port def PowerOutputPort {
        out item energy : EnergyPacket;
    }

    port def CommandInputPort {
        in item command : CommandPacket;
    }

    port def CommandOutputPort {
        out item command : CommandPacket;
    }

    port def TelemetryInputPort {
        in item telemetry : TelemetryPacket;
    }

    port def TelemetryOutputPort {
        out item telemetry : TelemetryPacket;
    }

    port def ObservationOutputPort {
        out item observation : SensorObservation;
    }

    port def ObservationInputPort {
        in item observation : SensorObservation;
    }

    port def ManipulatorPort {
        in item workpiece : Workpiece;
        out item result : ManipulationResult;
    }

    port def EnvironmentInteractionPort {
        out item observation : SensorObservation;
        in item workpiece : Workpiece;
    }

    part def SupervisoryController {
        attribute updateRate : Hertz = 50 [Hz];
        attribute commandLatencyLimit : Millisecond = 20 [ms];

        port commandsOut : CommandOutputPort;
        port telemetryIn : TelemetryInputPort;
        port observationsIn : ObservationInputPort;

        action assignMicrobotTask {
            in item observation : SensorObservation;
            out item command : CommandPacket;
        }

        action fuseSwarmTelemetry {
            in item telemetry : TelemetryPacket;
            out attribute swarmHealth : Percent;
        }
    }

    part def WirelessPowerModule {
        attribute carrierFrequency : Hertz = 13560000 [Hz];
        attribute maxDeliveredPower : Milliwatt = 25 [mW];
        attribute regulationTolerance : Percent = 5;

        port powerOut : PowerOutputPort;

        action regulatePower {
            in attribute requestedPower : Milliwatt;
            out item energy : EnergyPacket;
        }
    }

    part def Microbot {
        attribute id : RobotIdentifier;
        attribute bodyLength : Millimeter = 2.5 [mm];
        attribute bodyWidth : Millimeter = 1.2 [mm];
        attribute bodyHeight : Millimeter = 0.8 [mm];
        attribute mass : Milligram = 18 [mg];
        attribute maxSpeed : Micrometer = 900 [um];
        attribute positionAccuracy : Micrometer = 8 [um];
        attribute nominalPowerDraw : Milliwatt = 7 [mW];
        attribute maxSurfaceTemperature : DegreesCelsius = 42 [degC];

        port commandIn : CommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port powerIn : PowerInputPort;
        port environment : EnvironmentInteractionPort;
        port manipulator : ManipulatorPort;

        part processor : EmbeddedProcessor;
        part sensorSuite : MicroSensorSuite;
        part actuatorSet : MicroActuatorSet;
        part energyStore : MicroEnergyStore;
        part endEffector : PrecisionEndEffector;
        part localizationUnit : LocalizationUnit;

        connect powerIn.energy to energyStore.energyIn.energy;
        connect commandIn.command to processor.commandIn.command;
        connect sensorSuite.observationOut.observation to processor.observationIn.observation;
        connect processor.telemetryOut.telemetry to telemetryOut.telemetry;
        connect processor.actuatorCommand.command to actuatorSet.commandIn.command;
        connect processor.manipulatorCommand.command to endEffector.commandIn.command;
        connect environment.observation to sensorSuite.environmentObservation.observation;
        connect manipulator.workpiece to endEffector.workpieceIn.workpiece;
        connect endEffector.resultOut.result to manipulator.result;

        action executeAssignedTask {
            in item command : CommandPacket;
            out item result : ManipulationResult;

            first startLocalization;
            then navigateToTarget;
            then verifyTarget;
            then performManipulation;
            then reportResult;
        }

        state def OperationalState {
            entry action initializeElectronics;
            state Dormant;
            state SelfTest;
            state AwaitingCommand;
            state Navigating;
            state Inspecting;
            state Manipulating;
            state Reporting;
            state ReturningToSafePose;
            state Faulted;

            initial then Dormant;

            transition Dormant_to_SelfTest
                first Dormant
                accept item energy : EnergyPacket
                if energy.chargePercent >= 20
                then SelfTest;

            transition SelfTest_to_AwaitingCommand
                first SelfTest
                if processor.selfTestPassed == true
                then AwaitingCommand;

            transition AwaitingCommand_to_Navigating
                first AwaitingCommand
                accept item command : CommandPacket
                then Navigating;

            transition Navigating_to_Inspecting
                first Navigating
                if localizationUnit.positionError <= 8 [um]
                then Inspecting;

            transition Inspecting_to_Manipulating
                first Inspecting
                if sensorSuite.targetConfidence >= 85
                then Manipulating;

            transition Manipulating_to_Reporting
                first Manipulating
                if endEffector.lastResult.successConfidence >= 90
                then Reporting;

            transition Reporting_to_ReturningToSafePose
                first Reporting
                then ReturningToSafePose;

            transition ReturningToSafePose_to_AwaitingCommand
                first ReturningToSafePose
                if actuatorSet.velocity == 0 [um]
                then AwaitingCommand;

            transition Any_to_Faulted
                first Dormant
                if energyStore.chargePercent < 5
                then Faulted;
        }
    }

    part def EmbeddedProcessor {
        attribute clockFrequency : Hertz = 48000000 [Hz];
        attribute selfTestPassed : Boolean = false;
        attribute maximumControlLoopPeriod : Millisecond = 5 [ms];

        port commandIn : CommandInputPort;
        port observationIn : ObservationInputPort;
        port actuatorCommand : CommandOutputPort;
        port manipulatorCommand : CommandOutputPort;
        port telemetryOut : TelemetryOutputPort;

        action computeMotionPlan {
            in item command : CommandPacket;
            in item observation : SensorObservation;
            out item actuatorCommand : CommandPacket;
        }

        action generateTelemetry {
            out item telemetry : TelemetryPacket;
        }
    }

    part def MicroSensorSuite {
        attribute opticalResolution : Micrometer = 2 [um];
        attribute proximityRange : Micrometer = 500 [um];
        attribute targetConfidence : Percent = 0;
        attribute sampleRate : Hertz = 200 [Hz];

        port environmentObservation : ObservationInputPort;
        port observationOut : ObservationOutputPort;

        part opticalSensor : OpticalMicroImager;
        part forceSensor : NanoForceSensor;
        part temperatureSensor : TemperatureSensor;

        action senseEnvironment {
            out item observation : SensorObservation;
        }
    }

    part def OpticalMicroImager {
        attribute pixelPitch : Micrometer = 1.4 [um];
        attribute fieldOfView : Micrometer = 1200 [um];
    }

    part def NanoForceSensor {
        attribute forceRange : NanoNewton = 5000 [nN];
        attribute forceResolution : NanoNewton = 10 [nN];
    }

    part def TemperatureSensor {
        attribute accuracy : DegreesCelsius = 0.5 [degC];
        attribute updatePeriod : Millisecond = 50 [ms];
    }

    part def MicroActuatorSet {
        attribute stepResolution : Micrometer = 1 [um];
        attribute velocity : Micrometer = 0 [um];
        attribute maximumThrust : NanoNewton = 3000 [nN];

        port commandIn : CommandInputPort;

        part leftDrive : PiezoelectricLegArray;
        part rightDrive : PiezoelectricLegArray;

        action moveToTarget {
            in item command : CommandPacket;
        }

        action holdPosition {
            in attribute duration : Millisecond;
        }
    }

    part def PiezoelectricLegArray {
        attribute legCount : Integer = 24;
        attribute driveVoltage : Millivolt = 3200 [mV];
        attribute strideLength : Micrometer = 6 [um];
    }

    part def MicroEnergyStore {
        attribute capacity : Milliwatt = 40 [mW];
        attribute chargePercent : Percent = 100;
        attribute minimumOperationalCharge : Percent = 10;

        port energyIn : PowerInputPort;

        action acceptWirelessPower {
            in item energy : EnergyPacket;
        }
    }

    part def PrecisionEndEffector {
        attribute tipDiameter : Micrometer = 20 [um];
        attribute maximumGripForce : NanoNewton = 2500 [nN];
        attribute placementAccuracy : Micrometer = 5 [um];

        port commandIn : CommandInputPort;
        port workpieceIn : ManipulatorPort;
        port resultOut : ManipulatorPort;

        attribute lastResult : ManipulationResult;

        action grasp {
            in item workpiece : Workpiece;
        }

        action displace {
            in item workpiece : Workpiece;
            out item result : ManipulationResult;
        }

        action release;
    }

    part def LocalizationUnit {
        attribute positionError : Micrometer = 100 [um];
        attribute confidence : Percent = 0;
        attribute updateRate : Hertz = 100 [Hz];

        action estimatePose {
            in item observation : SensorObservation;
            out attribute positionError : Micrometer;
        }
    }

    part def MicrobotSwarm {
        attribute swarmSize : Integer = 8;
        attribute minimumAvailableRobots : Integer = 5;
        attribute aggregateCoverageRate : Micrometer = 6000 [um];

        port commandsIn : CommandInputPort;
        port telemetryOut : TelemetryOutputPort;
        port powerIn : PowerInputPort;
        port environment : EnvironmentInteractionPort;

        part robot01 : Microbot {
            attribute id = "MB-01";
        }
        part robot02 : Microbot {
            attribute id = "MB-02";
        }
        part robot03 : Microbot {
            attribute id = "MB-03";
        }
        part robot04 : Microbot {
            attribute id = "MB-04";
        }
        part robot05 : Microbot {
            attribute id = "MB-05";
        }
        part robot06 : Microbot {
            attribute id = "MB-06";
        }
        part robot07 : Microbot {
            attribute id = "MB-07";
        }
        part robot08 : Microbot {
            attribute id = "MB-08";
        }

        connect commandsIn.command to robot01.commandIn.command;
        connect commandsIn.command to robot02.commandIn.command;
        connect commandsIn.command to robot03.commandIn.command;
        connect commandsIn.command to robot04.commandIn.command;
        connect commandsIn.command to robot05.commandIn.command;
        connect commandsIn.command to robot06.commandIn.command;
        connect commandsIn.command to robot07.commandIn.command;
        connect commandsIn.command to robot08.commandIn.command;

        connect powerIn.energy to robot01.powerIn.energy;
        connect powerIn.energy to robot02.powerIn.energy;
        connect powerIn.energy to robot03.powerIn.energy;
        connect powerIn.energy to robot04.powerIn.energy;
        connect powerIn.energy to robot05.powerIn.energy;
        connect powerIn.energy to robot06.powerIn.energy;
        connect powerIn.energy to robot07.powerIn.energy;
        connect powerIn.energy to robot08.powerIn.energy;

        connect robot01.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot02.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot03.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot04.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot05.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot06.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot07.telemetryOut.telemetry to telemetryOut.telemetry;
        connect robot08.telemetryOut.telemetry to telemetryOut.telemetry;
    }

    part def ConfinedOperatingEnvironment {
        attribute workspaceLength : Millimeter = 50 [mm];
        attribute workspaceWidth : Millimeter = 30 [mm];
        attribute workspaceHeight : Millimeter = 10 [mm];
        attribute nominalTemperature : DegreesCelsius = 25 [degC];
        attribute particulateFeatureSize : Micrometer = 50 [um];

        port interaction : EnvironmentInteractionPort;

        part targetWorkpiece : Workpiece {
            attribute featureDiameter = 80 [um];
            attribute targetDisplacement = 250 [um];
            attribute allowedForce = 2000 [nN];
        }
    }

    part def MicroboticsSystem {
        attribute missionId : MissionIdentifier = "MICROBOTICS-PRECISION-MANIPULATION-001";
        attribute primaryFunction : String =
            "Coordinate miniature robotic agents to sense, navigate, manipulate microscopic targets, and report verified task completion.";
        attribute requiredTaskSuccessConfidence : Percent = 90;
        attribute maximumMissionDuration : Millisecond = 600000 [ms];

        part controller : SupervisoryController;
        part wirelessPower : WirelessPowerModule;
        part swarm : MicrobotSwarm;
        part environment : ConfinedOperatingEnvironment;

        connect controller.commandsOut.command to swarm.commandsIn.command;
        connect swarm.telemetryOut.telemetry to controller.telemetryIn.telemetry;
        connect wirelessPower.powerOut.energy to swarm.powerIn.energy;
        connect environment.interaction.observation to controller.observationsIn.observation;
        connect swarm.environment.observation to environment.interaction.observation;
        connect environment.interaction.workpiece to swarm.environment.workpiece;

        action performPrimaryFunction {
            in item workpiece : Workpiece;
            out item result : ManipulationResult;

            first surveyWorkspace;
            then assignSwarmTasks;
            then deliverWirelessPower;
            then coordinateMicrobotNavigation;
            then executePrecisionManipulation;
            then verifyCompletion;
            then reportMissionStatus;
        }

        action surveyWorkspace {
            out item observation : SensorObservation;
        }

        action assignSwarmTasks {
            in item observation : SensorObservation;
            out item command : CommandPacket;
        }

        action deliverWirelessPower {
            out item energy : EnergyPacket;
        }

        action coordinateMicrobotNavigation {
            in item command : CommandPacket;
        }

        action executePrecisionManipulation {
            in item workpiece : Workpiece;
            out item result : ManipulationResult;
        }

        action verifyCompletion {
            in item result : ManipulationResult;
            out attribute verified : Boolean;
        }

        action reportMissionStatus {
            out item telemetry : TelemetryPacket;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall coordinate a swarm of microbots to inspect a confined environment, navigate to microscopic task sites, perform precision manipulation, and report verified completion. */
        subject system : MicroboticsSystem;

        require constraint {
            system.requiredTaskSuccessConfidence >= 90
        }
    }

    requirement def SizeRequirement {
        doc /* Each microbot shall fit within a 3 mm by 2 mm by 1 mm bounding volume. */
        subject robot : Microbot;

        require constraint {
            robot.bodyLength <= 3 [mm] and
            robot.bodyWidth <= 2 [mm] and
            robot.bodyHeight <= 1 [mm]
        }
    }

    requirement def LocalizationRequirement {
        doc /* Each active microbot shall localize itself within 10 micrometers of the commanded target before manipulation begins. */
        subject robot : Microbot;

        require constraint {
            robot.localizationUnit.positionError <= 10 [um]
        }
    }

    requirement def ManipulationForceRequirement {
        doc /* The end effector shall limit applied manipulation force to prevent damage to microscopic workpieces. */
        subject robot : Microbot;

        require constraint {
            robot.endEffector.maximumGripForce <= 2500 [nN]
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* Microbot surface temperature shall remain below 42 degrees Celsius during operation. */
        subject robot : Microbot;

        require constraint {
            robot.maxSurfaceTemperature <= 42 [degC]
        }
    }

    requirement def SwarmAvailabilityRequirement {
        doc /* The system shall complete the primary function when at least five of eight microbots are available. */
        subject swarm : MicrobotSwarm;

        require constraint {
            swarm.minimumAvailableRobots >= 5 and swarm.swarmSize == 8
        }
    }

    requirement def PowerRequirement {
        doc /* The wireless power module shall provide sufficient regulated power for simultaneous operation of the microbot swarm. */
        subject powerModule : WirelessPowerModule;

        require constraint {
            powerModule.maxDeliveredPower >= 25 [mW] and
            powerModule.regulationTolerance <= 5
        }
    }

    requirement def MissionDurationRequirement {
        doc /* The system shall complete a precision manipulation mission within ten minutes. */
        subject system : MicroboticsSystem;

        require constraint {
            system.maximumMissionDuration <= 600000 [ms]
        }
    }

    satisfy PrimaryFunctionRequirement by MicroboticsSystem;
    satisfy SizeRequirement by Microbot;
    satisfy LocalizationRequirement by LocalizationUnit;
    satisfy ManipulationForceRequirement by PrecisionEndEffector;
    satisfy ThermalSafetyRequirement by Microbot;
    satisfy SwarmAvailabilityRequirement by MicrobotSwarm;
    satisfy PowerRequirement by WirelessPowerModule;
    satisfy MissionDurationRequirement by MicroboticsSystem;
}
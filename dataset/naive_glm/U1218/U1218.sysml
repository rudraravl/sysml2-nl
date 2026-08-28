package DeepSpaceProbe {
    public import ISQ::*;
    public import ScalarValues::*;

    // ===== Value Types =====
    attribute def PowerValue :> Real { unit "W"; }
    attribute def EnergyValue :> Real { unit "J"; }
    attribute def VoltageValue :> Real { unit "V"; }
    attribute def CurrentValue :> Real { unit "A"; }
    attribute def TemperatureValue :> Real { unit "K"; }
    attribute def AngleValue :> Real { unit "rad"; }
    attribute def AngularVelocityValue :> Real { unit "rad/s"; }
    attribute def MassValue :> Real { unit "kg"; }
    attribute def DataRateValue :> Real { unit "bit/s"; }
    attribute def DataSizeValue :> Real { unit "bit"; }
    attribute def DistanceValue :> Real { unit "m"; }
    attribute def VelocityValue :> Real { unit "m/s"; }
    attribute def TimeValue :> Real { unit "s"; }
    attribute def FrequencyValue :> Real { unit "Hz"; }

    // ===== Item Definitions =====
    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def CommandPacket {
        attribute commandId : String;
        attribute priority : Integer;
        attribute payload : String;
    }
    item def TelemetryPacket {
        attribute subsystemId : String;
        attribute healthStatus : String;
        attribute timestamp : TimeValue;
    }
    item def ScienceData {
        attribute imageId : String;
        attribute spectralBand : Integer;
        attribute size : DataSizeValue;
        attribute quality : Real;
    }
    item def AttitudeCommand {
        attribute targetOrientation : AngleValue;
        attribute targetAngularVelocity : AngularVelocityValue;
    }
    item def AttitudeState {
        attribute orientation : AngleValue;
        attribute angularVelocity : AngularVelocityValue;
    }
    item def NavigationSolution {
        attribute position : DistanceValue[3];
        attribute velocity : VelocityValue[3];
        attribute timestamp : TimeValue;
    }
    item def ManeuverPlan {
        attribute deltaV : VelocityValue;
        attribute duration : TimeValue;
    }
    item def ThermalSetpoint {
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out power : PowerFlow;
    }
    port def PowerConsumerPort {
        in power : PowerFlow;
    }
    port def CommandPort {
        in commands : CommandPacket;
    }
    port def TelemetryPort {
        out telemetry : TelemetryPacket;
    }
    port def ScienceDataPort {
        out data : ScienceData;
    }
    port def DataStoragePort {
        in data : ScienceData;
        out storedData : ScienceData;
    }
    port def AttitudeCmdPort {
        in cmd : AttitudeCommand;
    }
    port def AttitudeStatePort {
        out state : AttitudeState;
    }
    port def NavSolutionPort {
        out solution : NavigationSolution;
    }
    port def ManeuverPort {
        out plan : ManeuverPlan;
    }
    port def ThermalControlPort {
        out setpoint : ThermalSetpoint;
    }
    port def RFLinkPort {
        in uplink : CommandPacket;
        out downlink : TelemetryPacket;
        out scienceDownlink : ScienceData;
    }

    // ===== Requirements =====
    requirement def PowerGenerationRequirement {
        attribute minPower : PowerValue = 300.0;
        subject : generator;
        require generator.peakPower >= minPower
    }
    requirement def EnergyStorageRequirement {
        attribute minEnergy : EnergyValue = 5.0e6;
        subject : battery;
        require battery.capacity >= minEnergy
    }
    requirement def PointingAccuracyRequirement {
        attribute maxError : AngleValue = 0.0017;
        subject : acs;
        require acs.pointingError <= maxError
    }
    requirement def DataStorageRequirement {
        attribute minCapacity : DataSizeValue = 1.0e12;
        subject : storage;
        require storage.capacity >= minCapacity
    }
    requirement def ThermalRangeRequirement {
        attribute minOpTemp : TemperatureValue = 263.15;
        attribute maxOpTemp : TemperatureValue = 313.15;
        subject : thermal;
        require thermal.minMaintained >= minOpTemp and thermal.maxMaintained <= maxOpTemp
    }
    requirement def AutonomyRequirement {
        subject : probe;
        require probe.maxRealTimeDelay == 0.0
    }

    requirement PowerReq : PowerGenerationRequirement {
        subject : generator => probe.powerSubsystem.solarArray;
    }
    requirement BatteryReq : EnergyStorageRequirement {
        subject : battery => probe.powerSubsystem.batteryPack;
    }
    requirement PointingReq : PointingAccuracyRequirement {
        subject : acs => probe.attitudeControl;
    }
    requirement StorageReq : DataStorageRequirement {
        subject : storage => probe.dataStorage;
    }
    requirement ThermalReq : ThermalRangeRequirement {
        subject : thermal => probe.thermalControl;
    }
    requirement AutonomyReq : AutonomyRequirement {
        subject : probe => probe;
    }

    // ===== Subsystem Definitions =====

    part def PowerSubsystem {
        attribute peakPower : PowerValue = 400.0;
        attribute busVoltage : VoltageValue = 28.0;
        attribute totalEnergyStored : EnergyValue = 6.0e6;

        port powerOut : PowerPort;
        port telemetryOut : TelemetryPort;
        port cmdIn : CommandPort;

        part solarArray {
            attribute area : Real = 8.0;
            attribute efficiency : Real = 0.28;
            attribute generatedPower : PowerValue = 400.0;
            attribute sunAngle : AngleValue;
            item generatedPowerFlow : PowerFlow;

            action generatePower {
                in sunAngle : AngleValue;
                out power : PowerFlow;
            }
        }

        part batteryPack {
            attribute capacity : EnergyValue = 6.0e6;
            attribute chargeLevel : Real = 1.0;
            attribute cellVoltage : VoltageValue = 28.0;
            item storedEnergy : PowerFlow;

            state chargingState {
                entry { chargeLevel := chargeLevel + 0.01; }
            }
            state dischargingState {
                entry { chargeLevel := chargeLevel - 0.01; }
            }
        }

        part powerDistributionUnit {
            attribute busVoltageValue : VoltageValue = 28.0;
            attribute loadCurrent : CurrentValue;
            item distributedPower : PowerFlow;

            action distributePower {
                in inputPower : PowerFlow;
                out outputPower : PowerFlow;
            }
        }

        action managePower {
            in generatedPower : PowerFlow;
            in loadDemand : CurrentValue;
            out distributedPower : PowerFlow;
        }

        state powerState {
            initial normal;
            state normal;
            state lowPower;
            state critical;
            transition normal to lowPower when batteryPack.chargeLevel < 0.3;
            transition lowPower to critical when batteryPack.chargeLevel < 0.15;
            transition lowPower to normal when batteryPack.chargeLevel > 0.5;
            transition critical to normal when batteryPack.chargeLevel > 0.7;
        }
    }

    part def CommunicationSubsystem {
        attribute downlinkRate : DataRateValue = 256.0e3;
        attribute uplinkRate : DataRateValue = 4.0e3;
        attribute carrierFreq : FrequencyValue = 8.4e9;

        port rfLink : RFLinkPort;
        port telemetryIn : TelemetryPort;
        port cmdOut : CommandPort;
        port scienceDataIn : ScienceDataPort;
        port powerIn : PowerConsumerPort;

        part highGainAntenna {
            attribute gain : Real = 46.0;
            attribute diameter : Real = 2.5;
            attribute pointingAngle : AngleValue;
        }

        part transponder {
            attribute active : Boolean = true;
            attribute transmitPower : PowerValue = 20.0;

            action receiveCommands {
                in rfSignal : CommandPacket;
                out decodedCommand : CommandPacket;
            }
            action transmitTelemetry {
                in telemetry : TelemetryPacket;
                out rfSignal : TelemetryPacket;
            }
            action transmitScienceData {
                in data : ScienceData;
                out rfSignal : ScienceData;
            }
        }

        action communicate {
            in commands : CommandPacket;
            in telemetry : TelemetryPacket;
            in scienceData : ScienceData;
            out uplinkCommands : CommandPacket;
            out downlinkTelemetry : TelemetryPacket;
            out downlinkScience : ScienceData;
        }

        state commState {
            initial idle;
            state idle;
            state receiving;
            state transmitting;
            transition idle to receiving when transponder.active and rfLink.uplink.isNotEmpty;
            transition receiving to idle when true;
            transition idle to transmitting when telemetryIn.telemetry.isNotEmpty or scienceDataIn.data.isNotEmpty;
            transition transmitting to idle when true;
        }
    }

    part def AttitudeControlSubsystem {
        attribute pointingError : AngleValue = 0.001;
        attribute slewRate : AngularVelocityValue = 0.01;

        port cmdIn : AttitudeCmdPort;
        port stateOut : AttitudeStatePort;
        port telemetryOut : TelemetryPort;
        port powerIn : PowerConsumerPort;

        part reactionWheels[4] {
            attribute maxTorque : Real = 0.1;
            attribute wheelSpeed : AngularVelocityValue;
            attribute saturated : Boolean = false;

            action applyTorque {
                in torque : Real;
                out angularVelocity : AngularVelocityValue;
            }
        }

        part thrusters[8] {
            attribute thrustLevel : Real = 5.0;
            attribute fuelRemaining : MassValue = 40.0;

            action fireThruster {
                in duration : TimeValue;
                out deltaV : VelocityValue;
            }
        }

        part starTracker {
            attribute accuracy : AngleValue = 0.0005;
            attribute starsTracked : Integer = 0;

            action trackStars {
                out attitude : AttitudeState;
            }
        }

        part inertialMeasurementUnit {
            attribute gyroDrift : AngularVelocityValue = 0.00001;
            attribute currentOrientation : AngleValue;
            attribute currentAngularVelocity : AngularVelocityValue;
        }

        action controlAttitude {
            in command : AttitudeCommand;
            in measuredState : AttitudeState;
            out correctedState : AttitudeState;
        }

        state acsState {
            initial stable;
            state stable;
            state slewing;
            state stabilizing;
            state safeHold;
            transition stable to slewing when cmdIn.cmd.targetOrientation != stateOut.state.orientation;
            transition slewing to stabilizing when stateOut.state.angularVelocity < 0.0001;
            transition stabilizing to stable when stateOut.state.angularVelocity < 0.00001;
            transition stable to safeHold when telemetryOut.telemetry.healthStatus == "FAULT";
            transition slewing to safeHold when telemetryOut.telemetry.healthStatus == "FAULT";
            transition safeHold to stable when cmdIn.cmd.targetOrientation == stateOut.state.orientation;
        }
    }

    part def ScienceInstrumentSubsystem {
        attribute spectralBands : Integer = 12;
        attribute resolution : Real = 0.5;
        attribute fieldOfView : AngleValue = 0.087;

        port dataOut : ScienceDataPort;
        port powerIn : PowerConsumerPort;
        port cmdIn : CommandPort;
        port telemetryOut : TelemetryPort;

        part multispectralImager {
            attribute detectorTemp : TemperatureValue = 150.0;
            attribute exposureTime : TimeValue = 1.0;
            attribute pixelCount : Integer = 2048 * 2048;

            action captureImage {
                in exposure : TimeValue;
                out image : ScienceData;
            }
        }

        part spectrometer {
            attribute wavelengthRange : Real[2] = (400e-9, 2500e-9);
            attribute spectralResolution : Real = 5e-9;

            action acquireSpectrum {
                out spectrum : ScienceData;
            }
        }

        part calibrationUnit {
            attribute lastCalibration : TimeValue = 0.0;
            attribute calibrationInterval : TimeValue = 86400.0;

            action calibrate {
                out calibrationData : ScienceData;
            }
        }

        action collectScience {
            in target : String;
            out data : ScienceData;
        }

        state instrumentState {
            initial standby;
            state standby;
            state imaging;
            state calibrating;
            transition standby to imaging when cmdIn.commands.commandId == "IMAGE";
            transition imaging to standby when dataOut.data.size > 0;
            transition standby to calibrating when (now - calibrationUnit.lastCalibration) > calibrationUnit.calibrationInterval;
            transition calibrating to standby when true;
        }
    }

    part def DataStorageSubsystem {
        attribute capacity : DataSizeValue = 2.0e12;
        attribute usedSpace : DataSizeValue = 0.0;
        attribute fragmentation : Real = 0.0;

        port dataIn : ScienceDataPort;
        port dataOut : ScienceDataPort;
        port powerIn : PowerConsumerPort;
        port telemetryOut : TelemetryPort;

        part solidStateRecorder {
            attribute capacityValue : DataSizeValue = 2.0e12;
            attribute writeSpeed : DataRateValue = 50.0e6;
            attribute readSpeed : DataRateValue = 100.0e6;
            attribute bitErrorRate : Real = 1.0e-12;

            action writeData {
                in data : ScienceData;
            }
            action readData {
                out data : ScienceData;
            }
        }

        part fileManager {
            attribute fileCount : Integer = 0;
            attribute indexSize : DataSizeValue = 0.0;

            action indexFile {
                in data : ScienceData;
                out fileId : String;
            }
            action deleteFile {
                in fileId : String;
            }
        }

        action storeData {
            in incoming : ScienceData;
            out stored : ScienceData;
        }

        action retrieveData {
            out data : ScienceData;
        }

        state storageState {
            initial ready;
            state ready;
            state writing;
            state reading;
            state full;
            transition ready to writing when dataIn.data.isNotEmpty;
            transition writing to ready when true;
            transition ready to reading when dataOut.storedData.isNotEmpty;
            transition reading to ready when true;
            transition ready to full when usedSpace >= capacity;
            transition full to ready when usedSpace < capacity * 0.9;
        }
    }

    part def NavigationSubsystem {
        attribute positionAccuracy : DistanceValue = 1000.0;
        attribute velocityAccuracy : VelocityValue = 0.05;

        port solutionOut : NavSolutionPort;
        port maneuverOut : ManeuverPort;
        port powerIn : PowerConsumerPort;
        port cmdIn : CommandPort;
        port telemetryOut : TelemetryPort;

        part starCamera {
            attribute catalogSize : Integer = 5000;
            attribute matchedStars : Integer = 0;

            action identifyStars {
                out attitudeRef : AngleValue[3];
            }
        }

        part inertialNav {
            attribute accumulatedError : DistanceValue = 0.0;
            attribute driftRate : VelocityValue = 0.001;

            action integrate {
                in acceleration : Real[3];
                out solution : NavigationSolution;
            }
        }

        part trajectoryPlanner {
            attribute plannedDeltaV : VelocityValue = 0.0;
            attribute maneuverCount : Integer = 0;

            action planManeuver {
                in currentSolution : NavigationSolution;
                in targetSolution : NavigationSolution;
                out plan : ManeuverPlan;
            }
        }

        action determinePosition {
            out solution : NavigationSolution;
        }

        action executeManeuver {
            in plan : ManeuverPlan;
            out deltaV : VelocityValue;
        }

        state navState {
            initial coasting;
            state coasting;
            state computing;
            state maneuvering;
            transition coasting to computing when cmdIn.commands.commandId == "NAV_UPDATE";
            transition computing to coasting when solutionOut.solution.isNotEmpty;
            transition coasting to maneuvering when maneuverOut.plan.isNotEmpty;
            transition maneuvering to coasting when true;
        }
    }

    part def ThermalControlSubsystem {
        attribute minMaintained : TemperatureValue = 263.15;
        attribute maxMaintained : TemperatureValue = 313.15;
        attribute heaterPower : PowerValue = 50.0;

        port thermalOut : ThermalControlPort;
        port powerIn : PowerConsumerPort;
        port telemetryOut : TelemetryPort;

        part radiators {
            attribute area : Real = 3.0;
            attribute emissivity : Real = 0.85;
            attribute radiatorTemp : TemperatureValue = 270.0;

            action rejectHeat {
                in heatFlux : Real;
                out radiatorTemp : TemperatureValue;
            }
        }

        part heaters {
            attribute power : PowerValue = 50.0;
            attribute dutyCycle : Real = 0.5;
            attribute active : Boolean = true;

            action heat {
                in dutyCycle : Real;
                out heatFlux : Real;
            }
        }

        part thermalSensors[12] {
            attribute measuredTemp : TemperatureValue;
            attribute location : String;

            action measure {
                out temperature : TemperatureValue;
            }
        }

        part louvers {
            attribute openAngle : AngleValue;
            attribute autoMode : Boolean = true;

            action adjust {
                in temp : TemperatureValue;
                out angle : AngleValue;
            }
        }

        action regulateTemperature {
            in measuredTemps : TemperatureValue[*];
            out setpoint : ThermalSetpoint;
        }

        state thermalState {
            initial nominal;
            state nominal;
            state heating;
            state cooling;
            transition nominal to heating when thermalSensors.measuredTemp < minMaintained;
            transition nominal to cooling when thermalSensors.measuredTemp > maxMaintained;
            transition heating to nominal when thermalSensors.measuredTemp >= minMaintained + 5.0;
            transition cooling to nominal when thermalSensors.measuredTemp <= maxMaintained - 5.0;
        }
    }

    // ===== Top-Level Probe =====
    part def DeepSpaceProbeSystem {
        attribute missionDuration : TimeValue = 3.15e7;
        attribute maxRealTimeDelay : TimeValue = 0.0;
        attribute missionPhase : String = "CRUISE";

        port rfLink : RFLinkPort;

        part powerSubsystem : PowerSubsystem {
            part solarArray;
            part batteryPack;
            part powerDistributionUnit;
        }

        part communicationSubsystem : CommunicationSubsystem {
            part highGainAntenna;
            part transponder;
        }

        part attitudeControl : AttitudeControlSubsystem {
            part reactionWheels[4];
            part thrusters[8];
            part starTracker;
            part inertialMeasurementUnit;
        }

        part scienceInstrument : ScienceInstrumentSubsystem {
            part multispectralImager;
            part spectrometer;
            part calibrationUnit;
        }

        part dataStorage : DataStorageSubsystem {
            part solidStateRecorder;
            part fileManager;
        }

        part navigation : NavigationSubsystem {
            part starCamera;
            part inertialNav;
            part trajectoryPlanner;
        }

        part thermalControl : ThermalControlSubsystem {
            part radiators;
            part heaters;
            part thermalSensors[12];
            part louvers;
        }

        // ===== Internal Connections =====
        connection powerBus connect powerSubsystem.powerOut to communicationSubsystem.powerIn;
        connection powerBus2 connect powerSubsystem.powerOut to attitudeControl.powerIn;
        connection powerBus3 connect powerSubsystem.powerOut to scienceInstrument.powerIn;
        connection powerBus4 connect powerSubsystem.powerOut to dataStorage.powerIn;
        connection powerBus5 connect powerSubsystem.powerOut to navigation.powerIn;
        connection powerBus6 connect powerSubsystem.powerOut to thermalControl.powerIn;

        connection commandFlow connect communicationSubsystem.cmdOut to powerSubsystem.cmdIn;
        connection commandFlow2 connect communicationSubsystem.cmdOut to attitudeControl.cmdIn;
        connection commandFlow3 connect communicationSubsystem.cmdOut to scienceInstrument.cmdIn;
        connection commandFlow4 connect communicationSubsystem.cmdOut to navigation.cmdIn;

        connection telemetryFlow connect powerSubsystem.telemetryOut to communicationSubsystem.telemetryIn;
        connection telemetryFlow2 connect attitudeControl.telemetryOut to communicationSubsystem.telemetryIn;
        connection telemetryFlow3 connect scienceInstrument.telemetryOut to communicationSubsystem.telemetryIn;
        connection telemetryFlow4 connect dataStorage.telemetryOut to communicationSubsystem.telemetryIn;
        connection telemetryFlow5 connect navigation.telemetryOut to communicationSubsystem.telemetryIn;
        connection telemetryFlow6 connect thermalControl.telemetryOut to communicationSubsystem.telemetryIn;

        connection scienceDataFlow connect scienceInstrument.dataOut to dataStorage.dataIn;
        connection storedDataFlow connect dataStorage.dataOut to communicationSubsystem.scienceDataIn;

        connection attitudeCmdFlow connect navigation.solutionOut to attitudeControl.cmdIn;
        connection attitudeStateFlow connect attitudeControl.stateOut to navigation.cmdIn;

        connection thermalSetpointFlow connect thermalControl.thermalOut to powerSubsystem.cmdIn;

        connection rfExternal connect rfLink to communicationSubsystem.rfLink;

        // ===== Mission State Machine =====
        state missionState {
            initial deployment;
            state deployment {
                entry { missionPhase := "DEPLOYMENT"; }
            }
            state cruise {
                entry { missionPhase := "CRUISE"; }
            }
            state scienceObservation {
                entry { missionPhase := "SCIENCE"; }
            }
            state dataDownlink {
                entry { missionPhase := "DOWNLINK"; }
            }
            state maneuver {
                entry { missionPhase := "MANEUVER"; }
            }
            state safeMode {
                entry { missionPhase := "SAFE"; }
            }

            transition deployment to cruise when powerSubsystem.batteryPack.chargeLevel > 0.5;
            transition cruise to scienceObservation when navigation.solutionOut.solution.isNotEmpty;
            transition scienceObservation to dataDownlink when dataStorage.usedSpace > dataStorage.capacity * 0.8;
            transition dataDownlink to scienceObservation when dataStorage.usedSpace < dataStorage.capacity * 0.2;
            transition cruise to maneuver when navigation.maneuverOut.plan.isNotEmpty;
            transition maneuver to cruise when true;
            transition cruise to safeMode when powerSubsystem.batteryPack.chargeLevel < 0.15;
            transition scienceObservation to safeMode when powerSubsystem.batteryPack.chargeLevel < 0.15;
            transition dataDownlink to safeMode when powerSubsystem.batteryPack.chargeLevel < 0.15;
            transition safeMode to cruise when communicationSubsystem.rfLink.uplink.commandId == "RECOVER";
        }

        // ===== Autonomous Operations Action =====
        action autonomousOperations {
            in missionCommands : CommandPacket[*];
            out scienceResults : ScienceData[*];

            action determineTarget {
                out targetId : String;
            }
            action pointInstruments {
                in target : String;
                out attitudeCmd : AttitudeCommand;
            }
            action collectData {
                in target : String;
                out data : ScienceData;
            }
            action storeData {
                in data : ScienceData;
            }
            action checkCommWindow {
                out windowOpen : Boolean;
            }
            action pointAntenna {
                out attitudeCmd : AttitudeCommand;
            }
            action transmitData {
                in data : ScienceData;
                out transmitted : ScienceData;
            }
            action checkHealth {
                out healthy : Boolean;
            }
            action enterSafeMode {
                out safeModeActive : Boolean;
            }

            flow determineTarget.targetId to pointInstruments.target;
            flow pointInstruments.attitudeCmd to attitudeControl.cmdIn;
            flow determineTarget.targetId to collectData.target;
            flow collectData.data to storeData.data;
            flow checkCommWindow.windowOpen to pointAntenna;
            flow pointAntenna.attitudeCmd to attitudeControl.cmdIn;
            flow storeData.data to transmitData.data;
            flow checkHealth.healthy to enterSafeMode;
        }
    }

    // ===== Instance =====
    part probe : DeepSpaceProbeSystem {
        satisfy PowerReq by solarArray;
        satisfy BatteryReq by powerSubsystem.batteryPack;
        satisfy PointingReq by attitudeControl;
        satisfy StorageReq by dataStorage;
        satisfy ThermalReq by thermalControl;
        satisfy AutonomyReq by probe;
    }
}

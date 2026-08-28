package InterplanetarySpacecraftModel {

    attribute def Boolean;
    attribute def String;
    attribute def Integer;
    attribute def Real;

    attribute def MassValue;
    attribute def LengthValue;
    attribute def AreaValue;
    attribute def PowerValue;
    attribute def EnergyValue;
    attribute def ForceValue;
    attribute def TimeValue;
    attribute def VelocityValue;
    attribute def AngularVelocityValue;
    attribute def FrequencyValue;
    attribute def ElectricPotentialValue;
    attribute def ElectricCurrentValue;
    attribute def DurationValue;

    item def ElectricalPowerData {
        attribute power : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    item def CommandData {
        attribute commandId : String;
        attribute commandParameters : String;
    }
    item def TelemetryData {
        attribute source : String;
        attribute dataVolume : Integer;
    }
    item def ScienceData {
        attribute instrumentId : String;
        attribute dataVolume : Integer;
    }
    item def AttitudeData {
        attribute quaternionW : Real;
        attribute quaternionX : Real;
        attribute quaternionY : Real;
        attribute quaternionZ : Real;
        attribute angularRateX : AngularVelocityValue;
        attribute angularRateY : AngularVelocityValue;
        attribute angularRateZ : AngularVelocityValue;
    }
    item def ManeuverCommandData {
        attribute deltaV : VelocityValue;
        attribute burnDuration : TimeValue;
    }
    item def RfSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
        attribute modulation : String;
    }
    item def RecordedData {
        attribute dataBlock : String;
        attribute sizeBytes : Integer;
    }

    port def PowerSourcePort {
        out item powerData : ElectricalPowerData;
    }
    port def PowerSinkPort {
        in item powerData : ElectricalPowerData;
    }
    port def CommandInputPort {
        in item commandData : CommandData;
    }
    port def CommandOutputPort {
        out item commandData : CommandData;
    }
    port def TelemetryInputPort {
        in item telemetryData : TelemetryData;
    }
    port def TelemetryOutputPort {
        out item telemetryData : TelemetryData;
    }
    port def ScienceDataInputPort {
        in item scienceData : ScienceData;
    }
    port def ScienceDataOutputPort {
        out item scienceData : ScienceData;
    }
    port def AttitudeDataInputPort {
        in item attitudeData : AttitudeData;
    }
    port def AttitudeDataOutputPort {
        out item attitudeData : AttitudeData;
    }
    port def ManeuverCommandInputPort {
        in item maneuverCommandData : ManeuverCommandData;
    }
    port def ManeuverCommandOutputPort {
        out item maneuverCommandData : ManeuverCommandData;
    }
    port def AntennaRfPort {
        in item receivedData : TelemetryData;
        out item transmittedData : TelemetryData;
    }
    port def DataInputPort {
        in item recordedData : RecordedData;
    }
    port def DataOutputPort {
        out item recordedData : RecordedData;
    }
    port def HeaterCommandInputPort {
        in attribute heatOn : Boolean;
    }
    port def HeaterCommandOutputPort {
        out attribute heatOn : Boolean;
    }
    port def RadiatorCommandInputPort {
        in attribute radiatorDeployed : Boolean;
    }
    port def RadiatorCommandOutputPort {
        out attribute radiatorDeployed : Boolean;
    }

    part def SolarArrayAssembly {
        attribute deployedLength : LengthValue;
        attribute area : AreaValue;
        attribute powerGenerated : PowerValue;
        port powerOut : PowerSourcePort;
        perform action deploy {
            first start;
            then action extendPanels;
            then action lockPanels;
            then done;
        }
        perform action trackSun {
            first start;
            then action computeSunVector;
            then action rotateGimbal;
            then done;
        }
    }

    part def RechargeableBatterySystem {
        attribute capacity : EnergyValue;
        attribute stateOfCharge : Real;
        attribute cellCount : Integer;
        port chargeInput : PowerSinkPort;
        port dischargeOutput : PowerSourcePort;
        perform action charge {
            first start;
            then action monitorChargeState;
            then done;
        }
        perform action discharge {
            first start;
            then action providePower;
            then done;
        }
    }

    part def PowerDistributionUnit {
        port solarArrayInput1 : PowerSinkPort;
        port solarArrayInput2 : PowerSinkPort;
        port batteryDischargeInput : PowerSinkPort;
        port batteryChargeOutput : PowerSourcePort;
        port gncPowerOut : PowerSourcePort;
        port cdhPowerOut : PowerSourcePort;
        port commPowerOut : PowerSourcePort;
        port thermalPowerOut : PowerSourcePort;
        port sciencePowerOut : PowerSourcePort;
        port propulsionPowerOut : PowerSourcePort;
        perform action regulatePower {
            first start;
            then action monitorInputs;
            then action adjustVoltage;
            then done;
        }
    }

    part def StarTracker {
        port attitudeDataOut : AttitudeDataOutputPort;
        perform action trackStars {
            first start;
            then action captureImage;
            then action computeAttitude;
            then done;
        }
    }

    part def SunSensor {
        port attitudeDataOut : AttitudeDataOutputPort;
        perform action senseSunDirection {
            first start;
            then action measureSunAngle;
            then done;
        }
    }

    part def InertialMeasurementUnit {
        port attitudeDataOut : AttitudeDataOutputPort;
        perform action measureAngularRates {
            first start;
            then action readGyros;
            then done;
        }
    }

    part def GNCSystem {
        port powerInput : PowerSinkPort;
        port starTrackerDataIn : AttitudeDataInputPort;
        port sunSensorDataIn : AttitudeDataInputPort;
        port imuDataIn : AttitudeDataInputPort;
        port maneuverCommandOut : ManeuverCommandOutputPort;
        perform action determineAttitude {
            first start;
            then action fuseSensorData;
            then action computeState;
            then done;
        }
        perform action planManeuver {
            first start;
            then action computeDeltaV;
            then done;
        }
    }

    part def MainEngine {
        port commandIn : ManeuverCommandInputPort;
        attribute thrust : ForceValue;
        attribute specificImpulse : TimeValue;
        perform action performBurn {
            first start;
            then action openValves;
            then action combustPropellant;
            then done;
        }
    }

    part def ReactionControlThruster {
        port commandIn : ManeuverCommandInputPort;
        attribute thrust : ForceValue;
        perform action fireThruster {
            first start;
            then action openValve;
            then done;
        }
    }

    part def ChemicalPropulsionSystem {
        port powerInput : PowerSinkPort;
        port maneuverCommandIn : ManeuverCommandInputPort;
        port mainEngineCommandOut : ManeuverCommandOutputPort;
        port rcsCommandOut1 : ManeuverCommandOutputPort;
        port rcsCommandOut2 : ManeuverCommandOutputPort;
        port rcsCommandOut3 : ManeuverCommandOutputPort;
        port rcsCommandOut4 : ManeuverCommandOutputPort;
        attribute propellantMass : MassValue;
        part mainEngine : MainEngine;
        connect mainEngineCommandOut to mainEngine.commandIn;
        perform action executeManeuver {
            first start;
            then action selectThrusters;
            then action fireThrusters;
            then done;
        }
    }

    part def SolidStateRecorder {
        port dataIn : DataInputPort;
        port dataOut : DataOutputPort;
        attribute storageCapacity : Integer;
        perform action storeData {
            first start;
            then action writeToMemory;
            then done;
        }
    }

    part def CommandAndDataHandling {
        port powerInput : PowerSinkPort;
        port commandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;
        port recorderDataOut : DataOutputPort;
        port recorderDataIn : DataInputPort;
        port scienceDataIn1 : ScienceDataInputPort;
        port scienceDataIn2 : ScienceDataInputPort;
        port scienceDataIn3 : ScienceDataInputPort;
        port scienceDataIn4 : ScienceDataInputPort;
        perform action processCommands {
            first start;
            then action decodeCommand;
            then action dispatchCommand;
            then done;
        }
        perform action manageData {
            first start;
            then action collectScienceData;
            then action storeToRecorder;
            then action prepareTelemetry;
            then done;
        }
        perform action executeFlightSoftware {
            first start;
            then action loadSoftware;
            then action runSoftware;
            then done;
        }
    }

    part def HighGainAntenna {
        attribute diameter : LengthValue;
        port rfPort : AntennaRfPort;
        perform action steerAntenna {
            first start;
            then action computePointing;
            then action rotateGimbal;
            then done;
        }
    }

    part def LowGainAntenna {
        port rfPort : AntennaRfPort;
        perform action transmitEmergencyBeacon {
            first start;
            then action sendBeacon;
            then done;
        }
    }

    part def CommunicationSubsystem {
        port powerInput : PowerSinkPort;
        port highGainAntennaPort : AntennaRfPort;
        port lowGainAntennaPort : AntennaRfPort;
        port commandOutput : CommandOutputPort;
        port telemetryInput : TelemetryInputPort;
        perform action transmitData {
            first start;
            then action encodeData;
            then action modulateSignal;
            then done;
        }
        perform action receiveCommands {
            first start;
            then action demodulateSignal;
            then action decodeCommand;
            then done;
        }
    }

    part def ImagingSpectrometer {
        port scienceDataOut : ScienceDataOutputPort;
        perform action captureSpectralImage {
            first start;
            then action scanSurface;
            then action recordSpectrum;
            then action analyzeSurfaceAndAtmosphericComposition;
            then done;
        }
    }

    part def InfraredCamera {
        port scienceDataOut : ScienceDataOutputPort;
        perform action captureThermalImage {
            first start;
            then action scanInfrared;
            then action recordThermalMap;
            then done;
        }
    }

    part def Magnetometer {
        port scienceDataOut : ScienceDataOutputPort;
        perform action measureMagneticField {
            first start;
            then action sampleField;
            then action recordVector;
            then done;
        }
    }

    part def ParticleDetector {
        port scienceDataOut : ScienceDataOutputPort;
        perform action detectParticles {
            first start;
            then action collectParticleEvents;
            then action recordCounts;
            then done;
        }
    }

    part def ScienceInstrumentSuite {
        port powerInput : PowerSinkPort;
        port scienceDataOut1 : ScienceDataOutputPort;
        port scienceDataOut2 : ScienceDataOutputPort;
        port scienceDataOut3 : ScienceDataOutputPort;
        port scienceDataOut4 : ScienceDataOutputPort;
        part imagingSpectrometer : ImagingSpectrometer;
        part infraredCamera : InfraredCamera;
        part magnetometer : Magnetometer;
        part particleDetector : ParticleDetector;
        connect imagingSpectrometer.scienceDataOut to scienceDataOut1;
        connect infraredCamera.scienceDataOut to scienceDataOut2;
        connect magnetometer.scienceDataOut to scienceDataOut3;
        connect particleDetector.scienceDataOut to scienceDataOut4;
        perform action coordinateObservations {
            first start;
            then action scheduleInstrument;
            then done;
        }
    }

    part def Radiator {
        port commandIn : RadiatorCommandInputPort;
        perform action deployRadiator {
            first start;
            then action openLouvers;
            then done;
        }
    }

    part def Heater {
        port commandIn : HeaterCommandInputPort;
        perform action activateHeater {
            first start;
            then action turnOnHeater;
            then done;
        }
    }

    part def MultiLayerInsulation {
        attribute layers : Integer;
    }

    part def ThermalControlSystem {
        port powerInput : PowerSinkPort;
        port heaterCommandOut1 : HeaterCommandOutputPort;
        port heaterCommandOut2 : HeaterCommandOutputPort;
        port heaterCommandOut3 : HeaterCommandOutputPort;
        port heaterCommandOut4 : HeaterCommandOutputPort;
        port radiatorCommandOut1 : RadiatorCommandOutputPort;
        port radiatorCommandOut2 : RadiatorCommandOutputPort;
        part radiator1 : Radiator;
        part radiator2 : Radiator;
        part heater1 : Heater;
        part heater2 : Heater;
        part heater3 : Heater;
        part heater4 : Heater;
        part multiLayerInsulation : MultiLayerInsulation;
        connect heaterCommandOut1 to heater1.commandIn;
        connect heaterCommandOut2 to heater2.commandIn;
        connect heaterCommandOut3 to heater3.commandIn;
        connect heaterCommandOut4 to heater4.commandIn;
        connect radiatorCommandOut1 to radiator1.commandIn;
        connect radiatorCommandOut2 to radiator2.commandIn;
        perform action regulateTemperature {
            first start;
            then action readTemperatureSensors;
            then action adjustHeaters;
            then action deployRadiators;
            then done;
        }
    }

    part def Spacecraft {
        attribute missionName : String;
        attribute targetBody : String;
        attribute mass : MassValue;
        attribute missionElapsedTime : TimeValue;

        part solarArray1 : SolarArrayAssembly;
        part solarArray2 : SolarArrayAssembly;
        part batterySystem : RechargeableBatterySystem;
        part powerDistributionUnit : PowerDistributionUnit;
        part starTracker : StarTracker;
        part sunSensor : SunSensor;
        part inertialMeasurementUnit : InertialMeasurementUnit;
        part gncSystem : GNCSystem;
        part rcsThruster1 : ReactionControlThruster;
        part rcsThruster2 : ReactionControlThruster;
        part rcsThruster3 : ReactionControlThruster;
        part rcsThruster4 : ReactionControlThruster;
        part propulsionSystem : ChemicalPropulsionSystem;
        part solidStateRecorder : SolidStateRecorder;
        part commandAndDataHandling : CommandAndDataHandling;
        part highGainAntenna : HighGainAntenna;
        part lowGainAntenna : LowGainAntenna;
        part communicationSubsystem : CommunicationSubsystem;
        part scienceInstrumentSuite : ScienceInstrumentSuite;
        part thermalControlSystem : ThermalControlSystem;

        connect solarArray1.powerOut to powerDistributionUnit.solarArrayInput1;
        connect solarArray2.powerOut to powerDistributionUnit.solarArrayInput2;
        connect batterySystem.dischargeOutput to powerDistributionUnit.batteryDischargeInput;
        connect powerDistributionUnit.batteryChargeOutput to batterySystem.chargeInput;
        connect powerDistributionUnit.gncPowerOut to gncSystem.powerInput;
        connect powerDistributionUnit.cdhPowerOut to commandAndDataHandling.powerInput;
        connect powerDistributionUnit.commPowerOut to communicationSubsystem.powerInput;
        connect powerDistributionUnit.thermalPowerOut to thermalControlSystem.powerInput;
        connect powerDistributionUnit.sciencePowerOut to scienceInstrumentSuite.powerInput;
        connect powerDistributionUnit.propulsionPowerOut to propulsionSystem.powerInput;

        connect starTracker.attitudeDataOut to gncSystem.starTrackerDataIn;
        connect sunSensor.attitudeDataOut to gncSystem.sunSensorDataIn;
        connect inertialMeasurementUnit.attitudeDataOut to gncSystem.imuDataIn;
        connect gncSystem.maneuverCommandOut to propulsionSystem.maneuverCommandIn;
        connect propulsionSystem.rcsCommandOut1 to rcsThruster1.commandIn;
        connect propulsionSystem.rcsCommandOut2 to rcsThruster2.commandIn;
        connect propulsionSystem.rcsCommandOut3 to rcsThruster3.commandIn;
        connect propulsionSystem.rcsCommandOut4 to rcsThruster4.commandIn;

        connect communicationSubsystem.highGainAntennaPort to highGainAntenna.rfPort;
        connect communicationSubsystem.lowGainAntennaPort to lowGainAntenna.rfPort;
        connect commandAndDataHandling.commandInput to communicationSubsystem.commandOutput;
        connect commandAndDataHandling.telemetryOutput to communicationSubsystem.telemetryInput;
        connect commandAndDataHandling.recorderDataOut to solidStateRecorder.dataIn;
        connect solidStateRecorder.dataOut to commandAndDataHandling.recorderDataIn;
        connect scienceInstrumentSuite.scienceDataOut1 to commandAndDataHandling.scienceDataIn1;
        connect scienceInstrumentSuite.scienceDataOut2 to commandAndDataHandling.scienceDataIn2;
        connect scienceInstrumentSuite.scienceDataOut3 to commandAndDataHandling.scienceDataIn3;
        connect scienceInstrumentSuite.scienceDataOut4 to commandAndDataHandling.scienceDataIn4;

        attribute def SigCruiseStart;
        attribute def SigApproachStart;
        attribute def SigOrbitInsertionComplete;
        attribute def SigAnomaly;
        attribute def SigRecoveryCommand;

        perform action pointSolarArraysAtSun {
            first start;
            then action rotateSolarArray;
            then done;
        }
        perform action awaitGroundCommand {
            first start;
            then action listenForCommand;
            then done;
        }

        state missionStates {
            entry; then launch;
            state launch;
            accept SigCruiseStart then cruise;
            state cruise;
            accept SigApproachStart then approach;
            state approach;
            accept SigOrbitInsertionComplete then orbit;
            state orbit;
            accept SigAnomaly then safeMode;
            state safeMode {
                entry pointSolarArraysAtSun;
                do awaitGroundCommand;
            }
            transition safeMode_recover
                first safeMode
                accept SigRecoveryCommand
                then cruise;
        }
    }

    part def EarthGroundStation {
        port rfPort : AntennaRfPort;
        perform action sendCommands {
            first start;
            then action encodeCommand;
            then action transmitSignal;
            then done;
        }
        perform action receiveTelemetry {
            first start;
            then action receiveSignal;
            then action decodeTelemetry;
            then done;
        }
    }

    part jupiterExplorer : Spacecraft {
        :>> missionName = "Jupiter Deep Space Explorer";
        :>> targetBody = "Jupiter";
        :>> mass = 2500;

        part solarArray1 : SolarArrayAssembly {
            :>> deployedLength = 5;
            :>> area = 20;
            :>> powerGenerated = 800;
        }
        part solarArray2 : SolarArrayAssembly {
            :>> deployedLength = 5;
            :>> area = 20;
            :>> powerGenerated = 800;
        }
        part batterySystem : RechargeableBatterySystem {
            :>> capacity = 5000;
            :>> cellCount = 8;
        }
        part highGainAntenna : HighGainAntenna {
            :>> diameter = 3;
        }
        part propulsionSystem : ChemicalPropulsionSystem {
            part mainEngine : MainEngine {
                :>> thrust = 645;
                :>> specificImpulse = 320;
            }
        }
        part solidStateRecorder : SolidStateRecorder {
            :>> storageCapacity = 256000000;
        }
    }

    part groundStation : EarthGroundStation;

    message telemetryDownlink of TelemetryData from jupiterExplorer.highGainAntenna.rfPort to groundStation.rfPort;
}

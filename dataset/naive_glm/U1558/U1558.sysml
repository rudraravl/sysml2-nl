package InterplanetarySpacecraftModel {

    value type PowerUnit > Real { unit "W"; }
    value type EnergyUnit > Real { unit "Wh"; }
    value type VoltageUnit > Real { unit "V"; }
    value type CurrentUnit > Real { unit "A"; }
    value type TemperatureUnit > Real { unit "degC"; }
    value type DistanceUnit > Real { unit "km"; }
    value type VelocityUnit > Real { unit "km/s"; }
    value type AngleUnit > Real { unit "deg"; }
    value type AngularRateUnit > Real { unit "deg/s"; }
    value type DataRateUnit > Real { unit "kbps"; }
    value type DataVolumeUnit > Real { unit "Gb"; }
    value type MassUnit > Real { unit "kg"; }
    value type ForceUnit > Real { unit "N"; }
    value type FrequencyUnit > Real { unit "MHz"; }
    value type TimeUnit > Real { unit "s"; }
    value type AreaUnit > Real { unit "m^2"; }

    item def ElectricalPower {
        attribute voltage : VoltageUnit;
        attribute current : CurrentUnit;
    }

    item def DataPacket {
        attribute volume : DataVolumeUnit;
        attribute source : String;
    }

    item def ScienceData :> DataPacket {
        attribute instrumentId : String;
        attribute observationType : String;
    }

    item def Command {
        attribute id : String;
        attribute priority : Integer;
        attribute source : String;
    }

    item def Telemetry {
        attribute dataRate : DataRateUnit;
        attribute healthStatus : String;
    }

    item def AttitudeState {
        attribute roll : AngleUnit;
        attribute pitch : AngleUnit;
        attribute yaw : AngleUnit;
    }

    item def OrbitalState {
        attribute position : DistanceUnit[3];
        attribute velocity : VelocityUnit[3];
    }

    item def ThrustCommand {
        attribute magnitude : ForceUnit;
        attribute direction : AngleUnit[3];
        attribute duration : TimeUnit;
    }

    item def ThermalFlux {
        attribute magnitude : PowerUnit;
    }

    item def RFSignal {
        attribute frequency : FrequencyUnit;
        attribute dataRate : DataRateUnit;
        attribute powerLevel : PowerUnit;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def DataOutPort {
        out data : DataPacket;
    }

    port def DataInPort {
        in data : DataPacket;
    }

    port def CmdInPort {
        in command : Command;
    }

    port def CmdOutPort {
        out command : Command;
    }

    port def TlmOutPort {
        out telemetry : Telemetry;
    }

    port def AttitudeOutPort {
        out attitude : AttitudeState;
    }

    port def NavOutPort {
        out navState : OrbitalState;
    }

    port def ThrustCmdOutPort {
        out thrustCmd : ThrustCommand;
    }

    port def ThrustCmdInPort {
        in thrustCmd : ThrustCommand;
    }

    port def RFOutPort {
        out rfSignal : RFSignal;
    }

    port def RFInPort {
        in rfSignal : RFSignal;
    }

    part def SolarArrayAssembly {
        attribute deployedArea : AreaUnit;
        attribute maxPower : PowerUnit;
        attribute currentPower : PowerUnit;
        attribute efficiency : Real;
        port powerOut : PowerOutPort;

        action def generatePower {
            in sunlightIntensity : Real;
            in sunAngle : AngleUnit;
            out generatedPower : ElectricalPower;
        }
    }

    part def BatterySystem {
        attribute capacity : EnergyUnit;
        attribute chargeLevel : EnergyUnit;
        attribute nominalVoltage : VoltageUnit;
        attribute depthOfDischargeLimit : Real;
        port chargeIn : PowerInPort;
        port dischargeOut : PowerOutPort;

        state batteryState {
            state Charging;
            state Discharging;
            state Full;
            transition Charging to Full when chargeLevel >= capacity;
            transition Full to Discharging when chargeLevel < capacity * 0.99;
            transition Discharging to Charging when chargeLevel < capacity * 0.5;
        }
    }

    part def PowerDistributionUnit {
        port solarIn : PowerInPort;
        port batteryDischargeIn : PowerInPort;
        port batteryChargeOut : PowerOutPort;
        port gncPowerOut : PowerOutPort;
        port cdhPowerOut : PowerOutPort;
        port commsPowerOut : PowerOutPort;
        port sciencePowerOut : PowerOutPort;
        port thermalPowerOut : PowerOutPort;
        port propulsionPowerOut : PowerOutPort;

        attribute totalBusPower : PowerUnit;
        attribute busVoltage : VoltageUnit;
        attribute solarInputPower : PowerUnit;
        attribute batteryInputPower : PowerUnit;

        action def distributePower {
            in solarPower : ElectricalPower;
            in batteryPower : ElectricalPower;
            out busPower : ElectricalPower;
        }

        action def regulateBusVoltage {
            in inputVoltage : VoltageUnit;
            out regulatedVoltage : VoltageUnit;
        }
    }

    part def PowerSubsystem {
        part solarArrays : SolarArrayAssembly[2];
        part battery : BatterySystem;
        part pdu : PowerDistributionUnit;

        port gncPowerOut : PowerOutPort;
        port cdhPowerOut : PowerOutPort;
        port commsPowerOut : PowerOutPort;
        port sciencePowerOut : PowerOutPort;
        port thermalPowerOut : PowerOutPort;
        port propulsionPowerOut : PowerOutPort;

        connection solarArrays.powerOut to pdu.solarIn;
        connection battery.dischargeOut to pdu.batteryDischargeIn;
        connection pdu.batteryChargeOut to battery.chargeIn;

        connection pdu.gncPowerOut to gncPowerOut;
        connection pdu.cdhPowerOut to cdhPowerOut;
        connection pdu.commsPowerOut to commsPowerOut;
        connection pdu.sciencePowerOut to sciencePowerOut;
        connection pdu.thermalPowerOut to thermalPowerOut;
        connection pdu.propulsionPowerOut to propulsionPowerOut;
    }

    part def StarTracker {
        attribute accuracy : AngleUnit;
        attribute updateRate : FrequencyUnit;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def determineStarAttitude {
            in starPattern : String;
            out attitude : AttitudeState;
        }
    }

    part def SunSensor {
        attribute fieldOfView : AngleUnit;
        attribute accuracy : AngleUnit;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def detectSunDirection {
            out sunAngle : AngleUnit[2];
        }
    }

    part def InertialMeasurementUnit {
        attribute driftRate : AngularRateUnit;
        attribute gyroBias : AngularRateUnit;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def measureInertialState {
            out attitude : AttitudeState;
            out angularRate : AngularRateUnit[3];
        }
    }

    part def GNCSubsystem {
        part starTracker : StarTracker;
        part sunSensor : SunSensor;
        part imu : InertialMeasurementUnit;

        port powerIn : PowerInPort;
        port attitudeOut : AttitudeOutPort;
        port navOut : NavOutPort;
        port thrustCmdOut : ThrustCmdOutPort;
        port dataOut : DataOutPort;

        attribute currentAttitude : AttitudeState;
        attribute currentNavState : OrbitalState;
        attribute targetState : OrbitalState;

        connection powerIn to starTracker.powerIn;
        connection powerIn to sunSensor.powerIn;
        connection powerIn to imu.powerIn;

        action def navigate {
            in starData : AttitudeState;
            in sunData : AngleUnit[2];
            in imuData : AttitudeState;
            in imuRate : AngularRateUnit[3];
            out navSolution : OrbitalState;
        }

        action def computeGuidance {
            in targetState : OrbitalState;
            in currentState : OrbitalState;
            out thrustCommand : ThrustCommand;
        }

        action def determineAttitude {
            in starAttitude : AttitudeState;
            in sunDirection : AngleUnit[2];
            in imuAttitude : AttitudeState;
            out fusedAttitude : AttitudeState;
        }
    }

    part def MainEngine {
        attribute thrust : ForceUnit;
        attribute specificImpulse : TimeUnit;
        attribute totalImpulses : Integer;
        port thrustCmdIn : ThrustCmdInPort;
        port powerIn : PowerInPort;

        action def performBurn {
            in command : ThrustCommand;
            out appliedThrust : ThrustCommand;
        }
    }

    part def RCSThruster {
        attribute thrust : ForceUnit;
        attribute specificImpulse : TimeUnit;
        port thrustCmdIn : ThrustCmdInPort;
        port powerIn : PowerInPort;

        action def fireThruster {
            in command : ThrustCommand;
        }
    }

    part def PropulsionSubsystem {
        part mainEngine : MainEngine;
        part rcsThrusters : RCSThruster[8];
        attribute propellantMass : MassUnit;
        attribute initialPropellantMass : MassUnit;

        port powerIn : PowerInPort;
        port thrustCmdIn : ThrustCmdInPort;
        port thrustCmdOut : ThrustCmdOutPort;

        connection powerIn to mainEngine.powerIn;
        connection powerIn to rcsThrusters.powerIn;

        action def executeManeuver {
            in command : ThrustCommand;
            out appliedThrust : ThrustCommand;
        }

        action def adjustAttitude {
            in command : ThrustCommand;
            out appliedThrust : ThrustCommand;
        }
    }

    part def FlightProcessor {
        attribute clockSpeed : FrequencyUnit;
        attribute memorySize : DataVolumeUnit;
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port cmdIn : CmdInPort;
        port cmdOut : CmdOutPort;
        port powerIn : PowerInPort;

        action def executeFlightSoftware {
            in command : Command;
            out processedCommand : Command;
        }

        action def runControlLoop {
            in sensorData : DataPacket;
            out controlCommand : Command;
        }
    }

    part def SolidStateRecorder {
        attribute capacity : DataVolumeUnit;
        attribute usedSpace : DataVolumeUnit;
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def storeData {
            in data : DataPacket;
        }

        action def retrieveData {
            out data : DataPacket;
        }

        action def manageStorage {
            in newData : DataPacket;
            out status : String;
        }
    }

    part def CDHSubsystem {
        part processor : FlightProcessor;
        part recorder : SolidStateRecorder;

        port powerIn : PowerInPort;
        port cmdIn : CmdInPort;
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port tlmOut : TlmOutPort;

        connection powerIn to processor.powerIn;
        connection powerIn to recorder.powerIn;
        connection processor.cmdOut to recorder.dataIn;
        connection recorder.dataOut to processor.dataIn;
        connection processor.dataOut to dataOut;
        connection cmdIn to processor.cmdIn;
        connection processor.cmdOut to cmdIn;

        action def processCommand {
            in command : Command;
            out dispatch : Command;
        }

        action def manageScienceData {
            in scienceData : ScienceData;
            out storedData : DataPacket;
        }

        action def generateTelemetry {
            in healthData : String;
            out telemetry : Telemetry;
        }
    }

    part def HighGainAntenna {
        attribute gain : Real;
        attribute diameter : Real;
        attribute pointingAccuracy : AngleUnit;
        port dataIn : DataInPort;
        port rfOut : RFOutPort;
        port rfIn : RFInPort;
        port powerIn : PowerInPort;

        action def transmitHighRate {
            in data : DataPacket;
            out rfSignal : RFSignal;
        }

        action def receiveUplink {
            in rfSignal : RFSignal;
            out command : Command;
        }

        action def steerAntenna {
            in targetDirection : AngleUnit[2];
            out achievedPointing : AngleUnit[2];
        }
    }

    part def LowGainAntenna {
        attribute gain : Real;
        attribute beamwidth : AngleUnit;
        port dataIn : DataInPort;
        port rfOut : RFOutPort;
        port rfIn : RFInPort;
        port powerIn : PowerInPort;

        action def transmitLowRate {
            in data : DataPacket;
            out rfSignal : RFSignal;
        }

        action def receiveEmergencyUplink {
            in rfSignal : RFSignal;
            out command : Command;
        }
    }

    part def CommsSubsystem {
        part hga : HighGainAntenna;
        part lga : LowGainAntenna;

        port powerIn : PowerInPort;
        port dataIn : DataInPort;
        port cmdOut : CmdOutPort;
        port tlmOut : TlmOutPort;

        attribute downlinkRate : DataRateUnit;
        attribute uplinkRate : DataRateUnit;
        attribute activeAntenna : String;
        attribute linkEstablished : Boolean;

        connection powerIn to hga.powerIn;
        connection powerIn to lga.powerIn;
        connection dataIn to hga.dataIn;
        connection dataIn to lga.dataIn;

        action def establishLink {
            in target : String;
            out linkStatus : String;
        }

        action def selectAntenna {
            in mode : String;
            out selectedAntenna : String;
        }

        action def receiveCommands {
            in rfSignal : RFSignal;
            out command : Command;
        }
    }

    part def ImagingSpectrometer {
        attribute spectralRangeMin : Real;
        attribute spectralRangeMax : Real;
        attribute spatialResolution : AngleUnit;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def captureSpectrum {
            in targetCoordinates : AngleUnit[2];
            out data : ScienceData;
        }
    }

    part def InfraredCamera {
        attribute wavelengthMin : Real;
        attribute wavelengthMax : Real;
        attribute detectorType : String;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def captureThermalImage {
            in targetCoordinates : AngleUnit[2];
            out data : ScienceData;
        }
    }

    part def Magnetometer {
        attribute sensitivity : Real;
        attribute dynamicRange : Real;
        attribute boomLength : DistanceUnit;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def measureMagneticField {
            out data : ScienceData;
        }
    }

    part def ParticleDetector {
        attribute energyRangeMin : Real;
        attribute energyRangeMax : Real;
        attribute particleTypes : String;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        action def detectParticles {
            out data : ScienceData;
        }
    }

    part def ScienceInstrumentSuite {
        part imagingSpectrometer : ImagingSpectrometer;
        part infraredCamera : InfraredCamera;
        part magnetometer : Magnetometer;
        part particleDetector : ParticleDetector;

        port powerIn : PowerInPort;
        port dataOut : DataOutPort;

        connection powerIn to imagingSpectrometer.powerIn;
        connection powerIn to infraredCamera.powerIn;
        connection powerIn to magnetometer.powerIn;
        connection powerIn to particleDetector.powerIn;
        connection imagingSpectrometer.dataOut to dataOut;
        connection infraredCamera.dataOut to dataOut;
        connection magnetometer.dataOut to dataOut;
        connection particleDetector.dataOut to dataOut;

        action def conductObservation {
            in observationPlan : String;
            out scienceData : ScienceData;
        }

        action def calibrateInstruments {
            out calibrationStatus : String;
        }
    }

    part def Radiator {
        attribute dissipationCapacity : PowerUnit;
        attribute operatingTempRange : TemperatureUnit[2];
        port powerIn : PowerInPort;

        action def radiateHeat {
            in heatLoad : ThermalFlux;
            out radiatedFlux : ThermalFlux;
        }
    }

    part def Heater {
        attribute powerRating : PowerUnit;
        attribute setPoint : TemperatureUnit;
        port powerIn : PowerInPort;

        action def applyHeat {
            in targetTemp : TemperatureUnit;
            out heatFlux : ThermalFlux;
        }

        action def regulateHeater {
            in currentTemp : TemperatureUnit;
            out heaterState : String;
        }
    }

    part def MultiLayerInsulation {
        attribute numLayers : Integer;
        attribute effectiveEmittance : Real;
        attribute areaCovered : AreaUnit;
    }

    part def ThermalControlSubsystem {
        part radiators : Radiator[4];
        part heaters : Heater[6];
        part mli : MultiLayerInsulation;

        port powerIn : PowerInPort;

        attribute operatingTempMin : TemperatureUnit;
        attribute operatingTempMax : TemperatureUnit;
        attribute currentTemp : TemperatureUnit;

        connection powerIn to radiators.powerIn;
        connection powerIn to heaters.powerIn;

        action def regulateTemperature {
            in currentTemp : TemperatureUnit;
            out heaterCommand : String;
            out radiatorCommand : String;
        }

        action def monitorThermalState {
            out thermalStatus : String;
        }
    }

    part def Spacecraft {
        attribute dryMass : MassUnit;
        attribute propellantMass : MassUnit;
        attribute totalMass : MassUnit;
        attribute designLife : TimeUnit;
        attribute missionTarget : String;
        attribute anomalyDetected : Boolean;
        attribute recoveryCommandReceived : Boolean;
        attribute orbitAchieved : Boolean;
        attribute altitude : DistanceUnit;
        attribute distanceToTarget : DistanceUnit;
        attribute inSafeMode : Boolean;
        attribute solarPointingAchieved : Boolean;

        part powerSubsystem : PowerSubsystem;
        part gncSubsystem : GNCSubsystem;
        part propulsionSubsystem : PropulsionSubsystem;
        part cdhSubsystem : CDHSubsystem;
        part commsSubsystem : CommsSubsystem;
        part scienceSuite : ScienceInstrumentSuite;
        part thermalControl : ThermalControlSubsystem;

        connection powerSubsystem.gncPowerOut to gncSubsystem.powerIn;
        connection powerSubsystem.cdhPowerOut to cdhSubsystem.powerIn;
        connection powerSubsystem.commsPowerOut to commsSubsystem.powerIn;
        connection powerSubsystem.sciencePowerOut to scienceSuite.powerIn;
        connection powerSubsystem.thermalPowerOut to thermalControl.powerIn;
        connection powerSubsystem.propulsionPowerOut to propulsionSubsystem.powerIn;

        connection gncSubsystem.thrustCmdOut to propulsionSubsystem.thrustCmdIn;
        connection gncSubsystem.attitudeOut to cdhSubsystem.dataIn;

        connection scienceSuite.dataOut to cdhSubsystem.dataIn;
        connection cdhSubsystem.dataOut to commsSubsystem.dataIn;
        connection commsSubsystem.cmdOut to cdhSubsystem.cmdIn;
        connection cdhSubsystem.tlmOut to commsSubsystem.dataIn;

        action orientSolarArraysToSun {
            in currentAttitude : AttitudeState;
            out commandedAttitude : AttitudeState;
        }

        action enterSafeMode {
            in anomaly : String;
            out safeModeAction : String;
        }

        action recoverFromSafeMode {
            in recoveryCommand : Command;
            out recoveryAction : String;
        }

        state missionStateMachine {
            state Launch {
                entry action initializeSystems;
            }
            state Cruise {
                entry action configureForCruise;
            }
            state PlanetaryApproach {
                entry action prepareForEncounter;
            }
            state OrbitalOperations {
                entry action beginScienceOperations;
            }
            state SafeMode {
                entry action orientSolarArraysToSun;
            }

            transition Launch to Cruise when altitude > 100000;
            transition Cruise to PlanetaryApproach when distanceToTarget < 1000000;
            transition PlanetaryApproach to OrbitalOperations when orbitAchieved == true;

            transition Launch to SafeMode when anomalyDetected == true;
            transition Cruise to SafeMode when anomalyDetected == true;
            transition PlanetaryApproach to SafeMode when anomalyDetected == true;
            transition OrbitalOperations to SafeMode when anomalyDetected == true;

            transition SafeMode to Cruise when recoveryCommandReceived == true and solarPointingAchieved == true;
        }

        action def initializeSystems {
            out status : String;
        }

        action def configureForCruise {
            out status : String;
        }

        action def prepareForEncounter {
            out status : String;
        }

        action def beginScienceOperations {
            out status : String;
        }
    }

    requirement def PowerGenerationRequirement {
        subject spacecraft : Spacecraft;
        attribute requiredBusPower : PowerUnit = 600;
        require spacecraft.powerSubsystem.pdu.totalBusPower >= requiredBusPower;
    }

    requirement def BatteryCapacityRequirement {
        subject spacecraft : Spacecraft;
        attribute minBatteryCapacity : EnergyUnit = 2000;
        require spacecraft.powerSubsystem.battery.capacity >= minBatteryCapacity;
    }

    requirement def SolarArrayPowerRequirement {
        subject spacecraft : Spacecraft;
        attribute minSolarPowerPerArray : PowerUnit = 300;
        require spacecraft.powerSubsystem.solarArrays.maxPower >= minSolarPowerPerArray;
    }

    requirement def CommunicationLinkRequirement {
        subject spacecraft : Spacecraft;
        attribute minDownlinkRate : DataRateUnit = 100;
        require spacecraft.commsSubsystem.downlinkRate >= minDownlinkRate;
    }

    requirement def BackupCommsRequirement {
        subject spacecraft : Spacecraft;
        require spacecraft.commsSubsystem.lga.gain > 0;
    }

    requirement def DataStorageRequirement {
        subject spacecraft : Spacecraft;
        attribute minStorage : DataVolumeUnit = 500;
        require spacecraft.cdhSubsystem.recorder.capacity >= minStorage;
    }

    requirement def ThermalControlRequirement {
        subject spacecraft : Spacecraft;
        attribute minOpTemp : TemperatureUnit = -20;
        attribute maxOpTemp : TemperatureUnit = 40;
        require spacecraft.thermalControl.operatingTempMin >= minOpTemp;
        require spacecraft.thermalControl.operatingTempMax <= maxOpTemp;
    }

    requirement def MainEngineThrustRequirement {
        subject spacecraft : Spacecraft;
        attribute minThrust : ForceUnit = 500;
        require spacecraft.propulsionSubsystem.mainEngine.thrust >= minThrust;
    }

    requirement def RCSAttitudeControlRequirement {
        subject spacecraft : Spacecraft;
        attribute minRCSThrust : ForceUnit = 10;
        require spacecraft.propulsionSubsystem.rcsThrusters.thrust >= minRCSThrust;
    }

    requirement def GNCAccuracyRequirement {
        subject spacecraft : Spacecraft;
        attribute maxAttitudeError : AngleUnit = 0.1;
        require spacecraft.gncSubsystem.starTracker.accuracy <= maxAttitudeError;
    }

    requirement def SafeModeRequirement {
        subject spacecraft : Spacecraft;
        doc /* Upon detecting a serious anomaly, the spacecraft shall enter Safe Mode, orient solar arrays toward the sun, minimize non-essential activity, and await recovery instructions from ground controllers. */
        require spacecraft.anomalyDetected == true implies spacecraft.inSafeMode == true;
    }

    requirement def MissionDurationRequirement {
        subject spacecraft : Spacecraft;
        attribute minMissionLife : TimeUnit = 315360000;
        require spacecraft.designLife >= minMissionLife;
    }

    requirement def ScienceInstrumentRequirement {
        subject spacecraft : Spacecraft;
        require spacecraft.scienceSuite.imagingSpectrometer.spectralRangeMax > 1000;
        require spacecraft.scienceSuite.infraredCamera.wavelengthMax > 5000;
        require spacecraft.scienceSuite.magnetometer.sensitivity < 0.01;
        require spacecraft.scienceSuite.particleDetector.energyRangeMax > 1000;
    }

    requirement def PropellantMassRequirement {
        subject spacecraft : Spacecraft;
        attribute minPropellant : MassUnit = 500;
        require spacecraft.propellantMass >= minPropellant;
    }

    requirement def ThermalRadiatorRequirement {
        subject spacecraft : Spacecraft;
        attribute minDissipation : PowerUnit = 200;
        require spacecraft.thermalControl.radiators.dissipationCapacity >= minDissipation;
    }

    requirement def ProcessorPerformanceRequirement {
        subject spacecraft : Spacecraft;
        attribute minClockSpeed : FrequencyUnit = 100;
        require spacecraft.cdhSubsystem.processor.clockSpeed >= minClockSpeed;
    }
}

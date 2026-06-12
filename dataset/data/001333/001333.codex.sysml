package AerobotMissionSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage :> Real {
        doc /* Unitless ratio expressed from 0 to 100. */
    }

    attribute def DataRate :> Real {
        doc /* Megabits per second. */
    }

    attribute def EnergyCapacity :> Real {
        doc /* Watt hours. */
    }

    attribute def Pressure :> Real {
        doc /* Pascals. */
    }

    attribute def Temperature :> Real {
        doc /* Degrees Celsius. */
    }

    attribute def Altitude :> Real {
        doc /* Meters above selected datum. */
    }

    attribute def Velocity :> Real {
        doc /* Meters per second. */
    }

    attribute def Mass :> Real {
        doc /* Kilograms. */
    }

    attribute def Volume :> Real {
        doc /* Cubic meters. */
    }

    attribute def Power :> Real {
        doc /* Watts. */
    }

    attribute def Duration :> Real {
        doc /* Seconds. */
    }

    item def AtmosphericSample {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute humidity : Percentage;
        attribute windSpeed : Velocity;
        attribute altitude : Altitude;
        attribute timestamp : Duration;
    }

    item def ScienceDataPacket {
        attribute packetSize : DataRate;
        attribute priority : Integer;
        attribute validChecksum : Boolean;
        attribute collectionAltitude : Altitude;
    }

    item def CommandPacket {
        attribute commandId : Integer;
        attribute targetAltitude : Altitude;
        attribute requestedMode : AerobotMode;
        attribute executeAfter : Duration;
    }

    item def PowerFlow {
        attribute suppliedPower : Power;
        attribute busVoltage : Real;
    }

    item def BuoyancyGas {
        attribute gasMass : Mass;
        attribute gasTemperature : Temperature;
        attribute envelopePressure : Pressure;
    }

    enum def AerobotMode {
        enum idle;
        enum launch;
        enum ascend;
        enum stationKeep;
        enum survey;
        enum descend;
        enum communicate;
        enum safe;
        enum terminate;
    }

    enum def HealthStatus {
        enum nominal;
        enum degraded;
        enum critical;
    }

    port def PowerPort {
        out item power : PowerFlow;
    }

    port def LoadPowerPort {
        in item power : PowerFlow;
    }

    port def CommandPort {
        in item command : CommandPacket;
    }

    port def TelemetryPort {
        out item telemetry : ScienceDataPacket;
    }

    port def AtmospherePort {
        in item atmosphere : AtmosphericSample;
    }

    port def GasPort {
        inout item gas : BuoyancyGas;
    }

    part def Aerobot {
        attribute totalMass : Mass = 62.0;
        attribute maxOperationalAltitude : Altitude = 55000.0;
        attribute minOperationalAltitude : Altitude = 20000.0;
        attribute commandedAltitude : Altitude = 35000.0;
        attribute currentAltitude : Altitude;
        attribute verticalVelocity : Velocity;
        attribute storedEnergy : EnergyCapacity;
        attribute mode : AerobotMode;
        attribute health : HealthStatus;

        port commandReceiver : CommandPort;
        port scienceTelemetry : TelemetryPort;
        port atmosphericInterface : AtmospherePort;

        part flightEnvelope : BuoyantEnvelope {
            attribute envelopeVolume = 95.0;
            attribute burstPressure = 8500.0;
        }

        part buoyancyController : BuoyancyControlSystem;
        part avionics : FlightAvionics;
        part sciencePayload : AtmosphericSciencePayload;
        part powerSystem : ElectricalPowerSystem;
        part communicationSystem : CommunicationSystem;
        part thermalSystem : ThermalControlSystem;
        part recoverySystem : RecoveryAndTerminationSystem;

        connect powerSystem.primaryPower to avionics.powerInput;
        connect powerSystem.primaryPower to buoyancyController.powerInput;
        connect powerSystem.primaryPower to sciencePayload.powerInput;
        connect powerSystem.primaryPower to communicationSystem.powerInput;
        connect powerSystem.primaryPower to thermalSystem.powerInput;
        connect flightEnvelope.gasInterface to buoyancyController.gasInterface;
        connect atmosphericInterface to sciencePayload.atmosphereInput;
        connect commandReceiver to avionics.commandInput;
        connect sciencePayload.scienceOutput to communicationSystem.dataInput;
        connect communicationSystem.telemetryOutput to scienceTelemetry;

        perform action primaryFunction;
        exhibit state aerobotOperatingStates;
    }

    part def BuoyantEnvelope {
        attribute envelopeVolume : Volume;
        attribute burstPressure : Pressure;
        attribute gasTemperature : Temperature;
        attribute internalPressure : Pressure;
        attribute liftMargin : Percentage;

        port gasInterface : GasPort;
    }

    part def BuoyancyControlSystem {
        attribute ballastMass : Mass = 8.0;
        attribute ventRate : Real = 0.035;
        attribute ballastReleaseRate : Real = 0.025;
        attribute targetAltitudeError : Altitude;
        attribute controllerHealth : HealthStatus;

        port powerInput : LoadPowerPort;
        port gasInterface : GasPort;

        action adjustAltitude {
            in currentAltitude : Altitude;
            in targetAltitude : Altitude;
            out ventCommand : Boolean;
            out ballastCommand : Boolean;

            first start;
            then computeAltitudeError;
            then decideBuoyancyAction;
            then issueActuatorCommand;
        }
    }

    part def FlightAvionics {
        attribute processorLoad : Percentage;
        attribute navigationConfidence : Percentage;
        attribute estimatedAltitude : Altitude;
        attribute estimatedVerticalVelocity : Velocity;
        attribute avionicsHealth : HealthStatus;

        port powerInput : LoadPowerPort;
        port commandInput : CommandPort;

        action navigateAndControl {
            in atmosphere : AtmosphericSample;
            in command : CommandPacket;
            out selectedMode : AerobotMode;
            out altitudeSetpoint : Altitude;

            first validateCommand;
            then estimateFlightState;
            then selectOperatingMode;
            then publishGuidance;
        }
    }

    part def AtmosphericSciencePayload {
        attribute samplePeriod : Duration = 5.0;
        attribute instrumentTemperature : Temperature;
        attribute payloadHealth : HealthStatus;

        port powerInput : LoadPowerPort;
        port atmosphereInput : AtmospherePort;
        port scienceOutput : TelemetryPort;

        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part windEstimator : WindEstimator;

        action collectAtmosphericProfile {
            in sample : AtmosphericSample;
            out packet : ScienceDataPacket;

            first acquirePressure;
            then acquireTemperature;
            then acquireHumidity;
            then estimateWind;
            then validateMeasurement;
            then packageScienceData;
        }
    }

    part def PressureSensor {
        attribute rangeMin : Pressure = 100.0;
        attribute rangeMax : Pressure = 110000.0;
        attribute accuracy : Percentage = 0.5;
    }

    part def TemperatureSensor {
        attribute rangeMin : Temperature = -95.0;
        attribute rangeMax : Temperature = 55.0;
        attribute accuracy : Temperature = 0.3;
    }

    part def HumiditySensor {
        attribute rangeMin : Percentage = 0.0;
        attribute rangeMax : Percentage = 100.0;
        attribute accuracy : Percentage = 2.0;
    }

    part def WindEstimator {
        attribute windSpeedAccuracy : Velocity = 0.8;
        attribute updatePeriod : Duration = 10.0;
    }

    part def ElectricalPowerSystem {
        attribute batteryCapacity : EnergyCapacity = 1800.0;
        attribute solarArrayPeakPower : Power = 420.0;
        attribute essentialLoadPower : Power = 95.0;
        attribute payloadLoadPower : Power = 140.0;
        attribute stateOfCharge : Percentage;
        attribute powerHealth : HealthStatus;

        port primaryPower : PowerPort;

        part battery : Battery;
        part solarArray : SolarArray;
        part powerController : PowerController;

        connect solarArray.generatedPower to powerController.sourcePower;
        connect battery.storedPower to powerController.storagePower;
        connect powerController.regulatedPower to primaryPower;
    }

    part def Battery {
        attribute capacity : EnergyCapacity = 1800.0;
        attribute stateOfCharge : Percentage;
        attribute minimumSafeCharge : Percentage = 25.0;

        port storedPower : PowerPort;
    }

    part def SolarArray {
        attribute peakPower : Power = 420.0;
        attribute degradationMargin : Percentage = 15.0;

        port generatedPower : PowerPort;
    }

    part def PowerController {
        attribute busVoltage : Real = 28.0;
        attribute conversionEfficiency : Percentage = 92.0;

        port sourcePower : LoadPowerPort;
        port storagePower : LoadPowerPort;
        port regulatedPower : PowerPort;
    }

    part def CommunicationSystem {
        attribute downlinkRate : DataRate = 2.0;
        attribute uplinkRate : DataRate = 0.064;
        attribute linkMargin : Real = 6.0;
        attribute communicationHealth : HealthStatus;

        port powerInput : LoadPowerPort;
        port dataInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        action transmitTelemetry {
            in packet : ScienceDataPacket;
            out transmitted : Boolean;

            first queuePacket;
            then encodePacket;
            then pointAntenna;
            then transmitPacket;
            then confirmDelivery;
        }
    }

    part def ThermalControlSystem {
        attribute avionicsTemperature : Temperature;
        attribute batteryTemperature : Temperature;
        attribute heaterPower : Power = 60.0;
        attribute thermalHealth : HealthStatus;

        port powerInput : LoadPowerPort;

        action regulateTemperature {
            in measuredTemperature : Temperature;
            out heaterEnabled : Boolean;

            first compareToThermalLimits;
            then commandHeater;
            then verifyThermalResponse;
        }
    }

    part def RecoveryAndTerminationSystem {
        attribute parachuteMass : Mass = 4.5;
        attribute terminationArmed : Boolean = false;
        attribute recoveryHealth : HealthStatus;

        port powerInput : LoadPowerPort;

        action terminateFlight {
            first safePayload;
            then ventEnvelope;
            then deployRecoveryDevice;
            then transmitFinalBeacon;
        }
    }

    action def SurveyAtmosphere {
        in targetAltitude : Altitude;
        out profilePacket : ScienceDataPacket;

        first stabilizeAtAltitude;
        then sampleAtmosphere;
        then correlateNavigationState;
        then storeScienceRecord;
        then downlinkScienceRecord;
    }

    action def MaintainBuoyantFlight {
        in commandedAltitude : Altitude;
        in measuredAltitude : Altitude;
        out mode : AerobotMode;

        first computeAltitudeError;
        then adjustEnvelopeGasOrBallast;
        then verifyVerticalRate;
        then continueStationKeeping;
    }

    action def AerobotPrimaryFunction {
        in missionCommand : CommandPacket;
        out transmittedScience : ScienceDataPacket;

        objective {
            doc /* The Aerobot's primary high-level function is to sustain controlled buoyant flight through an atmosphere while collecting and transmitting vertical atmospheric profile data. */
        }

        first receiveMissionCommand;
        then establishBuoyantFlight;
        then maintainCommandedAltitudeBand;
        then collectAtmosphericMeasurements;
        then transmitScienceTelemetry;
    }

    state def AerobotOperatingStates {
        entry action initializeVehicle;

        state idle;
        state launch;
        state ascend;
        state stationKeep;
        state survey;
        state descend;
        state communicate;
        state safe;
        state terminate;

        initial then idle;

        transition idle_to_launch
            first idle
            accept CommandPacket
            if command.requestedMode == AerobotMode::launch
            then launch;

        transition launch_to_ascend
            first launch
            if health == HealthStatus::nominal
            then ascend;

        transition ascend_to_stationKeep
            first ascend
            if currentAltitude >= commandedAltitude
            then stationKeep;

        transition stationKeep_to_survey
            first stationKeep
            if verticalVelocity < 0.2
            then survey;

        transition survey_to_communicate
            first survey
            after 300.0
            then communicate;

        transition communicate_to_stationKeep
            first communicate
            if storedEnergy > 450.0
            then stationKeep;

        transition stationKeep_to_descend
            first stationKeep
            accept CommandPacket
            if command.requestedMode == AerobotMode::descend
            then descend;

        transition descend_to_stationKeep
            first descend
            if currentAltitude <= commandedAltitude
            then stationKeep;

        transition any_to_safe
            first idle
            if health == HealthStatus::critical
            then safe;

        transition safe_to_terminate
            first safe
            if storedEnergy < 150.0
            then terminate;
    }

    requirement def ControlledBuoyantFlightRequirement {
        doc /* The Aerobot shall maintain controlled buoyant flight within the commanded altitude band during nominal atmospheric survey operations. */
        attribute commandedAltitude : Altitude;
        attribute allowableAltitudeError : Altitude = 250.0;

        require constraint {
            abs(currentAltitude - commandedAltitude) <= allowableAltitudeError
        }
    }

    requirement def AtmosphericSurveyRequirement {
        doc /* The Aerobot shall collect pressure, temperature, humidity, wind speed, and altitude data while operating in survey mode. */
        attribute maximumSamplePeriod : Duration = 10.0;

        require constraint {
            sciencePayload.samplePeriod <= maximumSamplePeriod
        }
    }

    requirement def TelemetryRequirement {
        doc /* The Aerobot shall transmit validated science data packets to the mission receiver during each communication opportunity. */
        attribute minimumDownlinkRate : DataRate = 0.5;

        require constraint {
            communicationSystem.downlinkRate >= minimumDownlinkRate
        }
    }

    requirement def PowerEnduranceRequirement {
        doc /* The Aerobot shall preserve enough stored energy to continue essential flight control and communication after a survey interval. */
        attribute minimumStateOfCharge : Percentage = 25.0;

        require constraint {
            powerSystem.stateOfCharge >= minimumStateOfCharge
        }
    }

    requirement def ThermalSurvivalRequirement {
        doc /* The Aerobot shall keep avionics and battery temperatures within operational limits throughout flight. */
        attribute minimumTemperature : Temperature = -40.0;
        attribute maximumTemperature : Temperature = 60.0;

        require constraint {
            thermalSystem.avionicsTemperature >= minimumTemperature and
            thermalSystem.avionicsTemperature <= maximumTemperature and
            thermalSystem.batteryTemperature >= minimumTemperature and
            thermalSystem.batteryTemperature <= maximumTemperature
        }
    }

    requirement def SafeTerminationRequirement {
        doc /* The Aerobot shall provide a controlled flight termination and recovery sequence if critical health or power conditions occur. */
        attribute criticalEnergyThreshold : EnergyCapacity = 150.0;

        require constraint {
            recoverySystem.terminationArmed == true implies storedEnergy <= criticalEnergyThreshold
        }
    }

    part aerobotSystem : Aerobot {
        attribute totalMass = 62.0;
        attribute commandedAltitude = 35000.0;
        attribute currentAltitude = 0.0;
        attribute verticalVelocity = 0.0;
        attribute storedEnergy = 1800.0;
        attribute mode = AerobotMode::idle;
        attribute health = HealthStatus::nominal;

        perform action primaryFunction : AerobotPrimaryFunction;
    }

    satisfy ControlledBuoyantFlightRequirement by aerobotSystem;
    satisfy AtmosphericSurveyRequirement by aerobotSystem.sciencePayload;
    satisfy TelemetryRequirement by aerobotSystem.communicationSystem;
    satisfy PowerEnduranceRequirement by aerobotSystem.powerSystem;
    satisfy ThermalSurvivalRequirement by aerobotSystem.thermalSystem;
    satisfy SafeTerminationRequirement by aerobotSystem.recoverySystem;
}
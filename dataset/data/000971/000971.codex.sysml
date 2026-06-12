package AltimeterSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::Pa;
    }

    attribute def Altitude :> ISQ::length {
        unit = SI::m;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::K;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::V;
    }

    attribute def TimeDuration :> ISQ::time {
        unit = SI::s;
    }

    attribute def Frequency :> ISQ::frequency {
        unit = SI::Hz;
    }

    item def StaticAirSample {
        attribute staticPressure : Pressure;
        attribute ambientTemperature : Temperature;
    }

    item def PressureMeasurement {
        attribute measuredPressure : Pressure;
        attribute measurementTemperature : Temperature;
        attribute sampleTime : TimeDuration;
        attribute sensorHealth : Boolean;
    }

    item def AltitudeEstimate {
        attribute pressureAltitude : Altitude;
        attribute correctedAltitude : Altitude;
        attribute verticalTrend : Altitude;
        attribute valid : Boolean;
    }

    item def PilotSetting {
        attribute barometricReferencePressure : Pressure;
        attribute unitsInFeet : Boolean;
    }

    item def DisplayCommand {
        attribute displayedAltitude : Altitude;
        attribute warningActive : Boolean;
        attribute dataValid : Boolean;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute availableCurrent : ISQ::electricCurrent;
        attribute powerGood : Boolean;
    }

    port def StaticPressurePort {
        in item air : StaticAirSample;
    }

    port def SensorDataPort {
        out item pressureData : PressureMeasurement;
    }

    port def SettingPort {
        in item setting : PilotSetting;
    }

    port def AltitudeDataPort {
        out item altitudeData : AltitudeEstimate;
    }

    port def DisplayPort {
        in item displayCommand : DisplayCommand;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    action def SenseStaticPressure {
        in item air : StaticAirSample;
        out item pressureData : PressureMeasurement;

        attribute sensorResolution : Pressure = 1.0 [SI::Pa];
        attribute maximumSensorError : Pressure = 15.0 [SI::Pa];
    }

    action def FilterPressureSignal {
        in item rawPressure : PressureMeasurement;
        out item filteredPressure : PressureMeasurement;

        attribute filterCutoffFrequency : Frequency = 5.0 [SI::Hz];
        attribute filterSettlingTime : TimeDuration = 0.25 [SI::s];
    }

    action def ComputePressureAltitude {
        in item filteredPressure : PressureMeasurement;
        in item setting : PilotSetting;
        out item altitude : AltitudeEstimate;

        attribute seaLevelStandardPressure : Pressure = 101325.0 [SI::Pa];
        attribute validPressureMinimum : Pressure = 22632.0 [SI::Pa];
        attribute validPressureMaximum : Pressure = 108000.0 [SI::Pa];
    }

    action def GenerateDisplayCommand {
        in item altitude : AltitudeEstimate;
        out item command : DisplayCommand;

        attribute updatePeriod : TimeDuration = 0.1 [SI::s];
    }

    state def AltimeterOperationalState {
        entry action initialize;

        state Off;
        state SelfTest;
        state Measuring;
        state Degraded;
        state Failed;

        transition first Off;

        transition powerApplied
            first Off
            then SelfTest;

        transition selfTestPassed
            first SelfTest
            then Measuring;

        transition sensorWarning
            first Measuring
            then Degraded;

        transition sensorRecovered
            first Degraded
            then Measuring;

        transition unrecoverableFault
            first SelfTest
            then Failed;

        transition criticalFault
            first Measuring
            then Failed;

        transition powerRemovedFromMeasuring
            first Measuring
            then Off;

        transition powerRemovedFromFailed
            first Failed
            then Off;
    }

    part def StaticPressureProbe {
        port staticPort : StaticPressurePort;

        attribute icingDetected : Boolean;
        attribute blockageDetected : Boolean;
        attribute pressureLag : TimeDuration = 0.05 [SI::s];
    }

    part def PressureSensor {
        port airInput : StaticPressurePort;
        port sensorOutput : SensorDataPort;
        port powerInput : PowerInputPort;

        attribute operatingVoltageMinimum : Voltage = 4.75 [SI::V];
        attribute operatingVoltageMaximum : Voltage = 5.25 [SI::V];
        attribute pressureRangeMinimum : Pressure = 15000.0 [SI::Pa];
        attribute pressureRangeMaximum : Pressure = 110000.0 [SI::Pa];
        attribute accuracy : Pressure = 15.0 [SI::Pa];

        perform action sense : SenseStaticPressure;
    }

    part def AltitudeProcessor {
        port sensorInput : SensorDataPort;
        port settingInput : SettingPort;
        port altitudeOutput : AltitudeDataPort;
        port powerInput : PowerInputPort;

        attribute calculationPeriod : TimeDuration = 0.05 [SI::s];
        attribute maximumComputationLatency : TimeDuration = 0.02 [SI::s];
        attribute lastKnownValidAltitude : Altitude;

        perform action filter : FilterPressureSignal;
        perform action compute : ComputePressureAltitude;
    }

    part def BarometricSettingControl {
        port settingOutput : SettingPort;

        attribute selectedReferencePressure : Pressure = 101325.0 [SI::Pa];
        attribute settingIncrement : Pressure = 100.0 [SI::Pa];
        attribute pilotSelectable : Boolean = true;
    }

    part def AltitudeDisplay {
        port commandInput : DisplayPort;
        port powerInput : PowerInputPort;

        attribute refreshRate : Frequency = 10.0 [SI::Hz];
        attribute minimumDisplayedAltitude : Altitude = -500.0 [SI::m];
        attribute maximumDisplayedAltitude : Altitude = 12000.0 [SI::m];
        attribute displayResolution : Altitude = 1.0 [SI::m];

        perform action render : GenerateDisplayCommand;
    }

    part def PowerConditioner {
        port powerInput : PowerInputPort;
        port regulatedSensorPower : PowerInputPort;
        port regulatedProcessorPower : PowerInputPort;
        port regulatedDisplayPower : PowerInputPort;

        attribute nominalInputVoltage : Voltage = 28.0 [SI::V];
        attribute regulatedOutputVoltage : Voltage = 5.0 [SI::V];
        attribute undervoltageThreshold : Voltage = 18.0 [SI::V];
    }

    part def Altimeter {
        port staticPressureInput : StaticPressurePort;
        port pilotSettingInput : SettingPort;
        port aircraftPowerInput : PowerInputPort;
        port altitudeOutput : AltitudeDataPort;

        part probe : StaticPressureProbe;
        part pressureSensor : PressureSensor;
        part processor : AltitudeProcessor;
        part settingControl : BarometricSettingControl;
        part display : AltitudeDisplay;
        part powerConditioner : PowerConditioner;

        attribute operatingState : AltimeterOperationalState;
        attribute primaryFunction : String = "Measure ambient static pressure and convert it into a valid pressure-corrected altitude indication for flight crew awareness.";
        attribute altitudeUpdateRate : Frequency = 10.0 [SI::Hz];
        attribute requiredAccuracyBelow3000m : Altitude = 30.0 [SI::m];
        attribute startupTimeLimit : TimeDuration = 5.0 [SI::s];

        connect staticPressureInput to probe.staticPort;
        connect probe.staticPort to pressureSensor.airInput;
        connect pressureSensor.sensorOutput to processor.sensorInput;
        connect pilotSettingInput to processor.settingInput;
        connect settingControl.settingOutput to processor.settingInput;
        connect processor.altitudeOutput to altitudeOutput;
        connect processor.altitudeOutput to display.commandInput;
        connect aircraftPowerInput to powerConditioner.powerInput;
        connect powerConditioner.regulatedSensorPower to pressureSensor.powerInput;
        connect powerConditioner.regulatedProcessorPower to processor.powerInput;
        connect powerConditioner.regulatedDisplayPower to display.powerInput;
    }

    requirement def ProvideAltitudeIndication {
        doc /* The altimeter shall provide the flight crew with a continuously updated altitude indication derived from sensed ambient static pressure and the selected barometric reference setting. */
        subject altimeter : Altimeter;

        require constraint {
            altimeter.altitudeUpdateRate >= 10.0 [SI::Hz]
        }
    }

    requirement def PressureMeasurementAccuracy {
        doc /* The pressure sensing subsystem shall measure static pressure with sufficient accuracy to support high-level altitude awareness. */
        subject sensor : PressureSensor;

        require constraint {
            sensor.accuracy <= 15.0 [SI::Pa]
        }
    }

    requirement def AltitudeAccuracyLowAltitude {
        doc /* The altimeter shall maintain altitude indication error within 30 meters when operating below 3000 meters under valid pressure input conditions. */
        subject altimeter : Altimeter;

        require constraint {
            altimeter.requiredAccuracyBelow3000m <= 30.0 [SI::m]
        }
    }

    requirement def StartupAvailability {
        doc /* The altimeter shall complete self-test and begin providing valid altitude data within five seconds after valid aircraft power is applied. */
        subject altimeter : Altimeter;

        require constraint {
            altimeter.startupTimeLimit <= 5.0 [SI::s]
        }
    }

    requirement def DetectInvalidPressureInput {
        doc /* The altimeter shall identify pressure sensor data as invalid when measured pressure is outside the certified operating pressure range. */
        subject processor : AltitudeProcessor;

        require constraint {
            processor.maximumComputationLatency <= 0.02 [SI::s]
        }
    }

    requirement def ProvideDegradedMode {
        doc /* The altimeter shall enter a degraded operating state when pressure data is suspect but not fully failed, retaining the last known valid altitude and warning the display. */
        subject altimeter : Altimeter;
    }

    satisfy ProvideAltitudeIndication by Altimeter;
    satisfy PressureMeasurementAccuracy by PressureSensor;
    satisfy AltitudeAccuracyLowAltitude by Altimeter;
    satisfy StartupAvailability by Altimeter;
    satisfy DetectInvalidPressureInput by AltitudeProcessor;
    satisfy ProvideDegradedMode by Altimeter;

    part altimeterSystem : Altimeter {
        attribute altitudeUpdateRate = 10.0 [SI::Hz];
        attribute startupTimeLimit = 5.0 [SI::s];
        attribute requiredAccuracyBelow3000m = 30.0 [SI::m];
    }
}
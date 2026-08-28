package SmartGasMeter {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // =========================================================================
    // Value Types with Units
    // =========================================================================
    value type VolumeFlowRateValue :> Real { 
        doc / "Volumetric flow rate of natural gas";
        unit : VolumeFlowRateUnit[1] = cubic_metre_per_second; 
    }
    value type VolumeValue :> Real { 
        doc / "Accumulated volume of natural gas";
        unit : VolumeUnit[1] = cubic_metre; 
    }
    value type PressureValue :> Real { 
        doc / "Absolute gas pressure";
        unit : PressureUnit[1] = pascal; 
    }
    value type TemperatureValue :> Real { 
        doc / "Absolute gas temperature";
        unit : TemperatureUnit[1] = kelvin; 
    }
    value type EnergyValue :> Real { 
        doc / "Energy content of consumed gas (in kWh)";
        unit : EnergyUnit[1] = kilowatt_hour; 
    }
    value type HeatingValue :> Real { 
        doc / "Calorific / heating value of gas per standard volume";
        unit : SpecificEnergyUnit[1] = joule_per_cubic_metre; 
    }
    value type CompressibilityFactorValue :> Real {
        doc / "Dimensionless gas compressibility factor";
    }
    value type AlarmCodeValue :> Integer {
        doc / "Enumerated alarm identifier";
    }
    value type TimestampValue :> String {
        doc / "ISO-8601 timestamp string";
    }
    value type StatusValue :> String {
        doc / "Operational state label";
    }

    // =========================================================================
    // Item Definitions
    // =========================================================================
    item def NaturalGas {
        doc / "Natural gas as a fluid medium flowing through the meter";
    }

    item def GasSample {
        doc / "Instantaneous snapshot of gas conditions at the meter";
        :>> pressure : PressureValue;
        :>> temperature : TemperatureValue;
        :>> flowRate : VolumeFlowRateValue;
    }

    item def MeterReading {
        doc / "Recorded meter reading sent to storage and remote systems";
        :>> timestamp : TimestampValue;
        :>> volume : VolumeValue;
        :>> standardVolume : VolumeValue;
        :>> energy : EnergyValue;
        :>> flowRate : VolumeFlowRateValue;
        :>> pressure : PressureValue;
        :>> temperature : TemperatureValue;
        :>> status : StatusValue;
    }

    item def AlarmEvent {
        doc / "Diagnostic alarm notification";
        :>> code : AlarmCodeValue;
        :>> timestamp : TimestampValue;
        :>> description : String;
        :>> severity : String;
    }

    item def ConfigurationUpdate {
        doc / "Configuration parameters received from the utility company";
        :>> alarmPressureHigh : PressureValue;
        :>> alarmPressureLow : PressureValue;
        :>> alarmFlowHigh : VolumeFlowRateValue;
        :>> alarmFlowLow : VolumeFlowRateValue;
        :>> heatingValue : HeatingValue;
        :>> standardTemperature : TemperatureValue;
        :>> standardPressure : PressureValue;
    }

    // =========================================================================
    // Port Definitions
    // =========================================================================
    port def GasFlowPort {
        doc / "Port carrying natural gas flow";
        out item flow : NaturalGas;
        out item sample : GasSample;
    }

    port def PressureSignalPort {
        doc / "Pressure transducer signal port";
        out item pressure : PressureValue;
    }

    port def TemperatureSignalPort {
        doc / "Temperature sensor signal port";
        out item temperature : TemperatureValue;
    }

    port def FlowSignalPort {
        doc / "Flow measurement signal port";
        out item flowRate : VolumeFlowRateValue;
    }

    port def SensorDataPort {
        doc / "Aggregated sensor data port to the computation module";
        in item pressure : PressureValue;
        in item temperature : TemperatureValue;
        in item flowRate : VolumeFlowRateValue;
    }

    port def DisplayDataPort {
        doc / "Computed values and status sent to the display";
        in item flowRate : VolumeFlowRateValue;
        in item totalVolume : VolumeValue;
        in item totalEnergy : EnergyValue;
        in item status : StatusValue;
        in item alarm : AlarmEvent;
    }

    port def StoragePort {
        doc / "Storage logging port";
        in item reading : MeterReading;
    }

    port def CommunicationTxPort {
        doc / "Outbound communication to utility backend";
        out item reading : MeterReading;
        out item alarm : AlarmEvent;
    }

    port def CommunicationRxPort {
        doc / "Inbound configuration from utility backend";
        in item config : ConfigurationUpdate;
    }

    port def AlarmPort {
        doc / "Alarm event broadcast port";
        out item alarm : AlarmEvent;
    }

    port def ControlSignalPort {
        doc / "Control/enable signal between modules";
        in item enable : Boolean;
        in item mode : StatusValue;
    }

    // =========================================================================
    // Subsystem Definitions
    // =========================================================================
    part def FlowMeasurementUnit {
        doc / "Measures the volumetric flow rate of natural gas";
        port gasIn : GasFlowPort;
        port gasOut : GasFlowPort;
        port flowSignal : FlowSignalPort;
        attribute resolution : VolumeFlowRateValue = 0.001 cubic_metre_per_second;
        attribute maxFlowRate : VolumeFlowRateValue = 0.5 cubic_metre_per_second;
        attribute currentFlowRate : VolumeFlowRateValue;
        attribute flowDetectedThreshold : VolumeFlowRateValue = 0.001 cubic_metre_per_second;

        action measureFlow {
            in gasFlow : NaturalGas;
            out measuredRate : VolumeFlowRateValue;
        }

        perform measureFlow over gasIn.flow;

        calculation updateFlowRate {
            doc / "Sample the gas flow and emit the latest flow rate";
            in flowRate : VolumeFlowRateValue;
            return result : VolumeFlowRateValue = flowRate;
        }
    }

    part def PressureTransducer {
        doc / "Measures the absolute pressure of the gas in the pipe";
        port gasIn : GasFlowPort;
        port pressureSignal : PressureSignalPort;
        attribute rangeMin : PressureValue = 50 kilopascal;
        attribute rangeMax : PressureValue = 500 kilopascal;
        attribute currentPressure : PressureValue;

        action measurePressure {
            in gasSample : GasSample;
            out measuredPressure : PressureValue;
        }

        perform measurePressure over gasIn.sample;
    }

    part def TemperatureSensor {
        doc / "Measures the absolute temperature of the gas in the pipe";
        port gasIn : GasFlowPort;
        port temperatureSignal : TemperatureSignalPort;
        attribute rangeMin : TemperatureValue = 233.15 kelvin;
        attribute rangeMax : TemperatureValue = 353.15 kelvin;
        attribute currentTemperature : TemperatureValue;

        action measureTemperature {
            in gasSample : GasSample;
            out measuredTemperature : TemperatureValue;
        }

        perform measureTemperature over gasIn.sample;
    }

    part def ComputationModule {
        doc / "Central computation: PT correction, accumulation, and energy calculation";
        port sensorIn : SensorDataPort;
        port displayOut : DisplayDataPort;
        port storageOut : StoragePort;
        port commOut : CommunicationTxPort;
        port controlIn : ControlSignalPort;

        attribute standardPressure : PressureValue := 101325 pascal;
        attribute standardTemperature : TemperatureValue := 288.15 kelvin;
        attribute heatingValue : HeatingValue := 39500000 joule_per_cubic_metre;
        attribute compressibilityFactor : CompressibilityFactorValue := 0.998;
        attribute standardCompressibilityFactor : CompressibilityFactorValue := 0.999;

        attribute accumulatedVolume : VolumeValue := 0 cubic_metre;
        attribute accumulatedStandardVolume : VolumeValue := 0 cubic_metre;
        attribute accumulatedEnergy : EnergyValue := 0 kilowatt_hour;
        attribute currentFlowRate : VolumeFlowRateValue;
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentStatus : StatusValue := "standby";
        attribute lastAlarm : AlarmEvent;

        calculation computeStandardVolume {
            doc / "Convert measured volume to standard volume via pressure-temperature correction";
            in measuredVolume : VolumeValue;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in z : CompressibilityFactorValue;
            in standardP : PressureValue;
            in standardT : TemperatureValue;
            in standardZ : CompressibilityFactorValue;
            return standardVolume : VolumeValue =
                measuredVolume * (standardP / pressure) * (temperature / standardT) * (z / standardZ);
        }

        calculation computeEnergy {
            doc / "Calculate energy content from standard volume and heating value";
            in standardVolume : VolumeValue;
            in hv : HeatingValue;
            return energy : EnergyValue =
                EnergyValue(standardVolume * hv / 3600000);
        }

        action accumulateReading {
            doc / "Accumulate the latest reading into totals and publish to display/storage/comm";
            in flowRate : VolumeFlowRateValue;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in dt : Real;
            out reading : MeterReading;
        }
    }

    part def DisplayUnit {
        doc / "Local user display showing flow rate, total volume, total energy, and status";
        port displayIn : DisplayDataPort;
        attribute backlightEnabled : Boolean = false;
        attribute lastDisplayedFlowRate : VolumeFlowRateValue;
        attribute lastDisplayedVolume : VolumeValue;
        attribute lastDisplayedEnergy : EnergyValue;
        attribute lastDisplayedStatus : StatusValue;
        attribute lastDisplayedAlarm : AlarmEvent;

        action refreshDisplay {
            in flowRate : VolumeFlowRateValue;
            in volume : VolumeValue;
            in energy : EnergyValue;
            in status : StatusValue;
            in alarm : AlarmEvent;
        }
    }

    part def DataStorageModule {
        doc / "Persistent internal storage of historical meter readings";
        port storageIn : StoragePort;
        attribute capacityEntries : Integer = 87600;
        attribute storedReadings : MeterReading[0..*] := {};
        attribute retentionDays : Integer = 365;

        action storeReading {
            in reading : MeterReading;
            out archive : MeterReading;
        }

        action purgeOldReadings {
            doc / "Remove entries older than the retention period";
        }
    }

    part def CommunicationInterface {
        doc / "Wireless/wired interface to utility backend for telemetry and configuration";
        port txOut : CommunicationTxPort;
        port rxIn : CommunicationRxPort;
        attribute protocol : String = "DLMS/COSEM";
        attribute pollIntervalSeconds : Integer = 900;
        attribute linkActive : Boolean;

        action transmitReading {
            in reading : MeterReading;
        }

        action transmitAlarm {
            in alarm : AlarmEvent;
        }

        action receiveConfiguration {
            out config : ConfigurationUpdate;
        }
    }

    part def DiagnosticModule {
        doc / "Monitors sensor readings for safety anomalies and raises alarms";
        port sensorIn : SensorDataPort;
        port alarmOut : AlarmPort;
        port controlOut : ControlSignalPort;

        attribute nominalFlowHigh : VolumeFlowRateValue := 0.45 cubic_metre_per_second;
        attribute nominalFlowLow : VolumeFlowRateValue := 0.0001 cubic_metre_per_second;
        attribute nominalPressureHigh : PressureValue := 450 kilopascal;
        attribute nominalPressureLow : PressureValue := 60 kilopascal;
        attribute nominalTemperatureHigh : TemperatureValue := 343.15 kelvin;
        attribute nominalTemperatureLow : TemperatureValue := 243.15 kelvin;
        attribute leakDetectionThreshold : VolumeFlowRateValue := 0.005 cubic_metre_per_second;
        attribute currentAlarm : AlarmEvent;

        action detectAnomalies {
            in flowRate : VolumeFlowRateValue;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            out alarm : AlarmEvent;
        }

        action generateLeakAlarm {
            doc / "Generate alarm indicating a suspected gas leak from continuous low flow";
            out alarm : AlarmEvent;
        }

        action generatePressureAlarm {
            doc / "Generate alarm indicating out-of-range gas pressure";
            out alarm : AlarmEvent;
        }
    }

    // =========================================================================
    // Top-Level Smart Gas Meter System
    // =========================================================================
    part def SmartGasMeterSystem {
        doc / "Modern smart gas meter for residential/commercial buildings";

        part flowMeasurement : FlowMeasurementUnit;
        part pressureTransducer : PressureTransducer;
        part temperatureSensor : TemperatureSensor;
        part computation : ComputationModule;
        part display : DisplayUnit;
        part storage : DataStorageModule;
        part communication : CommunicationInterface;
        part diagnostic : DiagnosticModule;

        // External ports
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        port externalCommTx : CommunicationTxPort;
        port externalCommRx : CommunicationRxPort;
        port externalAlarm : AlarmPort;

        // Connections - gas flow
        connect gasInlet.flow to flowMeasurement.gasIn.flow;
        connect gasInlet.sample to flowMeasurement.gasIn.sample;
        connect flowMeasurement.gasOut.flow to gasOutlet.flow;
        connect flowMeasurement.gasOut.sample to gasOutlet.sample;

        // Gas path tapped for pressure and temperature sensing
        connect gasInlet.sample to pressureTransducer.gasIn.sample;
        connect gasInlet.sample to temperatureSensor.gasIn.sample;

        // Sensor signals to computation
        connect flowMeasurement.flowSignal.flowRate to computation.sensorIn.flowRate;
        connect pressureTransducer.pressureSignal.pressure to computation.sensorIn.pressure;
        connect temperatureSensor.temperatureSignal.temperature to computation.sensorIn.temperature;

        // Sensor signals to diagnostic
        connect flowMeasurement.flowSignal.flowRate to diagnostic.sensorIn.flowRate;
        connect pressureTransducer.pressureSignal.pressure to diagnostic.sensorIn.pressure;
        connect temperatureSensor.temperatureSignal.temperature to diagnostic.sensorIn.temperature;

        // Computation outputs
        connect computation.displayOut to display.displayIn;
        connect computation.storageOut to storage.storageIn;
        connect computation.commOut to communication.txOut;

        // Diagnostic alarm path
        connect diagnostic.alarmOut.alarm to computation.displayIn.alarm;
        connect diagnostic.alarmOut.alarm to externalAlarm.alarm;
        connect diagnostic.alarmOut.alarm to communication.txOut.alarm;

        // Control loop: diagnostic influences computation state
        connect diagnostic.controlOut to computation.controlIn;

        // Communication external links
        connect communication.txOut.reading to externalCommTx.reading;
        connect communication.txOut.alarm to externalCommTx.alarm;
        connect externalCommRx.config to communication.rxIn.config;

        // =========================================================================
        // Operational State Machine
        // =========================================================================
        attribute operationalMode : StatusValue;

        state machine OperationalLifecycle {
            doc / "Top-level standby/measuring/alarm/maintenance cycle";

            state standby {
                doc / "Low-power mode when no gas flow is detected";
                entry action {
                    computation.currentStatus := "standby";
                    computation.currentFlowRate := 0 cubic_metre_per_second;
                }
                do action {
                    doc / "Periodically sample sensors to detect flow onset";
                }
            }

            state measuring {
                doc / "Active measurement mode with continuous PT correction and accumulation";
                entry action {
                    computation.currentStatus := "measuring";
                }
                do action {
                    doc / "Continuously read sensors, compute standard volume, energy, and store readings";
                    computation.accumulatedVolume := computation.accumulatedVolume +
                        (computation.currentFlowRate * 1.0);
                    computation.accumulatedStandardVolume := computation.accumulatedStandardVolume +
                        computeStandardVolume(computation.currentFlowRate * 1.0,
                                              computation.currentPressure,
                                              computation.currentTemperature,
                                              computation.compressibilityFactor,
                                              computation.standardPressure,
                                              computation.standardTemperature,
                                              computation.standardCompressibilityFactor);
                    computation.accumulatedEnergy := computation.accumulatedEnergy +
                        computeEnergy(computation.accumulatedStandardVolume,
                                      computation.heatingValue);
                }
            }

            state alarm {
                doc / "Alarm state entered when a diagnostic anomaly is detected";
                entry action {
                    computation.currentStatus := "alarm";
                    computation.lastAlarm := diagnostic.currentAlarm;
                }
                do action {
                    doc / "Continuously broadcast alarm while condition persists";
                }
            }

            state maintenance {
                doc / "Technician servicing mode with measurement paused";
                entry action {
                    computation.currentStatus := "maintenance";
                }
            }

            transition init_to_standby initial to standby;

            transition standby_to_measuring
                source standby
                target measuring
                when flowMeasurement.currentFlowRate > flowMeasurement.flowDetectedThreshold;

            transition measuring_to_standby
                source measuring
                target standby
                when flowMeasurement.currentFlowRate <= flowMeasurement.flowDetectedThreshold
                    and diagnostic.currentAlarm.code == 0;

            transition any_to_alarm
                source measuring
                target alarm
                when diagnostic.currentAlarm.code != 0;

            transition alarm_to_measuring
                source alarm
                target measuring
                when diagnostic.currentAlarm.code == 0
                    and flowMeasurement.currentFlowRate > flowMeasurement.flowDetectedThreshold;

            transition alarm_to_standby
                source alarm
                target standby
                when diagnostic.currentAlarm.code == 0
                    and flowMeasurement.currentFlowRate <= flowMeasurement.flowDetectedThreshold;

            transition measuring_to_maintenance
                source measuring
                target maintenance
                when computation.controlIn.mode == "maintenance";

            transition standby_to_maintenance
                source standby
                target maintenance
                when computation.controlIn.mode == "maintenance";

            transition alarm_to_maintenance
                source alarm
                target maintenance
                when computation.controlIn.mode == "maintenance";

            transition maintenance_to_standby
                source maintenance
                target standby
                when computation.controlIn.mode != "maintenance";
        }
    }

    // =========================================================================
    // Requirements
    // =========================================================================
    requirement def GasMeterRequirements {
        doc / "Top-level requirements for the smart gas meter";

        requirement ContinuousFlowMonitoring {
            doc / "The meter shall continuously monitor the volume of natural gas passing through it.";
            subject :> smartMeter : SmartGasMeterSystem;
        }

        requirement PressureTemperatureCorrection {
            doc / "The meter shall correct measured volume to a standard volume based on measured pressure and temperature.";
            subject :> smartMeter;
        }

        requirement EnergyCalculation {
            doc / "The meter shall calculate total energy content consumed based on gas properties.";
            subject :> smartMeter;
        }

        requirement FlowMeasurementAccuracy {
            doc / "The flow measurement unit shall measure flow rate within 1.5% of true value across its operating range.";
            subject :> flowUnit : FlowMeasurementUnit;
        }

        requirement PressureMeasurementRange {
            doc / "The pressure transducer shall measure absolute gas pressure between 50 kPa and 500 kPa.";
            subject :> pressureUnit : PressureTransducer;
        }

        requirement TemperatureMeasurementRange {
            doc / "The temperature sensor shall measure gas temperature between -40 C and +80 C.";
            subject :> tempUnit : TemperatureSensor;
        }

        requirement LocalDisplayProvision {
            doc / "The display unit shall show current flow rate, total volume, total energy, and operational status.";
            subject :> displayUnit : DisplayUnit;
        }

        requirement HistoricalLogging {
            doc / "The data storage module shall log each reading with timestamp for at least 365 days.";
            subject :> storageUnit : DataStorageModule;
        }

        requirement RemoteCommunication {
            doc / "The communication interface shall transmit readings and alarms to the utility billing system.";
            subject :> commUnit : CommunicationInterface;
        }

        requirement ConfigurationReception {
            doc / "The communication interface shall accept configuration updates from the utility backend.";
            subject :> commUnit2 : CommunicationInterface;
        }

        requirement LeakDetection {
            doc / "The diagnostic module shall detect continuous low-flow conditions that may indicate a leak.";
            subject :> diagUnit : DiagnosticModule;
        }

        requirement PressureSafety {
            doc / "The diagnostic module shall raise an alarm when gas pressure is outside safe limits.";
            subject :> diagUnit2 : DiagnosticModule;
        }

        requirement StandbyPowerEfficiency {
            doc / "The meter shall enter a low-power standby mode when no gas flow is detected.";
            subject :> smartMeter;
        }

        requirement AutoActivationOnFlow {
            doc / "The meter shall automatically enter measuring state upon detection of gas flow.";
            subject :> smartMeter;
        }

        requirement AlarmReporting {
            doc / "Upon detection of an anomaly, the meter shall enter alarm state and transmit a notification.";
            subject :> smartMeter;
        }

        requirement MaintenanceModeSupport {
            doc / "The meter shall provide a dedicated maintenance mode for technician servicing.";
            subject :> smartMeter;
        }
    }

    // Verification of requirements by the system design
    verification PressureTemperatureCorrectionVerification {
        doc / "Confirm standard volume computation matches expected PT-corrected value";
        subject :> smartMeter : SmartGasMeterSystem;
        objective {
            doc / "Verify computeStandardVolume returns the expected standard volume";
        }
    }

    verification LeakDetectionVerification {
        doc / "Confirm a continuous low flow triggers a leak alarm";
        subject :> diagUnit : DiagnosticModule;
        objective {
            doc / "Verify generateLeakAlarm is invoked when flow is below threshold for sustained period";
        }
    }

    verification StateMachineVerification {
        doc / "Confirm the four operational states transition correctly";
        subject :> smartMeter;
        objective {
            doc / "Verify transitions standby->measuring->alarm->maintenance are correct under the defined guards";
        }
    }
}

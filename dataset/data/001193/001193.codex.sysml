package PiezometerSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure;
    attribute def Temperature;
    attribute def Length;
    attribute def VolumeFlowRate;
    attribute def ElectricPotential;
    attribute def ElectricCurrent;
    attribute def StateOfCharge;
    attribute def Time;
    attribute def Frequency;
    attribute def Boolean;

    item def Groundwater {
        attribute hydraulicHead : Length;
        attribute porePressure : Pressure;
        attribute temperature : Temperature;
        attribute turbidityIndex : Real;
    }

    item def PressureSignal {
        attribute measuredPressure : Pressure;
        attribute sampleTime : Time;
        attribute sensorTemperature : Temperature;
        attribute qualityValid : Boolean;
    }

    item def HeadMeasurement {
        attribute waterLevelElevation : Length;
        attribute hydraulicHead : Length;
        attribute compensatedPressure : Pressure;
        attribute measurementTime : Time;
        attribute confidence : Real;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    item def TelemetryMessage {
        attribute deviceId : String;
        attribute pressure : Pressure;
        attribute head : Length;
        attribute temperature : Temperature;
        attribute batterySoc : StateOfCharge;
        attribute timestamp : Time;
        attribute alarmActive : Boolean;
    }

    port def GroundwaterPort {
        in item water : Groundwater;
    }

    port def PressureSensingPort {
        in item water : Groundwater;
        out item pressureSignal : PressureSignal;
    }

    port def MeasurementPort {
        in item pressureSignal : PressureSignal;
        out item headMeasurement : HeadMeasurement;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def TelemetryPort {
        out item message : TelemetryMessage;
    }

    port def MaintenancePort {
        in item calibrationCommand : String;
        out item diagnosticReport : String;
    }

    action def SensePorePressure {
        in item water : Groundwater;
        out item signal : PressureSignal;
        attribute samplingRate : Frequency = 1 [Hz];
    }

    action def CompensateAndConvertToHead {
        in item rawSignal : PressureSignal;
        out item measurement : HeadMeasurement;
        attribute fluidDensity : Real = 1000;
        attribute gravity : Real = 9.80665;
        attribute sensorDatumElevation : Length;
    }

    action def StoreMeasurement {
        in item measurement : HeadMeasurement;
        out item storedRecord : HeadMeasurement;
    }

    action def TransmitTelemetry {
        in item measurement : HeadMeasurement;
        in attribute batterySoc : StateOfCharge;
        out item message : TelemetryMessage;
    }

    action def CheckForAlarms {
        in item measurement : HeadMeasurement;
        out attribute alarmActive : Boolean;
        attribute highHeadLimit : Length;
        attribute lowHeadLimit : Length;
    }

    state def PiezometerOperatingState {
        entry action InitializeElectronics;
        state Off;
        state Startup;
        state Standby;
        state Measuring;
        state Processing;
        state Transmitting;
        state Alarm;
        state Maintenance;
        state Fault;

        transition first Off;
        transition Off_to_Startup
            first Off then Startup
            accept PowerApplied;

        transition Startup_to_Standby
            first Startup then Standby
            accept SelfTestPassed;

        transition Startup_to_Fault
            first Startup then Fault
            accept SelfTestFailed;

        transition Standby_to_Measuring
            first Standby then Measuring
            accept SampleTimerExpired;

        transition Measuring_to_Processing
            first Measuring then Processing
            accept PressureSampleCaptured;

        transition Processing_to_Transmitting
            first Processing then Transmitting
            accept MeasurementValid;

        transition Processing_to_Alarm
            first Processing then Alarm
            accept LimitExceeded;

        transition Alarm_to_Transmitting
            first Alarm then Transmitting
            accept AlarmRecordPrepared;

        transition Transmitting_to_Standby
            first Transmitting then Standby
            accept TelemetryComplete;

        transition Standby_to_Maintenance
            first Standby then Maintenance
            accept MaintenanceConnected;

        transition Maintenance_to_Standby
            first Maintenance then Standby
            accept MaintenanceDisconnected;

        transition Measuring_to_Fault
            first Measuring then Fault
            accept SensorFailureDetected;

        transition Transmitting_to_Fault
            first Transmitting then Fault
            accept CommunicationFailureDetected;
    }

    part def PorousTip {
        port groundwaterInterface : GroundwaterPort;
        attribute poreDiameter : Length = 60 [um];
        attribute bodyLength : Length = 0.12 [m];
        attribute cloggingIndex : Real;
    }

    part def Standpipe {
        port groundwaterInterface : GroundwaterPort;
        attribute internalDiameter : Length = 0.025 [m];
        attribute screenedLength : Length = 1.5 [m];
        attribute datumElevation : Length;
    }

    part def PressureTransducer {
        port sensing : PressureSensingPort;
        port powerIn : PowerPort;
        attribute rangeMin : Pressure = 0 [kPa];
        attribute rangeMax : Pressure = 700 [kPa];
        attribute accuracy : Pressure = 0.35 [kPa];
        attribute operatingTemperatureMin : Temperature = -20 [degC];
        attribute operatingTemperatureMax : Temperature = 60 [degC];

        perform action sense : SensePorePressure {
            in water = sensing.water;
            out signal = sensing.pressureSignal;
        }
    }

    part def TemperatureSensor {
        port powerIn : PowerPort;
        attribute measuredTemperature : Temperature;
        attribute accuracy : Temperature = 0.2 [K];
    }

    part def DataLogger {
        port measurementIn : MeasurementPort;
        port powerIn : PowerPort;
        port telemetryOut : TelemetryPort;
        port maintenance : MaintenancePort;

        attribute memoryCapacityRecords : Integer = 250000;
        attribute samplingInterval : Time = 900 [s];
        attribute deviceId : String;
        attribute highHeadLimit : Length;
        attribute lowHeadLimit : Length;

        perform action convert : CompensateAndConvertToHead {
            in rawSignal = measurementIn.pressureSignal;
            out measurement = measurementIn.headMeasurement;
        }

        perform action store : StoreMeasurement {
            in measurement = measurementIn.headMeasurement;
        }

        perform action alarmCheck : CheckForAlarms {
            in measurement = measurementIn.headMeasurement;
        }

        perform action transmit : TransmitTelemetry {
            in measurement = measurementIn.headMeasurement;
            out message = telemetryOut.message;
        }

        exhibit state behavior : PiezometerOperatingState;
    }

    part def BatteryPack {
        port powerOut : PowerPort;
        attribute nominalVoltage : ElectricPotential = 12 [V];
        attribute capacity : Real = 18;
        attribute stateOfCharge : StateOfCharge;
        attribute minimumOperationalSoc : StateOfCharge = 15;
    }

    part def SolarCharger {
        port powerOut : PowerPort;
        attribute panelPowerRating : Real = 20;
        attribute chargeVoltage : ElectricPotential = 14.4 [V];
    }

    part def TelemetryModule {
        port telemetry : TelemetryPort;
        port powerIn : PowerPort;
        attribute radioFrequency : Frequency = 915 [MHz];
        attribute transmitInterval : Time = 3600 [s];
        attribute lastTransmissionSuccess : Boolean;
    }

    part def ProtectiveEnclosure {
        attribute ingressProtectionCode : String = "IP67";
        attribute enclosureHeight : Length = 0.35 [m];
        attribute enclosureWidth : Length = 0.25 [m];
        attribute enclosureDepth : Length = 0.16 [m];
    }

    part def Piezometer {
        port aquiferInterface : GroundwaterPort;
        port telemetryOut : TelemetryPort;
        port maintenance : MaintenancePort;

        part porousTip : PorousTip;
        part standpipe : Standpipe;
        part pressureTransducer : PressureTransducer;
        part temperatureSensor : TemperatureSensor;
        part dataLogger : DataLogger;
        part battery : BatteryPack;
        part solarCharger : SolarCharger;
        part telemetryModule : TelemetryModule;
        part enclosure : ProtectiveEnclosure;

        attribute installationDepth : Length = 24 [m];
        attribute groundSurfaceElevation : Length = 103.4 [m];
        attribute sensorDatumElevation : Length = 79.4 [m];
        attribute primaryFunction : String = "Measure groundwater pore pressure and convert it to hydraulic head for monitoring subsurface water conditions.";

        connect aquiferInterface to porousTip.groundwaterInterface;
        connect porousTip.groundwaterInterface to standpipe.groundwaterInterface;
        connect standpipe.groundwaterInterface to pressureTransducer.sensing;
        connect pressureTransducer.sensing to dataLogger.measurementIn;
        connect dataLogger.telemetryOut to telemetryModule.telemetry;
        connect telemetryModule.telemetry to telemetryOut;
        connect dataLogger.maintenance to maintenance;
        connect battery.powerOut to pressureTransducer.powerIn;
        connect battery.powerOut to temperatureSensor.powerIn;
        connect battery.powerOut to dataLogger.powerIn;
        connect battery.powerOut to telemetryModule.powerIn;
        connect solarCharger.powerOut to battery.powerOut;
    }

    part def MonitoringStation {
        port telemetryIn : TelemetryPort;
        attribute stationName : String;
        attribute receivedHead : Length;
        attribute receivedPressure : Pressure;
        attribute alarmDisplayed : Boolean;
    }

    part def PiezometerMonitoringSystem {
        part fieldPiezometer : Piezometer;
        part remoteStation : MonitoringStation;

        connect fieldPiezometer.telemetryOut to remoteStation.telemetryIn;
    }

    requirement def PrimaryFunctionRequirement {
        subject monitoredPiezometer : Piezometer;
        doc /* The piezometer shall measure groundwater pore pressure at the installed depth and provide hydraulic head data suitable for hydrogeologic monitoring. */
        require constraint {
            monitoredPiezometer.primaryFunction == "Measure groundwater pore pressure and convert it to hydraulic head for monitoring subsurface water conditions."
        }
    }

    requirement def PressureMeasurementRangeRequirement {
        subject transducer : PressureTransducer;
        doc /* The pressure transducer shall support groundwater pore pressure measurements from 0 kPa to at least 700 kPa. */
        require constraint {
            transducer.rangeMin <= 0 [kPa] and transducer.rangeMax >= 700 [kPa]
        }
    }

    requirement def MeasurementAccuracyRequirement {
        subject transducer : PressureTransducer;
        doc /* The piezometer pressure measurement error shall not exceed 0.35 kPa over the specified operating range. */
        require constraint {
            transducer.accuracy <= 0.35 [kPa]
        }
    }

    requirement def SamplingRequirement {
        subject logger : DataLogger;
        doc /* The data logger shall collect a pressure sample at least once every 900 seconds during normal operation. */
        require constraint {
            logger.samplingInterval <= 900 [s]
        }
    }

    requirement def TelemetryRequirement {
        subject radio : TelemetryModule;
        doc /* The telemetry module shall transmit stored hydraulic head measurements at least once every 3600 seconds. */
        require constraint {
            radio.transmitInterval <= 3600 [s]
        }
    }

    requirement def EnvironmentalProtectionRequirement {
        subject enclosure : ProtectiveEnclosure;
        doc /* Above-ground electronics shall be protected by an enclosure rated IP67 or better. */
        require constraint {
            enclosure.ingressProtectionCode == "IP67"
        }
    }

    requirement def EnergyAutonomyRequirement {
        subject battery : BatteryPack;
        doc /* The battery pack shall maintain operation while state of charge remains above the minimum operational threshold. */
        require constraint {
            battery.stateOfCharge >= battery.minimumOperationalSoc
        }
    }

    satisfy PrimaryFunctionRequirement by Piezometer;
    satisfy PressureMeasurementRangeRequirement by PressureTransducer;
    satisfy MeasurementAccuracyRequirement by PressureTransducer;
    satisfy SamplingRequirement by DataLogger;
    satisfy TelemetryRequirement by TelemetryModule;
    satisfy EnvironmentalProtectionRequirement by ProtectiveEnclosure;
    satisfy EnergyAutonomyRequirement by BatteryPack;

    part system : PiezometerMonitoringSystem {
        part fieldPiezometer : Piezometer {
            attribute installationDepth = 24 [m];
            attribute groundSurfaceElevation = 103.4 [m];
            attribute sensorDatumElevation = 79.4 [m];
        }

        part remoteStation : MonitoringStation {
            attribute stationName = "Groundwater Monitoring Control Station";
        }
    }
}
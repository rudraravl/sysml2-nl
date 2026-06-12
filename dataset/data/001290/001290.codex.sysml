package TirePressureMonitoringSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def PressureValue {
        attribute value : Real;
        attribute unit : String = "kPa";
    }

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def VoltageValue {
        attribute value : Real;
        attribute unit : String = "V";
    }

    attribute def TimeValue {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def VehicleSpeedValue {
        attribute value : Real;
        attribute unit : String = "km/h";
    }

    enum def TirePosition {
        enum frontLeft;
        enum frontRight;
        enum rearLeft;
        enum rearRight;
    }

    enum def TirePressureStatus {
        enum normal;
        enum lowPressure;
        enum highPressure;
        enum rapidLeak;
        enum sensorFault;
        enum unknown;
    }

    enum def WarningSeverity {
        enum none;
        enum advisory;
        enum caution;
        enum critical;
    }

    item def TireTelemetry {
        attribute tirePosition : TirePosition;
        attribute measuredPressure : PressureValue;
        attribute measuredTemperature : TemperatureValue;
        attribute sensorBatteryVoltage : VoltageValue;
        attribute sampleAge : TimeValue;
        attribute diagnosticValid : Boolean;
    }

    item def TireStatusReport {
        attribute tirePosition : TirePosition;
        attribute pressureStatus : TirePressureStatus;
        attribute severity : WarningSeverity;
        attribute displayedPressure : PressureValue;
        attribute message : String;
    }

    item def VehicleMotionData {
        attribute vehicleSpeed : VehicleSpeedValue;
        attribute ignitionOn : Boolean;
        attribute vehicleMoving : Boolean;
    }

    item def DriverAlert {
        attribute severity : WarningSeverity;
        attribute alertText : String;
        attribute audibleToneRequested : Boolean;
        attribute affectedTire : TirePosition;
    }

    port def TelemetryOutPort {
        out item telemetry : TireTelemetry;
    }

    port def TelemetryInPort {
        in item telemetry : TireTelemetry;
    }

    port def StatusOutPort {
        out item statusReport : TireStatusReport;
    }

    port def StatusInPort {
        in item statusReport : TireStatusReport;
    }

    port def MotionDataInPort {
        in item motionData : VehicleMotionData;
    }

    port def AlertOutPort {
        out item alert : DriverAlert;
    }

    port def AlertInPort {
        in item alert : DriverAlert;
    }

    part def Tire {
        attribute position : TirePosition;
        attribute nominalColdPressure : PressureValue = (value = 240.0, unit = "kPa");
        attribute minimumAllowedPressure : PressureValue = (value = 190.0, unit = "kPa");
        attribute maximumAllowedPressure : PressureValue = (value = 310.0, unit = "kPa");

        port telemetryPort : TelemetryOutPort;

        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part wirelessTransmitter : WirelessTransmitter;
        part battery : SensorBattery;

        connect pressureSensor.telemetryPort to wirelessTransmitter.telemetryInput;
        connect temperatureSensor.telemetryPort to wirelessTransmitter.telemetryInput;
        connect wirelessTransmitter.telemetryOutput to telemetryPort;
    }

    part def PressureSensor {
        attribute measurementRangeMinimum : PressureValue = (value = 0.0, unit = "kPa");
        attribute measurementRangeMaximum : PressureValue = (value = 500.0, unit = "kPa");
        attribute accuracy : PressureValue = (value = 7.0, unit = "kPa");
        attribute samplePeriod : TimeValue = (value = 5.0, unit = "s");

        port telemetryPort : TelemetryOutPort;
    }

    part def TemperatureSensor {
        attribute measurementRangeMinimum : TemperatureValue = (value = -40.0, unit = "degC");
        attribute measurementRangeMaximum : TemperatureValue = (value = 125.0, unit = "degC");
        attribute accuracy : TemperatureValue = (value = 2.0, unit = "degC");

        port telemetryPort : TelemetryOutPort;
    }

    part def SensorBattery {
        attribute nominalVoltage : VoltageValue = (value = 3.0, unit = "V");
        attribute lowVoltageThreshold : VoltageValue = (value = 2.2, unit = "V");
    }

    part def WirelessTransmitter {
        attribute transmissionPeriodWhileMoving : TimeValue = (value = 10.0, unit = "s");
        attribute transmissionPeriodWhileParked : TimeValue = (value = 60.0, unit = "s");

        port telemetryInput : TelemetryInPort;
        port telemetryOutput : TelemetryOutPort;
    }

    part def ReceiverModule {
        attribute maximumTelemetryAge : TimeValue = (value = 30.0, unit = "s");

        port frontLeftTelemetry : TelemetryInPort;
        port frontRightTelemetry : TelemetryInPort;
        port rearLeftTelemetry : TelemetryInPort;
        port rearRightTelemetry : TelemetryInPort;
        port validatedTelemetry : TelemetryOutPort;

        action validateTelemetry {
            in item rawTelemetry : TireTelemetry;
            out item acceptedTelemetry : TireTelemetry;

            first start;
            then checkDiagnosticValidity;
            then checkMessageAge;
            then publishAcceptedTelemetry;
            then done;

            action checkDiagnosticValidity;
            action checkMessageAge;
            action publishAcceptedTelemetry;
        }
    }

    part def PressureEvaluationController {
        attribute lowPressureThreshold : PressureValue = (value = 190.0, unit = "kPa");
        attribute highPressureThreshold : PressureValue = (value = 310.0, unit = "kPa");
        attribute rapidLeakRateThreshold : PressureValue = (value = 20.0, unit = "kPa");
        attribute rapidLeakObservationWindow : TimeValue = (value = 60.0, unit = "s");

        port telemetryInput : TelemetryInPort;
        port motionDataInput : MotionDataInPort;
        port statusOutput : StatusOutPort;
        port alertOutput : AlertOutPort;

        action evaluatePressure {
            in item telemetry : TireTelemetry;
            in item motion : VehicleMotionData;
            out item status : TireStatusReport;
            out item alert : DriverAlert;

            first receiveTelemetry;
            then compensateForTemperature;
            then compareAgainstThresholds;
            then detectRapidLeak;
            then classifySeverity;
            then publishStatusAndAlert;
            then done;

            action receiveTelemetry;
            action compensateForTemperature;
            action compareAgainstThresholds;
            action detectRapidLeak;
            action classifySeverity;
            action publishStatusAndAlert;
        }

        state behavior pressureMonitoringStateMachine {
            entry action initializeMonitoring;

            state Off;
            state Standby;
            state Monitoring;
            state WarningActive;
            state FaultActive;

            transition first Off;

            transition Off_to_Standby
                first Off
                accept VehicleMotionData
                if motionData.ignitionOn
                then Standby;

            transition Standby_to_Monitoring
                first Standby
                accept VehicleMotionData
                if motionData.vehicleMoving
                then Monitoring;

            transition Monitoring_to_WarningActive
                first Monitoring
                accept TireStatusReport
                if statusReport.severity == WarningSeverity::caution or statusReport.severity == WarningSeverity::critical
                then WarningActive;

            transition Monitoring_to_FaultActive
                first Monitoring
                accept TireStatusReport
                if statusReport.pressureStatus == TirePressureStatus::sensorFault
                then FaultActive;

            transition WarningActive_to_Monitoring
                first WarningActive
                accept TireStatusReport
                if statusReport.severity == WarningSeverity::none
                then Monitoring;

            transition FaultActive_to_Monitoring
                first FaultActive
                accept TireStatusReport
                if statusReport.pressureStatus != TirePressureStatus::sensorFault
                then Monitoring;

            transition Standby_to_Off
                first Standby
                accept VehicleMotionData
                if not motionData.ignitionOn
                then Off;
        }
    }

    part def DriverDisplay {
        port statusInput : StatusInPort;
        port alertInput : AlertInPort;

        action presentPressureStatus {
            in item status : TireStatusReport;
            in item alert : DriverAlert;

            first updateTirePressureGraphic;
            then showTextWarning;
            then requestAudibleTone;
            then done;

            action updateTirePressureGraphic;
            action showTextWarning;
            action requestAudibleTone;
        }
    }

    part def VehicleDataGateway {
        port motionDataOutput : MotionDataInPort;
    }

    part def TirePressureMonitoringSystem {
        doc
        /*
         * Primary function:
         * The tire-pressure monitoring system continuously receives pressure,
         * temperature, and diagnostic data from tire-mounted sensors, evaluates
         * each tire against pressure and leak-rate limits, and alerts the driver
         * when a tire is underinflated, overinflated, leaking rapidly, or unable
         * to report valid data.
         */

        part frontLeftTire : Tire {
            attribute position = TirePosition::frontLeft;
        }

        part frontRightTire : Tire {
            attribute position = TirePosition::frontRight;
        }

        part rearLeftTire : Tire {
            attribute position = TirePosition::rearLeft;
        }

        part rearRightTire : Tire {
            attribute position = TirePosition::rearRight;
        }

        part receiver : ReceiverModule;
        part controller : PressureEvaluationController;
        part display : DriverDisplay;
        part vehicleGateway : VehicleDataGateway;

        connect frontLeftTire.telemetryPort to receiver.frontLeftTelemetry;
        connect frontRightTire.telemetryPort to receiver.frontRightTelemetry;
        connect rearLeftTire.telemetryPort to receiver.rearLeftTelemetry;
        connect rearRightTire.telemetryPort to receiver.rearRightTelemetry;

        connect receiver.validatedTelemetry to controller.telemetryInput;
        connect vehicleGateway.motionDataOutput to controller.motionDataInput;
        connect controller.statusOutput to display.statusInput;
        connect controller.alertOutput to display.alertInput;

        action monitorTirePressure {
            first collectTireTelemetry;
            then validateSensorMessages;
            then evaluateEachTirePressure;
            then determineDriverAlert;
            then presentDriverInformation;
            then done;

            action collectTireTelemetry;
            action validateSensorMessages;
            action evaluateEachTirePressure;
            action determineDriverAlert;
            action presentDriverInformation;
        }
    }

    requirement def DetectLowPressureRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall identify a tire as low pressure when its validated
         * measured pressure is below 190 kPa while the vehicle ignition is on.
         */

        require constraint {
            tpms.controller.lowPressureThreshold.value == 190.0
        }
    }

    requirement def DetectHighPressureRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall identify a tire as high pressure when its validated
         * measured pressure exceeds 310 kPa.
         */

        require constraint {
            tpms.controller.highPressureThreshold.value == 310.0
        }
    }

    requirement def DetectRapidLeakRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall issue a critical warning when tire pressure decreases
         * by at least 20 kPa within a 60 second observation window.
         */

        require constraint {
            tpms.controller.rapidLeakRateThreshold.value == 20.0 and
            tpms.controller.rapidLeakObservationWindow.value == 60.0
        }
    }

    requirement def AlertDriverRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall provide a visual tire-specific warning and request an
         * audible tone for caution or critical pressure conditions.
         */

        require constraint {
            true
        }
    }

    requirement def SensorFaultRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall report a sensor fault if telemetry is diagnostically
         * invalid or older than 30 seconds while monitoring is active.
         */

        require constraint {
            tpms.receiver.maximumTelemetryAge.value == 30.0
        }
    }

    requirement def MonitoringFunctionRequirement {
        subject tpms : TirePressureMonitoringSystem;

        doc
        /*
         * The system shall perform its primary function by collecting tire sensor
         * telemetry, validating it, evaluating pressure status, and informing the
         * driver of unsafe tire-pressure conditions.
         */

        require constraint {
            true
        }
    }

    satisfy DetectLowPressureRequirement by TirePressureMonitoringSystem::controller;
    satisfy DetectHighPressureRequirement by TirePressureMonitoringSystem::controller;
    satisfy DetectRapidLeakRequirement by TirePressureMonitoringSystem::controller;
    satisfy AlertDriverRequirement by TirePressureMonitoringSystem::display;
    satisfy SensorFaultRequirement by TirePressureMonitoringSystem::receiver;
    satisfy MonitoringFunctionRequirement by TirePressureMonitoringSystem;
}
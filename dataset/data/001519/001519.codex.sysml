package OpenHardwareSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def PartsPerMillion : Real {
        unit = "ppm";
    }

    attribute def Hectopascal : Real {
        unit = "hPa";
    }

    attribute def Lux : Real {
        unit = "lx";
    }

    attribute def MilliampereHour : Real {
        unit = "mAh";
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def EnvironmentalSample {
        attribute temperature : Temperature;
        attribute relativeHumidity : Percent;
        attribute carbonDioxide : PartsPerMillion;
        attribute pressure : Hectopascal;
        attribute illuminance : Lux;
        attribute sampleTime : Time;
    }

    item def TelemetryPacket {
        attribute deviceId : String;
        attribute sequenceNumber : Integer;
        attribute batteryStateOfCharge : Percent;
        attribute sample : EnvironmentalSample;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def PowerOutputPort {
        out item powerOut : ElectricalPower;
    }

    port def SensorDataPort {
        out item sample : EnvironmentalSample;
    }

    port def TelemetryPort {
        out item packet : TelemetryPacket;
    }

    port def ControlPort {
        in item command : String;
        out item status : String;
    }

    action def AcquireEnvironmentalSample {
        out sample : EnvironmentalSample;
    }

    action def ValidateSample {
        in rawSample : EnvironmentalSample;
        out validSample : EnvironmentalSample;
        out isValid : Boolean;
    }

    action def PackageTelemetry {
        in sample : EnvironmentalSample;
        in batteryStateOfCharge : Percent;
        out packet : TelemetryPacket;
    }

    action def TransmitTelemetry {
        in packet : TelemetryPacket;
        out acknowledged : Boolean;
    }

    state def MonitorOperatingState {
        entry action initializeHardware;
        state Off;
        state Booting;
        state Sampling;
        state Validating;
        state Transmitting;
        state LowPowerSleep;
        state Fault;

        transition first Off;

        transition powerApplied
            first Off
            then Booting;

        transition bootComplete
            first Booting
            then Sampling;

        transition sampleCaptured
            first Sampling
            then Validating;

        transition validData
            first Validating
            then Transmitting;

        transition invalidData
            first Validating
            then Fault;

        transition telemetrySent
            first Transmitting
            then LowPowerSleep;

        transition wakeIntervalElapsed
            first LowPowerSleep
            then Sampling;

        transition unrecoverableError
            first Sampling
            then Fault;

        transition resetRequested
            first Fault
            then Booting;
    }

    part def OpenHardwareEnvironmentalMonitor {
        doc /* 
         * Primary high-level function:
         * An open hardware environmental monitor senses indoor air and light conditions,
         * packages validated measurements with device health information, and publishes
         * telemetry for transparent community inspection, replication, and improvement.
         */

        attribute deviceId : String;
        attribute nominalSupplyVoltage : ElectricPotential = 5 [V];
        attribute samplingPeriod : Time = 60 [s];
        attribute telemetryRetryLimit : Integer = 3;
        attribute enclosureVolume : Volume = 0.0012 [m^3];

        port usbPower : PowerInputPort;
        port solarPower : PowerInputPort;
        port telemetryOut : TelemetryPort;
        port maintenance : ControlPort;

        part powerSubsystem : PowerSubsystem;
        part controller : OpenMicrocontrollerBoard;
        part sensorArray : EnvironmentalSensorArray;
        part radio : WirelessTelemetryModule;
        part enclosure : OpenPrintableEnclosure;
        part statusIndicator : StatusIndicator;

        connection usbToPower
            connect usbPower.powerIn to powerSubsystem.usbInput.powerIn;

        connection solarToPower
            connect solarPower.powerIn to powerSubsystem.solarInput.powerIn;

        connection regulatedPowerToController
            connect powerSubsystem.regulatedOutput.powerOut to controller.powerInput.powerIn;

        connection regulatedPowerToSensors
            connect powerSubsystem.regulatedOutput.powerOut to sensorArray.powerInput.powerIn;

        connection regulatedPowerToRadio
            connect powerSubsystem.regulatedOutput.powerOut to radio.powerInput.powerIn;

        connection sensorDataToController
            connect sensorArray.sensorOutput.sample to controller.sensorInput.sample;

        connection controllerTelemetryToRadio
            connect controller.telemetryOutput.packet to radio.telemetryInput.packet;

        connection radioToSystemTelemetry
            connect radio.radioOutput.packet to telemetryOut.packet;

        connection controllerStatusToIndicator
            connect controller.statusOutput.status to statusIndicator.statusInput.command;

        perform action monitorCycle {
            action acquire : AcquireEnvironmentalSample;
            action validate : ValidateSample;
            action package : PackageTelemetry;
            action transmit : TransmitTelemetry;

            flow acquire.sample to validate.rawSample;
            flow validate.validSample to package.sample;
            flow powerSubsystem.battery.stateOfCharge to package.batteryStateOfCharge;
            flow package.packet to transmit.packet;
        }

        exhibit state operatingState : MonitorOperatingState;
    }

    part def PowerSubsystem {
        attribute regulatedVoltage : ElectricPotential = 3.3 [V];
        attribute maximumContinuousCurrent : ElectricCurrent = 1.2 [A];

        port usbInput : PowerInputPort;
        port solarInput : PowerInputPort;
        port regulatedOutput : PowerOutputPort;

        part battery : RechargeableBattery;
        part charger : ChargeController;
        part regulator : BuckBoostRegulator;

        connection usbToCharger
            connect usbInput.powerIn to charger.usbInput.powerIn;

        connection solarToCharger
            connect solarInput.powerIn to charger.solarInput.powerIn;

        connection chargerToBattery
            connect charger.batteryOutput.powerOut to battery.chargeInput.powerIn;

        connection batteryToRegulator
            connect battery.dischargeOutput.powerOut to regulator.input.powerIn;

        connection regulatorToOutput
            connect regulator.output.powerOut to regulatedOutput.powerOut;
    }

    part def RechargeableBattery {
        attribute chemistry : String = "LiFePO4";
        attribute nominalVoltage : ElectricPotential = 3.2 [V];
        attribute capacity : MilliampereHour = 3000 [mAh];
        attribute stateOfCharge : Percent;
        attribute minimumSafeVoltage : ElectricPotential = 2.8 [V];

        port chargeInput : PowerInputPort;
        port dischargeOutput : PowerOutputPort;
    }

    part def ChargeController {
        attribute maximumChargeCurrent : ElectricCurrent = 0.5 [A];
        attribute chargeEfficiency : Percent = 88 [%];

        port usbInput : PowerInputPort;
        port solarInput : PowerInputPort;
        port batteryOutput : PowerOutputPort;
    }

    part def BuckBoostRegulator {
        attribute outputVoltage : ElectricPotential = 3.3 [V];
        attribute conversionEfficiency : Percent = 92 [%];

        port input : PowerInputPort;
        port output : PowerOutputPort;
    }

    part def OpenMicrocontrollerBoard {
        attribute boardName : String = "Arduino-compatible open hardware controller";
        attribute clockFrequency : Frequency = 48 [MHz];
        attribute firmwareVersion : String = "1.0.0-open";
        attribute sleepCurrent : ElectricCurrent = 0.002 [A];

        port powerInput : PowerInputPort;
        port sensorInput : SensorDataPort;
        port telemetryOutput : TelemetryPort;
        port statusOutput : ControlPort;

        perform action processSample {
            action validate : ValidateSample;
            action package : PackageTelemetry;
        }
    }

    part def EnvironmentalSensorArray {
        attribute temperatureAccuracy : Temperature = 0.5 [K];
        attribute humidityAccuracy : Percent = 3 [%];
        attribute co2Accuracy : PartsPerMillion = 50 [ppm];
        attribute pressureAccuracy : Hectopascal = 1 [hPa];

        port powerInput : PowerInputPort;
        port sensorOutput : SensorDataPort;

        part temperatureHumiditySensor : TemperatureHumiditySensor;
        part carbonDioxideSensor : CarbonDioxideSensor;
        part pressureSensor : PressureSensor;
        part lightSensor : LightSensor;
    }

    part def TemperatureHumiditySensor {
        attribute measurementRangeLow : Temperature = 253.15 [K];
        attribute measurementRangeHigh : Temperature = 358.15 [K];
        attribute humidityRangeLow : Percent = 0 [%];
        attribute humidityRangeHigh : Percent = 100 [%];
    }

    part def CarbonDioxideSensor {
        attribute measurementRangeLow : PartsPerMillion = 400 [ppm];
        attribute measurementRangeHigh : PartsPerMillion = 5000 [ppm];
        attribute warmupTime : Time = 30 [s];
    }

    part def PressureSensor {
        attribute measurementRangeLow : Hectopascal = 300 [hPa];
        attribute measurementRangeHigh : Hectopascal = 1100 [hPa];
    }

    part def LightSensor {
        attribute measurementRangeLow : Lux = 0 [lx];
        attribute measurementRangeHigh : Lux = 65000 [lx];
    }

    part def WirelessTelemetryModule {
        attribute protocol : String = "LoRaWAN";
        attribute carrierFrequency : Frequency = 915 [MHz];
        attribute transmitPower : Power = 0.1 [W];
        attribute maximumPayloadSize : Integer = 51;

        port powerInput : PowerInputPort;
        port telemetryInput : TelemetryPort;
        port radioOutput : TelemetryPort;
    }

    part def StatusIndicator {
        attribute color : String;
        attribute blinkPeriod : Time = 1 [s];

        port statusInput : ControlPort;
    }

    part def OpenPrintableEnclosure {
        attribute material : String = "PETG";
        attribute wallThickness : Length = 0.002 [m];
        attribute ingressProtectionTarget : String = "IP32";
        attribute ventArea : Area = 0.0004 [m^2];
    }

    requirement def OpenHardwareRequirement {
        subject monitor : OpenHardwareEnvironmentalMonitor;

        require constraint {
            monitor.controller.boardName != "";
        }

        doc /* The controller design files, firmware, and assembly documentation shall be available for inspection, modification, and replication under an open hardware license. */
    }

    requirement def PrimaryFunctionRequirement {
        subject monitor : OpenHardwareEnvironmentalMonitor;

        require constraint {
            monitor.samplingPeriod <= 300 [s]
        }

        doc /* The system shall periodically measure environmental conditions and publish telemetry packets containing temperature, humidity, carbon dioxide, pressure, light level, and battery state. */
    }

    requirement def PowerRequirement {
        subject monitor : OpenHardwareEnvironmentalMonitor;

        require constraint {
            monitor.powerSubsystem.regulatedVoltage == 3.3 [V]
        }

        doc /* The power subsystem shall provide regulated low-voltage power to the controller, sensor array, and radio from USB or solar-charged battery sources. */
    }

    requirement def TelemetryRequirement {
        subject monitor : OpenHardwareEnvironmentalMonitor;

        require constraint {
            monitor.radio.maximumPayloadSize >= 32
        }

        doc /* The telemetry subsystem shall transmit validated measurements as compact packets suitable for low-power open wireless networks. */
    }

    requirement def MaintainabilityRequirement {
        subject monitor : OpenHardwareEnvironmentalMonitor;

        require constraint {
            monitor.enclosure.wallThickness >= 0.0015 [m]
        }

        doc /* The mechanical enclosure shall support fabrication using common desktop 3D printers and shall permit access to the controller, battery, and sensors for repair. */
    }

    satisfy PrimaryFunctionRequirement by OpenHardwareEnvironmentalMonitor;
    satisfy OpenHardwareRequirement by OpenHardwareEnvironmentalMonitor;
    satisfy PowerRequirement by PowerSubsystem;
    satisfy TelemetryRequirement by WirelessTelemetryModule;
    satisfy MaintainabilityRequirement by OpenPrintableEnclosure;

    part openHardwareMonitor : OpenHardwareEnvironmentalMonitor {
        attribute deviceId = "OH-ENV-001";
        attribute samplingPeriod = 60 [s];
    }
}
package PulseOximeterModel {

    package Units {
        unit def percent;
        unit def bpm;
        unit def volt;
        unit def milliamp;
        unit def watt;
        unit def second;
        unit def hertz;
        unit def lumen;
        unit def nanometer;
    }

    package ValueTypes {
        value type SpO2Value :> Real {
            unit :> Units::percent;
            min = 0;
            max = 100;
        }
        value type PulseRateValue :> Real {
            unit :> Units::bpm;
            min = 0;
            max = 300;
        }
        value type VoltageValue :> Real {
            unit :> Units::volt;
        }
        value type CurrentValue :> Real {
            unit :> Units::milliamp;
        }
        value type PowerValue :> Real {
            unit :> Units::watt;
        }
        value type TimeValue :> Real {
            unit :> Units::second;
        }
        value type FrequencyValue :> Real {
            unit :> Units::hertz;
        }
        value type LumenValue :> Real {
            unit :> Units::lumen;
        }
        value type WavelengthValue :> Real {
            unit :> Units::nanometer;
        }
        value type BatteryLevelValue :> Real {
            unit :> Units::percent;
            min = 0;
            max = 100;
        }
    }

    package ItemTypes {
        item def LightSignal {
            attribute wavelength : ValueTypes::WavelengthValue;
            attribute intensity : ValueTypes::LumenValue;
            attribute isOn : Boolean;
        }

        item def RawOpticalSignal {
            attribute redAbsorption : Real;
            attribute irAbsorption : Real;
            attribute ambientNoise : Real;
            attribute timestamp : ValueTypes::TimeValue;
        }

        item def FilteredSignal {
            attribute redFiltered : Real;
            attribute irFiltered : Real;
            attribute plethysmograph : Real;
            attribute timestamp : ValueTypes::TimeValue;
        }

        item def VitalSigns {
            attribute spo2 : ValueTypes::SpO2Value;
            attribute pulseRate : ValueTypes::PulseRateValue;
            attribute plethWaveform : Real[*] ordered;
            attribute signalStrength : Real;
            attribute timestamp : ValueTypes::TimeValue;
        }

        item def ElectricalPower {
            attribute voltage : ValueTypes::VoltageValue;
            attribute current : ValueTypes::CurrentValue;
        }

        enum def SeverityKind {
            normal;
            warning;
            critical;
        }

        item def AlarmEvent {
            attribute severity : ItemTypes::SeverityKind;
            attribute message : String;
            attribute spo2Reading : ValueTypes::SpO2Value;
            attribute pulseRateReading : ValueTypes::PulseRateValue;
            attribute timestamp : ValueTypes::TimeValue;
        }
    }

    package PortDefinitions {
        port def OpticalOutputPort {
            out item light : ItemTypes::LightSignal;
        }

        port def OpticalInputPort {
            in item light : ItemTypes::LightSignal;
        }

        port def RawSignalOutputPort {
            out item rawSignal : ItemTypes::RawOpticalSignal;
        }

        port def RawSignalInputPort {
            in item rawSignal : ItemTypes::RawOpticalSignal;
        }

        port def FilteredSignalOutputPort {
            out item filteredSignal : ItemTypes::FilteredSignal;
        }

        port def VitalSignsOutputPort {
            out item vitals : ItemTypes::VitalSigns;
        }

        port def VitalSignsInputPort {
            in item vitals : ItemTypes::VitalSigns;
        }

        port def PowerOutputPort {
            out item power : ItemTypes::ElectricalPower;
        }

        port def PowerInputPort {
            in item power : ItemTypes::ElectricalPower;
        }

        port def AlarmOutputPort {
            out item alarm : ItemTypes::AlarmEvent;
        }

        port def AlarmInputPort {
            in item alarm : ItemTypes::AlarmEvent;
        }
    }

    package Components {

        part def RedLED {
            port out lightOut : PortDefinitions::OpticalOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute wavelength : ValueTypes::WavelengthValue = 660;
            attribute driveCurrent : ValueTypes::CurrentValue = 12;
            attribute maxDriveCurrent : ValueTypes::CurrentValue = 15;
            attribute isEmitting : Boolean = false;

            action def emitLight {
                in power : ItemTypes::ElectricalPower;
                out light : ItemTypes::LightSignal;
            }

            perform emit : emitLight;
        }

        part def InfraredLED {
            port out lightOut : PortDefinitions::OpticalOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute wavelength : ValueTypes::WavelengthValue = 940;
            attribute driveCurrent : ValueTypes::CurrentValue = 12;
            attribute maxDriveCurrent : ValueTypes::CurrentValue = 15;
            attribute isEmitting : Boolean = false;

            action def emitLight {
                in power : ItemTypes::ElectricalPower;
                out light : ItemTypes::LightSignal;
            }

            perform emit : emitLight;
        }

        part def Photodetector {
            port in lightIn : PortDefinitions::OpticalInputPort;
            port out rawOut : PortDefinitions::RawSignalOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute sensitivity : Real = 0.85;
            attribute darkCurrent : ValueTypes::CurrentValue = 0.001;
            attribute responseTime : ValueTypes::TimeValue = 0.001;

            action def detectLight {
                in redLight : ItemTypes::LightSignal;
                in irLight : ItemTypes::LightSignal;
                out rawSignal : ItemTypes::RawOpticalSignal;
            }

            perform detect : detectLight;
        }

        part def FingerSensor {
            part redLED : RedLED;
            part irLED : InfraredLED;
            part photodetector : Photodetector;

            port out rawSignalOut : PortDefinitions::RawSignalOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute isAttached : Boolean = false;
            attribute fingerPresent : Boolean = false;
            attribute sensorType : String = "ReusableClip";

            connection redLightPath connect redLED.lightOut to photodetector.lightIn;
            connection irLightPath connect irLED.lightOut to photodetector.lightIn;
            connection rawSignalFeed connect photodetector.rawOut to rawSignalOut;

            action def sensePatient {
                in power : ItemTypes::ElectricalPower;
                out rawSignal : ItemTypes::RawOpticalSignal;

                flow from power to redLED.powerIn.power;
                flow from power to irLED.powerIn.power;
                flow from redLED.lightOut.light to photodetector.lightIn.light;
                flow from irLED.lightOut.light to photodetector.lightIn.light;
                flow from photodetector.rawOut.rawSignal to rawSignal;
            }

            perform sense : sensePatient;
        }

        part def SignalProcessor {
            port in rawIn : PortDefinitions::RawSignalInputPort;
            port out vitalsOut : PortDefinitions::VitalSignsOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute samplingRate : ValueTypes::FrequencyValue = 100;
            attribute filterLowCutoff : ValueTypes::FrequencyValue = 0.5;
            attribute filterHighCutoff : ValueTypes::FrequencyValue = 5.0;
            attribute calibrationFactor : Real = 1.0;
            attribute processingLatency : ValueTypes::TimeValue = 0.5;

            action def filterNoise {
                in raw : ItemTypes::RawOpticalSignal;
                out filtered : ItemTypes::FilteredSignal;
            }

            action def computeSpO2 {
                in filtered : ItemTypes::FilteredSignal;
                out spo2 : ValueTypes::SpO2Value;
            }

            action def computePulseRate {
                in filtered : ItemTypes::FilteredSignal;
                out pulseRate : ValueTypes::PulseRateValue;
            }

            action def assembleVitals {
                in spo2 : ValueTypes::SpO2Value;
                in pulseRate : ValueTypes::PulseRateValue;
                in filtered : ItemTypes::FilteredSignal;
                out vitals : ItemTypes::VitalSigns;
            }

            action def processingPipeline {
                in raw : ItemTypes::RawOpticalSignal;
                out vitals : ItemTypes::VitalSigns;

                flow from raw to filterNoise.raw;
                flow from filterNoise.filtered to computeSpO2.filtered;
                flow from filterNoise.filtered to computePulseRate.filtered;
                flow from filterNoise.filtered to assembleVitals.filtered;
                flow from computeSpO2.spo2 to assembleVitals.spo2;
                flow from computePulseRate.pulseRate to assembleVitals.pulseRate;
                flow from assembleVitals.vitals to vitals;
            }

            perform pipeline : processingPipeline;
        }

        part def DisplayModule {
            port in vitalsIn : PortDefinitions::VitalSignsInputPort;
            port in alarmIn : PortDefinitions::AlarmInputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute spo2Display : ValueTypes::SpO2Value;
            attribute pulseRateDisplay : ValueTypes::PulseRateValue;
            attribute plethWaveformDisplay : Real[*] ordered;
            attribute backlightEnabled : Boolean = true;
            attribute displayRefreshRate : ValueTypes::FrequencyValue = 60;
            attribute screenType : String = "LCD";

            action def renderNumericValues {
                in vitals : ItemTypes::VitalSigns;
            }

            action def renderPlethWaveform {
                in vitals : ItemTypes::VitalSigns;
            }

            action def renderAlarmIndicator {
                in alarm : ItemTypes::AlarmEvent;
            }

            action def updateDisplay {
                in vitals : ItemTypes::VitalSigns;
                in alarm : ItemTypes::AlarmEvent;

                flow from vitals to renderNumericValues.vitals;
                flow from vitals to renderPlethWaveform.vitals;
                flow from alarm to renderAlarmIndicator.alarm;
            }

            perform update : updateDisplay;
        }

        part def AlarmSubsystem {
            port in vitalsIn : PortDefinitions::VitalSignsInputPort;
            port out alarmOut : PortDefinitions::AlarmOutputPort;
            port in powerIn : PortDefinitions::PowerInputPort;

            attribute spo2CriticalThreshold : ValueTypes::SpO2Value = 85;
            attribute spo2WarningThreshold : ValueTypes::SpO2Value = 90;
            attribute pulseRateHighThreshold : ValueTypes::PulseRateValue = 120;
            attribute pulseRateLowThreshold : ValueTypes::PulseRateValue = 50;
            attribute currentSpo2 : ValueTypes::SpO2Value = 98;
            attribute currentPulseRate : ValueTypes::PulseRateValue = 72;
            attribute currentSeverity : ItemTypes::SeverityKind = ItemTypes::SeverityKind::normal;
            attribute audibleAlarmEnabled : Boolean = true;
            attribute visualAlarmEnabled : Boolean = true;
            attribute alarmDelay : ValueTypes::TimeValue = 5;

            state def AlarmStateBehavior {
                entry; then Normal;

                state Normal {
                    entry {
                        currentSeverity = ItemTypes::SeverityKind::normal;
                    }
                }

                state Warning {
                    entry {
                        currentSeverity = ItemTypes::SeverityKind::warning;
                    }
                }

                state Critical {
                    entry {
                        currentSeverity = ItemTypes::SeverityKind::critical;
                    }
                }

                transition on Normal to Warning
                    when currentSpo2 < spo2WarningThreshold and currentSpo2 >= spo2CriticalThreshold;

                transition on Normal to Critical
                    when currentSpo2 < spo2CriticalThreshold;

                transition on Normal to Warning
                    when currentPulseRate > pulseRateHighThreshold or currentPulseRate < pulseRateLowThreshold;

                transition on Warning to Critical
                    when currentSpo2 < spo2CriticalThreshold;

                transition on Warning to Normal
                    when currentSpo2 >= spo2WarningThreshold and currentPulseRate <= pulseRateHighThreshold and currentPulseRate >= pulseRateLowThreshold;

                transition on Critical to Warning
                    when currentSpo2 >= spo2CriticalThreshold and currentSpo2 < spo2WarningThreshold;

                transition on Critical to Normal
                    when currentSpo2 >= spo2WarningThreshold and currentPulseRate <= pulseRateHighThreshold and currentPulseRate >= pulseRateLowThreshold;
            }

            exhibit alarmStates : AlarmStateBehavior;

            action def evaluateThresholds {
                in vitals : ItemTypes::VitalSigns;
                out alarm : ItemTypes::AlarmEvent;
            }

            action def activateAudibleAlarm {
                in alarm : ItemTypes::AlarmEvent;
            }

            action def activateVisualAlarm {
                in alarm : ItemTypes::AlarmEvent;
            }

            perform evaluate : evaluateThresholds;
            perform audible : activateAudibleAlarm;
            perform visual : activateVisualAlarm;
        }

        part def Battery {
            port out powerOut : PortDefinitions::PowerOutputPort;

            attribute capacity : ValueTypes::CurrentValue = 2000;
            attribute currentLevel : ValueTypes::BatteryLevelValue = 100;
            attribute nominalVoltage : ValueTypes::VoltageValue = 3.7;
            attribute isCharging : Boolean = false;
            attribute isPresent : Boolean = true;
            attribute cycleCount : Integer = 0;

            state def BatteryStateBehavior {
                entry; then Discharging;

                state Discharging;
                state Charging;
                state Depleted;

                transition on Discharging to Charging
                    when isCharging == true;

                transition on Charging to Discharging
                    when isCharging == false and currentLevel > 0;

                transition on Discharging to Depleted
                    when currentLevel <= 0;

                transition on Depleted to Charging
                    when isCharging == true;
            }

            exhibit batteryStates : BatteryStateBehavior;

            action def supplyPower {
                out power : ItemTypes::ElectricalPower;
            }

            perform supply : supplyPower;
        }

        part def PowerSubsystem {
            part battery : Battery;
            port out powerOut : PortDefinitions::PowerOutputPort;

            attribute estimatedRuntime : ValueTypes::TimeValue = 14400;
            attribute chargingCircuitActive : Boolean = false;
            attribute powerManagementEnabled : Boolean = true;

            connection powerDistribution connect battery.powerOut to powerOut;
        }

        part def NellcorPulseOximeter {
            part fingerSensor : FingerSensor;
            part signalProcessor : SignalProcessor;
            part display : DisplayModule;
            part alarmSubsystem : AlarmSubsystem;
            part powerSubsystem : PowerSubsystem;

            port out systemAlarmOut : PortDefinitions::AlarmOutputPort;
            port out systemVitalsOut : PortDefinitions::VitalSignsOutputPort;
            port in systemPowerIn : PortDefinitions::PowerInputPort;

            attribute deviceSerialNumber : String;
            attribute deviceModel : String = "Nellcor";
            attribute firmwareVersion : String = "1.0";
            attribute isPowered : Boolean = false;
            attribute systemActive : Boolean = false;

            connection rawSignalFeed connect fingerSensor.rawSignalOut to signalProcessor.rawIn;
            connection vitalsToDisplay connect signalProcessor.vitalsOut to display.vitalsIn;
            connection vitalsToAlarm connect signalProcessor.vitalsOut to alarmSubsystem.vitalsIn;
            connection vitalsToSystem connect signalProcessor.vitalsOut to systemVitalsOut;
            connection alarmToDisplay connect alarmSubsystem.alarmOut to display.alarmIn;
            connection alarmToSystem connect alarmSubsystem.alarmOut to systemAlarmOut;

            connection powerToSensor connect powerSubsystem.powerOut to fingerSensor.powerIn;
            connection powerToProcessor connect powerSubsystem.powerOut to signalProcessor.powerIn;
            connection powerToDisplay connect powerSubsystem.powerOut to display.powerIn;
            connection powerToAlarm connect powerSubsystem.powerOut to alarmSubsystem.powerIn;

            state def SystemOperationStates {
                entry; then Off;

                state Off;
                state Standby;
                state Monitoring;
                state AlarmActive;

                transition on Off to Standby
                    when isPowered == true;

                transition on Standby to Off
                    when isPowered == false;

                transition on Standby to Monitoring
                    when fingerSensor.fingerPresent == true;

                transition on Monitoring to Standby
                    when fingerSensor.fingerPresent == false;

                transition on Monitoring to AlarmActive
                    when alarmSubsystem.currentSeverity != ItemTypes::SeverityKind::normal;

                transition on AlarmActive to Monitoring
                    when alarmSubsystem.currentSeverity == ItemTypes::SeverityKind::normal;
            }

            exhibit systemStates : SystemOperationStates;
        }
    }

    package Requirements {

        requirement def MeasurementAccuracyRequirement {
            attribute id : String = "REQ-001";
            text = "The pulse oximeter shall measure SpO2 with an accuracy of plus or minus 2 percent for saturations between 70 and 100 percent.";
        }

        requirement def PulseRateAccuracyRequirement {
            attribute id : String = "REQ-002";
            text = "The pulse oximeter shall measure pulse rate with an accuracy of plus or minus 3 beats per minute for rates between 30 and 250 bpm.";
        }

        requirement def AlarmActivationRequirement {
            attribute id : String = "REQ-003";
            text = "The system shall activate both audible and visual alarms within 5 seconds when SpO2 falls below 85 percent or pulse rate exceeds 120 bpm or falls below 50 bpm.";
        }

        requirement def AlarmSeverityRequirement {
            attribute id : String = "REQ-004";
            text = "The system shall differentiate between critical alarms for low oxygen saturation and warning alarms for abnormal pulse rate.";
        }

        requirement def BatteryLifeRequirement {
            attribute id : String = "REQ-005";
            text = "The rechargeable battery shall support continuous monitoring for at least 4 hours on a single charge.";
        }

        requirement def PatientSafetyRequirement {
            attribute id : String = "REQ-006";
            text = "The optical sensor shall not exceed 15 milliamperes of drive current to either LED to ensure patient tissue safety.";
        }

        requirement def DisplayRequirement {
            attribute id : String = "REQ-007";
            text = "The display shall show numeric SpO2 and pulse rate values and a plethysmographic waveform updated at least once per second.";
        }

        requirement def ReliabilityRequirement {
            attribute id : String = "REQ-008";
            text = "The device shall maintain continuous operation for at least 10000 hours of cumulative monitoring without component failure.";
        }

        requirement def ContinuousMonitoringRequirement {
            attribute id : String = "REQ-009";
            text = "The system shall provide continuous non-invasive monitoring of arterial oxygen saturation and pulse rate.";
        }

        requirement def SignalProcessingRequirement {
            attribute id : String = "REQ-010";
            text = "The signal processor shall filter noise from the raw optical signal and calculate SpO2 by analyzing differential absorption of red and infrared light.";
        }

        part def OximeterVerification {
            part oximeter : Components::NellcorPulseOximeter;

            satisfy MeasurementAccuracyRequirement by oximeter.signalProcessor;
            satisfy PulseRateAccuracyRequirement by oximeter.signalProcessor;
            satisfy AlarmActivationRequirement by oximeter.alarmSubsystem;
            satisfy AlarmSeverityRequirement by oximeter.alarmSubsystem;
            satisfy BatteryLifeRequirement by oximeter.powerSubsystem;
            satisfy PatientSafetyRequirement by oximeter.fingerSensor;
            satisfy DisplayRequirement by oximeter.display;
            satisfy ReliabilityRequirement by oximeter;
            satisfy ContinuousMonitoringRequirement by oximeter;
            satisfy SignalProcessingRequirement by oximeter.signalProcessor;
        }
    }
}

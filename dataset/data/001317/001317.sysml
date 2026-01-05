package WheelSpeedSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    enum def SensorStatus {
        enum operational;
        enum degraded;
        enum failed;
        enum initializing;
    }

    enum def SensorType {
        enum magneticInductive;
        enum hallEffect;
        enum activeABS;
    }

    item def WheelSpeedData {
        attribute angularVelocity : ISQ::AngularVelocityValue;
        attribute linearSpeed : ISQ::SpeedValue;
        attribute timestamp : DateTime;
        attribute sensorId : String;
        attribute quality : Real;
    }

    item def RawPulseSignal {
        attribute pulseFrequency : ISQ::FrequencyValue;
        attribute signalVoltage : Real;
        attribute timestamp : DateTime;
    }

    port def SpeedDataOutputPort {
        out item speedData : WheelSpeedData;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : Real;
        in attribute groundReference : Real;
    }

    port def DiagnosticOutputPort {
        out attribute status : SensorStatus;
        out attribute faultCode : Integer;
        out attribute temperature : ISQ::TemperatureValue;
    }

    port def RawSignalPort {
        out item pulseSignal : RawPulseSignal;
    }

    port def ProcessedSignalPort {
        in item pulseSignal : RawPulseSignal;
        out item speedData : WheelSpeedData;
    }

    connection def SignalConnection {
        end source : RawSignalPort[1];
        end destination : ProcessedSignalPort[1];
    }

    part def ToneRing {
        attribute numberOfTeeth : Integer;
        attribute diameter : ISQ::LengthValue;
        attribute material : String;
        attribute rotationalSpeed : ISQ::AngularVelocityValue;

        perform action generateMagneticPattern {
            out magneticFieldVariation;
        }
    }

    part def SensingElement {
        attribute sensorType : SensorType;
        attribute sensitivity : Real;
        attribute airGap : ISQ::LengthValue;
        attribute operatingTemperature : ISQ::TemperatureValue;

        port rawOutputPort : RawSignalPort;

        perform action detectMagneticField {
            in fieldVariation;
            out pulseSignal : RawPulseSignal;
        }
    }

    part def SignalConditioner {
        attribute amplificationGain : Real;
        attribute filterCutoffFrequency : ISQ::FrequencyValue;
        attribute noiseThreshold : Real;

        port inputPort {
            in item rawSignal : RawPulseSignal;
        }

        port outputPort {
            out item conditionedSignal : RawPulseSignal;
        }

        perform action amplifySignal {
            in rawInput : RawPulseSignal;
            out amplifiedOutput : RawPulseSignal;
        }

        perform action filterNoise {
            in noisyInput : RawPulseSignal;
            out cleanOutput : RawPulseSignal;
        }
    }

    part def SpeedCalculator {
        attribute wheelRadius : ISQ::LengthValue;
        attribute teethCount : Integer;
        attribute calibrationFactor : Real;

        port signalInputPort {
            in item pulseData : RawPulseSignal;
        }

        port speedOutputPort {
            out item calculatedSpeed : WheelSpeedData;
        }

        perform action calculateAngularVelocity {
            in pulseFreq : ISQ::FrequencyValue;
            in teeth : Integer;
            out angularVel : ISQ::AngularVelocityValue;
        }

        perform action calculateLinearSpeed {
            in angularVel : ISQ::AngularVelocityValue;
            in radius : ISQ::LengthValue;
            out linearVel : ISQ::SpeedValue;
        }

        perform action assembleSpeedData {
            in angularVel : ISQ::AngularVelocityValue;
            in linearVel : ISQ::SpeedValue;
            out speedData : WheelSpeedData;
        }
    }

    part def SensorHousing {
        attribute material : String;
        attribute protectionRating : String;
        attribute mountingType : String;
        attribute cableLength : ISQ::LengthValue;

        part connector {
            attribute connectorType : String;
            attribute pinCount : Integer;
            attribute sealingType : String;
        }

        part mountingBracket {
            attribute bracketMaterial : String;
            attribute threadSize : String;
        }
    }

    action def MeasureWheelSpeed {
        in toneRingTeeth : Integer;
        in wheelRadius : ISQ::LengthValue;
        out measuredSpeed : WheelSpeedData;

        action detectPulses {
            out rawPulses : RawPulseSignal;
        }

        then action conditionSignal {
            in rawPulses : RawPulseSignal;
            out cleanPulses : RawPulseSignal;
        }

        then action computeAngularSpeed {
            in cleanPulses : RawPulseSignal;
            in teeth : Integer;
            out angularSpeed : ISQ::AngularVelocityValue;
        }

        then action computeLinearSpeed {
            in angularSpeed : ISQ::AngularVelocityValue;
            in radius : ISQ::LengthValue;
            out linearSpeed : ISQ::SpeedValue;
        }

        then action packageData {
            in angularSpeed : ISQ::AngularVelocityValue;
            in linearSpeed : ISQ::SpeedValue;
            out speedData : WheelSpeedData;
        }

        flow from detectPulses.rawPulses to conditionSignal.rawPulses;
        flow from conditionSignal.cleanPulses to computeAngularSpeed.cleanPulses;
        flow from computeAngularSpeed.angularSpeed to computeLinearSpeed.angularSpeed;
        flow from computeAngularSpeed.angularSpeed to packageData.angularSpeed;
        flow from computeLinearSpeed.linearSpeed to packageData.linearSpeed;
        flow from packageData.speedData to measuredSpeed;
    }

    action def PerformDiagnostics {
        out diagnosticStatus : SensorStatus;
        out faultCode : Integer;

        action checkPowerSupply {
            out powerOk : Boolean;
        }

        then action checkSignalQuality {
            out signalOk : Boolean;
        }

        then action checkTemperature {
            out tempOk : Boolean;
        }

        then action evaluateOverallStatus {
            in powerStatus : Boolean;
            in signalStatus : Boolean;
            in temperatureStatus : Boolean;
            out overallStatus : SensorStatus;
            out fault : Integer;
        }

        flow from checkPowerSupply.powerOk to evaluateOverallStatus.powerStatus;
        flow from checkSignalQuality.signalOk to evaluateOverallStatus.signalStatus;
        flow from checkTemperature.tempOk to evaluateOverallStatus.temperatureStatus;
        flow from evaluateOverallStatus.overallStatus to diagnosticStatus;
        flow from evaluateOverallStatus.fault to faultCode;
    }

    part def WheelSpeedSensor {
        attribute sensorId : String;
        attribute wheelPosition : String;
        attribute nominalAirGap : ISQ::LengthValue;
        attribute maxOperatingSpeed : ISQ::AngularVelocityValue;
        attribute minOperatingSpeed : ISQ::AngularVelocityValue;
        attribute measurementAccuracy : Real;
        attribute responseTime : Real;
        attribute operatingVoltageMin : Real;
        attribute operatingVoltageMax : Real;
        attribute currentConsumption : Real;

        port dataPort : SpeedDataOutputPort;
        port powerPort : PowerInputPort;
        port diagnosticPort : DiagnosticOutputPort;

        part sensingElement : SensingElement[1] {
            attribute :>> sensorType = SensorType::magneticInductive;
            attribute :>> sensitivity = 0.95;
        }

        part signalConditioner : SignalConditioner[1] {
            attribute :>> amplificationGain = 10.0;
            attribute :>> noiseThreshold = 0.05;
        }

        part speedCalculator : SpeedCalculator[1] {
            attribute :>> teethCount = 48;
            attribute :>> calibrationFactor = 1.0;
        }

        part housing : SensorHousing[1] {
            attribute :>> material = "Stainless Steel 316";
            attribute :>> protectionRating = "IP67";
            attribute :>> mountingType = "M12 Threaded";
        }

        part toneRing : ToneRing[1] {
            attribute :>> numberOfTeeth = 48;
            attribute :>> material = "Ferromagnetic Steel";
        }

        connection signalPath : SignalConnection
            connect source references sensingElement.rawOutputPort
            to destination references signalConditioner.inputPort;

        perform action measureSpeed : MeasureWheelSpeed {
            in toneRingTeeth = toneRing.numberOfTeeth;
            in wheelRadius = speedCalculator.wheelRadius;
            out measuredSpeed;
        }

        perform action diagnostics : PerformDiagnostics {
            out diagnosticStatus;
            out faultCode;
        }

        exhibit state sensorOperationalStates {
            entry action initialize;

            state powerOff;

            state initializing {
                entry diagnostics;
            }

            state operational {
                do measureSpeed;

                state idle {
                    entry action enterIdleMode;
                }

                state measuring {
                    entry action startContinuousMeasurement;
                    do action performMeasurement;
                    exit action stopMeasurement;
                }

                transition idle_to_measuring
                    first idle
                    accept when toneRing.rotationalSpeed
                    then measuring;

                transition measuring_to_idle
                    first measuring
                    accept after 1.0[s]
                    then idle;
            }

            state fault {
                entry action logFaultCondition;
                do action attemptSelfRecovery;
            }

            transition powerOff_to_initializing
                first powerOff
                accept when powerPort.supplyVoltage >= operatingVoltageMin
                then initializing;

            transition initializing_to_operational
                first initializing
                accept when diagnostics.diagnosticStatus == SensorStatus::operational
                then operational;

            transition initializing_to_fault
                first initializing
                accept when diagnostics.diagnosticStatus == SensorStatus::failed
                then fault;

            transition operational_to_fault
                first operational
                accept when diagnostics.diagnosticStatus == SensorStatus::failed
                then fault;

            transition fault_to_initializing
                first fault
                accept after 3.0[s]
                then initializing;

            transition operational_to_powerOff
                first operational
                accept when powerPort.supplyVoltage < operatingVoltageMin
                then powerOff;
        }
    }

    part def WheelSpeedSensingUnit {
        attribute unitId : String;
        attribute installationDate : DateTime;
        attribute calibrationDate : DateTime;

        part sensor : WheelSpeedSensor[1];

        port speedOutput : SpeedDataOutputPort;
        port powerInput : PowerInputPort;
        port diagnosticOutput : DiagnosticOutputPort;

        connect sensor.dataPort to speedOutput;
        connect sensor.powerPort to powerInput;
        connect sensor.diagnosticPort to diagnosticOutput;
    }

    part wheelSpeedSensingUnit : WheelSpeedSensingUnit {
        attribute :>> unitId = "WSU_FL_001";

        part :>> sensor {
            attribute :>> sensorId = "WSS_FL_001";
            attribute :>> wheelPosition = "Front Left";
            attribute :>> measurementAccuracy = 0.98;
            attribute :>> responseTime = 0.003;
            attribute :>> currentConsumption = 0.020;
            attribute :>> operatingVoltageMin = 9.0;
            attribute :>> operatingVoltageMax = 16.0;
        }
    }

    requirement def AccuracyRequirement {
        doc /* The wheel speed sensing unit shall measure wheel angular velocity with accuracy of at least 98% over the full operating range. */

        subject sensingUnit : WheelSpeedSensingUnit;

        require constraint {
            sensingUnit.sensor.measurementAccuracy >= 0.98
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The wheel speed sensing unit shall provide speed measurements with response time not exceeding 5 milliseconds. */

        subject sensingUnit : WheelSpeedSensingUnit;

        require constraint {
            sensingUnit.sensor.responseTime <= 0.005
        }
    }

    requirement def EnvironmentalProtectionRequirement {
        doc /* The wheel speed sensing unit shall provide IP67 environmental protection rating for operation in harsh automotive conditions. */

        subject sensingUnit : WheelSpeedSensingUnit;

        require constraint {
            sensingUnit.sensor.housing.protectionRating == "IP67"
        }
    }

    requirement accuracyReq : AccuracyRequirement {
        subject unit references wheelSpeedSensingUnit;
    }

    requirement responseReq : ResponseTimeRequirement {
        subject unit references wheelSpeedSensingUnit;
    }

    requirement environmentalReq : EnvironmentalProtectionRequirement {
        subject unit references wheelSpeedSensingUnit;
    }
}

package TorqueSensingUnit {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----

    value def TorqueValue :> Real {
        unit TorqueUnit;
    }
    unit TorqueUnit : N*m;

    value def VoltageValue :> Real {
        unit VoltageUnit;
    }
    unit VoltageUnit : V;

    value def AngularVelocityValue :> Real {
        unit AngularVelocityUnit;
    }
    unit AngularVelocityUnit : rad/s;

    value def TemperatureValue :> Real {
        unit TemperatureUnit;
    }
    unit TemperatureUnit : degC;

    value def FrequencyValue :> Real {
        unit FrequencyUnit;
    }
    unit FrequencyUnit : Hz;

    value def DigitalCount :> Integer;

    value def TimeStamp :> Real {
        unit TimeStampUnit;
    }
    unit TimeStampUnit : s;

    // ---- Enumerations ----

    enum def OperationalMode {
        STARTUP;
        SELF_TEST;
        NORMAL_OPERATION;
        CALIBRATION;
        OVERLOAD_PROTECTION;
        ERROR;
    }

    enum def DataValidity {
        VALID;
        INVALID;
        SUSPECT;
    }

    enum def CalibrationCommand {
        ZERO_CAL;
        SPAN_CAL;
        APPLY_REFERENCE;
        COMMIT;
        ABORT;
    }

    enum def StatusFlag {
        OK;
        OVERLOAD;
        SELF_TEST_FAIL;
        CALIBRATION_ACTIVE;
        INTERNAL_FAULT;
    }

    // ---- Item definitions ----

    item def RawStrainSignal {
        attribute voltage : VoltageValue;
        attribute noiseLevel : VoltageValue;
    }

    item def ConditionedSignal {
        attribute voltage : VoltageValue;
        attribute bandwidth : FrequencyValue;
    }

    item def DigitalSample {
        attribute count : DigitalCount;
        attribute resolutionBits : Integer;
    }

    item def TemperatureReading {
        attribute temperature : TemperatureValue;
    }

    item def CalibrationData {
        attribute zeroOffset : DigitalCount;
        attribute sensitivity : Real;
        attribute tempCoefficient : Real;
        attribute referenceTemp : TemperatureValue;
    }

    item def TorqueMeasurement {
        attribute torque : TorqueValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute timestamp : TimeStamp;
        attribute validity : DataValidity;
        attribute status : StatusFlag;
    }

    item def DiagnosticReport {
        attribute mode : OperationalMode;
        attribute temperature : TemperatureValue;
        attribute status : StatusFlag;
        attribute cycleCount : Integer;
        attribute overloadEventCount : Integer;
    }

    item def CommandMessage {
        attribute command : CalibrationCommand;
        attribute referenceTorque : TorqueValue;
    }

    item def MechanicalTorque {
        attribute appliedTorque : TorqueValue;
        attribute shaftSpeed : AngularVelocityValue;
    }

    // ---- Port definitions ----

    port def MechanicalInterface {
        in item torqueInput : MechanicalTorque;
    }

    port def DataOutputPort {
        out item torqueStream : TorqueMeasurement;
    }

    port def DiagnosticPort {
        in item command : CommandMessage;
        out item report : DiagnosticReport;
    }

    // ---- Internal component definitions ----

    part def StrainGaugeBridge {
        attribute bridgeResistance : Real;
        attribute excitationVoltage : VoltageValue;
        attribute gaugeFactor : Real;
        in item mechanicalDeformation;
        out item rawSignal : RawStrainSignal;
        action def sense {
            in deformation;
            out signal : RawStrainSignal;
        }
    }

    part def SignalConditioner {
        attribute gain : Real;
        attribute filterCutoff : FrequencyValue;
        in item inputSignal : RawStrainSignal;
        out item outputSignal : ConditionedSignal;
        action def amplifyAndFilter {
            in raw : RawStrainSignal;
            out conditioned : ConditionedSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer;
        attribute sampleRate : FrequencyValue;
        attribute inputRange : VoltageValue;
        in item analogInput : ConditionedSignal;
        out item digitalOutput : DigitalSample;
        action def convert {
            in analog : ConditionedSignal;
            out digital : DigitalSample;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : TemperatureValue;
        in item ambient;
        out item reading : TemperatureReading;
        action def measureTemperature {
            out temp : TemperatureReading;
        }
    }

    part def SignalProcessor {
        attribute clockFrequency : FrequencyValue;
        attribute storedCalibration : CalibrationData;
        in item digitalSample : DigitalSample;
        in item temperature : TemperatureReading;
        in item command : CommandMessage;
        out item measurement : TorqueMeasurement;
        out item report : DiagnosticReport;
        action def computeTorque {
            in sample : DigitalSample;
            in temp : TemperatureReading;
            in cal : CalibrationData;
            out result : TorqueMeasurement;
        }
        action def updateCalibration {
            in cmd : CommandMessage;
            inout cal : CalibrationData;
        }
    }

    part def MountingFlange {
        attribute flangeDiameter : Real;
        attribute boltCircleDiameter : Real;
        attribute boltCount : Integer;
        attribute boltSize : String;
    }

    part def Bolt {
        attribute size : String;
        attribute material : String;
        attribute tensileStrength : Real;
    }

    part def ShieldedCable {
        attribute length : Real;
        attribute conductorCount : Integer;
        attribute shieldingType : String;
        attribute ratedVoltage : VoltageValue;
    }

    part def RuggedConnector {
        attribute pinCount : Integer;
        attribute ingressProtection : String;
        attribute lockingMechanism : String;
    }

    // ---- Main assembly ----

    part def DynamicTorqueSensingUnit {

        attribute ratedTorque : TorqueValue = 1000 [N*m];
        attribute overloadThreshold : TorqueValue = 1200 [N*m];
        attribute operatingTempMin : TemperatureValue = -40 [degC];
        attribute operatingTempMax : TemperatureValue = 125 [degC];
        attribute serialNumber : String;

        port mechanicalInterface : MechanicalInterface;
        port dataOutput : DataOutputPort;
        port diagnostic : DiagnosticPort;

        part strainGaugeBridge : StrainGaugeBridge {
            attribute bridgeResistance = 350.0;
            attribute excitationVoltage = 5.0 [V];
            attribute gaugeFactor = 2.1;
        }

        part signalConditioner : SignalConditioner {
            attribute gain = 1000.0;
            attribute filterCutoff = 1000.0 [Hz];
        }

        part adc : AnalogToDigitalConverter {
            attribute resolutionBits = 24;
            attribute sampleRate = 10000.0 [Hz];
            attribute inputRange = 10.0 [V];
        }

        part temperatureSensor : TemperatureSensor {
            attribute accuracy = 0.5 [degC];
        }

        part signalProcessor : SignalProcessor {
            attribute clockFrequency = 80000000.0 [Hz];
            attribute storedCalibration : CalibrationData = CalibrationData {
                zeroOffset = 0;
                sensitivity = 1.0;
                tempCoefficient = 0.0001;
                referenceTemp = 25.0 [degC];
            };
        }

        part mountingFlange : MountingFlange {
            attribute flangeDiameter = 0.12;
            attribute boltCircleDiameter = 0.10;
            attribute boltCount = 8;
            attribute boltSize = "M8";
        }

        part bolts : Bolt[8] {
            attribute size = "M8";
            attribute material = "StainlessSteel";
            attribute tensileStrength = 800000000.0;
        }

        part cable : ShieldedCable {
            attribute length = 2.0;
            attribute conductorCount = 6;
            attribute shieldingType = "Braided";
            attribute ratedVoltage = 60.0 [V];
        }

        part connector : RuggedConnector {
            attribute pinCount = 6;
            attribute ingressProtection = "IP67";
            attribute lockingMechanism = "Bayonet";
        }

        // Internal connections
        connection strainToConditioner connect strainGaugeBridge.rawSignal to signalConditioner.inputSignal;
        connection conditionerToADC connect signalConditioner.outputSignal to adc.analogInput;
        connection adcToProcessor connect adc.digitalOutput to signalProcessor.digitalSample;
        connection tempToProcessor connect temperatureSensor.reading to signalProcessor.temperature;
        connection cmdToProcessor connect diagnostic.command to signalProcessor.command;
        connection processorToOutput connect signalProcessor.measurement to dataOutput.torqueStream;
        connection processorToDiagnostic connect signalProcessor.report to diagnostic.report;

        // ---- State machine ----

        state def TorqueSensingStateMachine {

            state startup {
                entry action {
                    // Initialize subsystems
                }
                do action initializeSubsystems {
                    // Power up strain gauge bridge, signal conditioner, ADC, processor
                }
                transition to selfTest
                    when (true);
            }

            state selfTest {
                entry action {
                    // Begin self-test sequence
                }
                do action performSelfTest {
                    // Verify strain gauge bridge continuity
                    // Verify ADC conversion
                    // Verify temperature sensor
                    // Verify processor memory
                }
                transition to normalOperation
                    when (selfTestPassed == true);
                transition to errorState
                    when (selfTestPassed == false);
            }

            state normalOperation {
                entry action {
                    // Enter continuous measurement loop
                }
                do action continuousMeasurement {
                    // Acquire strain signal
                    // Condition and digitize
                    // Apply calibration and temperature compensation
                    // Emit TorqueMeasurement on dataOutput
                }
                transition to calibrationMode
                    when (calibrationRequested == true);
                transition to overloadProtection
                    when (measuredTorque > overloadThreshold);
                transition to errorState
                    when (internalFaultDetected == true);
            }

            state calibrationMode {
                entry action {
                    // Suspend normal output, mark status as CALIBRATION_ACTIVE
                }
                do action performCalibration {
                    // Accept zero/span commands via diagnostic port
                    // Apply reference torque
                    // Update storedCalibration
                }
                transition to normalOperation
                    when (calibrationComplete == true);
                transition to errorState
                    when (calibrationFailure == true);
            }

            state overloadProtection {
                entry action {
                    // Disable dataOutput, set status OVERLOAD
                }
                do action monitorOverload {
                    // Continue monitoring torque
                    // Increment overloadEventCount
                }
                transition to normalOperation
                    when (measuredTorque < (overloadThreshold * 0.9));
                transition to errorState
                    when (overloadDurationExceeded == true);
            }

            state errorState {
                entry action {
                    // Disable output, set status INTERNAL_FAULT
                }
                do action reportFault {
                    // Emit diagnostic report with fault details
                }
                transition to startup
                    when (resetCommandReceived == true);
            }
        }

        // Behavioral attributes used by state machine
        attribute selfTestPassed : Boolean;
        attribute calibrationRequested : Boolean;
        attribute calibrationComplete : Boolean;
        attribute calibrationFailure : Boolean;
        attribute measuredTorque : TorqueValue;
        attribute internalFaultDetected : Boolean;
        attribute overloadDurationExceeded : Boolean;
        attribute resetCommandReceived : Boolean;

        exhibit state behavior TorqueSensingStateMachine;

        // ---- Requirements ----

        requirement def TorqueMeasurementAccuracy {
            doc "The sensing unit shall measure torque within ±0.1% of rated torque under specified operating conditions."
            attribute accuracyPercent : Real = 0.1;
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def OverloadProtectionRequirement {
            doc "The sensing unit shall enter overload protection mode when measured torque exceeds 120% of rated torque."
            attribute overloadFactor : Real = 1.2;
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def TemperatureCompensationRequirement {
            doc "The sensing unit shall compensate torque measurements for temperature variations using an integrated temperature sensor."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def DataStreamRequirement {
            doc "The sensing unit shall provide a continuous real-time data stream containing torque, angular velocity, timestamp, and validity flag."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def SelfTestRequirement {
            doc "The sensing unit shall perform a self-test upon startup and enter error state if the self-test fails."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def CalibrationModeRequirement {
            doc "The sensing unit shall support zero and span calibration via the diagnostic port."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def MechanicalInterfaceRequirement {
            doc "The sensing unit shall include a mounting flange with a standard bolt pattern suitable for engine test stands and dynamometers."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        requirement def ElectricalInterfaceRequirement {
            doc "The sensing unit shall include a shielded cable with a rugged connector rated IP67 or better."
            subject sensingUnit : DynamicTorqueSensingUnit;
        }

        // Requirement satisfactions
        satisfy TorqueMeasurementAccuracy by signalProcessor.computeTorque;
        satisfy OverloadProtectionRequirement by TorqueSensingStateMachine.overloadProtection;
        satisfy TemperatureCompensationRequirement by temperatureSensor;
        satisfy DataStreamRequirement by dataOutput;
        satisfy SelfTestRequirement by TorqueSensingStateMachine.selfTest;
        satisfy CalibrationModeRequirement by TorqueSensingStateMachine.calibrationMode;
        satisfy MechanicalInterfaceRequirement by mountingFlange;
        satisfy ElectricalInterfaceRequirement by cable;
    }
}

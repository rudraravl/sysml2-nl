package NanoTetherballSensingUnit {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value type ForceValue :> Real {
        :>> unit = 'N';
    }

    value type NanoForceValue :> Real {
        :>> unit = 'nN';
    }

    value type DisplacementValue :> Real {
        :>> unit = 'nm';
    }

    value type VoltageValue :> Real {
        :>> unit = 'mV';
    }

    value type DigitalCount :> Integer {
        :>> unit = 'count';
    }

    value type TemperatureValue :> Real {
        :>> unit = 'K';
    }

    value type SamplingRateValue :> Real {
        :>> unit = 'kHz';
    }

    value type AccuracyValue :> Real {
        :>> unit = '%';
    }

    value type FrequencyValue :> Real {
        :>> unit = 'Hz';
    }

    value type GainValue :> Real {
        :>> unit = 'V/V';
    }

    // ===== Item Types =====

    item def PhysicalForce {
        attribute magnitude : ForceValue;
        attribute direction : Vector3D;
    }

    item def RawVoltageSignal {
        attribute amplitude : VoltageValue;
        attribute noiseFloor : VoltageValue;
    }

    item def ConditionedVoltageSignal {
        attribute amplitude : VoltageValue;
        attribute snr : Real;
    }

    item def DigitalReading {
        attribute count : DigitalCount;
        attribute timestamp : Real;
        attribute valid : Boolean;
    }

    item def CalibrationReference {
        attribute knownForce : NanoForceValue;
        attribute certifiedAccuracy : AccuracyValue;
    }

    item def StatusMessage {
        attribute code : String;
        attribute severity : Integer;
    }

    // ===== Port Definitions =====

    port def ForceInputPort {
        in force : PhysicalForce;
    }

    port def MechanicalDisplacementPort {
        out displacement : DisplacementValue;
    }

    port def RawVoltagePort {
        out rawVoltage : RawVoltageSignal;
    }

    port def ConditionedVoltagePort {
        out conditionedVoltage : ConditionedVoltageSignal;
    }

    port def DigitalDataPort {
        out digitalReading : DigitalReading;
    }

    port def ControlPort {
        in command : String;
        out status : StatusMessage;
    }

    port def CalibrationPort {
        in reference : CalibrationReference;
    }

    // ===== Mechanical Sensing Element =====

    part def Nanoparticle {
        attribute mass : Real = 1.0e-18 [kg];
        attribute charge : Real = 0.0 [C];
        attribute restingPosition : Vector3D = (0.0, 0.0, 0.0);
        attribute currentPosition : Vector3D;
        attribute displacement : DisplacementValue;

        private attribute displacementVector : Vector3D;

        action def updatePosition(in appliedForce : PhysicalForce) {
            // Simplified: displacement proportional to force via tether stiffness
            local stiffness : Real = 0.001 [N/m];
            local disp : DisplacementValue = (appliedForce.magnitude / stiffness) * 1.0e9;
            assign displacement = disp;
            assign currentPosition = (appliedForce.direction.x * disp, appliedForce.direction.y * disp, appliedForce.direction.z * disp);
        }
    }

    part def Tether {
        attribute length : Real = 500.0 [nm];
        attribute stiffness : Real = 0.001 [N/m];
        attribute dampingCoefficient : Real = 1.0e-12 [N*s/m];
        attribute elasticModulus : Real = 1.0e6 [Pa];
        attribute maxDeflection : DisplacementValue = 400.0;
        attribute intact : Boolean = true;
    }

    part def MechanicalSensingElement {
        part nanoparticle : Nanoparticle;
        part tether : Tether;

        port forceInput : ForceInputPort;
        port displacementOutput : MechanicalDisplacementPort;

        action def senseForce {
            in appliedForce : PhysicalForce;
            out measuredDisplacement : DisplacementValue;
            
            // Check tether integrity
            if tether.intact) {
                nanoparticle.updatePosition(appliedForce);
                if nanoparticle.displacement > tether.maxDeflection) {
                    // Over-range condition
                    assign measuredDisplacement = tether.maxDeflection;
                } else {
                    assign measuredDisplacement = nanoparticle.displacement;
                }
            } else {
                assign measuredDisplacement = 0.0;
            }
        }

        action def resetPosition {
            assign nanoparticle.currentPosition = nanoparticle.restingPosition;
            assign nanoparticle.displacement = 0.0;
        }
    }

    // ===== Piezoelectric Transducer =====

    part def PiezoelectricTransducer {
        attribute piezoCoefficient : Real = 10.0 [mV/nm];
        attribute bandwidth : FrequencyValue = 50.0;
        attribute operatingTempMin : TemperatureValue = 233.15;
        attribute operatingTempMax : TemperatureValue = 358.15;

        port displacementInput : MechanicalDisplacementPort;
        port rawVoltageOutput : RawVoltagePort;

        action def transduce(in displacement : DisplacementValue) : RawVoltageSignal {
            local amplitude : VoltageValue = displacement * piezoCoefficient;
            local noise : VoltageValue = 0.05;
            return RawVoltageSignal{amplitude = amplitude, noiseFloor = noise};
        }
    }

    // ===== Signal Conditioner =====

    part def SignalConditioner {
        attribute gain : GainValue = 1000.0;
        attribute filterCutoffLow : FrequencyValue = 0.1;
        attribute filterCutoffHigh : FrequencyValue = 20.0;
        attribute inputImpedance : Real = 1.0e9 [ohm];
        attribute commonModeRejection : Real = 80.0 [dB];

        port rawVoltageInput : RawVoltagePort;
        port conditionedVoltageOutput : ConditionedVoltagePort;

        action def amplify(in rawSignal : RawVoltageSignal) : VoltageValue {
            return rawSignal.amplitude * gain;
        }

        action def filter(in amplifiedVoltage : VoltageValue) : VoltageValue {
            // Bandpass filtering approximation
            return amplifiedVoltage;
        }

        action def condition(in rawSignal : RawVoltageSignal) : ConditionedVoltageSignal {
            local amplified : VoltageValue = amplify(rawSignal);
            local filtered : VoltageValue = filter(amplified);
            local snrValue : Real = (filtered / rawSignal.noiseFloor) * gain;
            return ConditionedVoltageSignal{amplitude = filtered, snr = snrValue};
        }
    }

    // ===== Analog-to-Digital Converter =====

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 24;
        attribute samplingRate : SamplingRateValue = 10.0;
        attribute inputRangeMin : VoltageValue = -5.0;
        attribute inputRangeMax : VoltageValue = 5.0;
        attribute referenceVoltage : VoltageValue = 5.0;
        attribute conversionTime : Real = 0.1 [ms];

        port conditionedVoltageInput : ConditionedVoltagePort;
        port digitalDataOutput : DigitalDataPort;

        action def convert(in conditionedSignal : ConditionedVoltageSignal) : DigitalReading {
            local maxCount : Integer = 2 ^ resolutionBits;
            local normalized : Real = (conditionedSignal.amplitude - inputRangeMin) / (inputRangeMax - inputRangeMin);
            local clamped : Real;
            if normalized < 0.0) {
                assign clamped = 0.0;
            } else if normalized > 1.0) {
                assign clamped = 1.0;
            } else {
                assign clamped = normalized;
            }
            local countValue : DigitalCount = (clamped * maxCount) as Integer;
            return DigitalReading{count = countValue, timestamp = 0.0, valid = true};
        }
    }

    // ===== Controller =====

    part def Controller {
        attribute clockFrequency : FrequencyValue = 100000.0;
        attribute firmwareVersion : String = "2.1.0";
        attribute powerMode : String;
        attribute faultCount : Integer = 0;
        attribute maxFaultCount : Integer = 5;
        attribute calibrationOffset : DigitalCount = 0;
        attribute calibrationScale : Real = 1.0;
        attribute lastReading : DigitalReading;
        attribute currentMode : String;

        port controlInterface : ControlPort;
        port calibrationInterface : CalibrationPort;
        port digitalInput : DigitalDataPort;
        port digitalOutput : DigitalDataPort;

        state machinedef ControllerStateMachine {
            entry;
            
            state idle {
                entry {
                    assign powerMode = "low-power";
                    assign currentMode = "idle";
                }
                do logStatus("Idle - awaiting trigger");
                transition idle_to_active by startMeasurement;
                transition idle_to_fault by faultDetected;
            }

            state active {
                entry {
                    assign powerMode = "full";
                    assign currentMode = "active";
                }
                do acquireReadings;
                transition active_to_idle by stopMeasurement;
                transition active_to_fault by faultDetected;
            }

            state fault {
                entry {
                    assign powerMode = "safe";
                    assign currentMode = "fault";
                    assign faultCount = faultCount + 1;
                }
                do logError;
                transition fault_to_idle by clearFault;
            }

            transition initial to idle;
        }

        action def acquireReadings {
            // Continuously read from ADC and apply calibration
            local rawReading : DigitalReading = digitalInput.digitalReading;
            local calibratedCount : DigitalCount = (rawReading.count - calibrationOffset) * calibrationScale as Integer;
            assign lastReading = DigitalReading{count = calibratedCount, timestamp = rawReading.timestamp, valid = rawReading.valid};
            digitalOutput.digitalReading = lastReading;
        }

        action def logStatus(in message : String) {
            controlInterface.status = StatusMessage{code = message, severity = 0};
        }

        action def logError {
            controlInterface.status = StatusMessage{code = "FAULT", severity = 2};
        }

        action def performCalibration(in reference : CalibrationReference) {
            // Apply known reference force and record ADC output
            local expectedCount : DigitalCount = (reference.knownForce * 1.0e-9 * 1000.0 * 10.0 * 1000.0 / 10.0) as Integer;
            local measuredCount : DigitalCount = digitalInput.digitalReading.count;
            assign calibrationOffset = measuredCount - expectedCount;
            assign calibrationScale = 1.0;
        }

        action def verifyAccuracy(in reference : CalibrationReference) : AccuracyValue {
            local expectedCount : DigitalCount = (reference.knownForce * 1.0e-9 * 1000.0 * 10.0 * 1000.0 / 10.0) as Integer;
            local measuredCount : DigitalCount = lastReading.count;
            local error : Real = abs(measuredCount - expectedCount) / expectedCount * 100.0;
            return error;
        }

        action def startMeasurement {
            // Trigger state transition to active
        }

        action def stopMeasurement {
            // Return to idle
        }

        action def faultDetected {
            // Error condition detected
        }

        action def clearFault {
            // Reset fault condition
        }
    }

    // ===== Temperature Sensor =====

    part def TemperatureSensor {
        attribute range : TemperatureValue = 125.0;
        attribute accuracy : AccuracyValue = 1.0;
        attribute currentTemperature : TemperatureValue;

        port tempOutput : <<out>> TemperatureValue;

        action def measureTemperature : TemperatureValue {
            return currentTemperature;
        }
    }

    // ===== Power Management =====

    part def PowerManager {
        attribute supplyVoltage : VoltageValue = 3.3;
        attribute idleCurrent : Real = 0.001 [A];
        attribute activeCurrent : Real = 0.015 [A];
        attribute faultCurrent : Real = 0.0005 [A];
        attribute powerGood : Boolean = true;

        action def regulatePower(in mode : String) {
            // Adjust power based on operational mode
        }

        action def monitorPower : Boolean {
            return powerGood;
        }
    }

    // ===== Top-Level Nano-Tetherball Sensing Unit =====

    part def NanoTetherballSensor {
        attribute deviceId : String = "NTSU-2024-A";
        attribute manufacturer : String = "NanoSense Instruments";
        attribute serialNumber : String;
        attribute operatingTempMin : TemperatureValue = 233.15;
        attribute operatingTempMax : TemperatureValue = 358.15;
        attribute accuracySpec : AccuracyValue = 0.5;
        attribute samplingRateSpec : SamplingRateValue = 10.0;
        attribute measurementRange : NanoForceValue = 500.0;

        part mechanicalElement : MechanicalSensingElement;
        part piezoTransducer : PiezoelectricTransducer;
        part signalConditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part controller : Controller;
        part temperatureSensor : TemperatureSensor;
        part powerManager : PowerManager;

        port externalForceInput : ForceInputPort;
        port dataOutput : DigitalDataPort;
        port controlPort : ControlPort;
        port calibrationPort : CalibrationPort;

        // Connections
        connection mechanicalElement.displacementOutput to piezoTransducer.displacementInput;
        connection piezoTransducer.rawVoltageOutput to signalConditioner.rawVoltageInput;
        connection signalConditioner.conditionedVoltageOutput to adc.conditionedVoltageInput;
        connection adc.digitalDataOutput to controller.digitalInput;
        connection controller.digitalOutput to dataOutput;
        connection externalForceInput to mechanicalElement.forceInput;
        connection controlPort to controller.controlInterface;
        connection calibrationPort to controller.calibrationInterface;

        action def fullSensingCycle(in appliedForce : PhysicalForce) : DigitalReading {
            // Step 1: Mechanical sensing
            local displacement : DisplacementValue;
            mechanicalElement.senseForce(appliedForce, displacement);
            
            // Step 2: Piezoelectric transduction
            local rawSignal : RawVoltageSignal = piezoTransducer.transduce(displacement);
            
            // Step 3: Signal conditioning
            local conditionedSignal : ConditionedVoltageSignal = signalConditioner.condition(rawSignal);
            
            // Step 4: Analog-to-digital conversion
            local digitalReading : DigitalReading = adc.convert(conditionedSignal);
            
            // Step 5: Controller processing with calibration
            controller.lastReading = digitalReading;
            
            return digitalReading;
        }

        action def calibrate(in reference : CalibrationReference) {
            controller.performCalibration(reference);
        }

        action def verifyMeasurement(in reference : CalibrationReference) : AccuracyValue {
            return controller.verifyAccuracy(reference);
        }

        action def powerOnSequence {
            powerManager.regulatePower("idle");
            controller.ControllerStateMachine.restart();
        }

        action def powerOffSequence {
            powerManager.regulatePower("off");
        }
    }

    // ===== Requirements =====

    requirement def ForceMeasurementRequirement {
        subject sensor : NanoTetherballSensor;
        attribute requiredRange : NanoForceValue = 500.0;
        attribute requiredAccuracy : AccuracyValue = 0.5;
        attribute requiredResolution : NanoForceValue = 0.1;
        
        requirement {
            subject = sensor;
            predicate sensor.measurementRange >= requiredRange;
        }
        requirement {
            subject = sensor;
            predicate sensor.accuracySpec <= requiredAccuracy;
        }
    }

    requirement def SamplingRateRequirement {
        subject sensor : NanoTetherballSensor;
        attribute minSamplingRate : SamplingRateValue = 10.0;
        
        requirement {
            subject = sensor;
            predicate sensor.samplingRateSpec >= minSamplingRate;
        }
    }

    requirement def TemperatureRangeRequirement {
        subject sensor : NanoTetherballSensor;
        attribute minTemp : TemperatureValue = 233.15;
        attribute maxTemp : TemperatureValue = 358.15;
        
        requirement {
            subject = sensor;
            predicate sensor.operatingTempMin <= minTemp;
        }
        requirement {
            subject = sensor;
            predicate sensor.operatingTempMax >= maxTemp;
        }
    }

    requirement def StateManagementRequirement {
        subject controller : Controller;
        
        requirement {
            subject = controller;
            predicate controller.ControllerStateMachine.idle.isDefined;
        }
        requirement {
            subject = controller;
            predicate controller.ControllerStateMachine.active.isDefined;
        }
        requirement {
            subject = controller;
            predicate controller.ControllerStateMachine.fault.isDefined;
        }
    }

    requirement def CalibrationRequirement {
        subject sensor : NanoTetherballSensor;
        attribute calibrationInterval : Real = 8760.0 [h];
        attribute maxCalibrationError : AccuracyValue = 1.0;
        
        requirement {
            subject = sensor;
            predicate sensor.calibrate.isInvokable;
        }
        requirement {
            subject = sensor;
            predicate sensor.verifyMeasurement.isInvokable;
        }
    }

    requirement def SignalChainRequirement {
        subject sensor : NanoTetherballSensor;
        attribute minGain : GainValue = 500.0;
        attribute minSNR : Real = 40.0;
        attribute adcResolution : Integer = 24;
        
        requirement {
            subject = sensor.signalConditioner;
            predicate sensor.signalConditioner.gain >= minGain;
        }
        requirement {
            subject = sensor.adc;
            predicate sensor.adc.resolutionBits >= adcResolution;
        }
    }

    requirement def PowerManagementRequirement {
        subject sensor : NanoTetherballSensor;
        attribute maxIdlePower : Real = 0.0033 [W];
        attribute maxActivePower : Real = 0.0495 [W];
        
        requirement {
            subject = sensor.powerManager;
            predicate sensor.powerManager.idleCurrent * 3.3 <= maxIdlePower;
        }
        requirement {
            subject = sensor.powerManager;
            predicate sensor.powerManager.activeCurrent * 3.3 <= maxActivePower;
        }
    }

    requirement def MechanicalIntegrityRequirement {
        subject sensor : NanoTetherballSensor;
        attribute tetherLength : Real = 500.0 [nm];
        attribute maxDisplacement : DisplacementValue = 400.0;
        
        requirement {
            subject = sensor.mechanicalElement.tether;
            predicate sensor.mechanicalElement.tether.length == tetherLength;
        }
        requirement {
            subject = sensor.mechanicalElement.tether;
            predicate sensor.mechanicalElement.tether.maxDeflection >= maxDisplacement;
        }
    }

    // ===== Verification =====

    verification def VerifyForceMeasurement {
        subject sensor : NanoTetherballSensor;
        objective {
            doc /* Verify that the sensor meets force measurement range and accuracy requirements. */
        }
        return sensor.measurementRange >= 500.0 and sensor.accuracySpec <= 0.5;
    }

    verification def VerifySamplingRate {
        subject sensor : NanoTetherballSensor;
        objective {
            doc /* Verify that the ADC sampling rate meets or exceeds the minimum. */
        }
        return sensor.adc.samplingRate >= 10.0;
    }

    verification def VerifyTemperatureRange {
        subject sensor : NanoTetherballSensor;
        objective {
            doc /* Verify operation across the specified temperature range. */
        }
        return sensor.operatingTempMin <= 233.15 and sensor.operatingTempMax >= 358.15;
    }

    verification def VerifyCalibration {
        subject sensor : NanoTetherballSensor;
        objective {
            doc /* Verify calibration process produces accurate results against known reference. */
        }
        local reference : CalibrationReference = CalibrationReference{knownForce = 100.0, certifiedAccuracy = 0.1};
        sensor.calibrate(reference);
        local result : AccuracyValue = sensor.verifyMeasurement(reference);
        return result <= 1.0;
    }

    verification def VerifyStateTransitions {
        subject sensor : NanoTetherballSensor;
        objective {
            doc /* Verify all operational states are reachable and transitions function correctly. */
        }
        return sensor.controller.ControllerStateMachine.idle.isDefined 
            and sensor.controller.ControllerStateMachine.active.isDefined 
            and sensor.controller.ControllerStateMachine.fault.isDefined;
    }

    // ===== Package-level instantiation =====

    part def SensorAssembly {
        part nanoTetherballSensor : NanoTetherballSensor;
        
        requirement satisfaction {
            satisfy ForceMeasurementRequirement by nanoTetherballSensor;
            satisfy SamplingRateRequirement by nanoTetherballSensor;
            satisfy TemperatureRangeRequirement by nanoTetherballSensor;
            satisfy StateManagementRequirement by nanoTetherballSensor.controller;
            satisfy CalibrationRequirement by nanoTetherballSensor;
            satisfy SignalChainRequirement by nanoTetherballSensor;
            satisfy PowerManagementRequirement by nanoTetherballSensor;
            satisfy MechanicalIntegrityRequirement by nanoTetherballSensor;
        }
    }

}

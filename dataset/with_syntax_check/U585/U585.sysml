package AccelerometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AccelerationVector {
        attribute x : AccelerationValue;
        attribute y : AccelerationValue;
        attribute z : AccelerationValue;
    }
    
    attribute def SensorStatus {
        attribute isCalibrated : Boolean;
        attribute isOperational : Boolean;
        attribute temperature : TemperatureValue;
    }
    
    attribute def SamplingRate :> Real;
    
    attribute def SensitivityLevel :> Real;
    
    attribute def CalibrationCommand;
    attribute def StopCommand;
    attribute def ResetCommand;
    
    port def AccelerationOutputPort {
        out acceleration : AccelerationVector;
        out status : SensorStatus;
    }
    
    port def PowerInputPort {
        in voltage : VoltageValue;
        in current : ElectricCurrentValue;
    }
    
    port def ControlInputPort {
        in samplingRate : SamplingRate;
        in sensitivity : SensitivityLevel;
    }
    
    part def SensingElement {
        attribute mass : MassValue;
        attribute springConstant : Real;
        attribute dampingCoefficient : Real;
        
        port mechanicalInput {
            in appliedAcceleration : AccelerationVector;
        }
        
        port mechanicalOutput {
            out displacement : LengthValue;
        }
    }
    
    part def SignalConditioner {
        port analogInput {
            in rawSignal : VoltageValue;
        }
        
        port analogOutput {
            out conditionedSignal : VoltageValue;
        }
        
        attribute gain : Real;
        attribute offset : VoltageValue;
    }
    
    part def AnalogToDigitalConverter {
        port analogInput {
            in analogSignal : VoltageValue;
        }
        
        port digitalOutput {
            out digitalValue : Real;
        }
        
        attribute resolution : Real;
        attribute conversionRate : SamplingRate;
    }
    
    part def DataProcessor {
        port digitalInput {
            in rawData : Real;
        }
        
        port dataOutput {
            out processedAcceleration : AccelerationVector;
        }
        
        attribute calibrationMatrix : Real[9];
        attribute offsetCorrection : AccelerationVector;
    }
    
    action def CalibrateAccelerometer {
        in currentStatus : SensorStatus;
        out calibratedStatus : SensorStatus;
        out calibrationData : Real[9];
        
        first start;
        then action collectStaticSamples {
            out staticReadings : Real[100];
        }
        then action computeOffsets {
            in readings = collectStaticSamples.staticReadings;
            out offsets : AccelerationVector;
        }
        then action computeScaleFactors {
            out scaleFactors : Real[3];
        }
        then action updateCalibration {
            in offsets = computeOffsets.offsets;
            in scales = computeScaleFactors.scaleFactors;
            out matrix : Real[9];
        }
        then assign calibrationData := updateCalibration.matrix;
        then done;
    }
    
    action def MeasureAcceleration {
        in samplingRate : SamplingRate;
        in sensitivity : SensitivityLevel;
        out acceleration : AccelerationVector;
        out status : SensorStatus;
        
        first start;
        then merge continuousMeasurement;
        then action senseMotion {
            out rawDisplacement : LengthValue;
        }
        then action convertToVoltage {
            in displacement = senseMotion.rawDisplacement;
            out voltage : VoltageValue;
        }
        then action conditionSignal {
            in inputVoltage = convertToVoltage.voltage;
            out conditionedVoltage : VoltageValue;
        }
        then action digitizeSignal {
            in analogVoltage = conditionSignal.conditionedVoltage;
            out digitalValue : Real;
        }
        then action processData {
            in rawValue = digitizeSignal.digitalValue;
            out accelerationOutput : AccelerationVector;
        }
        then assign acceleration := processData.accelerationOutput;
        then action checkStatus {
            out currentStatus : SensorStatus;
        }
        then assign status := checkStatus.currentStatus;
        then decide;
            if status.isOperational then continuousMeasurement;
            if not status.isOperational then shutdown;
        action shutdown;
        then done;
    }
    
    state def AccelerometerStates {
        attribute powerMode : String;
        
        entry; then idle;
        
        state idle {
            entry assign powerMode := "low";
        }
        
        transition idle_to_calibrating
            first idle
            accept CalibrationCommand
            then calibrating;
        
        state calibrating {
            entry assign powerMode := "high";
            do action performCalibration : CalibrateAccelerometer;
        }
        
        transition calibrating_to_measuring
            first calibrating
            if performCalibration.calibratedStatus.isCalibrated
            then measuring;
        
        transition calibrating_to_fault
            first calibrating
            if not performCalibration.calibratedStatus.isCalibrated
            then fault;
        
        state measuring {
            entry assign powerMode := "normal";
            do action continuousMeasure : MeasureAcceleration;
        }
        
        transition measuring_to_idle
            first measuring
            accept StopCommand
            then idle;
        
        transition measuring_to_fault
            first measuring
            if not continuousMeasure.status.isOperational
            then fault;
        
        state fault {
            entry assign powerMode := "low";
        }
        
        transition fault_to_idle
            first fault
            accept ResetCommand
            then idle;
    }
    
    part def Accelerometer {
        attribute operatingRange : AccelerationValue;
        attribute measurementAccuracy : Real;
        attribute nominalSamplingRate : SamplingRate;
        
        port powerPort : PowerInputPort;
        port controlPort : ControlInputPort;
        port outputPort : AccelerationOutputPort;
        
        part sensingElement : SensingElement[3] {
            doc /* Three orthogonal sensing elements for x, y, z axes */
        }
        
        part signalConditioner : SignalConditioner[3];
        
        part adc : AnalogToDigitalConverter[3];
        
        part processor : DataProcessor;
        
        perform action measureAcceleration : MeasureAcceleration {
            in samplingRate = controlPort.samplingRate;
            in sensitivity = controlPort.sensitivity;
            out acceleration = outputPort.acceleration;
            out status = outputPort.status;
        }
        
        exhibit state accelerometerBehavior : AccelerometerStates;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The accelerometer shall measure acceleration in the range of -16g to +16g on each axis */
        subject accel : Accelerometer;
        require constraint {
            accel.operatingRange >= 156.96
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The accelerometer shall provide measurement accuracy within 2% of full scale */
        subject accel : Accelerometer;
        require constraint {
            accel.measurementAccuracy <= 0.02
        }
    }
    
    requirement def SamplingRateRequirement {
        doc /* The accelerometer shall support sampling rates up to 1000 Hz */
        subject accel : Accelerometer;
        require constraint {
            accel.nominalSamplingRate >= 1000.0
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The accelerometer shall support field calibration to compensate for offset and sensitivity errors */
        subject accel : Accelerometer;
    }
    
    requirement def PowerConsumptionRequirement {
        doc /* The accelerometer shall operate within specified power budget */
        subject accel : Accelerometer;
        require constraint {
            accel.powerPort.voltage * accel.powerPort.current <= 0.5
        }
    }
    
    part accelerometerSystem : Accelerometer {
        doc /* 
            Primary Function: Measure and report three-axis linear acceleration
            
            The accelerometer system continuously senses motion-induced forces along three 
            orthogonal axes and converts them into digital acceleration measurements. 
            
            The system operates by detecting displacement of proof masses within sensing elements,
            converting mechanical displacement to electrical signals, conditioning and digitizing 
            those signals, and processing the data to produce calibrated acceleration vectors.
            
            Key capabilities include:
            - Tri-axial acceleration measurement
            - Configurable sampling rate and sensitivity
            - Self-calibration for offset and scale factor correction
            - Continuous operational monitoring and fault detection
            - Low-power idle and high-performance measurement modes
        */
        
        :>> operatingRange = 156.96;
        :>> measurementAccuracy = 0.015;
        :>> nominalSamplingRate = 1000.0;
    }
}

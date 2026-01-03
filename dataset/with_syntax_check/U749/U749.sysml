package LinearEncoderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PositionValue :> LengthValue;
    attribute def VelocityValue :> SpeedValue;
    attribute def ResolutionValue :> LengthValue;
    attribute def FrequencyValue :> Real;
    attribute def VoltageValue :> Real;
    
    enum def EncoderType {
        optical;
        magnetic;
        capacitive;
    }
    
    enum def OutputFormat {
        incremental;
        absolute;
        analog;
    }
    
    signal PowerOn;
    signal PowerOff;
    signal TestPassed;
    signal CalibrationComplete;
    signal StartMeasurement;
    signal StopMeasurement;
    signal SignalAcquired;
    signal ProcessingComplete;
    signal DataTransmitted;
    signal ErrorDetected;
    signal DiagnosisComplete;
    signal RecoveryComplete;
    
    item def OpticalSignal {
        attribute intensity : Real;
        attribute wavelength : LengthValue;
    }
    
    item def PositionData {
        attribute position : PositionValue;
        attribute velocity : VelocityValue;
        attribute timestamp : TimeValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute frequency : FrequencyValue;
    }
    
    port def OpticalPort {
        out emitted : OpticalSignal;
        in reflected : OpticalSignal;
    }
    
    port def SignalPort {
        out signal : ElectricalSignal;
    }
    
    port def DataPort {
        out data : PositionData;
    }
    
    part def GraduatedScale {
        attribute length : LengthValue;
        attribute pitch : LengthValue;
        attribute material : String;
        port opticalSurface : OpticalPort;
    }
    
    part def ReadHead {
        attribute encoderType : EncoderType;
        attribute ledWavelength : LengthValue;
        attribute photodetectorCount : Integer;
        port optical : OpticalPort;
        port analogOut : SignalPort;
    }
    
    part def SignalProcessor {
        attribute interpolationFactor : Integer;
        attribute samplingRate : FrequencyValue;
        port analogIn : SignalPort;
        port digitalOut : DataPort;
    }
    
    part def Controller {
        attribute resolution : ResolutionValue;
        attribute currentPosition : PositionValue;
        attribute currentVelocity : VelocityValue;
        port dataIn : DataPort;
        port outputPort : DataPort;
    }
    
    part def MountingAssembly {
        attribute alignmentTolerance : LengthValue;
        attribute maxLoad : MassValue;
        attribute rigidity : Real;
    }
    
    part def LinearEncoder {
        doc /* A precision measurement system that converts linear motion 
             * into electrical signals for accurate position determination. */
        
        attribute maxMeasurementRange : LengthValue;
        attribute systemResolution : ResolutionValue;
        attribute maxVelocity : VelocityValue;
        attribute outputFormat : OutputFormat;
        attribute operatingTempMin : TemperatureValue;
        attribute operatingTempMax : TemperatureValue;
        
        port externalDataPort : DataPort;
        
        part scale : GraduatedScale {
            attribute :>> length = 1000.0 [mm];
            attribute :>> pitch = 0.020 [mm];
            attribute :>> material = "glass";
        }
        
        part readHead : ReadHead {
            attribute :>> encoderType = EncoderType::optical;
            attribute :>> ledWavelength = 0.00065 [mm];
            attribute :>> photodetectorCount = 4;
        }
        
        part processor : SignalProcessor {
            attribute :>> interpolationFactor = 4096;
            attribute :>> samplingRate = 100000.0;
        }
        
        part controller : Controller {
            attribute :>> resolution = 0.0005 [mm];
        }
        
        part mounting : MountingAssembly {
            attribute :>> alignmentTolerance = 0.05 [mm];
            attribute :>> maxLoad = 10.0 [kg];
            attribute :>> rigidity = 0.95;
        }
        
        connection opticalLink connect readHead.optical to scale.opticalSurface;
        connection signalLink connect readHead.analogOut to processor.analogIn;
        connection dataLink connect processor.digitalOut to controller.dataIn;
        connection outputLink connect controller.outputPort to externalDataPort;
    }
    
    action def EmitLight {
        out lightBeam : OpticalSignal;
    }
    
    action def DetectReflection {
        in incident : OpticalSignal;
        out encodedSignal : ElectricalSignal;
    }
    
    action def InterpolateSignal {
        in rawSignal : ElectricalSignal;
        in interpolationFactor : Integer;
        out refinedSignal : ElectricalSignal;
    }
    
    action def ConvertToDigital {
        in analogSignal : ElectricalSignal;
        out digitalData : PositionData;
    }
    
    action def CalculateVelocity {
        in currentPosition : PositionValue;
        in previousPosition : PositionValue;
        in deltaTime : TimeValue;
        out velocity : VelocityValue;
    }
    
    action def UpdatePosition {
        in positionData : PositionData;
        out updatedPosition : PositionValue;
        out updatedVelocity : VelocityValue;
    }
    
    action def MeasureLinearPosition {
        doc /* Primary function: continuously measure linear position 
             * by reading optical scale graduations and converting to 
             * high-resolution digital position data. */
        
        first start;
        then merge measurementCycle;
        
        then action emitLight : EmitLight {
            out beam : OpticalSignal;
        }
        
        then action detectReflection : DetectReflection {
            in incident = emitLight.beam;
            out encodedSignal : ElectricalSignal;
        }
        
        then action interpolate : InterpolateSignal {
            in rawSignal = detectReflection.encodedSignal;
            in interpolationFactor = 4096;
            out refinedSignal : ElectricalSignal;
        }
        
        then action convertDigital : ConvertToDigital {
            in analogSignal = interpolate.refinedSignal;
            out digitalData : PositionData;
        }
        
        then action calculateVelocity : CalculateVelocity {
            in currentPosition = convertDigital.digitalData.position;
            in previousPosition : PositionValue;
            in deltaTime = 0.00001 [s];
            out velocity : VelocityValue;
        }
        
        then action updatePosition : UpdatePosition {
            in positionData = convertDigital.digitalData;
            out updatedPosition : PositionValue;
            out updatedVelocity : VelocityValue;
        }
        
        then decide;
            if updatePosition.updatedPosition != null then measurementCycle;
            else errorHandling;
        
        action errorHandling;
        then measurementCycle;
    }
    
    state def EncoderOperationalStates {
        entry; then powerOff;
        
        state powerOff;
        transition powerOff_to_initialization
            first powerOff
            accept PowerOn
            then initialization;
        
        state initialization {
            entry; then selfTest;
            
            state selfTest;
            transition selfTest_to_calibration
                first selfTest
                accept TestPassed
                then calibration;
            
            state calibration;
            transition calibration_to_ready
                first calibration
                accept CalibrationComplete
                then ready;
        }
        
        state ready;
        transition ready_to_measuring
            first ready
            accept StartMeasurement
            then measuring;
        
        state measuring {
            entry; then acquiring;
            
            state acquiring;
            transition acquiring_to_processing
                first acquiring
                accept SignalAcquired
                then processing;
            
            state processing;
            transition processing_to_outputting
                first processing
                accept ProcessingComplete
                then outputting;
            
            state outputting;
            transition outputting_to_acquiring
                first outputting
                accept DataTransmitted
                then acquiring;
        }
        
        transition measuring_to_ready
            first measuring
            accept StopMeasurement
            then ready;
        
        transition measuring_to_error
            first measuring
            accept ErrorDetected
            then error;
        
        state error {
            entry; then diagnosing;
            
            state diagnosing;
            transition diagnosing_to_recovering
                first diagnosing
                accept DiagnosisComplete
                then recovering;
            
            state recovering;
            transition recovering_to_ready
                first recovering
                accept RecoveryComplete
                then ready;
        }
        
        transition powerOff_transition
            accept PowerOff
            then powerOff;
    }
    
    requirement def PrimaryMeasurementFunctionReq {
        doc /* The linear encoder system shall measure linear displacement 
             * along a single axis and provide accurate position feedback. */
        subject encoder : LinearEncoder;
    }
    
    requirement <'REQ-LEN-001'> resolutionRequirement {
        doc /* The encoder shall provide position measurement resolution 
             * of 0.5 micrometers or better. */
        subject encoder : LinearEncoder;
        assert constraint {
            encoder.systemResolution <= 0.0005 [mm]
        }
    }
    
    requirement <'REQ-LEN-002'> accuracyRequirement {
        doc /* The encoder shall maintain position accuracy within 
             * +/- 3 micrometers over the full measurement range. */
        subject encoder : LinearEncoder;
    }
    
    requirement <'REQ-LEN-003'> measurementRangeRequirement {
        doc /* The encoder shall support measurement ranges from 
             * 100 mm to 3000 mm. */
        subject encoder : LinearEncoder;
        assert constraint {
            encoder.maxMeasurementRange >= 100.0 [mm] and
            encoder.maxMeasurementRange <= 3000.0 [mm]
        }
    }
    
    requirement <'REQ-LEN-004'> velocityCapabilityRequirement {
        doc /* The encoder shall accurately track motion at velocities 
             * up to 15 meters per second. */
        subject encoder : LinearEncoder;
        assert constraint {
            encoder.maxVelocity >= 15.0 [m/s]
        }
    }
    
    requirement <'REQ-LEN-005'> environmentalRequirement {
        doc /* The encoder shall operate reliably in industrial environments 
             * with temperatures from 0 to 60 degrees Celsius. */
        subject encoder : LinearEncoder;
        assert constraint {
            encoder.operatingTempMin <= 273.15 [K] and
            encoder.operatingTempMax >= 333.15 [K]
        }
    }
    
    requirement <'REQ-LEN-006'> interpolationRequirement {
        doc /* The signal processor shall provide interpolation factor 
             * of at least 4096 to achieve sub-micrometer resolution. */
        subject processor : SignalProcessor;
        assert constraint {
            processor.interpolationFactor >= 4096
        }
    }
    
    requirement <'REQ-LEN-007'> alignmentRequirement {
        doc /* The mounting assembly shall maintain alignment tolerance 
             * within 50 micrometers to ensure measurement accuracy. */
        subject mounting : MountingAssembly;
        assert constraint {
            mounting.alignmentTolerance <= 0.05 [mm]
        }
    }
    
    part precisionLinearEncoder : LinearEncoder {
        attribute :>> maxMeasurementRange = 1000.0 [mm];
        attribute :>> systemResolution = 0.0005 [mm];
        attribute :>> maxVelocity = 15.0 [m/s];
        attribute :>> outputFormat = OutputFormat::incremental;
        attribute :>> operatingTempMin = 273.15 [K];
        attribute :>> operatingTempMax = 333.15 [K];
        
        perform action measurePosition : MeasureLinearPosition;
        exhibit state operationalStates : EncoderOperationalStates;
    }
    
    satisfy PrimaryMeasurementFunctionReq by precisionLinearEncoder;
    satisfy resolutionRequirement by precisionLinearEncoder;
    satisfy measurementRangeRequirement by precisionLinearEncoder;
    satisfy velocityCapabilityRequirement by precisionLinearEncoder;
    satisfy environmentalRequirement by precisionLinearEncoder;
    satisfy interpolationRequirement by precisionLinearEncoder.processor;
    satisfy alignmentRequirement by precisionLinearEncoder.mounting;
}

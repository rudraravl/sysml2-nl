package TactileSensingUnitModel {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;
    import SI::*;
    
    item def RawAnalogSignal {
        attribute voltage : Real;
    }
    item def AmplifiedAnalogSignal {
        attribute voltage : Real;
    }
    item def DigitalSignal {
        attribute value : Integer;
    }
    item def ProcessedTactileData {
        attribute pressure :> ISQ::pressure;
        attribute force :> ISQ::force;
        attribute contactArea :> ISQ::area;
        attribute temperature :> ISQ::temperature;
        attribute timestamp : Time::DateTime;
    }
    item def CalibrationFactors {
        attribute pressureFactor : Real := 1.0;
        attribute forceFactor : Real := 1.0;
        attribute areaFactor : Real := 1.0;
        attribute tempOffset :> ISQ::temperature := 0 [K];
    }
    
    port def RawAnalogOutPort { out signal : RawAnalogSignal; }
    port def RawAnalogInPort { in signal : RawAnalogSignal; }
    port def AmplifiedAnalogOutPort { out signal : AmplifiedAnalogSignal; }
    port def AmplifiedAnalogInPort { in signal : AmplifiedAnalogSignal; }
    port def DigitalSignalOutPort { out signal : DigitalSignal; }
    port def DigitalSignalInPort { in signal : DigitalSignal; }
    port def ProcessedDataOutPort { out data : ProcessedTactileData; }
    port def ProcessedDataInPort { in data : ProcessedTactileData; }
    
    action def GenerateSignal { in forceApplied :> ISQ::force; out signal : RawAnalogSignal; }
    action def Amplify { in signal : RawAnalogSignal; out amplified : AmplifiedAnalogSignal; }
    action def Convert { in amplified : AmplifiedAnalogSignal; out digital : DigitalSignal; }
    action def Process { in digital : DigitalSignal; in calibration : CalibrationFactors; out data : ProcessedTactileData; }
    action def Log { in data : ProcessedTactileData; }
    
    part def PiezoelectricElement {
        port rawOut : RawAnalogOutPort;
        perform action generateSignal : GenerateSignal;
    }
    
    part def TactileSensor {
        part piezoElement : PiezoelectricElement;
        port rawAnalogOut : RawAnalogOutPort;
        perform action sense : GenerateSignal;
        connect piezoElement.rawOut to rawAnalogOut;
    }
    
    part def SignalAmplifier {
        attribute gain : Real := 100.0;
        port rawIn : RawAnalogInPort;
        port amplifiedOut : AmplifiedAnalogOutPort;
        perform action amplify : Amplify;
    }
    
    part def AnalogToDigitalConverter {
        port amplifiedIn : AmplifiedAnalogInPort;
        port digitalOut : DigitalSignalOutPort;
        perform action convert : Convert;
    }
    
    part def SignalProcessor {
        attribute calibration : CalibrationFactors;
        port digitalIn : DigitalSignalInPort;
        port processedOut : ProcessedDataOutPort;
        perform action process : Process;
    }
    
    part def DataLogger {
        attribute storageCapacity : Integer := 10000;
        attribute history : ProcessedTactileData [*];
        port dataIn : ProcessedDataInPort;
        perform action log : Log;
    }
    
    attribute def StartCalibrationSignal;
    attribute def CalibrationCompleteSignal;
    attribute def TriggerMeasurementSignal;
    attribute def AcquisitionCompleteSignal;
    attribute def ProcessingCompleteSignal;
    attribute def OutputCompleteSignal;
    attribute def ErrorSignal;
    attribute def ResetSignal;
    
    state def SensingUnitStates {
        entry;
        then idle;
        
        state idle;
        transition idle_to_calibrating
            first idle
            accept StartCalibrationSignal
            then calibrating;
        
        state calibrating;
        transition calibrating_to_ready
            first calibrating
            accept CalibrationCompleteSignal
            then ready;
        
        state ready;
        transition ready_to_acquiring
            first ready
            accept TriggerMeasurementSignal
            then acquiring;
        
        state acquiring;
        transition acquiring_to_processing
            first acquiring
            accept AcquisitionCompleteSignal
            then processing;
        
        state processing;
        transition processing_to_outputting
            first processing
            accept ProcessingCompleteSignal
            then outputting;
        
        state outputting;
        transition outputting_to_ready
            first outputting
            accept OutputCompleteSignal
            then ready;
        
        transition idle_to_error
            first idle
            accept ErrorSignal
            then error;
        transition calibrating_to_error
            first calibrating
            accept ErrorSignal
            then error;
        transition ready_to_error
            first ready
            accept ErrorSignal
            then error;
        transition acquiring_to_error
            first acquiring
            accept ErrorSignal
            then error;
        transition processing_to_error
            first processing
            accept ErrorSignal
            then error;
        transition outputting_to_error
            first outputting
            accept ErrorSignal
            then error;
        
        state error;
        transition error_to_idle
            first error
            accept ResetSignal
            then idle;
    }
    
    part def TactileSensingUnit {
        port externalOutput : ProcessedDataOutPort;
        
        part sensor : TactileSensor;
        part amplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part logger : DataLogger;
        
        connect sensor.rawAnalogOut to amplifier.rawIn;
        connect amplifier.amplifiedOut to adc.amplifiedIn;
        connect adc.digitalOut to processor.digitalIn;
        connect processor.processedOut to externalOutput;
        connect processor.processedOut to logger.dataIn;
        
        exhibit state sensingUnitStates : SensingUnitStates;
    }
    
    requirement def TactileMeasurementRequirement {
        doc "The system shall measure tactile data accurately and rapidly.";
        attribute maxPressureError :> ISQ::pressure := 1000 [Pa];
        attribute maxForceError :> ISQ::force := 0.5 [N];
        attribute maxTempError :> ISQ::temperature := 1 [K];
        attribute maxResponseTime :> ISQ::time := 0.01 [s];
        subject unit : TactileSensingUnit;
    }
    
    requirement def HighReliabilityRequirement {
        doc "The system shall have a mean time between failures of at least 10000 hours.";
        attribute minMTBF :> ISQ::time := 10000 [h];
        subject unit : TactileSensingUnit;
    }
    
    part sensingUnit : TactileSensingUnit;
    
    requirement tactileMeasurementReq : TactileMeasurementRequirement;
    requirement highReliabilityReq : HighReliabilityRequirement;
    
    satisfy tactileMeasurementReq by sensingUnit;
    satisfy highReliabilityReq by sensingUnit;
}

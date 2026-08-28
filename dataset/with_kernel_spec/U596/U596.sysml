package AnalogImageProcessingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    value def Voltage :> Real;
    value def Gain :> Real;
    value def ContrastLevel :> Real;
    value def BrightnessLevel :> Real;
    value def Frequency :> Real;
    
    item def OpticalImage;
    item def RawVideoSignal {
        attribute voltage : Voltage;
    }
    item def AmplifiedVideoSignal {
        attribute voltage : Voltage;
    }
    item def FilteredVideoSignal {
        attribute voltage : Voltage;
    }
    item def EnhancedVideoSignal {
        attribute voltage : Voltage;
    }
    item def SyncPulses {
        attribute hSyncFreq : Frequency;
        attribute vSyncFreq : Frequency;
    }
    item def CompositeVideoSignal {
        attribute voltage : Voltage;
    }
    item def OutputVideoSignal {
        attribute voltage : Voltage;
    }
    
    port def OpticalIn {
        in item opticalImage : OpticalImage;
    }
    port def VideoOut {
        out item outputVideo : OutputVideoSignal;
    }
    port def ControlIn {
        in attribute gain : Gain;
        in attribute contrast : ContrastLevel;
        in attribute brightness : BrightnessLevel;
    }
    
    part def PhotodetectorArray {
        in item opticalImage : OpticalImage;
        out item rawSignal : RawVideoSignal;
    }
    
    part def VideoAmplifier {
        in item rawSignal : RawVideoSignal;
        out item amplifiedSignal : AmplifiedVideoSignal;
        attribute gain : Gain = 1.0;
    }
    
    part def LowPassFilter {
        in item amplifiedSignal : AmplifiedVideoSignal;
        out item filteredSignal : FilteredVideoSignal;
        attribute cutoffFrequency : Frequency = 5000000.0;
    }
    
    part def ContrastController {
        in item filteredSignal : FilteredVideoSignal;
        out item contrastAdjustedSignal : EnhancedVideoSignal;
        attribute contrastLevel : ContrastLevel = 1.0;
    }
    
    part def BrightnessController {
        in item contrastAdjustedSignal : EnhancedVideoSignal;
        out item enhancedSignal : EnhancedVideoSignal;
        attribute brightnessLevel : BrightnessLevel = 0.0;
    }
    
    part def SyncGenerator {
        out item syncPulses : SyncPulses;
    }
    
    part def VideoMixer {
        in item enhancedSignal : EnhancedVideoSignal;
        in item syncPulses : SyncPulses;
        out item compositeSignal : CompositeVideoSignal;
    }
    
    part def OutputDriver {
        in item compositeSignal : CompositeVideoSignal;
        out item outputSignal : OutputVideoSignal;
    }
    
    state machine def SystemBehavior {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in errorDetected : Boolean;
        in resetCommand : Boolean;
        state idle;
        state processing;
        state fault;
        transition from idle to processing when startCommand;
        transition from processing to idle when stopCommand;
        transition from processing to fault when errorDetected;
        transition from fault to idle when resetCommand;
    }
    
    part def AnalogImageProcessor {
        port opticalIn : OpticalIn;
        port videoOut : VideoOut;
        port controlIn : ControlIn;
        
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute errorDetected : Boolean = false;
        attribute resetCommand : Boolean = false;
        
        part photodetectorArray : PhotodetectorArray;
        part videoAmplifier : VideoAmplifier;
        part lowPassFilter : LowPassFilter;
        part contrastController : ContrastController;
        part brightnessController : BrightnessController;
        part syncGenerator : SyncGenerator;
        part videoMixer : VideoMixer;
        part outputDriver : OutputDriver;
        
        flow opticalIn.opticalImage to photodetectorArray.opticalImage;
        flow photodetectorArray.rawSignal to videoAmplifier.rawSignal;
        flow videoAmplifier.amplifiedSignal to lowPassFilter.amplifiedSignal;
        flow lowPassFilter.filteredSignal to contrastController.filteredSignal;
        flow contrastController.contrastAdjustedSignal to brightnessController.contrastAdjustedSignal;
        flow brightnessController.enhancedSignal to videoMixer.enhancedSignal;
        flow syncGenerator.syncPulses to videoMixer.syncPulses;
        flow videoMixer.compositeSignal to outputDriver.compositeSignal;
        flow outputDriver.outputSignal to videoOut.outputVideo;
        
        bind controlIn.gain = videoAmplifier.gain;
        bind controlIn.contrast = contrastController.contrastLevel;
        bind controlIn.brightness = brightnessController.brightnessLevel;
        
        exhibit systemBehavior : SystemBehavior {
            in startCommand = startCommand;
            in stopCommand = stopCommand;
            in errorDetected = errorDetected;
            in resetCommand = resetCommand;
        }
    }
    
    requirement def SystemRequirements {
        subject processor : AnalogImageProcessor;
        requirement signalProcessing {
            doc /* The system shall convert an optical image into a composite video signal. */;
        }
        requirement stateManagement {
            doc /* The system shall operate in idle, processing, and fault states. */;
        }
    }
}

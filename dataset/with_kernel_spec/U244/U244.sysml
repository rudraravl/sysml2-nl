package HomeUltrasoundDevice {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def TemperatureValue :> Real;
    attribute def BatteryLevel :> Real;
    
    attribute def PowerOn;
    attribute def PowerOff;
    attribute def StartImaging;
    attribute def StopImaging;
    attribute def Freeze;
    attribute def Unfreeze;
    
    item def AcousticPulse;
    item def EchoData;
    item def ScanLine;
    item def ProcessedData;
    item def UltrasoundImage;
    item def Power;
    
    enum def ImagingMode {
        BMode;
        MMode;
        ColorDoppler;
    }
    
    action def GeneratePulse { out pulse : AcousticPulse; }
    action def CaptureEchoes { in pulse : AcousticPulse; out echoes : EchoData; }
    action def FocusBeam { in echoes : EchoData; out scanLine : ScanLine; }
    action def ProcessSignal { in scanLine : ScanLine; out processedData : ProcessedData; }
    action def AssembleImage { in processedData : ProcessedData; out image : UltrasoundImage; }
    action def DisplayImage { in image : UltrasoundImage; }
    action def MonitorTemperature { out temp : TemperatureValue; }
    
    part def TransducerArray {
        port acousticPort { out pulse : AcousticPulse; in echoes : EchoData; }
        port tempPort { out temp : TemperatureValue; }
        action generatePulse : GeneratePulse { out pulse; }
        action captureEchoes : CaptureEchoes { in pulse; out echoes; }
        action monitorTemp : MonitorTemperature { out temp; }
        flow from generatePulse.pulse to acousticPort.pulse;
        flow from acousticPort.echoes to captureEchoes.echoes;
        flow from monitorTemp.temp to tempPort.temp;
    }
    
    part def ThermalMonitor {
        port tempInPort { in temp : TemperatureValue; }
        port alertPort { out alert : Boolean; }
        attribute maxTemp : TemperatureValue = 41.0;
    }
    
    part def Beamformer {
        port dataInPort { in echoes : EchoData; }
        port dataOutPort { out scanLine : ScanLine; }
        action focusBeam : FocusBeam {
            in echoes = dataInPort.echoes;
            out scanLine;
        }
        flow from focusBeam.scanLine to dataOutPort.scanLine;
    }
    
    part def SignalProcessor {
        port dataInPort { in scanLine : ScanLine; }
        port dataOutPort { out processedData : ProcessedData; }
        action processSignal : ProcessSignal {
            in scanLine = dataInPort.scanLine;
            out processedData;
        }
        flow from processSignal.processedData to dataOutPort.processedData;
    }
    
    part def ImageProcessor {
        port dataInPort { in processedData : ProcessedData; }
        port dataOutPort { out image : UltrasoundImage; }
        action assembleImage : AssembleImage {
            in processedData = dataInPort.processedData;
            out image;
        }
        flow from assembleImage.image to dataOutPort.image;
    }
    
    part def DisplayModule {
        attribute screenSize : Real = 10.1;
        port imageInPort { in image : UltrasoundImage; }
        action displayImage : DisplayImage { in image = imageInPort.image; }
    }
    
    part def PowerManagement {
        attribute batteryCapacity : Real = 3;
        attribute currentLevel : BatteryLevel;
        port powerOut { out power : Power; }
    }
    
    part def ControlInterface {
        attribute hasTouchscreen : Boolean = true;
        attribute hasPhysicalButtons : Boolean = true;
        port controlPort { out modeCommand : ImagingMode; out powerCommand : String; }
    }
    
    state def DeviceStates {
        entry; then off;
        state off;
        accept PowerOn then standby;
        state standby;
        accept StartImaging then active;
        state active;
        accept Freeze then freeze;
        state freeze;
        accept Unfreeze then active;
        accept StopImaging then standby;
        accept PowerOff then off;
    }
    
    part def HomeUltrasoundDevice {
        attribute currentMode : ImagingMode;
        exhibit state deviceStates : DeviceStates;
        
        part transducer : TransducerArray;
        part thermalMonitor : ThermalMonitor;
        part beamformer : Beamformer;
        part signalProcessor : SignalProcessor;
        part imageProcessor : ImageProcessor;
        part display : DisplayModule;
        part power : PowerManagement;
        part controls : ControlInterface;
        
        flow from transducer.acousticPort.echoes to beamformer.dataInPort.echoes;
        flow from beamformer.dataOutPort.scanLine to signalProcessor.dataInPort.scanLine;
        flow from signalProcessor.dataOutPort.processedData to imageProcessor.dataInPort.processedData;
        flow from imageProcessor.dataOutPort.image to display.imageInPort.image;
        flow from transducer.tempPort.temp to thermalMonitor.tempInPort.temp;
    }
    
    requirement def ContinuousOperationReq {
        doc /* The device shall support at least 3 hours of continuous operation. */;
        attribute minDuration : Real = 3;
    }
    requirement def TemperatureSafetyReq {
        doc /* The transducer surface temperature shall not exceed 41 degrees Celsius. */;
        attribute maxAllowed : TemperatureValue = 41.0;
    }
    requirement def DisplaySizeReq {
        doc /* The display shall be a 10.1-inch screen. */;
        attribute requiredSize : Real = 10.1;
    }
    requirement def ImagingModesReq {
        doc /* The system shall support B-mode, M-mode, and Color Doppler imaging. */;
    }
    
    requirement ContinuousOperation : ContinuousOperationReq;
    requirement TemperatureSafety : TemperatureSafetyReq;
    requirement DisplaySize : DisplaySizeReq;
    requirement ImagingModes : ImagingModesReq;
}

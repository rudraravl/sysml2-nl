package FlatPanelDetectorSystem {
    private import ISQ::*;
    
    item def XRayExposure;
    item def VisibleLight;
    item def ElectricalCharge;
    item def RawImageData;
    item def ProcessedImageData;
    item def Command;
    item def Status;
    
    action def ConvertXRayToLight {
        in xray : XRayExposure;
        out light : VisibleLight;
    }
    action def ConvertLightToCharge {
        in light : VisibleLight;
        out charge : ElectricalCharge;
    }
    action def DigitizeCharge {
        in charge : ElectricalCharge;
        out rawImg : RawImageData;
    }
    action def ProcessImage {
        in rawImg : RawImageData;
        out procImg : ProcessedImageData;
    }
    
    part def ScintillatorPanel {
        in port xrayIn : XRayExposure;
        out port lightOut : VisibleLight;
        action convert : ConvertXRayToLight {
            in xray = xrayIn;
            out light = lightOut;
        }
    }
    
    part def PhotodiodeMatrix {
        in port lightIn : VisibleLight;
        out port chargeOut : ElectricalCharge;
        action convert : ConvertLightToCharge {
            in light = lightIn;
            out charge = chargeOut;
        }
    }
    
    part def ReadoutCircuitry {
        in port chargeIn : ElectricalCharge;
        out port rawImgOut : RawImageData;
        action digitize : DigitizeCharge {
            in charge = chargeIn;
            out rawImg = rawImgOut;
        }
    }
    
    part def ImageProcessingUnit {
        in port rawImgIn : RawImageData;
        out port procImgOut : ProcessedImageData;
        action process : ProcessImage {
            in rawImg = rawImgIn;
            out procImg = procImgOut;
        }
    }
    
    part def ControllerModule {
        in port cmdIn : Command;
        out port statusOut : Status;
        attribute exposureTime : TimeValue = 0.1;
    }
    
    part def ThermalManagementSystem {
        in port targetTempIn : TemperatureValue;
        out port currentTempOut : TemperatureValue;
        action regulate;
    }
    
    part def FlatPanelDetector {
        in port xrayInput : XRayExposure;
        in port cmdInput : Command;
        out port imageOutput : ProcessedImageData;
        out port statusOutput : Status;
        
        attribute targetTemp : TemperatureValue = 298.0;
        
        part controller : ControllerModule;
        part thermal : ThermalManagementSystem {
            targetTempIn = targetTemp;
        }
        part scintillator : ScintillatorPanel;
        part photodiode : PhotodiodeMatrix;
        part readout : ReadoutCircuitry;
        part processor : ImageProcessingUnit;
        
        connect cmdInput to controller.cmdIn;
        connect controller.statusOut to statusOutput;
        
        connect xrayInput to scintillator.xrayIn;
        connect scintillator.lightOut to photodiode.lightIn;
        connect photodiode.chargeOut to readout.chargeIn;
        connect readout.rawImgOut to processor.rawImgIn;
        connect processor.procImgOut to imageOutput;
        
        state operationalCycle {
            entry; then standby;
            state standby;
            transition first standby accept startCmd : Command via cmdInput then initialization;
            state initialization;
            transition first initialization do action initialize then exposure;
            state exposure {
                do scintillator.convert;
                do photodiode.convert;
            }
            transition first exposure accept endExposure : Command via cmdInput then readout;
            state readout;
            transition first readout do readout.digitize then processing;
            state processing;
            transition first processing do processor.process then standby;
        }
        
        action initialize;
    }
    
    requirement def ImageCaptureRequirement {
        doc /* The Flat Panel Detector shall capture X-ray exposure and produce a processed digital image. */
        subject detector : FlatPanelDetector;
    }
    
    requirement def ThermalStabilityRequirement {
        doc /* The thermal management system shall maintain the detector temperature within ±1K of the target. */
        subject thermalSys : ThermalManagementSystem;
    }
}

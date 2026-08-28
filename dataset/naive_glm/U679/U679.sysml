package FlatPanelDetectorSystem {
    import ScalarValues::*;
    import ISQ::*;

    item def XRayPhoton;
    item def VisibleLightPhoton;
    item def ElectricalCharge {
        attr value : Real;
    }
    item def RawImage {
        attr pixelData : Real[0..*];
    }
    item def ProcessedImage {
        attr pixelData : Real[0..*];
    }
    item def ControlCommand {
        attr commandType : String;
    }
    item def StatusReport {
        attr status : String;
    }
    
    value type Temperature :> Real {
        doc "Temperature in Celsius";
    }

    port def XRayInputPort {
        out xrayFlux : XRayPhoton;
    }
    port def LightTransferPort {
        out lightFlux : VisibleLightPhoton;
    }
    port def ChargeTransferPort {
        out charge : ElectricalCharge;
    }
    port def RawDataPort {
        out rawImage : RawImage;
    }
    port def ProcessedDataPort {
        out processedImage : ProcessedImage;
    }
    port def CommandPort {
        in command : ControlCommand;
        out status : StatusReport;
    }
    port def ControlSignalPort {
        out trigger : ControlCommand;
    }
    port def CoolingPort {
        out temperature : Temperature;
    }

    part def ScintillatorPanel {
        port in xrayInput : XRayInputPort;
        port out lightOutput : LightTransferPort;
        
        action convertXRayToLight {
            in xray : XRayPhoton;
            out light : VisibleLightPhoton;
        }
    }
    
    part def PhotodiodeMatrix {
        port in lightInput : LightTransferPort;
        port out chargeOutput : ChargeTransferPort;
        
        action convertLightToCharge {
            in light : VisibleLightPhoton;
            out charge : ElectricalCharge;
        }
    }
    
    part def ReadoutCircuitry {
        port in chargeInput : ChargeTransferPort;
        port out rawImageOutput : RawDataPort;
        port in control : ControlSignalPort;
        
        action scanAndDigitize {
            in charge : ElectricalCharge;
            out rawImg : RawImage;
        }
    }
    
    part def ImageProcessingUnit {
        port in rawImageInput : RawDataPort;
        port out processedImageOutput : ProcessedDataPort;
        port in control : ControlSignalPort;
        
        action processImage {
            in rawImg : RawImage;
            out procImg : ProcessedImage;
        }
    }
    
    part def ControllerModule {
        port in commandInput : CommandPort;
        port out readoutControl : ControlSignalPort;
        port out processingControl : ControlSignalPort;
        port out thermalControl : ControlSignalPort;
        
        action orchestrateTiming {
            in cmd : ControlCommand;
            out rControl : ControlCommand;
            out pControl : ControlCommand;
            out tControl : ControlCommand;
        }
    }
    
    part def ThermalManagementSystem {
        port in control : ControlSignalPort;
        port out coolingOutput : CoolingPort;
        
        action coolDetector {
            in cmd : ControlCommand;
            out temp : Temperature;
        }
    }
    
    part def FlatPanelDetector {
        port in xrayPort : XRayInputPort;
        port in cmdPort : CommandPort;
        port out dataPort : ProcessedDataPort;
        
        part scintillator : ScintillatorPanel;
        part photodiode : PhotodiodeMatrix;
        part readout : ReadoutCircuitry;
        part imageProcessor : ImageProcessingUnit;
        part controller : ControllerModule;
        part thermalSystem : ThermalManagementSystem;
        
        connection xrayToScintillator connect xrayPort to scintillator.xrayInput;
        connection scintillatorToPhotodiode connect scintillator.lightOutput to photodiode.lightInput;
        connection photodiodeToReadout connect photodiode.chargeOutput to readout.chargeInput;
        connection readoutToProcessor connect readout.rawImageOutput to imageProcessor.rawImageInput;
        connection processorToDataPort connect imageProcessor.processedImageOutput to dataPort;
        
        connection controllerToReadout connect controller.readoutControl to readout.control;
        connection controllerToProcessor connect controller.processingControl to imageProcessor.control;
        connection controllerToThermal connect controller.thermalControl to thermalSystem.control;
        
        connection cmdToController connect cmdPort to controller.commandInput;
        
        state def FPDStateMachine {
            state standby;
            state initialization;
            state exposure;
            state readout;
            state processing;
            
            accept "StartAcquisition" then standby to initialization;
            accept "XRayDetected" then initialization to exposure;
            accept "ExposureComplete" then exposure to readout;
            accept "ReadoutComplete" then readout to processing;
            accept "ProcessingComplete" then processing to standby;
        }
        
        requirement def ImageQualityRequirement {
            doc "The detector must produce high-quality digital images."
        }
        
        requirement def ThermalStabilityRequirement {
            doc "The detector must maintain stable operating temperature below 35 degrees Celsius."
        }
    }
    
    part def ExternalSystem {
        port out commandOutput : CommandPort;
        port in imageInput : ProcessedDataPort;
    }
    
    part def FPDSystemContext {
        part detector : FlatPanelDetector;
        part externalSystem : ExternalSystem;
        
        connection cmdToDetector connect externalSystem.commandOutput to detector.cmdPort;
        connection imageToExternal connect detector.dataPort to externalSystem.imageInput;
    }
}

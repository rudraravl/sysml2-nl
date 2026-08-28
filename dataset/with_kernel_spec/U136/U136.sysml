package VisualProsthesisSystem {
    private import ScalarValues::*;
    private import SI::FrequencyUnit;
    private import ISQElectromagnetism::ElectricCurrentUnit;
    private import ISQElectromagnetism::ElectricResistanceUnit;
    private import ISQElectromagnetism::ElectricPotentialUnit;
    
    item def VideoFrame;
    item def ProcessedImage;
    item def StimulationPattern {
        attribute currentLevels : ElectricCurrentUnit[60];
    }
    item def TissueResponse {
        attribute impedance : ElectricResistanceUnit;
    }
    item def ControlCommand;
    item def SystemData;
    
    attribute def Power {
        attribute voltage : ElectricPotentialUnit;
        attribute current : ElectricCurrentUnit;
    }
    
    port def VideoOutPort { out item frame : VideoFrame; }
    port def VideoInPort { in item frame : VideoFrame; }
    port def ImageOutPort { out item image : ProcessedImage; }
    port def ImageInPort { in item image : ProcessedImage; }
    port def StimulationOutPort { out item pattern : StimulationPattern; }
    port def StimulationInPort { in item pattern : StimulationPattern; }
    port def PowerOutPort { out attribute power : Power; }
    port def PowerInPort { in attribute power : Power; }
    port def CommPort { in item command : ControlCommand; out item data : SystemData; }
    port def TissueResponsePort { out item response : TissueResponse; }
    
    part def ExternalCamera {
        port videoOut : VideoOutPort;
        port powerIn : PowerInPort;
        attribute captureRate : FrequencyUnit = 30;
        
        perform action captureVideo {
            out item frame : VideoFrame;
            first start;
            then action captureFrame;
            then done;
        }
    }
    
    part def ImageProcessingUnit {
        port videoIn : VideoInPort;
        port imageOut : ImageOutPort;
        port powerIn : PowerInPort;
        port comm : CommPort;
        
        perform action processImage {
            in item rawFrame : VideoFrame;
            out item procImage : ProcessedImage;
            first start;
            then action edgeDetection;
            then action contrastEnhancement;
            then done;
        }
    }
    
    part def StimulusGenerator {
        port imageIn : ImageInPort;
        port stimOut : StimulationOutPort;
        port powerIn : PowerInPort;
        
        perform action generatePattern {
            in item image : ProcessedImage;
            out item pattern : StimulationPattern;
            first start;
            then action mapToGrid;
            then action calculateCurrent;
            then done;
        }
    }
    
    part def RetinalElectrodeArray {
        port stimIn : StimulationInPort;
        port responseOut : TissueResponsePort;
        port powerIn : PowerInPort;
        attribute electrodeCount : Integer = 60;
        
        perform action stimulate {
            in item pattern : StimulationPattern;
            first start;
            then action deliverPulses;
            then done;
        }
        
        perform action monitorResponse {
            out item response : TissueResponse;
            first start;
            then action measureResponse;
            then done;
        }
    }
    
    part def BatteryUnit {
        port powerOut : PowerOutPort;
        port comm : CommPort;
        attribute batteryLevel : Real;
        
        state PowerManagement {
            state Normal {
                entry action {
                    first start;
                    then done;
                }
                transition to LowPower when batteryLevel < 0.2;
            }
            state LowPower {
                entry action {
                    first start;
                    then done;
                }
                transition to Normal when batteryLevel > 0.8;
            }
        }
    }
    
    part def WirelessTransceiver {
        port comm : CommPort;
        port powerIn : PowerInPort;
    }
    
    part def VisualProsthesis {
        part camera : ExternalCamera;
        part processor : ImageProcessingUnit;
        part generator : StimulusGenerator;
        part array : RetinalElectrodeArray;
        part battery : BatteryUnit;
        part transceiver : WirelessTransceiver;
        
        connect camera.videoOut to processor.videoIn;
        connect processor.imageOut to generator.imageIn;
        connect generator.stimOut to array.stimIn;
        
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to processor.powerIn;
        connect battery.powerOut to generator.powerIn;
        connect battery.powerOut to array.powerIn;
        connect battery.powerOut to transceiver.powerIn;
        
        connect transceiver.comm to processor.comm;
        connect transceiver.comm to battery.comm;
        
        satisfy RestorePartialVision by self;
        satisfy CaptureRateReq by camera.captureRate;
        satisfy ElectrodeCountReq by array.electrodeCount;
        satisfy SafetyMonitoringReq by array.monitorResponse;
        satisfy PowerManagementReq by battery.PowerManagement;
    }
    
    requirement def RestorePartialVision {
        doc /* The system shall restore partial vision to individuals with retinal degenerative diseases. */
    }
    requirement def CaptureRateReq {
        doc /* The camera shall capture video at 30 frames per second. */
        attribute requiredRate : FrequencyUnit = 30;
    }
    requirement def ElectrodeCountReq {
        doc /* The retinal implant shall contain exactly 60 microelectrodes. */
        attribute requiredCount : Integer = 60;
    }
    requirement def SafetyMonitoringReq {
        doc /* The system shall continuously monitor retinal tissue response for safety. */
    }
    requirement def PowerManagementReq {
        doc /* The battery unit shall support a low-power mode when charge is low. */
    }
}

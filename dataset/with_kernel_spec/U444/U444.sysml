package VideoscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Length :> ISQ::length;
    attribute def ElectricPotential :> ISQ::electricPotential;
    attribute def PlaneAngle :> ISQ::planeAngle;
    
    item def VideoFrame {
        attribute width : Integer = 1920;
        attribute height : Integer = 1080;
        attribute timestamp : Real;
    }
    
    item def ControlCommand {
        attribute depth : Length;
        attribute angle : PlaneAngle;
        attribute brightness : Real;
    }
    
    item def DefectReport {
        attribute location : String;
        attribute severity : Integer;
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotential;
    }
    
    port def VideoPort {
        item video : VideoFrame;
    }
    
    port def CommandPort {
        item command : ControlCommand;
    }
    
    port def DataPort {
        item report : DefectReport;
    }
    
    requirement def InspectionRequirement {
        doc /* The videoscope system shall allow remote visual inspection of inaccessible or enclosed areas. */
    }
    
    requirement def TubeLengthRequirement {
        doc /* The insertion tube shall be approximately 2.5 meters in length. */
        subject tube : InsertionTube;
    }
    
    requirement def TubeDiameterRequirement {
        doc /* The insertion tube shall be approximately 6 millimeters in diameter. */
        subject tube : InsertionTube;
    }
    
    requirement def SensorResolutionRequirement {
        doc /* The CMOS image sensor shall capture at 1920x1080 resolution. */
        subject sensor : CMOSImageSensor;
    }
    
    requirement def ArticulationRequirement {
        doc /* The articulation mechanism shall allow bending up to 180 degrees. */
        subject articulation : ArticulationMechanism;
    }
    
    requirement def MonitorSizeRequirement {
        doc /* The monitor shall have a 10-inch screen. */
        subject monitor : Monitor;
    }
    
    requirement def PowerSupplyRequirement {
        doc /* The system shall be powered by a central 12-volt power supply. */
        subject ps : PowerSupply;
    }
    
    requirement def DefectDetectionRequirement {
        doc /* The video processing unit shall automatically detect potential defects. */
        subject processor : VideoProcessingUnit;
    }
    
    requirement def RealTimeDisplayRequirement {
        doc /* The system shall display processed video in real-time on the monitor. */
        subject system : Videoscope;
    }
    
    part def CMOSImageSensor {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        in port powerIn : PowerPort;
        out port videoOut : VideoPort;
    }
    
    part def LEDLightSource {
        attribute maxBrightness : Real = 100;
        in port powerIn : PowerPort;
        in port controlIn : CommandPort;
    }
    
    part def ArticulationMechanism {
        attribute maxAngle : PlaneAngle = 180 [deg];
        in port controlIn : CommandPort;
        in port powerIn : PowerPort;
    }
    
    part def InsertionTube {
        attribute length : Length = 2.5 [m];
        attribute diameter : Length = 0.006 [m];
        
        in port powerIn : PowerPort;
        in port commandIn : CommandPort;
        out port videoOut : VideoPort;
        
        part sensor : CMOSImageSensor;
        part light : LEDLightSource;
        part articulation : ArticulationMechanism;
        
        connect powerIn to sensor.powerIn;
        connect powerIn to light.powerIn;
        connect powerIn to articulation.powerIn;
        connect commandIn to light.controlIn;
        connect commandIn to articulation.controlIn;
        connect sensor.videoOut to videoOut;
    }
    
    part def MainConsole {
        in port powerIn : PowerPort;
        out port commandOut : CommandPort;
        in port videoIn : VideoPort;
    }
    
    part def VideoProcessingUnit {
        in port powerIn : PowerPort;
        in port videoIn : VideoPort;
        out port videoOut : VideoPort;
        out port defectOut : DataPort;
    }
    
    part def Monitor {
        attribute screenSize : Length = 0.254 [m];
        in port powerIn : PowerPort;
        in port videoIn : VideoPort;
    }
    
    part def PowerSupply {
        attribute outputVoltage : ElectricPotential = 12 [V];
        out port powerOut : PowerPort;
    }
    
    part def Videoscope {
        part insertionTube : InsertionTube;
        part console : MainConsole;
        part processor : VideoProcessingUnit;
        part monitor : Monitor;
        part powerSupply : PowerSupply;
        
        connect powerSupply.powerOut to insertionTube.powerIn;
        connect powerSupply.powerOut to console.powerIn;
        connect powerSupply.powerOut to processor.powerIn;
        connect powerSupply.powerOut to monitor.powerIn;
        
        connect console.commandOut to insertionTube.commandIn;
        connect insertionTube.videoOut to processor.videoIn;
        connect processor.videoOut to monitor.videoIn;
        connect processor.videoOut to console.videoIn;
    }
    
    part videoscope : Videoscope;
    
    requirement inspectionReq : InspectionRequirement;
    satisfy inspectionReq by videoscope;
    
    requirement tubeLengthReq : TubeLengthRequirement;
    satisfy tubeLengthReq by videoscope.insertionTube;
    
    requirement tubeDiameterReq : TubeDiameterRequirement;
    satisfy tubeDiameterReq by videoscope.insertionTube;
    
    requirement sensorResReq : SensorResolutionRequirement;
    satisfy sensorResReq by videoscope.insertionTube.sensor;
    
    requirement articulationReq : ArticulationRequirement;
    satisfy articulationReq by videoscope.insertionTube.articulation;
    
    requirement monitorSizeReq : MonitorSizeRequirement;
    satisfy monitorSizeReq by videoscope.monitor;
    
    requirement powerSupplyReq : PowerSupplyRequirement;
    satisfy powerSupplyReq by videoscope.powerSupply;
    
    requirement defectDetectionReq : DefectDetectionRequirement;
    satisfy defectDetectionReq by videoscope.processor;
    
    requirement realTimeDisplayReq : RealTimeDisplayRequirement;
    satisfy realTimeDisplayReq by videoscope;
    
    action def ProcessVideo {
        in rawFrame : VideoFrame;
        out processedFrame : VideoFrame;
        out report : DefectReport;
        
        first start;
        then action enhance {
            in item raw = rawFrame;
            out item processed = processedFrame;
        }
        then action detectDefects {
            in item video = processedFrame;
            out item defect = report;
        }
        then done;
    }
    
    action def InspectionProcess {
        in command : ControlCommand;
        out defectReport : DefectReport;
        
        attribute defectIdentified : Boolean = false;
        attribute taskComplete : Boolean = false;
        
        first start;
        then action guideProbe {
            in item cmd = command;
        }
        then merge observe;
        then action observeFeed;
        then decide;
            if defectIdentified or taskComplete then concludeInspection;
            else observe;
        then action concludeInspection {
            out item report = defectReport;
        }
        then done;
    }
}

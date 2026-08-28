package MicrofabricationSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value type Length_um :> Real {
        private attribute unit : String = "µm";
    }
    
    value type Temperature_C :> Real {
        private attribute unit : String = "°C";
    }
    
    value type Humidity_pct :> Real {
        private attribute unit : String = "%RH";
    }
    
    value type Pressure_Pa :> Real {
        private attribute unit : String = "Pa";
    }
    
    value type LaserPower_mW :> Real {
        private attribute unit : String = "mW";
    }
    
    value type Wavelength_nm :> Real {
        private attribute unit : String = "nm";
    }
    
    value type LayerThickness_nm :> Real {
        private attribute unit : String = "nm";
    }
    
    value type StagePosition_um :> Real {
        private attribute unit : String = "µm";
    }
    
    value type ScanSpeed_mm_per_s :> Real {
        private attribute unit : String = "mm/s";
    }
    
    value type ExposureTime_ms :> Real {
        private attribute unit : String = "ms";
    }
    
    value type NitrogenFlowRate_sccm :> Real {
        private attribute unit : String = "sccm";
    }
    
    value type ImageResolution_px :> Integer {
        private attribute unit : String = "px";
    }
    
    // ===== Item Definitions =====
    
    item def PhotopolymerResin {
        attribute viscosity_cP : Real;
        attribute refractiveIndex : Real;
        attribute absorptionCoefficient_per_um : Real;
        attribute criticalExposure_mJ_per_cm2 : Real;
    }
    
    item def InertGas {
        attribute gasType : String;
        attribute purity_pct : Real;
    }
    
    item def BuildJob {
        attribute jobId : String;
        attribute layerCount : Integer;
        attribute targetLayerThickness : LayerThickness_nm;
        attribute scanPattern : String;
    }
    
    item def LayerImage {
        attribute layerIndex : Integer;
        attribute pixelData : String;
        attribute resolution : ImageResolution_px;
    }
    
    item def InspectionResult {
        attribute layerIndex : Integer;
        attribute pass : Boolean;
        attribute measuredFeatureSize_nm : Real;
        attribute defectCount : Integer;
    }
    
    item def ControlCommand {
        attribute commandType : String;
        attribute timestamp : String;
    }
    
    item def LaserBeam {
        attribute power : LaserPower_mW;
        attribute wavelength : Wavelength_nm;
        attribute spotSize_nm : Real;
    }
    
    // ===== Port Definitions =====
    
    port def ControlPort {
        out item commands : ControlCommand;
        in item status : String;
    }
    
    port def ResinSupplyPort {
        out item resin : PhotopolymerResin;
    }
    
    port def GasFlowPort {
        out item gas : InertGas;
    }
    
    port def LaserOutputPort {
        out item beam : LaserBeam;
    }
    
    port def OpticalPathPort {
        in item inputBeam : LaserBeam;
        out item focusedBeam : LaserBeam;
    }
    
    port def StageMotionPort {
        in item positionCommand : StagePosition_um;
        out item currentPosition : StagePosition_um;
    }
    
    port def ImagingPort {
        out item image : LayerImage;
    }
    
    port def InspectionPort {
        in item image : LayerImage;
        out item result : InspectionResult;
    }
    
    // ===== Requirements =====
    
    requirement def MicrofabricationRequirement {
        subject system : MicrofabricationSystem;
        
        requirement BuildPrecision {
            subject :>> system;
            doc /* The system shall build structures with features smaller than 1 micrometer. */
            attribute minFeatureSize : Length_um = 0.5;
            assert constraint { system.achievedFeatureSize <= minFeatureSize }
        }
        
        requirement EnvironmentalControl {
            subject :>> system;
            doc /* The system shall control temperature, humidity, and atmosphere within the chamber. */
            attribute targetTemp : Temperature_C = 22.0;
            attribute tempTolerance : Temperature_C = 0.5;
            attribute targetHumidity : Humidity_pct = 5.0;
            attribute targetPressure : Pressure_Pa = 101325.0;
            assert constraint { 
                abs(system.chamber.currentTemp - targetTemp) <= tempTolerance and
                system.chamber.currentHumidity <= targetHumidity 
            }
        }
        
        requirement AutomatedFabrication {
            subject :>> system;
            doc /* The entire fabrication process shall be automated. */
            assert constraint { system.controller.automationEnabled == true }
        }
        
        requirement LayerByLayerConstruction {
            subject :>> system;
            doc /* The system shall construct objects layer by layer from photopolymer resin. */
            attribute maxLayerThickness : LayerThickness_nm = 500.0;
            assert constraint { system.currentLayerThickness <= maxLayerThickness }
        }
        
        requirement PostCuring {
            subject :>> system;
            doc /* The system shall perform post-curing to fully harden the finished part. */
            assert constraint { system.postCureCompleted == true }
        }
    }
    
    // ===== Part Definitions =====
    
    part def EnvironmentalChamber {
        port gasIn : GasFlowPort;
        port controlIn : ControlPort;
        
        attribute currentTemp : Temperature_C;
        attribute currentHumidity : Humidity_pct;
        attribute currentPressure : Pressure_Pa;
        attribute nitrogenConcentration_pct : Real;
        
        part heater {
            attribute setpoint : Temperature_C;
            attribute powerLevel : Real;
        }
        
        part humidifier {
            attribute setpoint : Humidity_pct;
            attribute active : Boolean;
        }
        
        part gasCirculation {
            attribute flowRate : NitrogenFlowRate_sccm;
            attribute active : Boolean;
        }
        
        part pressureController {
            attribute setpoint : Pressure_Pa;
        }
        
        exhibit state ChamberControl {
            entry; then Monitoring;
            
            state Monitoring {
                entry; 
                do action MonitorEnvironment;
                transition if currentTemp > 22.5 then to Heating;
                transition if currentHumidity > 5.0 then to Dehumidifying;
                transition if nitrogenConcentration_pct < 99.0 then to Purging;
            }
            
            state Heating {
                do action ActivateHeater;
                transition if currentTemp <= 22.0 then to Monitoring;
            }
            
            state Dehumidifying {
                do action Dehumidify;
                transition if currentHumidity <= 5.0 then to Monitoring;
            }
            
            state Purging {
                do action PurgeWithNitrogen;
                transition if nitrogenConcentration_pct >= 99.0 then to Monitoring;
            }
        }
        
        action MonitorEnvironment {
            in temp : Temperature_C;
            in humidity : Humidity_pct;
            in pressure : Pressure_Pa;
        }
        
        action ActivateHeater {
            out heaterPower : Real;
        }
        
        action Dehumidify {
            out humidifierActive : Boolean;
        }
        
        action PurgeWithNitrogen {
            out flowRate : NitrogenFlowRate_sccm;
        }
    }
    
    part def LaserSource {
        port opticalOut : LaserOutputPort;
        port controlIn : ControlPort;
        
        attribute power : LaserPower_mW;
        attribute wavelength : Wavelength_nm = 405.0;
        attribute spotSize_nm : Real;
        attribute active : Boolean;
        
        exhibit state LaserOperation {
            entry; then Idle;
            
            state Idle {
                entry;
                transition if controlIn.commands.commandType == "laserOn" then to Warming;
            }
            
            state Warming {
                do action WarmUp;
                transition if power >= 50.0 then to Ready;
            }
            
            state Ready {
                do action StabilizeBeam;
                transition if controlIn.commands.commandType == "laserOff" then to Idle;
                transition if controlIn.commands.commandType == "expose" then to Emitting;
            }
            
            state Emitting {
                do action EmitBeam;
                transition if controlIn.commands.commandType == "stopExposure" then to Ready;
            }
        }
        
        action WarmUp {
            out achievedPower : LaserPower_mW;
        }
        
        action StabilizeBeam {
            out stabilizedPower : LaserPower_mW;
        }
        
        action EmitBeam {
            out beam : LaserBeam;
        }
    }
    
    part def OpticalSystem {
        port opticalIn : OpticalPathPort;
        port controlIn : ControlPort;
        
        attribute focusPosition : StagePosition_um;
        attribute scanX : StagePosition_um;
        attribute scanY : StagePosition_um;
        attribute magnification : Real;
        attribute numericalAperture : Real;
        
        part beamExpander {
            attribute expansionRatio : Real;
        }
        
        part galvoScanner {
            attribute xAngle_deg : Real;
            attribute yAngle_deg : Real;
            attribute maxScanSpeed : ScanSpeed_mm_per_s;
        }
        
        part focusingLens {
            attribute focalLength_mm : Real;
            attribute workingDistance_mm : Real;
        }
        
        part beamShaper {
            attribute profileType : String;
        }
        
        exhibit state OpticalControl {
            entry; then Aligning;
            
            state Aligning {
                do action AlignOptics;
                transition then to Focusing;
            }
            
            state Focusing {
                do action SetFocus;
                transition then to Scanning;
            }
            
            state Scanning {
                do action ScanPattern;
                transition if controlIn.commands.commandType == "scanComplete" then to Idle;
            }
            
            state Idle {
                entry;
                transition if controlIn.commands.commandType == "startScan" then to Scanning;
            }
        }
        
        action AlignOptics {
            out alignmentStatus : Boolean;
        }
        
        action SetFocus {
            in targetZ : StagePosition_um;
            out focusPosition : StagePosition_um;
        }
        
        action ScanPattern {
            in pattern : String;
            out xPosition : StagePosition_um;
            out yPosition : StagePosition_um;
        }
    }
    
    part def PrecisionStage {
        port motionPort : StageMotionPort;
        port controlIn : ControlPort;
        
        attribute xPosition : StagePosition_um;
        attribute yPosition : StagePosition_um;
        attribute zPosition : StagePosition_um;
        attribute resolution_nm : Real;
        attribute maxTravel_mm : Real;
        
        part xAxisActuator {
            attribute position : StagePosition_um;
            attribute speed : ScanSpeed_mm_per_s;
        }
        
        part yAxisActuator {
            attribute position : StagePosition_um;
            attribute speed : ScanSpeed_mm_per_s;
        }
        
        part zAxisActuator {
            attribute position : StagePosition_um;
            attribute speed : ScanSpeed_mm_per_s;
        }
        
        part positionSensor {
            attribute accuracy_nm : Real;
        }
        
        exhibit state StageControl {
            entry; then Homing;
            
            state Homing {
                do action HomeStage;
                transition then to Ready;
            }
            
            state Ready {
                entry;
                transition if controlIn.commands.commandType == "move" then to Moving;
            }
            
            state Moving {
                do action MoveToPosition;
                transition if xPosition == motionPort.positionCommand and 
                              yPosition == motionPort.positionCommand and
                              zPosition == motionPort.positionCommand then to Ready;
            }
        }
        
        action HomeStage {
            out xHome : StagePosition_um;
            out yHome : StagePosition_um;
            out zHome : StagePosition_um;
        }
        
        action MoveToPosition {
            in targetX : StagePosition_um;
            in targetY : StagePosition_um;
            in targetZ : StagePosition_um;
            out achievedX : StagePosition_um;
            out achievedY : StagePosition_um;
            out achievedZ : StagePosition_um;
        }
    }
    
    part def MaterialSupplySystem {
        port resinOut : ResinSupplyPort;
        port controlIn : ControlPort;
        
        attribute resinLevel_pct : Real;
        attribute dispenseVolume_uL : Real;
        attribute layerThickness : LayerThickness_nm;
        
        part resinReservoir {
            attribute capacity_mL : Real;
            attribute currentVolume_mL : Real;
        }
        
        part dispensePump {
            attribute flowRate_uL_per_s : Real;
            attribute active : Boolean;
        }
        
        part doctorBlade {
            attribute gap_nm : LayerThickness_nm;
            attribute speed : ScanSpeed_mm_per_s;
        }
        
        part resinHeater {
            attribute setpoint : Temperature_C;
            attribute active : Boolean;
        }
        
        exhibit state SupplyControl {
            entry; then Idle;
            
            state Idle {
                entry;
                transition if controlIn.commands.commandType == "dispense" then to Dispensing;
            }
            
            state Dispensing {
                do action DispenseResin;
                transition then to Leveling;
            }
            
            state Leveling {
                do action LevelLayer;
                transition then to Idle;
            }
        }
        
        action DispenseResin {
            out volume : Real;
        }
        
        action LevelLayer {
            in gap : LayerThickness_nm;
            out achievedThickness : LayerThickness_nm;
        }
    }
    
    part def ImagingSystem {
        port imagingOut : ImagingPort;
        port controlIn : ControlPort;
        
        attribute resolution : ImageResolution_px;
        attribute fieldOfView_um : Length_um;
        attribute illuminationType : String;
        
        part camera {
            attribute pixelCount : ImageResolution_px;
            attribute exposureTime : ExposureTime_ms;
            attribute gain : Real;
        }
        
        part illuminationSource {
            attribute wavelength : Wavelength_nm;
            attribute intensity : Real;
        }
        
        part imagingOptics {
            attribute magnification : Real;
            attribute numericalAperture : Real;
        }
        
        exhibit state ImagingControl {
            entry; then Standby;
            
            state Standby {
                entry;
                transition if controlIn.commands.commandType == "inspect" then to Capturing;
            }
            
            state Capturing {
                do action CaptureImage;
                transition then to Processing;
            }
            
            state Processing {
                do action ProcessImage;
                transition then to Standby;
            }
        }
        
        action CaptureImage {
            out rawImage : LayerImage;
        }
        
        action ProcessImage {
            in rawImage : LayerImage;
            out processedImage : LayerImage;
        }
    }
    
    part def InspectionSystem {
        port inspectionIn : InspectionPort;
        port controlIn : ControlPort;
        
        attribute passThreshold_nm : Real;
        attribute maxDefectCount : Integer;
        
        part imageAnalyzer {
            attribute algorithmType : String;
            attribute confidenceLevel : Real;
        }
        
        part defectDetector {
            attribute sensitivity_nm : Real;
        }
        
        part featureMeasurer {
            attribute accuracy_nm : Real;
        }
        
        exhibit state InspectionControl {
            entry; then Waiting;
            
            state Waiting {
                entry;
                transition if inspectionIn.image != null then to Analyzing;
            }
            
            state Analyzing {
                do action AnalyzeImage;
                transition then to Evaluating;
            }
            
            state Evaluating {
                do action EvaluateResult;
                transition then to Reporting;
            }
            
            state Reporting {
                do action ReportResult;
                transition then to Waiting;
            }
        }
        
        action AnalyzeImage {
            in image : LayerImage;
            out featureSize : Real;
            out defectCount : Integer;
        }
        
        action EvaluateResult {
            in featureSize : Real;
            in defectCount : Integer;
            out pass : Boolean;
        }
        
        action ReportResult {
            out result : InspectionResult;
        }
    }
    
    part def PostCureSystem {
        port controlIn : ControlPort;
        
        attribute uvIntensity_mW_per_cm2 : Real;
        attribute cureTime_min : Real;
        attribute temperature : Temperature_C;
        
        part uvLamp {
            attribute wavelength : Wavelength_nm;
            attribute power : LaserPower_mW;
            attribute active : Boolean;
        }
        
        part cureChamber {
            attribute setpointTemp : Temperature_C;
            attribute currentTemp : Temperature_C;
        }
        
        exhibit state PostCureControl {
            entry; then Idle;
            
            state Idle {
                entry;
                transition if controlIn.commands.commandType == "postCure" then to Preheating;
            }
            
            state Preheating {
                do action Preheat;
                transition if cureChamber.currentTemp >= 40.0 then to Curing;
            }
            
            state Curing {
                do action CurePart;
                transition if cureTime_min >= 30.0 then to Cooling;
            }
            
            state Cooling {
                do action CoolDown;
                transition if cureChamber.currentTemp <= 25.0 then to Complete;
            }
            
            state Complete {
                entry;
                transition if controlIn.commands.commandType == "reset" then to Idle;
            }
        }
        
        action Preheat {
            out targetTemp : Temperature_C;
        }
        
        action CurePart {
            out uvExposure : Real;
            out duration : Real;
        }
        
        action CoolDown {
            out finalTemp : Temperature_C;
        }
    }
    
    part def CentralController {
        port controlOut : ControlPort;
        port stageControl : ControlPort;
        port laserControl : ControlPort;
        port opticalControl : ControlPort;
        port supplyControl : ControlPort;
        port imagingControl : ControlPort;
        port inspectionControl : ControlPort;
        port chamberControl : ControlPort;
        port postCureControl : ControlPort;
        
        attribute automationEnabled : Boolean = true;
        attribute currentLayer : Integer;
        attribute totalLayers : Integer;
        attribute buildComplete : Boolean;
        attribute currentLayerThickness : LayerThickness_nm;
        attribute achievedFeatureSize : Length_um;
        attribute postCureCompleted : Boolean;
        
        part jobManager {
            attribute currentJob : BuildJob;
            attribute layerQueue : Integer[0..*];
        }
        
        part motionPlanner {
            attribute scanPath : String;
            attribute scanSpeed : ScanSpeed_mm_per_s;
        }
        
        part qualityMonitor {
            attribute layerPassCount : Integer;
            attribute layerFailCount : Integer;
            attribute retryCount : Integer;
        }
        
        exhibit state FabricationProcess {
            entry; then Initialize;
            
            state Initialize {
                do action InitializeSystem;
                transition then to LoadJob;
            }
            
            state LoadJob {
                do action LoadBuildJob;
                transition then to PrepareEnvironment;
            }
            
            state PrepareEnvironment {
                do action PrepareChamber;
                transition if chamberControl.status == "environmentReady" then to PositionStage;
            }
            
            state PositionStage {
                do action MoveStageToStart;
                transition if stageControl.status == "positioned" then to DispenseLayer;
            }
            
            state DispenseLayer {
                do action CommandDispense;
                transition if supplyControl.status == "dispenseComplete" then to ExposeLayer;
            }
            
            state ExposeLayer {
                do action CommandExposure;
                transition if laserControl.status == "exposureComplete" then to InspectLayer;
            }
            
            state InspectLayer {
                do action CommandInspection;
                transition if inspectionControl.status == "inspectionComplete" then to EvaluateLayer;
            }
            
            state EvaluateLayer {
                do action EvaluateInspection;
                transition if qualityMonitor.layerPassCount > qualityMonitor.layerFailCount then to AdvanceStage;
                transition if qualityMonitor.retryCount < 3 then to DispenseLayer;
                transition then to ErrorState;
            }
            
            state AdvanceStage {
                do action AdvanceZ;
                transition if currentLayer < totalLayers then to DispenseLayer;
                transition then to PostCure;
            }
            
            state PostCure {
                do action CommandPostCure;
                transition if postCureControl.status == "cureComplete" then to Complete;
            }
            
            state Complete {
                do action FinalizeBuild;
            }
            
            state ErrorState {
                do action HandleError;
                transition if controlOut.commands.commandType == "retry" then to Initialize;
            }
        }
        
        action InitializeSystem {
            out status : String;
        }
        
        action LoadBuildJob {
            in job : BuildJob;
            out totalLayers : Integer;
        }
        
        action PrepareChamber {
            out command : ControlCommand;
        }
        
        action MoveStageToStart {
            out position : StagePosition_um;
        }
        
        action CommandDispense {
            out command : ControlCommand;
        }
        
        action CommandExposure {
            out command : ControlCommand;
            out scanPattern : String;
        }
        
        action CommandInspection {
            out command : ControlCommand;
        }
        
        action EvaluateInspection {
            in result : InspectionResult;
            out pass : Boolean;
        }
        
        action AdvanceZ {
            out deltaZ : StagePosition_um;
        }
        
        action CommandPostCure {
            out command : ControlCommand;
        }
        
        action FinalizeBuild {
            out buildComplete : Boolean;
        }
        
        action HandleError {
            out errorCode : Integer;
        }
    }
    
    // ===== Top-Level System =====
    
    part def MicrofabricationSystem {
        satisfy MicrofabricationRequirement;
        
        attribute achievedFeatureSize : Length_um;
        attribute currentLayerThickness : LayerThickness_nm;
        attribute postCureCompleted : Boolean;
        
        part controller : CentralController {
            :>> automationEnabled = true;
        }
        
        part chamber : EnvironmentalChamber;
        part laser : LaserSource;
        part optics : OpticalSystem;
        part stage : PrecisionStage;
        part materialSupply : MaterialSupplySystem;
        part imaging : ImagingSystem;
        part inspection : InspectionSystem;
        part postCure : PostCureSystem;
        
        // Connections
        connection controller.chamberControl to chamber.controlIn;
        connection controller.laserControl to laser.controlIn;
        connection controller.opticalControl to optics.controlIn;
        connection controller.stageControl to stage.controlIn;
        connection controller.supplyControl to materialSupply.controlIn;
        connection controller.imagingControl to imaging.controlIn;
        connection controller.inspectionControl to inspection.controlIn;
        connection controller.postCureControl to postCure.controlIn;
        
        connection laser.opticalOut to optics.opticalIn;
        connection materialSupply.resinOut to chamber;
        connection imaging.imagingOut to inspection.inspectionIn;
        
        // Internal flow connections
        flow from materialSupply.resinOut.resin to chamber;
        flow from laser.opticalOut.beam to optics.opticalIn.inputBeam;
        flow from optics.opticalIn.focusedBeam to stage;
        flow from imaging.imagingOut.image to inspection.inspectionIn.image;
    }
}

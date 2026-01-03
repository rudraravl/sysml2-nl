package AirtraqVideoLaryngoscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ViewQuality {
        attribute clarity : Real;
        attribute brightness : Real;
        attribute contrast : Real;
    }
    
    attribute def AirwayAnatomyData {
        attribute glottisDepth : LengthValue;
        attribute oralCavityWidth : LengthValue;
        attribute laryngealAxis : Real;
    }
    
    item def Patient {
        attribute airwayAnatomy : AirwayAnatomyData;
        attribute sedationLevel : Real;
    }
    
    item def EndotrachealTube {
        attribute diameter : LengthValue;
        attribute tubeLength : LengthValue;
        attribute cuffPressure : PressureValue;
    }
    
    item def OpticalSignal;
    item def VideoSignal;
    item def ElectricalPower;
    item def PowerOnCommand;
    item def BladePositionedEvent;
    item def IlluminationStableEvent;
    item def RepositionCompleteEvent;
    item def ProceedWithTubeCommand;
    item def TubeAdvancedEvent;
    item def DeviceRemovedEvent;
    
    port def PowerPort {
        out power : ElectricalPower;
    }
    
    port def OpticalPort {
        out opticalSignal : OpticalSignal;
    }
    
    port def VideoPort {
        in videoInput : VideoSignal;
        out videoOutput : VideoSignal;
    }
    
    port def ViewingPort {
        in displaySignal : VideoSignal;
    }
    
    port def GuidancePort {
        in tube : EndotrachealTube;
        out tubePosition : LengthValue;
    }
    
    part def BatteryModule {
        attribute voltage : Real;
        attribute capacity : Real;
        attribute chargeLevel : Real;
        port batteryOutput : PowerPort;
    }
    
    part def LEDIlluminationSystem {
        attribute luminousFlux : Real;
        attribute colorTemperature : ThermodynamicTemperatureValue;
        port powerInput : PowerPort;
        port lightOutput : OpticalPort;
    }
    
    part def OpticalPrismSystem {
        attribute prismAngle : Real;
        attribute transmissionEfficiency : Real;
        port lightInput : OpticalPort;
        port imageOutput : OpticalPort;
    }
    
    part def MicroCameraModule {
        attribute resolution : Real;
        attribute frameRate : Real;
        attribute sensorSize : AreaValue;
        port powerInput : PowerPort;
        port opticalInput : OpticalPort;
        port videoOutput : VideoPort;
    }
    
    part def VideoProcessingUnit {
        attribute processingDelay : TimeValue;
        attribute imageEnhancement : Real;
        port powerInput : PowerPort;
        port videoInput : VideoPort;
        port videoOutput : VideoPort;
    }
    
    part def DisplayScreen {
        attribute screenSize : LengthValue;
        attribute displayResolution : Real;
        attribute viewingAngle : Real;
        port powerInput : PowerPort;
        port videoInput : ViewingPort;
    }
    
    part def AnatomicalBlade {
        attribute bladeLength : LengthValue;
        attribute bladeCurvature : Real;
        attribute bladeThickness : LengthValue;
    }
    
    part def TubeGuidingChannel {
        attribute channelDiameter : LengthValue;
        attribute channelAngle : Real;
        port tubeGuide : GuidancePort;
    }
    
    part def AirtraqLaryngoscope {
        part battery : BatteryModule {
            attribute voltage = 3.0;
            attribute capacity = 1500.0;
            attribute chargeLevel = 100.0;
        }
        
        part ledSystem : LEDIlluminationSystem {
            attribute luminousFlux = 1200.0;
            attribute colorTemperature = 5500.0 [K];
        }
        
        part prismOptics : OpticalPrismSystem {
            attribute prismAngle = 45.0;
            attribute transmissionEfficiency = 0.92;
        }
        
        part microCamera : MicroCameraModule {
            attribute resolution = 1920.0;
            attribute frameRate = 30.0;
            attribute sensorSize = 4.0 [mm^2];
        }
        
        part videoProcessor : VideoProcessingUnit {
            attribute processingDelay = 0.05 [s];
            attribute imageEnhancement = 1.3;
        }
        
        part displayUnit : DisplayScreen {
            attribute screenSize = 2.4 ['in'];
            attribute displayResolution = 320.0;
            attribute viewingAngle = 120.0;
        }
        
        part blade : AnatomicalBlade {
            attribute bladeLength = 115.0 [mm];
            attribute bladeCurvature = 55.0;
            attribute bladeThickness = 3.5 [mm];
        }
        
        part tubeChannel : TubeGuidingChannel {
            attribute channelDiameter = 8.0 [mm];
            attribute channelAngle = 40.0;
        }
        
        connect battery.batteryOutput to ledSystem.powerInput;
        connect battery.batteryOutput to microCamera.powerInput;
        connect battery.batteryOutput to videoProcessor.powerInput;
        connect battery.batteryOutput to displayUnit.powerInput;
        connect ledSystem.lightOutput to prismOptics.lightInput;
        connect prismOptics.imageOutput to microCamera.opticalInput;
        connect microCamera.videoOutput to videoProcessor.videoInput;
        connect videoProcessor.videoOutput to displayUnit.videoInput;
    }
    
    action def InsertBlade {
        in patient : Patient;
        in blade : AnatomicalBlade;
        out insertionDepth : LengthValue;
        out bladePosition : AirwayAnatomyData;
    }
    
    action def ActivateIllumination {
        in ledSystem : LEDIlluminationSystem;
        out illuminationActive : Boolean;
    }
    
    action def CaptureAirwayImage {
        in camera : MicroCameraModule;
        in optics : OpticalPrismSystem;
        out rawVideoSignal : VideoSignal;
    }
    
    action def ProcessVideo {
        in processor : VideoProcessingUnit;
        in rawSignal : VideoSignal;
        out enhancedSignal : VideoSignal;
        out viewQuality : ViewQuality;
    }
    
    action def DisplayAirwayView {
        in display : DisplayScreen;
        in videoSignal : VideoSignal;
        out visualizationComplete : Boolean;
    }
    
    action def IdentifyGlottis {
        in viewQuality : ViewQuality;
        in airwayData : AirwayAnatomyData;
        out glottisVisible : Boolean;
        out glottisLocation : LengthValue;
    }
    
    action def GuideTubeThroughChannel {
        in tubeChannel : TubeGuidingChannel;
        in tube : EndotrachealTube;
        in targetLocation : LengthValue;
        out tubeAdvancement : LengthValue;
    }
    
    action def VerifyTubePlacement {
        in viewQuality : ViewQuality;
        in tubePosition : LengthValue;
        in glottisLocation : LengthValue;
        out placementCorrect : Boolean;
    }
    
    action def PerformIntubationProcedure {
        in patient : Patient;
        in device : AirtraqLaryngoscope;
        in endotrachealTube : EndotrachealTube;
        out intubationSuccessful : Boolean;
        
        first start;
        
        then action insertBladeAction : InsertBlade {
            in patient = PerformIntubationProcedure::patient;
            in blade = device.blade;
            out insertionDepth;
            out bladePosition;
        }
        
        then action activateLights : ActivateIllumination {
            in ledSystem = device.ledSystem;
            out illuminationActive;
        }
        
        then merge visualizationLoop;
        
        then action captureImage : CaptureAirwayImage {
            in camera = device.microCamera;
            in optics = device.prismOptics;
            out rawVideoSignal;
        }
        
        then action processImage : ProcessVideo {
            in processor = device.videoProcessor;
            in rawSignal = captureImage.rawVideoSignal;
            out enhancedSignal;
            out viewQuality;
        }
        
        then action displayView : DisplayAirwayView {
            in display = device.displayUnit;
            in videoSignal = processImage.enhancedSignal;
            out visualizationComplete;
        }
        
        then action identifyTarget : IdentifyGlottis {
            in viewQuality = processImage.viewQuality;
            in airwayData = insertBladeAction.bladePosition;
            out glottisVisible;
            out glottisLocation;
        }
        
        then decide;
            if identifyTarget.glottisVisible and processImage.viewQuality.clarity >= 0.75 then proceedWithIntubation;
            if not identifyTarget.glottisVisible or processImage.viewQuality.clarity < 0.75 then adjustPosition;
        
        action adjustPosition : InsertBlade {
            in patient = PerformIntubationProcedure::patient;
            in blade = device.blade;
            out insertionDepth;
            out bladePosition;
        }
        then visualizationLoop;
        
        action proceedWithIntubation {
            action guideTube : GuideTubeThroughChannel {
                in tubeChannel = device.tubeChannel;
                in tube = PerformIntubationProcedure::endotrachealTube;
                in targetLocation = identifyTarget.glottisLocation;
                out tubeAdvancement;
            }
            
            then action verifyPlacement : VerifyTubePlacement {
                in viewQuality = processImage.viewQuality;
                in tubePosition = guideTube.tubeAdvancement;
                in glottisLocation = identifyTarget.glottisLocation;
                out placementCorrect;
            }
            
            then decide;
                if verifyPlacement.placementCorrect then confirmSuccess;
                if not verifyPlacement.placementCorrect then retryGuidance;
            
            action confirmSuccess {
                assign intubationSuccessful := true;
            }
            then done;
            
            action retryGuidance : GuideTubeThroughChannel {
                in tubeChannel = device.tubeChannel;
                in tube = PerformIntubationProcedure::endotrachealTube;
                in targetLocation = identifyTarget.glottisLocation;
                out tubeAdvancement;
            }
            then verifyPlacement;
        }
    }
    
    state def IntubationOperatingStates {
        entry; then standby;
        
        state standby {
            entry assign systemReady := false;
        }
        
        transition standby_to_bladeInsertion
            first standby
            accept powerOn : PowerOnCommand
            then bladeInsertion;
        
        state bladeInsertion {
            entry assign bladeInserted := false;
        }
        
        transition bladeInsertion_to_illuminating
            first bladeInsertion
            accept bladePos : BladePositionedEvent
            then illuminating;
        
        state illuminating {
            entry assign lightsActive := true;
        }
        
        transition illuminating_to_visualizing
            first illuminating
            accept illumStable : IlluminationStableEvent
            then visualizing;
        
        state visualizing {
            entry assign viewingActive := true;
        }
        
        transition visualizing_to_targeting
            first visualizing
            if glottisIdentified
            then targeting;
        
        transition visualizing_to_repositioning
            first visualizing
            if not glottisIdentified and repositionAttempts < 3
            then repositioning;
        
        state repositioning {
            entry assign adjustingBlade := true;
        }
        
        transition repositioning_to_visualizing
            first repositioning
            accept reposComplete : RepositionCompleteEvent
            then visualizing;
        
        state targeting {
            entry assign targetLocked := true;
        }
        
        transition targeting_to_tubeInsertion
            first targeting
            accept proceedCmd : ProceedWithTubeCommand
            then tubeInsertion;
        
        state tubeInsertion {
            entry assign insertingTube := true;
        }
        
        transition tubeInsertion_to_verification
            first tubeInsertion
            accept tubeAdv : TubeAdvancedEvent
            then verification;
        
        state verification {
            entry assign verifyingPlacement := true;
        }
        
        transition verification_to_complete
            first verification
            if placementVerified
            then complete;
        
        transition verification_to_tubeInsertion
            first verification
            if not placementVerified and insertionAttempts < 2
            then tubeInsertion;
        
        state complete {
            entry assign procedureComplete := true;
        }
        
        transition complete_to_standby
            first complete
            accept deviceRemoved : DeviceRemovedEvent
            then standby;
        
        attribute systemReady : Boolean;
        attribute bladeInserted : Boolean;
        attribute lightsActive : Boolean;
        attribute viewingActive : Boolean;
        attribute glottisIdentified : Boolean;
        attribute repositionAttempts : Integer;
        attribute adjustingBlade : Boolean;
        attribute targetLocked : Boolean;
        attribute insertingTube : Boolean;
        attribute verifyingPlacement : Boolean;
        attribute placementVerified : Boolean;
        attribute insertionAttempts : Integer;
        attribute procedureComplete : Boolean;
    }
    
    requirement def OpticalSystemRequirement {
        doc /* The optical system shall provide continuous, clear visualization of the laryngeal structures 
                with minimum 0.75 clarity index and 45-degree field of view. */
        
        subject opticalSystem : AirtraqLaryngoscope;
        
        require constraint {
            opticalSystem.prismOptics.prismAngle >= 40.0 and
            opticalSystem.prismOptics.prismAngle <= 50.0
        }
        
        require constraint {
            opticalSystem.prismOptics.transmissionEfficiency >= 0.85
        }
        
        require constraint {
            opticalSystem.microCamera.resolution >= 1280.0
        }
    }
    
    requirement def IlluminationRequirement {
        doc /* The LED illumination system shall provide uniform, bright illumination of the airway 
                with minimum 1000 lumens luminous flux and 5000K color temperature for accurate tissue visualization. */
        
        subject illuminationSystem : LEDIlluminationSystem;
        
        require constraint {
            illuminationSystem.luminousFlux >= 1000.0
        }
        
        require constraint {
            illuminationSystem.colorTemperature >= 5000.0 [K] and
            illuminationSystem.colorTemperature <= 6000.0 [K]
        }
    }
    
    requirement def TubeGuidanceRequirement {
        doc /* The tube guiding channel shall accommodate endotracheal tubes from 6.0mm to 8.5mm diameter 
                and guide them at optimal angle between 35 and 45 degrees toward the glottic opening. */
        
        subject guidanceSystem : TubeGuidingChannel;
        
        require constraint {
            guidanceSystem.channelDiameter >= 6.0 [mm] and
            guidanceSystem.channelDiameter <= 8.5 [mm]
        }
        
        require constraint {
            guidanceSystem.channelAngle >= 35.0 and
            guidanceSystem.channelAngle <= 45.0
        }
    }
    
    requirement def PowerSystemRequirement {
        doc /* The battery module shall provide sufficient power for minimum 60 minutes of continuous operation 
                at full illumination and video processing capability. */
        
        subject powerSystem : BatteryModule;
        
        require constraint {
            powerSystem.capacity >= 1200.0
        }
        
        require constraint {
            powerSystem.voltage >= 2.8 and powerSystem.voltage <= 3.2
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Airtraq Video Laryngoscope System shall enable safe, efficient endotracheal intubation 
                by providing continuous indirect visualization of the glottic opening and guiding the endotracheal tube 
                into the trachea with minimal trauma to patient tissues. */
        
        subject system : AirtraqLaryngoscope;
        
        assume constraint patientCondition {
            doc /* Patient airway anatomy is within normal anatomical variation and patient is adequately sedated. */
        }
        
        require opticalPerformance : OpticalSystemRequirement {
            subject opticalSystem = system;
        }
        
        require illuminationPerformance : IlluminationRequirement {
            subject illuminationSystem = system.ledSystem;
        }
        
        require tubeGuidance : TubeGuidanceRequirement {
            subject guidanceSystem = system.tubeChannel;
        }
        
        require powerSupply : PowerSystemRequirement {
            subject powerSystem = system.battery;
        }
    }
    
    part airtraqSystem : AirtraqLaryngoscope {
        perform action intubationProcedure[*] ordered references PerformIntubationProcedure;
        
        exhibit state operatingStateMachine : IntubationOperatingStates;
    }
}

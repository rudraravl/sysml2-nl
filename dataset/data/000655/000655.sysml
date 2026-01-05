package IntubationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenSaturation {
        attribute value : Real;
        attribute unit : String = "%";
    }
    
    attribute def AirwayPressure :> ISQ::PressureValue;
    
    attribute def TubeSize {
        attribute innerDiameter : ISQ::LengthValue;
        attribute outerDiameter : ISQ::LengthValue;
    }
    
    attribute def VentilationRate {
        attribute breathsPerMinute : Real;
    }
    
    attribute def CuffPressure :> ISQ::PressureValue;
    
    attribute def InsertionDepth :> ISQ::LengthValue;
    
    item def OxygenatedAir {
        attribute oxygenConcentration : Real;
        attribute flowRate : ISQ::VolumeFlowRateValue;
    }
    
    item def ExhaledGas {
        attribute co2Concentration : Real;
        attribute volume : ISQ::VolumeValue;
    }
    
    port def AirwayPort {
        out item deliveredAir : OxygenatedAir;
        in item exhaledGas : ExhaledGas;
        attribute pressure : AirwayPressure;
    }
    
    port def VentilatorPort {
        out item oxygenFlow : OxygenatedAir;
        in item returnFlow : ExhaledGas;
    }
    
    port def MonitoringPort {
        in oxygenSaturation : OxygenSaturation;
        in endTidalCO2 : Real;
        in airwayPressure : AirwayPressure;
    }
    
    part def EndotrachealTube {
        attribute tubeSize : TubeSize;
        attribute cuffPressure : CuffPressure;
        attribute insertionDepth : InsertionDepth;
        port proximalEnd : VentilatorPort;
        port distalEnd : AirwayPort;
    }
    
    part def Laryngoscope {
        attribute bladeType : String;
        attribute lightIntensity : Real;
        attribute batteryLevel : Real;
    }
    
    part def VentilationBag {
        attribute bagVolume : ISQ::VolumeValue;
        attribute maxPressure : AirwayPressure;
        port bagOutlet : VentilatorPort;
    }
    
    part def OxygenSource {
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute oxygenConcentration : Real;
        attribute tankPressure : ISQ::PressureValue;
        port oxygenOutlet : VentilatorPort;
    }
    
    part def SuctionDevice {
        attribute suctionPressure : ISQ::PressureValue;
        attribute catheterSize : ISQ::LengthValue;
    }
    
    part def Patient {
        attribute baselineOxygenSaturation : OxygenSaturation;
        attribute airwayPatency : String;
        attribute consciousnessLevel : String;
        attribute lungCompliance : Real;
        port airway : AirwayPort;
        port monitoring : MonitoringPort;
    }
    
    part def IntubationEquipment {
        part etTube : EndotrachealTube;
        part scope : Laryngoscope;
        part bag : VentilationBag;
        part oxygenSupply : OxygenSource;
        part suction : SuctionDevice;
    }
    
    action def AssessPatient {
        in patient : Patient;
        out assessmentComplete : Boolean;
        out airwayStatus : String;
        out oxygenLevel : OxygenSaturation;
        out requiresIntubation : Boolean;
    }
    
    action def PreOxygenate {
        in oxygenSource : OxygenSource;
        in targetSaturation : Real;
        in duration : ISQ::TimeValue;
        out currentSaturation : OxygenSaturation;
        out preoxygenationComplete : Boolean;
    }
    
    action def PositionPatient {
        in patient : Patient;
        out headPosition : String;
        out neckAlignment : String;
        out positioningComplete : Boolean;
    }
    
    action def SuctionAirway {
        in suctionDevice : SuctionDevice;
        in patient : Patient;
        out airwayClear : Boolean;
    }
    
    action def VisualizeLarynx {
        in laryngoscope : Laryngoscope;
        in patient : Patient;
        out vocalCordsVisible : Boolean;
        out glotticOpening : String;
        out visualizationQuality : Real;
    }
    
    action def InsertTube {
        in tube : EndotrachealTube;
        in vocalCordsVisible : Boolean;
        in targetDepth : InsertionDepth;
        out tubeInserted : Boolean;
        out actualDepth : InsertionDepth;
    }
    
    action def InflateCuff {
        in tube : EndotrachealTube;
        in targetPressure : CuffPressure;
        out cuffInflated : Boolean;
        out sealAchieved : Boolean;
        out actualPressure : CuffPressure;
    }
    
    action def ConfirmPlacement {
        in tube : EndotrachealTube;
        in patient : Patient;
        out endTidalCO2Detected : Boolean;
        out bilateralBreathSounds : Boolean;
        out chestRiseSymmetric : Boolean;
        out placementConfirmed : Boolean;
    }
    
    action def SecureTube {
        in tube : EndotrachealTube;
        out tubeSecured : Boolean;
        out depthMarked : InsertionDepth;
    }
    
    action def InitiateVentilation {
        in ventilationBag : VentilationBag;
        in ventilationRate : VentilationRate;
        in targetPressure : AirwayPressure;
        out ventilationActive : Boolean;
        out oxygenSaturation : OxygenSaturation;
    }
    
    action def RemoveTube {
        in tube : EndotrachealTube;
        out tubeRemoved : Boolean;
    }
    
    action def AbortProcedure {
        out procedureAborted : Boolean;
    }
    
    action def PerformIntubation {
        in patient : Patient;
        in equipment : IntubationEquipment;
        out intubationSuccessful : Boolean;
        out airwaySecured : Boolean;
        
        first start;
        
        then action assess : AssessPatient {
            in patient = PerformIntubation::patient;
            out assessmentComplete;
            out airwayStatus;
            out oxygenLevel;
            out requiresIntubation;
        }
        
        then decide;
            if assess.requiresIntubation then preoxygenate;
            else abort;
        
        action preoxygenate : PreOxygenate {
            in oxygenSource = equipment.oxygenSupply;
            in targetSaturation = 100.0;
            in duration = 180.0 [SI::s];
            out currentSaturation;
            out preoxygenationComplete;
        }
        then position;
        
        action position : PositionPatient {
            in patient = PerformIntubation::patient;
            out headPosition;
            out neckAlignment;
            out positioningComplete;
        }
        then suction;
        
        action suction : SuctionAirway {
            in suctionDevice = equipment.suction;
            in patient = PerformIntubation::patient;
            out airwayClear;
        }
        then visualize;
        
        action visualize : VisualizeLarynx {
            in laryngoscope = equipment.scope;
            in patient = PerformIntubation::patient;
            out vocalCordsVisible;
            out glotticOpening;
            out visualizationQuality;
        }
        then decide;
            if visualize.vocalCordsVisible and visualize.visualizationQuality >= 0.7 then insert;
            else repositionAndRetry;
        
        action insert : InsertTube {
            in tube = equipment.etTube;
            in vocalCordsVisible = visualize.vocalCordsVisible;
            in targetDepth = 21.0 [SI::cm];
            out tubeInserted;
            out actualDepth;
        }
        then inflateCuff;
        
        action repositionAndRetry {
            then position;
        }
        
        action inflateCuff : InflateCuff {
            in tube = equipment.etTube;
            in targetPressure = 2500.0 [SI::Pa];
            out cuffInflated;
            out sealAchieved;
            out actualPressure;
        }
        then confirm;
        
        action confirm : ConfirmPlacement {
            in tube = equipment.etTube;
            in patient = PerformIntubation::patient;
            out endTidalCO2Detected;
            out bilateralBreathSounds;
            out chestRiseSymmetric;
            out placementConfirmed;
        }
        then decide;
            if confirm.placementConfirmed then secure;
            else removeTubeAndRetry;
        
        action secure : SecureTube {
            in tube = equipment.etTube;
            out tubeSecured;
            out depthMarked;
        }
        then ventilate;
        
        action removeTubeAndRetry : RemoveTube {
            in tube = equipment.etTube;
            out tubeRemoved;
        }
        then visualize;
        
        action ventilate : InitiateVentilation {
            in ventilationBag = equipment.bag;
            in ventilationRate;
            in targetPressure = 2000.0 [SI::Pa];
            out ventilationActive;
            out oxygenSaturation;
        }
        then assign intubationSuccessful := true;
        then assign airwaySecured := true;
        then done;
        
        action abort : AbortProcedure {
            out procedureAborted;
        }
        then assign intubationSuccessful := false;
        then assign airwaySecured := false;
        then done;
    }
    
    state def IntubationLifecycle {
        entry; then idle;
        
        state idle;
        transition idle to preparing;
        
        state preparing {
            entry; then assessingPatient;
            state assessingPatient;
            transition assessingPatient to preoxygenating;
            state preoxygenating;
            transition preoxygenating to positioning;
            state positioning;
        }
        transition preparing to visualizing;
        
        state visualizing;
        transition visualizing to inserting;
        
        state inserting;
        transition inserting to confirming;
        
        state confirming;
        transition confirming to ventilating 
            if "placementConfirmed";
        transition confirming to visualizing 
            if "!placementConfirmed";
        
        state ventilating;
        transition ventilating to monitoring;
        
        state monitoring;
        transition monitoring to extubating;
        
        state extubating;
        transition extubating to done;
    }
    
    requirement def AirwayManagementRequirement {
        doc /* The intubation system shall establish and maintain a secure artificial 
               airway for patients requiring mechanical ventilation or airway protection. */
        
        require oxygenationRequirement : OxygenationRequirement;
        require placementVerificationRequirement : PlacementVerificationRequirement;
        require safetyRequirement : SafetyRequirement;
    }
    
    requirement def OxygenationRequirement {
        doc /* The system shall maintain patient oxygen saturation above 90% 
               throughout the intubation procedure. */
        
        subject patient : Patient;
        
        require constraint {
            patient.monitoring.oxygenSaturation.value >= 90.0
        }
    }
    
    requirement def PlacementVerificationRequirement {
        doc /* Endotracheal tube placement shall be confirmed using multiple 
               verification methods including capnography and auscultation. */
        
        subject confirmation : ConfirmPlacement;
        
        require constraint {
            confirmation.endTidalCO2Detected and 
            confirmation.bilateralBreathSounds and 
            confirmation.chestRiseSymmetric
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall prevent complications including esophageal intubation,
               tube misplacement, and airway trauma. */
        
        require constraint cuffPressureLimit {
            doc /* Cuff pressure shall not exceed 30 cmH2O (approximately 2940 Pa) 
                   to prevent tracheal ischemia. */
        }
        
        require constraint insertionAttemptLimit {
            doc /* Number of insertion attempts shall be limited to minimize trauma 
                   and hypoxemia risk. */
        }
        
        require constraint preoxygenationDuration {
            doc /* Pre-oxygenation shall be performed for at least 3 minutes 
                   to maximize oxygen reserves. */
        }
    }
    
    part intubationSystem {
        doc /* 
        This model describes an endotracheal intubation system used in emergency and 
        critical care medicine. The system's primary function is to establish and maintain 
        a secure artificial airway in patients who cannot protect their own airway or 
        require mechanical ventilation support.
        
        The intubation process operates through a carefully sequenced series of clinical 
        actions. It begins with patient assessment to evaluate airway anatomy, baseline 
        oxygenation status, and the need for intubation. The patient is then pre-oxygenated 
        for several minutes to maximize oxygen reserves and provide a safety buffer during 
        the procedure. Proper positioning optimizes visualization of the airway structures.
        
        The airway is suctioned to clear secretions, then a laryngoscope is used to 
        visualize the vocal cords and glottic opening. Once adequate visualization is 
        achieved, an endotracheal tube is carefully inserted through the vocal cords into 
        the trachea to a predetermined depth. The tube's cuff is then inflated to create 
        a seal, preventing aspiration and enabling positive pressure ventilation.
        
        Critical to patient safety, tube placement must be confirmed through multiple methods 
        including detection of exhaled carbon dioxide, auscultation of bilateral breath sounds, 
        and observation of symmetric chest rise. Only after confirmation is the tube secured 
        at a marked depth and mechanical ventilation initiated. If placement cannot be confirmed, 
        the tube is removed and the procedure repeated with repositioning.
        
        This system integrates specialized equipment including the endotracheal tube, 
        laryngoscope, ventilation bag, oxygen source, and suction device. Clinical technique 
        and continuous physiological monitoring work together to achieve the life-saving goal 
        of securing the airway while minimizing complications such as hypoxemia, tube 
        misplacement, or airway trauma.
        */
        
        part patient : Patient {
            attribute baselineOxygenSaturation.value = 95.0;
            attribute airwayPatency = "patent";
            attribute consciousnessLevel = "unconscious";
            attribute lungCompliance = 0.8;
        }
        
        part equipment : IntubationEquipment {
            part etTube : EndotrachealTube {
                attribute tubeSize.innerDiameter = 7.5 [SI::mm];
                attribute tubeSize.outerDiameter = 10.0 [SI::mm];
                attribute insertionDepth = 21.0 [SI::cm];
                attribute cuffPressure = 2500.0 [SI::Pa];
            }
            
            part scope : Laryngoscope {
                attribute bladeType = "Macintosh 3";
                attribute lightIntensity = 100.0;
                attribute batteryLevel = 95.0;
            }
            
            part bag : VentilationBag {
                attribute bagVolume = 1600.0 [SI::mL];
                attribute maxPressure = 4000.0 [SI::Pa];
            }
            
            part oxygenSupply : OxygenSource {
                attribute flowRate = 15.0 [SI::L/SI::min];
                attribute oxygenConcentration = 100.0;
                attribute tankPressure = 2000000.0 [SI::Pa];
            }
            
            part suction : SuctionDevice {
                attribute suctionPressure = 20000.0 [SI::Pa];
                attribute catheterSize = 14.0 [SI::mm];
            }
        }
        
        perform action intubationProcedure : PerformIntubation {
            in patient = intubationSystem::patient;
            in equipment = intubationSystem::equipment;
            out intubationSuccessful;
            out airwaySecured;
        }
        
        state behavior lifecycle : IntubationLifecycle;
        
        satisfy airwayManagementReq : AirwayManagementRequirement;
        
        connection oxygenDelivery connect 
            equipment.oxygenSupply.oxygenOutlet to equipment.bag.bagOutlet;
        
        connection tubeToPatient connect 
            equipment.etTube.distalEnd to patient.airway;
        
        connection ventilatorToTube connect 
            equipment.bag.bagOutlet to equipment.etTube.proximalEnd;
    }
}

package VeressNeedleInsufflationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    
    item def CarbonDioxide;
    
    item def AbdominalWall {
        attribute thickness : LengthValue;
        attribute layers : Integer;
    }
    
    item def PeritonealCavity {
        attribute currentPressure : PressureValue;
        attribute currentVolume : VolumeValue;
    }
    
    port def GasFlowPort {
        in item gas : CarbonDioxide;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    
    part def SpringLoadedObturator {
        attribute springForce : ForceValue;
        attribute retracted : Boolean;
        attribute extensionLength : LengthValue;
    }
    
    part def SharpCannula {
        attribute outerDiameter : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute totalLength : LengthValue;
        attribute tipSharpness : Real;
    }
    
    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensingPort;
    }
    
    part def Stopcock {
        attribute isOpen : Boolean;
        port proximalPort : GasFlowPort;
        port distalPort : GasFlowPort;
    }
    
    part def VeressNeedle {
        attribute insertionDepth : LengthValue;
        attribute currentResistance : ForceValue;
        
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        
        part cannula : SharpCannula {
            attribute :>> outerDiameter = 2.1 [SI::mm];
            attribute :>> innerDiameter = 1.8 [SI::mm];
            attribute :>> totalLength = 120.0 [SI::mm];
            attribute :>> tipSharpness = 0.95;
        }
        
        part obturator : SpringLoadedObturator {
            attribute :>> springForce = 4.5 [SI::N];
            attribute :>> retracted = true;
            attribute :>> extensionLength = 5.0 [SI::mm];
        }
        
        part stopcock : Stopcock {
            attribute :>> isOpen = false;
        }
        
        part sensor : PressureSensor {
            attribute :>> measuredPressure = 0.0 [SI::kPa];
        }
        
        connection gasPath connect gasInlet to stopcock.proximalPort;
        connection internalPath connect stopcock.distalPort to gasOutlet;
    }
    
    part def CO2Insufflator {
        attribute setPressure : PressureValue;
        attribute setFlowRate : FlowRateValue;
        attribute cylinderPressure : PressureValue;
        
        port gasSupply : GasFlowPort;
        
        action def RegulateGasFlow {
            in targetPressure : PressureValue;
            in targetFlow : FlowRateValue;
            out actualFlow : FlowRateValue;
        }
    }
    
    action def PositionNeedle {
        in insertionSite : AbdominalWall;
        in angle : Real;
        out positioned : Boolean;
    }
    
    action def PenetrateAbdominalWall {
        in appliedForce : ForceValue;
        in targetDepth : LengthValue;
        out resistanceEncountered : ForceValue;
        out cavityEntered : Boolean;
    }
    
    action def VerifyPlacement {
        in aspirationTest : Boolean;
        in salineDropTest : Boolean;
        in pressureReading : PressureValue;
        out placementConfirmed : Boolean;
    }
    
    action def InsufflateAbdomen {
        in targetPressure : PressureValue;
        in flowRate : FlowRateValue;
        out currentPressure : PressureValue;
        out insufflationComplete : Boolean;
    }
    
    action def PerformVeressNeedleInsertion {
        first start;
        
        then action prepareEquipment {
            doc /* Verify needle integrity, check spring mechanism, 
                 * and confirm CO2 supply availability. */
        }
        
        then action positionNeedle : PositionNeedle {
            in insertionSite : AbdominalWall;
            in angle = 90.0;
            out positioned : Boolean;
        }
        
        then action penetrate : PenetrateAbdominalWall {
            in appliedForce : ForceValue;
            in targetDepth : LengthValue;
            out resistanceEncountered : ForceValue;
            out cavityEntered : Boolean;
        }
        
        then decide;
            if penetrate.cavityEntered then verifyPlacement;
            if not penetrate.cavityEntered then repositionAndRetry;
        
        action verifyPlacement : VerifyPlacement {
            in aspirationTest = true;
            in salineDropTest = true;
            in pressureReading : PressureValue;
            out placementConfirmed : Boolean;
        }
        
        then decide;
            if verifyPlacement.placementConfirmed then insufflate;
            if not verifyPlacement.placementConfirmed then repositionAndRetry;
        
        action insufflate : InsufflateAbdomen {
            in targetPressure = 2.0 [SI::kPa];
            in flowRate = 0.025 [SI::'m^3/s'];
            out currentPressure : PressureValue;
            out insufflationComplete : Boolean;
        }
        
        then action completeProcedure {
            doc /* Target pneumoperitoneum pressure achieved, 
                 * ready for trocar insertion. */
        }
        
        then done;
        
        action repositionAndRetry {
            doc /* Withdraw needle partially and attempt insertion 
                 * at adjusted angle or position. */
        }
        then positionNeedle;
    }
    
    state def VeressNeedleOperationStateMachine {
        entry; then idle;
        
        state idle {
            doc /* Needle prepared but not yet inserted. */
        }
        
        transition idle_to_advancing
            first idle
            accept insertionInitiated
            then advancing;
        
        state advancing {
            doc /* Needle advancing through abdominal wall layers. */
        }
        
        transition advancing_to_breached
            first advancing
            accept pressureDropDetected
            then peritoneumBreached;
        
        transition advancing_loop
            first advancing
            accept continuedResistance
            then advancing;
        
        state peritoneumBreached {
            doc /* Sudden pressure drop indicates peritoneal cavity entry. */
        }
        
        transition breached_to_verifying
            first peritoneumBreached
            then verifying;
        
        state verifying {
            doc /* Performing placement verification tests. */
        }
        
        transition verifying_to_insufflating
            first verifying
            accept placementVerified
            then insufflating;
        
        transition verifying_to_repositioning
            first verifying
            accept placementFailed
            then repositioning;
        
        state insufflating {
            doc /* CO2 gas flowing into peritoneal cavity. */
        }
        
        transition insufflating_to_target
            first insufflating
            accept pressureAtTarget
            then targetReached;
        
        state targetReached {
            doc /* Pneumoperitoneum established at target pressure. */
        }
        
        transition target_to_complete
            first targetReached
            then complete;
        
        state repositioning {
            doc /* Adjusting needle position for another attempt. */
        }
        
        transition repositioning_to_idle
            first repositioning
            then idle;
        
        state complete {
            doc /* Procedure complete, ready for trocar insertion. */
        }
    }
    
    part insufflationSystem {
        part needle : VeressNeedle {
            attribute :>> insertionDepth = 0.0 [SI::mm];
            attribute :>> currentResistance = 0.0 [SI::N];
        }
        
        part insufflator : CO2Insufflator {
            attribute :>> setPressure = 2.0 [SI::kPa];
            attribute :>> setFlowRate = 0.025 [SI::'m^3/s'];
            attribute :>> cylinderPressure = 5000.0 [SI::kPa];
        }
        
        part abdominalWall : AbdominalWall {
            attribute :>> thickness = 25.0 [SI::mm];
            attribute :>> layers = 7;
        }
        
        part peritonealCavity : PeritonealCavity {
            attribute :>> currentPressure = 0.0 [SI::kPa];
            attribute :>> currentVolume = 0.0 [SI::L];
        }
        
        item flow co2Flow of CarbonDioxide;
        
        connection gasDelivery connect insufflator.gasSupply to needle.gasInlet via co2Flow;
        
        perform action insertionProcedure references PerformVeressNeedleInsertion;
        exhibit state operationBehavior : VeressNeedleOperationStateMachine;
    }
    
    requirement <'VN-REQ-001'> primaryFunction {
        doc /* The Veress needle system shall establish pneumoperitoneum 
             * by safely accessing the peritoneal cavity and delivering 
             * pressurized CO2 gas to create a working space for 
             * minimally invasive laparoscopic surgery. */
        subject system :>> insufflationSystem;
    }
    
    requirement <'VN-REQ-002'> safetyMechanism {
        doc /* The spring-loaded blunt obturator shall automatically extend 
             * beyond the sharp cannula tip upon entering the peritoneal 
             * cavity to prevent injury to internal organs. */
        subject obturator :>> insufflationSystem.needle.obturator;
        
        assert constraint {
            obturator.retracted == false
        }
    }
    
    requirement <'VN-REQ-003'> targetPressure {
        doc /* The system shall establish and maintain pneumoperitoneum 
             * at a target pressure between 1.6-2.0 kPa for optimal 
             * surgical visualization and patient safety. */
        subject cavity :>> insufflationSystem.peritonealCavity;
        
        assert constraint {
            cavity.currentPressure >= 1.6 [SI::kPa] and 
            cavity.currentPressure <= 2.0 [SI::kPa]
        }
    }
    
    requirement <'VN-REQ-004'> needleDimensions {
        doc /* The Veress needle cannula shall have standard dimensions 
             * with outer diameter of 2.1mm and length of 120mm for 
             * compatibility with standard laparoscopic procedures. */
        subject cannula :>> insufflationSystem.needle.cannula;
        
        assert constraint {
            cannula.outerDiameter == 2.1 [SI::mm] and 
            cannula.totalLength == 120.0 [SI::mm]
        }
    }
    
    requirement <'VN-REQ-005'> flowControl {
        doc /* The system shall provide controlled CO2 flow rate 
             * not exceeding 0.033 m^3/s to prevent rapid pressure 
             * changes and patient discomfort. */
        subject insufflator :>> insufflationSystem.insufflator;
        
        assert constraint {
            insufflator.setFlowRate <= 0.033 [SI::'m^3/s']
        }
    }
    
    satisfy primaryFunction by insufflationSystem;
    satisfy safetyMechanism by insufflationSystem.needle.obturator;
    satisfy targetPressure by insufflationSystem.peritonealCavity;
    satisfy needleDimensions by insufflationSystem.needle.cannula;
    satisfy flowControl by insufflationSystem.insufflator;
}

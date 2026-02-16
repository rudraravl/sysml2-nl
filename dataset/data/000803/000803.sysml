package TrocarSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def ObturatorTipType {
        bladed;
        nonBladed;
        optical;
        dilating;
    }
    
    enum def SealStatus {
        sealed;
        compromised;
        open;
    }
    
    item def SurgicalInstrument {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
    }
    
    item def InsufflationGas {
        attribute pressure : PressureValue;
        attribute flowRate : Real;
    }
    
    item def AbdominalTissue {
        attribute thickness : LengthValue;
        attribute resistance : ForceValue;
    }
    
    port def InstrumentPort {
        in item instrument : SurgicalInstrument;
    }
    
    port def GasPort {
        in item gas : InsufflationGas;
    }
    
    port def TissueInterface;
    
    part def Obturator {
        attribute tipType : ObturatorTipType;
        attribute length : LengthValue;
        attribute outerDiameter : LengthValue;
        
        part tip {
            attribute sharpness : Real;
            attribute angle : Real;
        }
        
        port shaft : InstrumentPort;
    }
    
    part def Cannula {
        attribute outerDiameter : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute wallThickness : LengthValue;
        
        port lumen : InstrumentPort;
        port gasChannel : GasPort;
        port distalEnd : TissueInterface;
        port proximalEnd;
    }
    
    part def SealAssembly {
        attribute maxInstrumentDiameter : LengthValue;
        attribute leakageRate : Real;
        attribute sealStatus : SealStatus;
        
        port instrumentPassage : InstrumentPort;
        port gasRetention : GasPort;
        
        state machine sealBehavior {
            initial state idle {
                entry action setOpen { sealStatus := SealStatus::open; }
            }
            
            state sealed {
                entry action setSealed { sealStatus := SealStatus::sealed; }
                
                state noInstrument;
                state instrumentPresent;
                
                transition noInstrument_to_instrumentPresent
                    first noInstrument
                    accept InstrumentInsertionEvent
                    then instrumentPresent;
                
                transition instrumentPresent_to_noInstrument
                    first instrumentPresent
                    accept InstrumentRemovalEvent
                    then noInstrument;
            }
            
            transition idle_to_sealed
                first idle
                accept ActivateSealEvent
                then sealed;
            
            state compromised {
                entry action setCompromised { sealStatus := SealStatus::compromised; }
            }
            
            transition sealed_to_compromised
                first sealed
                accept LeakDetectedEvent
                then compromised;
            
            transition compromised_to_sealed
                first compromised
                accept ResealEvent
                then sealed;
        }
    }
    
    part def ValveAssembly {
        attribute crackingPressure : PressureValue;
        attribute maxFlowRate : Real;
        
        port gasInlet : GasPort;
        port gasOutlet : GasPort;
        
        action def RegulateFlow {
            in currentPressure : PressureValue;
            in targetPressure : PressureValue;
            out adjustedFlowRate : Real;
            
            first start;
            then action measurePressure {
                in pressure = currentPressure;
                out delta : PressureValue;
            }
            then decide;
                if measurePressure.delta > 0.0 [Pa] then increaseFlow;
                if measurePressure.delta <= 0.0 [Pa] then decreaseFlow;
            action increaseFlow {
                out :>> adjustedFlowRate;
            }
            then done;
            action decreaseFlow {
                out :>> adjustedFlowRate;
            }
            then done;
        }
    }
    
    part def Trocar {
        attribute nominalDiameter : LengthValue;
        attribute workingLength : LengthValue;
        attribute maxInsertionForce : ForceValue;
        
        part cannula : Cannula {
            attribute :>> outerDiameter : LengthValue;
            attribute :>> innerDiameter : LengthValue;
            attribute :>> length : LengthValue;
            attribute :>> wallThickness = 0.5 [mm];
        }
        
        part obturator : Obturator {
            attribute :>> tipType : ObturatorTipType;
            attribute :>> length : LengthValue;
            attribute :>> outerDiameter = cannula.innerDiameter - 0.2 [mm];
        }
        
        part seal : SealAssembly {
            attribute :>> maxInstrumentDiameter = cannula.innerDiameter - 1.0 [mm];
            attribute :>> leakageRate : Real;
        }
        
        part valve : ValveAssembly {
            attribute :>> crackingPressure : PressureValue;
            attribute :>> maxFlowRate : Real;
        }
        
        port instrumentAccess : InstrumentPort;
        port insufflationAccess : GasPort;
        port bodyWallInterface : TissueInterface;
        
        connection cannulaToSeal connect cannula.lumen to seal.instrumentPassage;
        connection sealToInstrument connect seal.instrumentPassage to instrumentAccess;
        connection cannulaToValve connect cannula.gasChannel to valve.gasOutlet;
        connection valveToInsufflation connect valve.gasInlet to insufflationAccess;
        connection cannulaToBody connect cannula.distalEnd to bodyWallInterface;
    }
    
    action def PenetrateTissue {
        in tissue : AbdominalTissue;
        in trocar : Trocar;
        in insertionForce : ForceValue;
        in insertionAngle : Real;
        out penetrationDepth : LengthValue;
        out successful : Boolean;
        
        first start;
        then action positionTrocar {
            in angle = insertionAngle;
            out positioned : Boolean;
        }
        then action applyForce {
            in force = insertionForce;
            in resistance = tissue.resistance;
            out forceApplied : Boolean;
        }
        then action pierceTissue {
            in tissueThickness = tissue.thickness;
            out depth : LengthValue;
        }
        then action verifyPlacement {
            in actualDepth = pierceTissue.depth;
            in expectedDepth = tissue.thickness;
            out :>> successful : Boolean;
        }
        then done;
    }
    
    action def RemoveObturator {
        in trocar : Trocar;
        out obturatorRemoved : Boolean;
        
        first start;
        then action unlock;
        then action withdraw {
            out :>> obturatorRemoved = true;
        }
        then done;
    }
    
    action def EstablishPneumoperitoneum {
        in gas : InsufflationGas;
        in targetPressure : PressureValue;
        in valve : ValveAssembly;
        out currentPressure : PressureValue;
        
        first start;
        then merge monitoringLoop;
        then action measurePressure {
            out pressure : PressureValue;
        }
        then decide;
            if measurePressure.pressure < targetPressure then insufflate;
            if measurePressure.pressure >= targetPressure then maintain;
        action insufflate {
            in flowRate = gas.flowRate;
            perform valve.RegulateFlow {
                in currentPressure = measurePressure.pressure;
                in targetPressure = targetPressure;
            }
        }
        then monitoringLoop;
        action maintain {
            out :>> currentPressure = measurePressure.pressure;
        }
        then monitoringLoop;
    }
    
    action def ProvideInstrumentAccess {
        in instrument : SurgicalInstrument;
        in seal : SealAssembly;
        in cannula : Cannula;
        out accessGranted : Boolean;
        out sealIntact : Boolean;
        
        first start;
        then action validateInstrumentSize {
            in instrumentDiameter = instrument.diameter;
            in maxDiameter = seal.maxInstrumentDiameter;
            out sizeValid : Boolean;
        }
        then decide;
            if validateInstrumentSize.sizeValid then allowPassage;
            else rejectInstrument;
        action allowPassage {
            out :>> accessGranted = true;
            then action checkSeal {
                in leakRate = seal.leakageRate;
                out :>> sealIntact : Boolean;
            }
        }
        then done;
        action rejectInstrument {
            out :>> accessGranted = false;
        }
        then done;
    }
    
    action def PerformMinimallyInvasiveSurgery {
        in targetTissue : AbdominalTissue;
        in trocarDevice : Trocar;
        in insufflationGas : InsufflationGas;
        in surgicalInstruments : SurgicalInstrument[1..*];
        
        first start;
        then action insertTrocar : PenetrateTissue {
            in tissue = targetTissue;
            in trocar = trocarDevice;
            in insertionForce = trocarDevice.maxInsertionForce;
            in insertionAngle = 90.0;
        }
        then action removeObturator : RemoveObturator {
            in trocar = trocarDevice;
        }
        then action activateSeal;
        then action establishPneumo : EstablishPneumoperitoneum {
            in gas = insufflationGas;
            in targetPressure = 15.0 [mmHg];
            in valve = trocarDevice.valve;
        }
        then merge surgicalLoop;
        then action provideAccess : ProvideInstrumentAccess {
            in instrument : SurgicalInstrument;
            in seal = trocarDevice.seal;
            in cannula = trocarDevice.cannula;
        }
        then decide;
            if provideAccess.accessGranted then continueOperation;
            else abortOperation;
        action continueOperation;
        then surgicalLoop;
        action abortOperation;
        then done;
    }
    
    requirement def MinimalTraumaRequirement {
        doc /* The trocar shall minimize tissue trauma during insertion 
             * by using an appropriate obturator tip design. */
        subject trocar : Trocar;
        require constraint {
            trocar.obturator.tipType == ObturatorTipType::nonBladed or
            trocar.obturator.tipType == ObturatorTipType::optical or
            trocar.obturator.tipType == ObturatorTipType::dilating
        }
    }
    
    requirement def SealIntegrityRequirement {
        doc /* The trocar seal shall maintain gas-tight integrity 
             * with leakage rate not exceeding specified limit. */
        subject seal : SealAssembly;
        require constraint {
            seal.leakageRate <= 0.1
        }
    }
    
    requirement def InstrumentCompatibilityRequirement {
        doc /* The trocar shall accommodate standard surgical instruments 
             * within the specified diameter range. */
        subject trocar : Trocar;
        require constraint {
            trocar.cannula.innerDiameter >= 5.0 [mm] and
            trocar.cannula.innerDiameter <= 15.0 [mm]
        }
    }
    
    requirement def InsertionForceRequirement {
        doc /* The trocar insertion force shall not exceed safe limits 
             * to prevent excessive tissue damage. */
        subject trocar : Trocar;
        require constraint {
            trocar.maxInsertionForce <= 60.0 [N]
        }
    }
    
    requirement def PneumoperitoneumMaintenanceRequirement {
        doc /* The trocar system shall maintain stable pneumoperitoneum 
             * pressure within therapeutic range. */
        subject valve : ValveAssembly;
        require constraint {
            valve.crackingPressure >= 12.0 [mmHg] and
            valve.crackingPressure <= 16.0 [mmHg]
        }
    }
    
    requirement <'TROCAR-SYS-001'> primaryFunction {
        doc /* The trocar system shall establish and maintain a sealed access port 
             * through the abdominal wall for minimally invasive surgical procedures,
             * enabling safe instrument passage while preserving pneumoperitoneum 
             * and minimizing tissue trauma. */
        subject trocarSystem : Trocar;
        
        assume constraint abdominalWallPresent {
            doc /* A viable abdominal wall with measurable thickness exists 
                 * at the surgical site. */
        }
        
        require minimalTrauma : MinimalTraumaRequirement {
            subject trocar :>> trocarSystem;
        }
        
        require sealIntegrity : SealIntegrityRequirement {
            subject seal :>> trocarSystem.seal;
        }
        
        require instrumentCompatibility : InstrumentCompatibilityRequirement {
            subject trocar :>> trocarSystem;
        }
        
        require insertionForce : InsertionForceRequirement {
            subject trocar :>> trocarSystem;
        }
        
        require pneumoMaintenance : PneumoperitoneumMaintenanceRequirement {
            subject valve :>> trocarSystem.valve;
        }
    }
    
    part trocarSystem : Trocar {
        attribute :>> nominalDiameter = 10.0 [mm];
        attribute :>> workingLength = 100.0 [mm];
        attribute :>> maxInsertionForce = 55.0 [N];
        
        part :>> cannula {
            attribute :>> outerDiameter = 10.5 [mm];
            attribute :>> innerDiameter = 9.5 [mm];
            attribute :>> length = 100.0 [mm];
        }
        
        part :>> obturator {
            attribute :>> tipType = ObturatorTipType::nonBladed;
            attribute :>> length = 105.0 [mm];
        }
        
        part :>> seal {
            attribute :>> maxInstrumentDiameter = 8.5 [mm];
            attribute :>> leakageRate = 0.05;
            attribute :>> sealStatus = SealStatus::open;
        }
        
        part :>> valve {
            attribute :>> crackingPressure = 14.0 [mmHg];
            attribute :>> maxFlowRate = 10.0;
        }
        
        perform action surgicalOperation : PerformMinimallyInvasiveSurgery {
            in trocarDevice = trocarSystem;
        }
    }
    
    satisfy primaryFunction by trocarSystem;
}

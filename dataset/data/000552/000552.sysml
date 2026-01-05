package BlindInsertionAirwayDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* 
     * This model describes a Blind Insertion Airway Device (BIAD) system used in emergency
     * airway management. The device enables rapid establishment of a patent airway without
     * requiring direct visualization of the vocal cords. The system consists of the airway
     * device itself, ventilation equipment, and monitoring components that work together
     * to secure the airway and deliver positive pressure ventilation to patients in
     * respiratory distress or arrest.
     */
    
    // Value Types
    attribute def PressureValue :> ISQ::pressureValue;
    attribute def VolumeValue :> ISQ::volumeValue;
    attribute def FlowRateValue :> ISQ::volumeFlowRateValue;
    attribute def OxygenConcentrationValue :> Real;
    
    // Enumerations
    enum def DeviceSize {
        size3;
        size4;
        size5;
    }
    
    enum def InsertionStatus {
        notInserted;
        partiallyInserted;
        fullyInserted;
        sealed;
    }
    
    enum def VentilationMode {
        manual;
        mechanical;
    }
    
    // Item Definitions
    item def VentilationGas {
        attribute oxygenConcentration : OxygenConcentrationValue;
        attribute flowRate : FlowRateValue;
    }
    
    item def Patient {
        attribute oxygenSaturation : Real;
        attribute endTidalCO2 : PressureValue;
        attribute chestRise : Boolean;
    }
    
    // Port Definitions
    port def VentilationPort {
        in ventGas : VentilationGas;
        out exhaustGas : VentilationGas;
    }
    
    port def InflationPort {
        in inflationVolume : VolumeValue;
        out currentPressure : PressureValue;
    }
    
    port def MonitoringPort {
        out pressure : PressureValue;
        out volume : VolumeValue;
        out saturation : Real;
    }
    
    // Part Definitions
    part def InflatableCuff {
        attribute cuffPressure : PressureValue;
        attribute cuffVolume : VolumeValue;
        attribute maxSafePressure : PressureValue = 6000.0 [SI::Pa];
        
        port inflationValve : InflationPort;
        
        assert constraint safePressureLimit {
            cuffPressure <= maxSafePressure
        }
    }
    
    part def VentilationLumen {
        attribute innerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute resistance : Real;
        
        port proximalEnd : VentilationPort;
        port distalEnd : VentilationPort;
    }
    
    part def AirwayTube {
        attribute tubeSize : DeviceSize;
        attribute insertionDepth : LengthValue;
        attribute insertionStatus : InsertionStatus;
        
        part pharyngealCuff : InflatableCuff {
            attribute :>> cuffPressure : PressureValue;
            attribute :>> cuffVolume : VolumeValue = 0.00002 [SI::'m³'];
        }
        
        part esophagealCuff : InflatableCuff {
            attribute :>> cuffPressure : PressureValue;
            attribute :>> cuffVolume : VolumeValue = 0.000015 [SI::'m³'];
        }
        
        part ventilationChannel : VentilationLumen {
            attribute :>> innerDiameter : LengthValue = 0.008 [SI::m];
            attribute :>> length : LengthValue = 0.25 [SI::m];
        }
        
        port airwayInterface : VentilationPort;
    }
    
    part def PressureManometer {
        attribute measuredPressure : PressureValue;
        attribute alarmThreshold : PressureValue = 6000.0 [SI::Pa];
        
        port sensorInput : InflationPort;
        port displayOutput : MonitoringPort;
    }
    
    part def InflationSyringe {
        attribute syringeCapacity : VolumeValue = 0.00005 [SI::'m³'];
        attribute deliveredVolume : VolumeValue;
        
        port inflationOutput : InflationPort;
    }
    
    part def VentilationBag {
        attribute bagVolume : VolumeValue = 0.0016 [SI::'m³'];
        attribute compressionVolume : VolumeValue;
        attribute ventilationMode : VentilationMode;
        
        port gasInlet : VentilationPort;
        port patientOutlet : VentilationPort;
    }
    
    part def OxygenSource {
        attribute oxygenPurity : OxygenConcentrationValue = 1.0;
        attribute supplyPressure : PressureValue;
        attribute flowRate : FlowRateValue;
        
        port oxygenOutlet : VentilationPort;
    }
    
    part def PatientMonitor {
        attribute displayedSaturation : Real;
        attribute displayedCO2 : PressureValue;
        attribute alarmActive : Boolean;
        
        port monitorInput : MonitoringPort;
    }
    
    part def BlindInsertionAirwayDevice {
        attribute deviceSize : DeviceSize;
        attribute maxCuffPressure : PressureValue = 6000.0 [SI::Pa];
        attribute isSealed : Boolean;
        
        part airwayTube : AirwayTube {
            attribute :>> tubeSize = deviceSize;
        }
        
        part inflationSystem : InflationSyringe {
            attribute :>> deliveredVolume : VolumeValue;
        }
        
        part pressureGauge : PressureManometer {
            attribute :>> alarmThreshold = maxCuffPressure;
        }
        
        port ventilationConnection : VentilationPort;
        port cuffInflationPort : InflationPort;
        port monitoringOutput : MonitoringPort;
        
        connection inflationToTube connect 
            inflationSystem.inflationOutput to airwayTube.pharyngealCuff.inflationValve;
        
        connection pressureMonitoring connect
            pressureGauge.sensorInput to airwayTube.pharyngealCuff.inflationValve;
    }
    
    // Action Definitions
    action def AssessAirway {
        in patient : Patient;
        out airwayCompromised : Boolean;
        out consciousnessLevel : Real;
    }
    
    action def SelectDeviceSize {
        in patientWeight : MassValue;
        out selectedSize : DeviceSize;
    }
    
    action def PrepareDevice {
        in device : BlindInsertionAirwayDevice;
        out deviceReady : Boolean;
        
        first start;
        then action checkIntegrity {
            out integrityOK : Boolean = true;
        }
        then action lubricateTube {
            out lubricationComplete : Boolean = true;
        }
        then action testCuffs {
            out cuffsIntact : Boolean = true;
        }
        then assign deviceReady = (checkIntegrity.integrityOK and 
                                   lubricateTube.lubricationComplete and 
                                   testCuffs.cuffsIntact);
        then done;
    }
    
    action def InsertDevice {
        in device : BlindInsertionAirwayDevice;
        in patient : Patient;
        out insertionComplete : Boolean;
        out insertionDepth : LengthValue;
        
        first start;
        then action positionPatient {
            out positioningComplete : Boolean = true;
        }
        then action advanceTube {
            out tubeAdvanced : Boolean = true;
            out depth : LengthValue = 0.23 [SI::m];
        }
        then assign insertionDepth = advanceTube.depth;
        then assign insertionComplete = advanceTube.tubeAdvanced;
        then done;
    }
    
    action def InflateCuffs {
        in device : BlindInsertionAirwayDevice;
        in targetPressure : PressureValue;
        out cuffsInflated : Boolean;
        out sealAchieved : Boolean;
        
        first start;
        then action inflatePharyngealCuff {
            in target : PressureValue = targetPressure;
            out inflated : Boolean = true;
        }
        then action inflateEsophagealCuff {
            in target : PressureValue = targetPressure;
            out inflated : Boolean = true;
        }
        then action checkSeal {
            out sealed : Boolean = true;
        }
        then assign cuffsInflated = (inflatePharyngealCuff.inflated and 
                                     inflateEsophagealCuff.inflated);
        then assign sealAchieved = checkSeal.sealed;
        then done;
    }
    
    action def VerifyPlacement {
        in device : BlindInsertionAirwayDevice;
        in patient : Patient;
        out placementCorrect : Boolean;
        out ventilationAdequate : Boolean;
        
        first start;
        then action auscultate {
            out bilateralBreathSounds : Boolean = true;
            out epigastricSounds : Boolean = false;
        }
        then action checkCapnography {
            out co2Detected : Boolean = true;
            out waveformNormal : Boolean = true;
        }
        then action observeChestRise {
            out chestRising : Boolean = patient.chestRise;
        }
        then assign placementCorrect = (auscultate.bilateralBreathSounds and 
                                        not auscultate.epigastricSounds and
                                        checkCapnography.co2Detected);
        then assign ventilationAdequate = (checkCapnography.waveformNormal and 
                                           observeChestRise.chestRising);
        then done;
    }
    
    action def DeliverVentilation {
        in device : BlindInsertionAirwayDevice;
        in patient : Patient;
        in ventilationGas : VentilationGas;
        out tidalVolume : VolumeValue;
        out peakPressure : PressureValue;
        
        first start;
        then action compressBag {
            out volume : VolumeValue = 0.0005 [SI::'m³'];
            out pressure : PressureValue = 2000.0 [SI::Pa];
        }
        then action deliverGas {
            in vol : VolumeValue = compressBag.volume;
            in press : PressureValue = compressBag.pressure;
        }
        then assign tidalVolume = compressBag.volume;
        then assign peakPressure = compressBag.pressure;
        then done;
    }
    
    action def MonitorVentilation {
        in patient : Patient;
        out saturation : Real;
        out co2Level : PressureValue;
        out ventilationStatus : Boolean;
        
        first start;
        then action measureSaturation {
            out spo2 : Real = patient.oxygenSaturation;
        }
        then action measureCO2 {
            out etco2 : PressureValue = patient.endTidalCO2;
        }
        then assign saturation = measureSaturation.spo2;
        then assign co2Level = measureCO2.etco2;
        then assign ventilationStatus = (saturation >= 90.0 and 
                                         co2Level >= 4000.0 [SI::Pa] and 
                                         co2Level <= 6000.0 [SI::Pa]);
        then done;
    }
    
    action def AdjustVentilation {
        in currentSaturation : Real;
        in currentCO2 : PressureValue;
        out adjustmentMade : Boolean;
        
        first start;
        then decide;
            if currentSaturation < 90.0 then increaseOxygen;
            if currentCO2 > 6000.0 [SI::Pa] then increaseRate;
            if currentCO2 < 4000.0 [SI::Pa] then decreaseRate;
        
        action increaseOxygen {
            out adjusted : Boolean = true;
        }
        then merge complete;
        
        action increaseRate {
            out adjusted : Boolean = true;
        }
        then complete;
        
        action decreaseRate {
            out adjusted : Boolean = true;
        }
        then complete;
        
        then merge complete;
        then assign adjustmentMade = true;
        then done;
    }
    
    action def SecureAirway {
        first start;
        
        then action assess : AssessAirway;
        
        then decide assessmentDecision;
            if assess.airwayCompromised then selectSize;
            if not assess.airwayCompromised then done;
        
        action selectSize : SelectDeviceSize;
        then action prepare : PrepareDevice;
        
        then decide preparationCheck;
            if prepare.deviceReady then insert;
            if not prepare.deviceReady then selectSize;
        
        action insert : InsertDevice;
        then action inflate : InflateCuffs {
            in targetPressure = 5000.0 [SI::Pa];
        }
        
        then decide sealCheck;
            if inflate.sealAchieved then verify;
            if not inflate.sealAchieved then reposition;
        
        action reposition : InsertDevice;
        then sealCheck;
        
        action verify : VerifyPlacement;
        
        then decide verificationDecision;
            if verify.placementCorrect and verify.ventilationAdequate then ventilate;
            if not verify.placementCorrect or not verify.ventilationAdequate then reposition;
        
        then merge ventilate;
        action ventilate : DeliverVentilation;
        
        then merge monitoringLoop;
        action monitor : MonitorVentilation;
        
        then decide monitoringDecision;
            if monitor.ventilationStatus then continueMonitoring;
            if not monitor.ventilationStatus then adjust;
        
        action adjust : AdjustVentilation {
            in currentSaturation = monitor.saturation;
            in currentCO2 = monitor.co2Level;
        }
        then continueMonitoring;
        
        then merge continueMonitoring;
        then monitoringLoop;
    }
    
    // State Machine
    state def AirwayDeviceLifecycle {
        entry; then idle;
        
        state idle {
            doc /* Device is prepared but not inserted */
        }
        
        transition idle_to_inserting
            first idle
            accept InsertCommand
            then inserting;
        
        state inserting {
            doc /* Device is being advanced into patient airway */
        }
        
        transition inserting_to_inflating
            first inserting
            if insertionComplete
            then inflating;
        
        state inflating {
            doc /* Cuffs are being inflated to create seal */
        }
        
        transition inflating_to_verifying
            first inflating
            if cuffsSealed
            then verifying;
        
        state verifying {
            doc /* Placement is being confirmed */
        }
        
        transition verifying_to_ventilating
            first verifying
            if placementConfirmed
            then ventilating;
        
        transition verifying_to_repositioning
            first verifying
            if not placementConfirmed
            then repositioning;
        
        state repositioning {
            doc /* Device position is being adjusted */
        }
        
        transition repositioning_to_inflating
            first repositioning
            then inflating;
        
        state ventilating {
            entry; then activeVentilation;
            
            state activeVentilation {
                doc /* Positive pressure ventilation is being delivered */
            }
            
            transition to_monitoring
                first activeVentilation
                accept MonitorCycle
                then monitoring;
            
            state monitoring {
                doc /* Patient parameters are being assessed */
            }
            
            transition monitoring_to_adjusting
                first monitoring
                if ventilationInadequate
                then adjusting;
            
            transition monitoring_to_active
                first monitoring
                if ventilationAdequate
                then activeVentilation;
            
            state adjusting {
                doc /* Ventilation parameters are being modified */
            }
            
            transition adjusting_to_active
                first adjusting
                then activeVentilation;
        }
        
        transition ventilating_to_removing
            first ventilating
            accept RemovalCommand
            then removing;
        
        state removing {
            doc /* Device is being extracted from patient */
        }
        
        transition removing_to_removed
            first removing
            if removalComplete
            then removed;
        
        state removed {
            doc /* Device has been removed and disposed */
        }
    }
    
    // Requirements
    requirement <'REQ-BIAD-001'> establishPatentAirway {
        doc /* 
         * The Blind Insertion Airway Device system shall establish and maintain
         * a patent airway in patients requiring emergency airway management without
         * requiring direct visualization of the vocal cords or laryngoscopy.
         */
        subject system : BlindInsertionAirwayDeviceSystem;
    }
    
    requirement <'REQ-BIAD-002'> cuffSealingPressure {
        doc /* 
         * The inflatable cuffs shall create an effective pharyngeal and esophageal
         * seal at pressures between 4000 and 6000 Pa to enable positive pressure
         * ventilation while preventing tissue ischemia.
         */
        subject cuff : InflatableCuff;
        assert constraint {
            cuff.cuffPressure >= 4000.0 [SI::Pa] and 
            cuff.cuffPressure <= 6000.0 [SI::Pa]
        }
    }
    
    requirement <'REQ-BIAD-003'> ventilationLumenPatency {
        doc /* 
         * The ventilation lumen shall provide an unobstructed pathway with
         * minimum internal diameter of 7 mm to allow adequate gas flow for
         * positive pressure ventilation.
         */
        subject lumen : VentilationLumen;
        assert constraint {
            lumen.innerDiameter >= 0.007 [SI::m]
        }
    }
    
    requirement <'REQ-BIAD-004'> tidalVolumeDelivery {
        doc /* 
         * The system shall enable delivery of tidal volumes between 400 and 600 mL
         * with peak airway pressures not exceeding 3000 Pa during normal ventilation.
         */
        subject ventilation : DeliverVentilation;
        assert constraint {
            ventilation.tidalVolume >= 0.0004 [SI::'m³'] and
            ventilation.tidalVolume <= 0.0006 [SI::'m³'] and
            ventilation.peakPressure <= 3000.0 [SI::Pa]
        }
    }
    
    requirement <'REQ-BIAD-005'> rapidDeployment {
        doc /* 
         * The device shall be capable of insertion, inflation, and verification
         * within 60 seconds by a trained operator in emergency conditions.
         */
        subject device : BlindInsertionAirwayDevice;
    }
    
    requirement <'REQ-BIAD-006'> oxygenationMaintenance {
        doc /* 
         * The system shall maintain patient oxygen saturation at or above 90%
         * and end-tidal CO2 between 4000-6000 Pa during continuous ventilation.
         */
        subject monitoring : MonitorVentilation;
        assert constraint {
            monitoring.saturation >= 90.0 and
            monitoring.co2Level >= 4000.0 [SI::Pa] and
            monitoring.co2Level <= 6000.0 [SI::Pa]
        }
    }
    
    // System Assembly
    part airwayManagementSystem {
        part biadDevice : BlindInsertionAirwayDevice {
            attribute :>> deviceSize = DeviceSize::size4;
            attribute :>> maxCuffPressure = 6000.0 [SI::Pa];
            
            part :>> airwayTube {
                attribute :>> insertionDepth = 0.23 [SI::m];
                attribute :>> insertionStatus = InsertionStatus::sealed;
                
                part :>> pharyngealCuff {
                    attribute :>> cuffPressure = 5000.0 [SI::Pa];
                    attribute :>> cuffVolume = 0.00002 [SI::'m³'];
                }
                
                part :>> esophagealCuff {
                    attribute :>> cuffPressure = 5000.0 [SI::Pa];
                    attribute :>> cuffVolume = 0.000015 [SI::'m³'];
                }
            }
            
            part :>> inflationSystem {
                attribute :>> deliveredVolume = 0.000035 [SI::'m³'];
            }
        }
        
        part ventilationEquipment : VentilationBag {
            attribute :>> bagVolume = 0.0016 [SI::'m³'];
            attribute :>> compressionVolume = 0.0005 [SI::'m³'];
            attribute :>> ventilationMode = VentilationMode::manual;
        }
        
        part oxygenSupply : OxygenSource {
            attribute :>> oxygenPurity = 1.0;
            attribute :>> flowRate = 0.00025 [SI::'m³'/SI::s];
            attribute :>> supplyPressure = 345000.0 [SI::Pa];
        }
        
        part monitor : PatientMonitor {
            attribute :>> displayedSaturation = 95.0;
            attribute :>> displayedCO2 = 5000.0 [SI::Pa];
            attribute :>> alarmActive = false;
        }
        
        item patient : Patient {
            attribute :>> oxygenSaturation = 95.0;
            attribute :>> endTidalCO2 = 5000.0 [SI::Pa];
            attribute :>> chestRise = true;
        }
        
        connection oxygenToVentilator connect
            oxygenSupply.oxygenOutlet to ventilationEquipment.gasInlet;
        
        connection ventilatorToDevice connect
            ventilationEquipment.patientOutlet to biadDevice.ventilationConnection;
        
        connection deviceMonitoring connect
            biadDevice.monitoringOutput to monitor.monitorInput;
        
        perform action airwaySecurement : SecureAirway;
    }
    
    // Requirement Satisfaction
    satisfy establishPatentAirway by airwayManagementSystem.biadDevice;
    satisfy cuffSealingPressure by airwayManagementSystem.biadDevice.airwayTube.pharyngealCuff;
    satisfy ventilationLumenPatency by airwayManagementSystem.biadDevice.airwayTube.ventilationChannel;
    satisfy tidalVolumeDelivery by airwayManagementSystem.airwaySecurement.ventilate;
    satisfy rapidDeployment by airwayManagementSystem.biadDevice;
    satisfy oxygenationMaintenance by airwayManagementSystem.airwaySecurement.monitor;
}

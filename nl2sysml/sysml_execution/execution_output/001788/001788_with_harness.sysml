package GasolineAdditiveSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ConcentrationRatio :> Real;
    attribute def OctaneRating :> Real;
    attribute def CleaningEfficiency :> Real;
    
    enum def AdditiveType {
        detergentCleaner;
        octaneBooster;
        fuelStabilizer;
        corrosionInhibitor;
    }
    
    enum def SystemState {
        idle;
        monitoring;
        dosing;
        mixing;
        verifying;
    }
    
    item def BaseGasoline {
        attribute volume : VolumeValue;
        attribute baseOctane : OctaneRating;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute contaminantLevel : MassValue;
    }
    
    item def ChemicalAdditive {
        attribute additiveType : AdditiveType;
        attribute concentration : ConcentrationRatio;
        attribute volume : VolumeValue;
        attribute octaneBoost : OctaneRating;
        attribute cleaningPower : CleaningEfficiency;
    }
    
    item def TreatedFuel {
        attribute totalVolume : VolumeValue;
        attribute finalOctane : OctaneRating;
        attribute additiveConcentration : ConcentrationRatio;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def FuelFlowPort {
        attribute flowRate : VolumeValue;
    }
    
    port def AdditiveFlowPort {
        attribute flowRate : VolumeValue;
    }
    
    port def SensorPort {
        attribute measuredValue : Real;
    }
    
    port def ControlPort {
        attribute commandSignal : Real;
    }
    
    part def FuelTank {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        port fuelOutlet : FuelFlowPort;
        item storedFuel : BaseGasoline;
    }
    
    part def AdditiveReservoir {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute minimumLevel : VolumeValue;
        port additiveOutlet : AdditiveFlowPort;
        item storedAdditive : ChemicalAdditive {
            :>> additiveType = AdditiveType::detergentCleaner;
            :>> concentration = 0.95;
            :>> octaneBoost = 5.0;
            :>> cleaningPower = 0.98;
        }
    }
    
    part def DosingPump {
        attribute maxFlowRate : VolumeValue;
        attribute currentFlowRate : VolumeValue;
        attribute pumpEfficiency : Real;
        port inlet : AdditiveFlowPort;
        port outlet : AdditiveFlowPort;
        port controlInput : ControlPort;
    }
    
    part def MixingChamber {
        attribute chamberVolume : VolumeValue;
        attribute mixingTime : DurationValue;
        attribute mixingEfficiency : Real;
        port fuelInlet : FuelFlowPort;
        port additiveInlet : AdditiveFlowPort;
        port mixtureOutlet : FuelFlowPort;
        
        assert constraint ProperMixing {
            mixingEfficiency >= 0.95
        }
    }
    
    part def FlowSensor {
        attribute accuracy : Real;
        port sensingPort : FuelFlowPort;
        port dataOutput : SensorPort;
        attribute measuredFlowRate : VolumeValue;
    }
    
    part def QualitySensor {
        attribute measurementAccuracy : Real;
        port sensingPort : FuelFlowPort;
        port dataOutput : SensorPort;
        attribute measuredOctane : OctaneRating;
        attribute measuredConcentration : ConcentrationRatio;
    }
    
    part def SystemController {
        attribute targetOctane : OctaneRating;
        attribute targetConcentration : ConcentrationRatio;
        attribute operatingState : SystemState;
        attribute fuelFlowDetected : Boolean;
        attribute qualityBelowTarget : Boolean;
        attribute qualityAcceptable : Boolean;
        attribute dosageComplete : Boolean;
        attribute mixingComplete : Boolean;
        attribute qualityMet : Boolean;
        attribute qualityNotMet : Boolean;
        port fuelFlowInput : SensorPort;
        port qualityInput : SensorPort;
        port pumpControl : ControlPort;
        
        state controlStateMachine {
            entry; then idleState;
            
            state idleState;
            transition idleToMonitoring
                first idleState
                if fuelFlowDetected
                then monitoringState;
            
            state monitoringState {
                entry; do action checkFuelQuality;
            }
            transition monitoringToDosing
                first monitoringState
                if qualityBelowTarget
                then dosingState;
            
            transition monitoringToIdle
                first monitoringState
                if qualityAcceptable
                then idleState;
            
            state dosingState {
                entry; do action calculateDosage;
                do action activatePump;
            }
            transition dosingToMixing
                first dosingState
                if dosageComplete
                then mixingState;
            
            state mixingState {
                entry; do action monitorMixing;
            }
            transition mixingToVerifying
                first mixingState
                if mixingComplete
                then verifyingState;
            
            state verifyingState {
                entry; do action verifyQuality;
            }
            transition verifyingToIdle
                first verifyingState
                if qualityMet
                then idleState;
            
            transition verifyingToDosing
                first verifyingState
                if qualityNotMet
                then dosingState;
        }
    }
    
    action def MeasureFuelFlow {
        in fuelStream : BaseGasoline;
        out flowRate : VolumeValue;
        out fuelQuality : OctaneRating;
    }
    
    action def CalculateAdditiveDose {
        in currentOctane : OctaneRating;
        in targetOctane : OctaneRating;
        in fuelVolume : VolumeValue;
        in additiveBoost : OctaneRating;
        out requiredAdditiveVolume : VolumeValue;
        out targetConcentration : ConcentrationRatio;
    }
    
    action def InjectAdditive {
        in additiveVolume : VolumeValue;
        in pumpFlowRate : VolumeValue;
        out injectionDuration : DurationValue;
        out injectionComplete : Boolean;
    }
    
    action def MixFuelAndAdditive {
        in baseFuel : BaseGasoline;
        in additive : ChemicalAdditive;
        in mixingDuration : DurationValue;
        out treatedFuel : TreatedFuel;
    }
    
    action def VerifyFuelQuality {
        in treatedFuel : TreatedFuel;
        in targetOctane : OctaneRating;
        in targetConcentration : ConcentrationRatio;
        out qualityMet : Boolean;
        out actualOctane : OctaneRating;
    }
    
    action def TreatmentCycle {
        first start;
        then merge continuousTreatment;
        
        action measureFlow : MeasureFuelFlow {
            in fuelStream : BaseGasoline;
            out flowRate : VolumeValue;
            out fuelQuality : OctaneRating;
        }
        
        then decide;
            if measureFlow.fuelQuality < 91.0 then calculateDose;
            if measureFlow.fuelQuality >= 91.0 then continuousTreatment;
        
        action calculateDose : CalculateAdditiveDose {
            in currentOctane = measureFlow.fuelQuality;
            in targetOctane = 93.0;
            in fuelVolume = measureFlow.flowRate;
            in additiveBoost = 5.0;
            out requiredAdditiveVolume : VolumeValue;
            out targetConcentration : ConcentrationRatio;
        }
        
        then action injectDose : InjectAdditive {
            in additiveVolume = calculateDose.requiredAdditiveVolume;
            in pumpFlowRate : VolumeValue;
            out injectionDuration : DurationValue;
            out injectionComplete : Boolean;
        }
        
        then action mixComponents : MixFuelAndAdditive {
            in baseFuel : BaseGasoline;
            in additive : ChemicalAdditive;
            in mixingDuration = 30 [s];
            out treatedFuel : TreatedFuel;
        }
        
        then action verifyQuality : VerifyFuelQuality {
            in treatedFuel = mixComponents.treatedFuel;
            in targetOctane = 93.0;
            in targetConcentration = calculateDose.targetConcentration;
            out qualityMet : Boolean;
            out actualOctane : OctaneRating;
        }
        
        then decide;
            if verifyQuality.qualityMet then continuousTreatment;
            if !verifyQuality.qualityMet then calculateDose;
        
        then continuousTreatment;
        then done;
    }
    
    part def GasolineAdditiveSystem {
        attribute systemEfficiency : Real;
        attribute operatingTemperature : ThermodynamicTemperatureValue;
        attribute throughput : VolumeValue;
        
        part fuelTank : FuelTank {
            attribute :>> capacity = 200 [L];
            attribute :>> currentLevel : VolumeValue;
        }
        
        part additiveReservoir : AdditiveReservoir {
            attribute :>> capacity = 20 [L];
            attribute :>> currentLevel : VolumeValue;
            attribute :>> minimumLevel = 2 [L];
        }
        
        part dosingPump : DosingPump {
            attribute :>> maxFlowRate = 0.5 [L/SI::min];
            attribute :>> currentFlowRate : VolumeValue;
            attribute :>> pumpEfficiency = 0.92;
        }
        
        part mixingChamber : MixingChamber {
            attribute :>> chamberVolume = 10 [L];
            attribute :>> mixingTime = 30 [s];
            attribute :>> mixingEfficiency = 0.97;
        }
        
        part fuelFlowSensor : FlowSensor {
            attribute :>> accuracy = 0.98;
            attribute :>> measuredFlowRate : VolumeValue;
        }
        
        part qualitySensor : QualitySensor {
            attribute :>> measurementAccuracy = 0.99;
            attribute :>> measuredOctane : OctaneRating;
            attribute :>> measuredConcentration : ConcentrationRatio;
        }
        
        part controller : SystemController {
            attribute :>> targetOctane = 93.0;
            attribute :>> targetConcentration = 0.02;
            attribute :>> operatingState = SystemState::idle;
            
            perform action treatmentCycle[*] ordered references GasolineAdditiveSystem::TreatmentCycle;
        }
        
        connection fuelSupply connect fuelTank.fuelOutlet to mixingChamber.fuelInlet;
        connection additiveSupply connect additiveReservoir.additiveOutlet to dosingPump.inlet;
        connection dosedAdditive connect dosingPump.outlet to mixingChamber.additiveInlet;
        connection mixedFuelOutput connect mixingChamber.mixtureOutlet to qualitySensor.sensingPort;
        connection flowMonitoring connect fuelTank.fuelOutlet to fuelFlowSensor.sensingPort;
        connection flowData connect fuelFlowSensor.dataOutput to controller.fuelFlowInput;
        connection qualityData connect qualitySensor.dataOutput to controller.qualityInput;
        connection pumpCommand connect controller.pumpControl to dosingPump.controlInput;
        
        assert constraint AdditiveConcentrationLimit {
            qualitySensor.measuredConcentration >= 0.01 and qualitySensor.measuredConcentration <= 0.05
        }
        
        assert constraint OctaneImprovement {
            qualitySensor.measuredOctane >= controller.targetOctane
        }
    }
    
    requirement <'REQ-GAS-001'> primaryFunction {
        doc /* The gasoline additive system shall enhance fuel quality by 
             * precisely blending chemical additives with base gasoline to 
             * improve octane rating, clean engine components, and optimize 
             * combustion performance.
             */
        subject system : GasolineAdditiveSystem;
    }
    
    requirement <'REQ-GAS-002'> octaneEnhancement {
        doc /* The system shall increase the octane rating of base gasoline 
             * from a minimum of 87 to a target of 93 through controlled 
             * additive injection.
             */
        subject system : GasolineAdditiveSystem;
        assert constraint {
            system.controller.targetOctane >= 93.0
        }
    }
    
    requirement <'REQ-GAS-003'> additiveConcentration {
        doc /* The additive concentration in the final fuel mixture shall 
             * be maintained between 1% and 5% by volume to ensure effective 
             * treatment without fuel degradation.
             */
        subject system : GasolineAdditiveSystem;
        assert constraint {
            system.controller.targetConcentration >= 0.01 and 
            system.controller.targetConcentration <= 0.05
        }
    }
    
    requirement <'REQ-GAS-004'> mixingHomogeneity {
        doc /* The mixing chamber shall achieve a minimum homogeneity 
             * efficiency of 95% to ensure uniform additive distribution 
             * throughout the fuel.
             */
        subject chamber : GasolineAdditiveSystem::mixingChamber;
        assert constraint {
            chamber.mixingEfficiency >= 0.95
        }
    }
    
    requirement <'REQ-GAS-005'> dosingAccuracy {
        doc /* The dosing pump shall maintain flow rate accuracy within 
             * ±3% of the calculated dosage to prevent over or under-treatment.
             */
        subject pump : GasolineAdditiveSystem::dosingPump;
        assert constraint {
            pump.pumpEfficiency >= 0.90
        }
    }
    
    requirement <'REQ-GAS-006'> reservoirMonitoring {
        doc /* The system shall monitor additive reservoir level and alert 
             * when level falls below minimum threshold to ensure continuous 
             * operation.
             */
        subject reservoir : GasolineAdditiveSystem::additiveReservoir;
        assert constraint {
            reservoir.currentLevel >= reservoir.minimumLevel
        }
    }
    
    part gasolineAdditiveSystemInstance : GasolineAdditiveSystem {
        attribute :>> systemEfficiency = 0.94;
        attribute :>> operatingTemperature = 298 [K];
        attribute :>> throughput = 100 [L/SI::min];
    }
    
    satisfy primaryFunction by gasolineAdditiveSystemInstance;
    satisfy octaneEnhancement by gasolineAdditiveSystemInstance;
    satisfy additiveConcentration by gasolineAdditiveSystemInstance;
    satisfy mixingHomogeneity by gasolineAdditiveSystemInstance.mixingChamber;
    satisfy dosingAccuracy by gasolineAdditiveSystemInstance.dosingPump;
    satisfy reservoirMonitoring by gasolineAdditiveSystemInstance.additiveReservoir;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import GasolineAdditiveSystem::*;

    action orchestrator {
        item testFuelStream : BaseGasoline {
            attribute volume : VolumeValue;
            attribute baseOctane : OctaneRating = 0.0;
            attribute temperature : ThermodynamicTemperatureValue;
            attribute contaminantLevel : MassValue;
        }
        action measureFlowProbe : MeasureFuelFlow {
            in fuelStream = testFuelStream;
        }
        first measureFlowProbe;
    }
}

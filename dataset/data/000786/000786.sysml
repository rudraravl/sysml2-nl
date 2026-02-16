package 'Surgical Lubricant System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ViscosityValue :> ISQ::DynamicViscosityValue;
    attribute def BiocompatibilityRating :> Real;
    attribute def SterilityLevel :> String;
    
    item def SurgicalLubricant {
        attribute viscosity : ViscosityValue;
        attribute isBiocompatible : Boolean;
        attribute isSterile : Boolean;
        attribute isWaterSoluble : Boolean;
        attribute pH : Real;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    item def LubricantFlow {
        attribute flowRate : ISQ::VolumetricFlowRateValue;
        attribute pressure : ISQ::PressureValue;
        attribute lubricant : SurgicalLubricant;
    }
    
    attribute def DispenseCommand;
    attribute def StopCommand;
    attribute def PrimeCommand;
    
    port def LubricantSupplyPort {
        out item lubricantFlow : LubricantFlow;
    }
    
    port def LubricantApplicationPort {
        in item lubricantFlow : LubricantFlow;
    }
    
    part def LubricantCartridge {
        attribute capacity : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute expirationDate : String;
        port outlet : LubricantSupplyPort;
    }
    
    part def PumpMechanism {
        attribute maxFlowRate : ISQ::VolumetricFlowRateValue;
        attribute maxPressure : ISQ::PressureValue;
        port inlet : LubricantApplicationPort;
        port outlet : LubricantSupplyPort;
    }
    
    part def ApplicationNozzle {
        attribute nozzleDiameter : ISQ::LengthValue;
        attribute tipGeometry : String;
        port inlet : LubricantApplicationPort;
    }
    
    part def FlowController {
        attribute targetFlowRate : ISQ::VolumetricFlowRateValue;
        attribute measuredFlowRate : ISQ::VolumetricFlowRateValue;
        attribute isPrimed : Boolean;
        perform action controlFlow;
    }
    
    part def SurgicalInstrument {
        attribute surfaceFriction : Real;
        port lubricationInterface : LubricantApplicationPort;
    }
    
    part def TissueSurface {
        attribute moistureLevel : Real;
        attribute traumaRisk : Real;
        port contactInterface : LubricantApplicationPort;
    }
    
    action def PrimeSystem {
        in cmd : PrimeCommand;
        in cartridgeVolume : ISQ::VolumeValue;
        in primeVolume : ISQ::VolumeValue;
        out primed : Boolean;
        out remainingVolume : ISQ::VolumeValue;
    }
    
    action def DispenseLubricant {
        in cmd : DispenseCommand;
        in targetFlow : ISQ::VolumetricFlowRateValue;
        in availableVolume : ISQ::VolumeValue;
        out actualFlow : ISQ::VolumetricFlowRateValue;
        out dispensedVolume : ISQ::VolumeValue;
    }
    
    action def MonitorFlow {
        in currentFlow : ISQ::VolumetricFlowRateValue;
        in targetFlow : ISQ::VolumetricFlowRateValue;
        out flowDeviation : Real;
        out flowStable : Boolean;
    }
    
    action def ReduceFriction {
        in lubricant : SurgicalLubricant;
        in baseFriction : Real;
        out reducedFriction : Real;
        out frictionReduction : Real;
    }
    
    action def controlFlow {
        first start;
        then action monitorState;
        then done;
    }
    
    action def ProvideSurgicalLubrication {
        in procedureType : String;
        in targetSites : Integer;
        in procedureDuration : ISQ::TimeValue;
        out totalDispensed : ISQ::VolumeValue;
        out lubricationEfficiency : Real;
        
        first start;
        
        then action initializeLubricant {
            out item preparedLubricant : SurgicalLubricant;
        }
        
        then action primeSystem : PrimeSystem {
            in cmd;
            in cartridgeVolume;
            in primeVolume;
            out primed;
            out remainingVolume;
        }
        
        then merge continuousApplication;
        
        then action monitorViscosity {
            in item lubricant = initializeLubricant.preparedLubricant;
            out viscosityStable : Boolean;
        }
        
        then decide;
            if monitorViscosity.viscosityStable then applyLubricant;
            if !monitorViscosity.viscosityStable then adjustTemperature;
        
        action adjustTemperature {
            in targetTemp : ISQ::ThermodynamicTemperatureValue;
            out item adjustedLubricant : SurgicalLubricant;
        }
        then continuousApplication;
        
        action applyLubricant : DispenseLubricant {
            in cmd;
            in targetFlow;
            in availableVolume = primeSystem.remainingVolume;
            out actualFlow;
            out dispensedVolume;
        }
        
        then action reduceSurfaceFriction : ReduceFriction {
            in lubricant = initializeLubricant.preparedLubricant;
            in baseFriction = 0.45;
            out reducedFriction;
            out frictionReduction;
        }
        
        then action evaluatePerformance {
            in frictionReduction = reduceSurfaceFriction.frictionReduction;
            out performanceAdequate : Boolean;
        }
        
        then decide;
            if evaluatePerformance.performanceAdequate then completeApplication;
            if !evaluatePerformance.performanceAdequate then continuousApplication;
        
        action completeApplication {
            in totalVolume = applyLubricant.dispensedVolume;
        }
        then done;
    }
    
    part surgicalLubricantSystem {
        doc /* A sterile delivery system that applies biocompatible lubricant to surgical instruments 
               and tissue surfaces to reduce friction, minimize trauma, and facilitate smooth instrument 
               manipulation during surgical procedures. */
        
        part cartridge : LubricantCartridge {
            attribute capacity = 50.0;
            attribute currentVolume = 50.0;
            attribute expirationDate = "2025-12-31";
        }
        
        part pump : PumpMechanism {
            attribute maxFlowRate = 10.0;
            attribute maxPressure = 200.0;
        }
        
        part nozzle : ApplicationNozzle {
            attribute nozzleDiameter = 1.5;
            attribute tipGeometry = "Tapered";
        }
        
        part controller : FlowController {
            attribute targetFlowRate = 5.0;
            attribute measuredFlowRate = 0.0;
            attribute isPrimed = false;
        }
        
        part instrument1 : SurgicalInstrument {
            attribute surfaceFriction = 0.45;
        }
        
        part instrument2 : SurgicalInstrument {
            attribute surfaceFriction = 0.50;
        }
        
        part tissue : TissueSurface {
            attribute moistureLevel = 0.60;
            attribute traumaRisk = 0.35;
        }
        
        connection cartridgeToPump connect cartridge.outlet to pump.inlet;
        connection pumpToNozzle connect pump.outlet to nozzle.inlet;
        connection nozzleToInstrument1 connect nozzle.inlet to instrument1.lubricationInterface;
        connection nozzleToInstrument2 connect nozzle.inlet to instrument2.lubricationInterface;
        connection nozzleToTissue connect nozzle.inlet to tissue.contactInterface;
        
        perform action lubricationOperation : ProvideSurgicalLubrication {
            in procedureType = "Laparoscopic Surgery";
            in targetSites = 3;
            in procedureDuration = 7200.0;
            out totalDispensed;
            out lubricationEfficiency;
        }
    }
    
    requirement <'SL-REQ-001'> biocompatibilityRequirement {
        doc /* The surgical lubricant shall be biocompatible and non-toxic to human tissue. */
        
        subject lubricant : SurgicalLubricant;
        
        require constraint {
            lubricant.isBiocompatible == true
        }
    }
    
    requirement <'SL-REQ-002'> sterilityRequirement {
        doc /* The surgical lubricant shall be sterile and maintain sterility during application. */
        
        subject lubricant : SurgicalLubricant;
        
        require constraint {
            lubricant.isSterile == true
        }
    }
    
    requirement <'SL-REQ-003'> frictionReductionRequirement {
        doc /* The surgical lubricant shall reduce surface friction by at least 60%. */
        
        subject frictionAction : ReduceFriction;
        
        require constraint {
            frictionAction.frictionReduction >= 0.60
        }
    }
    
    requirement <'SL-REQ-004'> viscosityRequirement {
        doc /* The surgical lubricant shall maintain viscosity between 1000 and 2000 mPa·s at body temperature. */
        
        subject lubricant : SurgicalLubricant;
        
        assume constraint temperatureRange {
            lubricant.temperature >= 310.0 and lubricant.temperature <= 315.0
        }
        
        require constraint {
            lubricant.viscosity >= 1000.0 and lubricant.viscosity <= 2000.0
        }
    }
    
    requirement <'SL-REQ-005'> waterSolubilityRequirement {
        doc /* The surgical lubricant shall be water-soluble for easy removal and cleaning. */
        
        subject lubricant : SurgicalLubricant;
        
        require constraint {
            lubricant.isWaterSoluble == true
        }
    }
    
    requirement <'SL-REQ-006'> flowControlRequirement {
        doc /* The system shall deliver lubricant at a controlled flow rate within ±5% of target. */
        
        subject flowMonitor : MonitorFlow;
        
        require constraint {
            flowMonitor.flowDeviation <= 0.05
        }
    }
    
    requirement <'SL-REQ-PRIMARY'> primaryFunctionRequirement {
        doc /* The primary function of the Surgical Lubricant System is to reduce friction between 
               surgical instruments and tissue surfaces by applying a sterile, biocompatible lubricant 
               in a controlled manner, thereby minimizing tissue trauma and facilitating smooth instrument 
               manipulation during surgical procedures. */
        
        subject system : surgicalLubricantSystem;
        
        assume constraint operationalEnvironment {
            doc /* System operates in sterile surgical environment at controlled temperature. */
        }
        
        require biocompatibilityRequirement;
        require sterilityRequirement;
        require frictionReductionRequirement;
        require viscosityRequirement;
        require waterSolubilityRequirement;
        require flowControlRequirement;
        
        require constraint systemEffectiveness {
            system.lubricationOperation.lubricationEfficiency >= 0.80
        }
    }
}

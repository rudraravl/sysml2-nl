package CapillaryActionIrrigationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    
    attribute def SurfaceTensionValue :> Real;
    
    attribute def ContactAngleValue :> Real;
    
    attribute def ViscosityValue :> Real;
    
    attribute def PorosityValue :> Real;
    
    attribute def MoistureLevel :> Real;
    
    enum def SystemState {
        initializing;
        wicking;
        delivering;
        equilibrium;
        depleted;
    }
    
    item def Water {
        attribute surfaceTension : SurfaceTensionValue;
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    port def FluidPort {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
    }
    
    port def MoisturePort {
        attribute moistureContent : MoistureLevel;
        attribute saturation : Real;
    }
    
    part def WaterReservoir {
        doc /* Container holding water supply for capillary distribution */
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute waterHeight : LengthValue;
        port outlet : FluidPort;
        
        assert constraint volumeLimit {
            currentLevel <= capacity
        }
        
        assert constraint positiveLevel {
            currentLevel >= 0.0 [m^3]
        }
    }
    
    part def CapillaryWick {
        doc /* Porous medium enabling water transport via capillary action */
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute poreRadius : LengthValue;
        attribute porosity : PorosityValue;
        attribute contactAngle : ContactAngleValue;
        attribute permeability : Real;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        attribute capillaryRiseHeight : LengthValue;
        attribute effectiveFlowRate : VolumeFlowRateValue;
        
        assert constraint capillaryRiseFormula {
            capillaryRiseHeight == (2.0 * 0.0728 * cos(contactAngle)) / 
                (998.0 * 9.81 * poreRadius)
        }
        
        assert constraint sufficientRise {
            capillaryRiseHeight >= length
        }
    }
    
    part def PlantingBed {
        doc /* Growing medium receiving water from capillary system */
        attribute soilVolume : VolumeValue;
        attribute currentMoisture : MoistureLevel;
        attribute targetMoisture : MoistureLevel;
        attribute evaporationRate : VolumeFlowRateValue;
        attribute plantWaterDemand : VolumeFlowRateValue;
        
        port waterInlet : FluidPort;
        port moistureInterface : MoisturePort;
        
        assert constraint moistureRange {
            currentMoisture >= 0.0 and currentMoisture <= 1.0
        }
        
        assert constraint targetRange {
            targetMoisture >= 0.3 and targetMoisture <= 0.7
        }
    }
    
    part def CapillaryIrrigationSystem {
        doc /* Passive irrigation system using capillary action to transport water 
             * from a reservoir through a porous wick to a planting bed, maintaining 
             * consistent soil moisture without pumps or external power. */
        
        part reservoir : WaterReservoir {
            attribute :>> capacity = 10.0 [L];
            attribute :>> currentLevel = 8.0 [L];
            attribute :>> waterHeight = 0.3 [m];
        }
        
        part wick : CapillaryWick {
            attribute :>> length = 0.25 [m];
            attribute :>> diameter = 0.01 [m];
            attribute :>> poreRadius = 0.0001 [m];
            attribute :>> porosity = 0.65;
            attribute :>> contactAngle = 0.349066;
            attribute :>> permeability = 0.85;
        }
        
        part plantingBed : PlantingBed {
            attribute :>> soilVolume = 0.05 [m^3];
            attribute :>> currentMoisture = 0.5;
            attribute :>> targetMoisture = 0.6;
            attribute :>> evaporationRate = 5.0e-8 [m^3/s];
            attribute :>> plantWaterDemand = 3.0e-8 [m^3/s];
        }
        
        connect reservoir.outlet to wick.inlet;
        connect wick.outlet to plantingBed.waterInlet;
        
        attribute totalWaterDemand : VolumeFlowRateValue = 
            plantingBed.evaporationRate + plantingBed.plantWaterDemand;
        
        assert constraint flowBalance {
            wick.effectiveFlowRate >= totalWaterDemand
        }
    }
    
    action def InitializeSystem {
        in system : CapillaryIrrigationSystem;
        out primed : Boolean;
        doc /* Prime the wick by ensuring contact with water reservoir */
    }
    
    action def MonitorReservoirLevel {
        in reservoir : WaterReservoir;
        out waterLevel : VolumeValue;
        out needsRefill : Boolean;
    }
    
    action def TransportWater {
        in wick : CapillaryWick;
        in reservoir : WaterReservoir;
        out deliveredFlow : VolumeFlowRateValue;
        doc /* Water moves through wick via capillary forces */
    }
    
    action def DistributeToSoil {
        in plantingBed : PlantingBed;
        in incomingFlow : VolumeFlowRateValue;
        out updatedMoisture : MoistureLevel;
        doc /* Water distributes into soil matrix from wick outlet */
    }
    
    action def CheckMoisture {
        in plantingBed : PlantingBed;
        out currentLevel : MoistureLevel;
        out withinTarget : Boolean;
    }
    
    action def OperateCapillarySystem {
        doc /* Continuous passive irrigation cycle */
        
        first start;
        then init : InitializeSystem;
        then merge continuousOperation;
        then monitor : MonitorReservoirLevel;
        then decide;
            if monitor.needsRefill then alert;
            if !monitor.needsRefill then transport;
        
        action alert {
            doc /* Signal reservoir depletion */
        }
        then done;
        
        action transport : TransportWater;
        then distribute : DistributeToSoil {
            in incomingFlow = transport.deliveredFlow;
        }
        then check : CheckMoisture;
        then continuousOperation;
    }
    
    state machine def IrrigationStateMachine {
        initial state Initializing;
        
        state Priming {
            entry action primingAction {
                doc /* Saturate wick with water */
            }
        }
        
        state ActiveWicking {
            entry action startWicking {
                doc /* Capillary forces draw water upward */
            }
        }
        
        state Delivering {
            entry action deliverWater {
                doc /* Water reaches planting bed */
            }
        }
        
        state Equilibrium {
            entry action maintainBalance {
                doc /* Supply matches demand */
            }
        }
        
        state Depleted {
            entry action stopFlow {
                doc /* Reservoir empty */
            }
        }
        
        transition first from Initializing to Priming;
        transition from Priming to ActiveWicking;
        transition from ActiveWicking to Delivering;
        transition from Delivering to Equilibrium;
        transition from Equilibrium to Delivering;
        transition from Equilibrium to Depleted;
        transition from Delivering to Depleted;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def PhysicalRequirement;
    
    requirement <'REQ-100'> primaryFunction : FunctionalRequirement {
        doc /* The capillary irrigation system shall passively transport water 
             * from a reservoir to a planting bed using capillary action through 
             * a porous wick, maintaining soil moisture without external power. */
        subject system : CapillaryIrrigationSystem;
    }
    
    requirement <'REQ-101'> capillaryLift : PhysicalRequirement {
        doc /* The wick shall generate sufficient capillary rise to overcome 
             * the vertical distance from reservoir water surface to planting bed. */
        subject wick : CapillaryWick;
        refine primaryFunction;
        
        assert constraint {
            wick.capillaryRiseHeight >= wick.length
        }
    }
    
    requirement <'REQ-102'> flowCapacity : PerformanceRequirement {
        doc /* The system shall deliver water at a rate meeting or exceeding 
             * the combined evaporation and plant water demand. */
        subject system : CapillaryIrrigationSystem;
        refine primaryFunction;
        
        assert constraint {
            system.wick.effectiveFlowRate >= system.totalWaterDemand
        }
    }
    
    requirement <'REQ-103'> moistureMaintenance : PerformanceRequirement {
        doc /* The system shall maintain planting bed moisture between 30% and 70% 
             * while the reservoir contains water. */
        subject system : CapillaryIrrigationSystem;
        refine primaryFunction;
        
        assert constraint {
            system.reservoir.currentLevel > 0.0 [L] implies
                (system.plantingBed.currentMoisture >= 0.3 and 
                 system.plantingBed.currentMoisture <= 0.7)
        }
    }
    
    requirement <'REQ-104'> reservoirCapacity : PhysicalRequirement {
        doc /* The reservoir shall have minimum capacity of 5 liters to support 
             * extended operation between refills. */
        subject reservoir : WaterReservoir;
        refine primaryFunction;
        
        assert constraint {
            reservoir.capacity >= 5.0 [L]
        }
    }
    
    requirement <'REQ-105'> wickProperties : PhysicalRequirement {
        doc /* The wick shall have porosity between 0.5 and 0.8 and pore radius 
             * between 0.05 mm and 0.2 mm for optimal capillary performance. */
        subject wick : CapillaryWick;
        refine capillaryLift;
        
        assert constraint {
            wick.porosity >= 0.5 and wick.porosity <= 0.8 and
            wick.poreRadius >= 0.00005 [m] and wick.poreRadius <= 0.0002 [m]
        }
    }
    
    part systemInstance : CapillaryIrrigationSystem;
    
    satisfy primaryFunction by systemInstance;
    satisfy capillaryLift by systemInstance.wick;
    satisfy flowCapacity by systemInstance;
    satisfy moistureMaintenance by systemInstance;
    satisfy reservoirCapacity by systemInstance.reservoir;
    satisfy wickProperties by systemInstance.wick;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import CapillaryActionIrrigationSystem::*;

    action orchestrator {
        action transportProbe : TransportWater {
            // TODO(human): unsupported input type for wick: CapillaryWick (type is not a primitive, enum, extracted payload def, or known value type)
            // TODO(human): unsupported input type for reservoir: WaterReservoir (type is not a primitive, enum, extracted payload def, or known value type)
        }
        first transportProbe;
    }
}

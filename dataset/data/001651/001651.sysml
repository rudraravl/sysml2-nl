package EmberSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* This model describes an Ember system: a glowing piece of combustible material 
         that sustains controlled oxidation to produce continuous radiant heat. The primary 
         function is to maintain a steady-state combustion process that converts chemical 
         energy from solid fuel into thermal energy through oxygen-driven oxidation, 
         providing persistent heat output without active flame. */
    
    attribute def EmberTemperature :> ThermodynamicTemperatureValue;
    attribute def OxygenConcentration :> Real;
    attribute def FuelMassValue :> MassValue;
    attribute def HeatFluxValue :> PowerValue;
    attribute def CombustionRate :> Real;
    attribute def EmberIntensity :> Real;
    
    enum def EmberState {
        dormant;
        igniting;
        glowing;
        fading;
        extinguished;
    }
    
    port def FuelInterfacePort {
        attribute fuelMassRate : Real;
        attribute fuelSurfaceArea : AreaValue;
        attribute fuelTemperature : ThermodynamicTemperatureValue;
    }
    
    port def OxygenInterfacePort {
        attribute oxygenFlowRate : VolumeFlowRateValue;
        attribute oxygenPurity : Real;
        attribute ambientPressure : PressureValue;
    }
    
    port def ThermalOutputPort {
        attribute heatFlux : PowerValue;
        attribute surfaceTemperature : ThermodynamicTemperatureValue;
        attribute radiationIntensity : Real;
    }
    
    item def FuelParticle {
        attribute mass : MassValue;
        attribute carbonContent : Real;
        attribute volatileContent : Real;
    }
    
    item def OxygenFlow {
        attribute volumeRate : VolumeFlowRateValue;
        attribute concentration : Real;
    }
    
    item def ThermalEnergy {
        attribute power : PowerValue;
        attribute wavelength : LengthValue;
    }
    
    part def FuelBed {
        attribute totalMass :> ISQ::mass;
        attribute porosity : Real;
        attribute surfaceArea :> ISQ::area;
        attribute charDepth : LengthValue;
        port fuelOutput : FuelInterfacePort;
    }
    
    part def AirSupplySystem {
        attribute flowCapacity : VolumeFlowRateValue;
        attribute oxygenContent : Real;
        attribute supplyPressure : PressureValue;
        port airOutput : OxygenInterfacePort;
    }
    
    part def CombustionCore {
        attribute coreTemperature :> ISQ::temperature;
        attribute reactionRate : CombustionRate;
        attribute emberBrightness : EmberIntensity;
        port fuelInput : FuelInterfacePort;
        port oxygenInput : OxygenInterfacePort;
        port heatOutput : ThermalOutputPort;
    }
    
    part def ThermalRadiator {
        attribute emissivity : Real;
        attribute radiativePower :> ISQ::power;
        attribute effectiveArea :> ISQ::area;
        port heatInput : ThermalOutputPort;
    }
    
    action def MonitorCombustionState {
        in currentTemp : EmberTemperature;
        in oxygenLevel : OxygenConcentration;
        in fuelRemaining : FuelMassValue;
        out state : EmberState;
        out intensity : EmberIntensity;
    }
    
    action def RegulateAirflow {
        in targetTemperature : EmberTemperature;
        in measuredTemperature : EmberTemperature;
        in currentIntensity : EmberIntensity;
        out adjustedFlowRate : VolumeFlowRateValue;
    }
    
    action def OxidizeFuel {
        in fuelAvailable : FuelMassValue;
        in oxygenSupply : OxygenConcentration;
        in reactionEfficiency : Real;
        out fuelConsumed : FuelMassValue;
        out heatGenerated : HeatFluxValue;
        out ashProduced : MassValue;
    }
    
    action def RadiateThermalEnergy {
        in inputHeat : HeatFluxValue;
        in surfaceTemp : EmberTemperature;
        in ambientTemp : ThermodynamicTemperatureValue;
        out radiatedPower : HeatFluxValue;
        out convectedPower : HeatFluxValue;
    }
    
    state def EmberLifecycle {
        entry; then dormantState;
        
        state dormantState {
            doc /* Ember is present but not actively combusting */
        }
        transition dormant_to_igniting
            first dormantState
            accept ignitionSignal : Boolean
            if ignitionSignal
            then ignitingState;
        
        state ignitingState {
            doc /* Initial combustion starting, temperature rising */
        }
        transition igniting_to_glowing
            first ignitingState
            accept tempReached : Boolean
            if tempReached
            then glowingState;
        
        state glowingState {
            doc /* Sustained combustion with visible incandescence */
        }
        transition glowing_to_fading
            first glowingState
            accept degradationSignal : Boolean
            if degradationSignal
            then fadingState;
        
        state fadingState {
            doc /* Combustion intensity decreasing */
        }
        transition fading_to_extinguished
            first fadingState
            accept extinctionSignal : Boolean
            if extinctionSignal
            then extinguishedState;
        
        transition fading_to_glowing
            first fadingState
            accept recoverySignal : Boolean
            if recoverySignal
            then glowingState;
        
        state extinguishedState {
            doc /* Combustion ceased, ember no longer active */
        }
        then done;
    }
    
    action def MaintainEmberOperation {
        first start;
        then merge monitoringCycle;
        
        then action monitor : MonitorCombustionState {
            in currentTemp;
            in oxygenLevel;
            in fuelRemaining;
            out state;
            out intensity;
        }
        
        then decide;
            if monitor.state == EmberState::glowing then regulateOperation;
            if monitor.state == EmberState::fading then boostOperation;
            if monitor.state == EmberState::extinguished then terminateOperation;
        
        action regulateOperation {
            action adjustAir : RegulateAirflow {
                in targetTemperature = 850.0[K];
                in measuredTemperature = monitor.currentTemp;
                in currentIntensity = monitor.intensity;
                out adjustedFlowRate;
            }
            then performCombustion : OxidizeFuel {
                in fuelAvailable = monitor.fuelRemaining;
                in oxygenSupply = monitor.oxygenLevel;
                in reactionEfficiency = 0.82;
                out fuelConsumed;
                out heatGenerated;
                out ashProduced;
            }
            then radiateEnergy : RadiateThermalEnergy {
                in inputHeat = performCombustion.heatGenerated;
                in surfaceTemp = monitor.currentTemp;
                in ambientTemp = 298.15[K];
                out radiatedPower;
                out convectedPower;
            }
        }
        then monitoringCycle;
        
        action boostOperation {
            action increaseAir : RegulateAirflow {
                in targetTemperature = 900.0[K];
                in measuredTemperature = monitor.currentTemp;
                in currentIntensity = monitor.intensity;
                out adjustedFlowRate;
            }
        }
        then monitoringCycle;
        
        action terminateOperation;
        then done;
    }
    
    part def EmberSystem {
        doc /* Complete ember system integrating fuel, oxidizer, and thermal output */
        
        attribute operatingTemperature : EmberTemperature;
        attribute totalFuelMass : FuelMassValue;
        attribute availableOxygen : OxygenConcentration;
        attribute thermalPowerOutput : HeatFluxValue;
        attribute currentState : EmberState;
        
        part fuelBed : FuelBed {
            attribute :>> totalMass = 1.8[kg];
            attribute :>> porosity = 0.45;
            attribute :>> surfaceArea = 0.035[m^2];
            attribute :>> charDepth = 0.015[m];
        }
        
        part airSupply : AirSupplySystem {
            attribute :>> flowCapacity = 0.0015[m^3/s];
            attribute :>> oxygenContent = 0.21;
            attribute :>> supplyPressure = 101325.0[Pa];
        }
        
        part combustionCore : CombustionCore {
            attribute :>> coreTemperature = 825.0[K];
            attribute :>> reactionRate = 0.12;
            attribute :>> emberBrightness = 0.68;
        }
        
        part thermalRadiator : ThermalRadiator {
            attribute :>> emissivity = 0.85;
            attribute :>> radiativePower = 420.0[W];
            attribute :>> effectiveArea = 0.028[m^2];
        }
        
        connect fuelBed.fuelOutput to combustionCore.fuelInput;
        connect airSupply.airOutput to combustionCore.oxygenInput;
        connect combustionCore.heatOutput to thermalRadiator.heatInput;
        
        perform action maintainOperation : MaintainEmberOperation;
        
        exhibit state lifecycle : EmberLifecycle;
    }
    
    part emberSystem : EmberSystem;
    
    requirement def EmberPrimaryFunctionRequirement {
        doc /* The ember system shall maintain sustained oxidation of solid fuel to 
               continuously generate radiant thermal energy through controlled combustion 
               at temperatures sufficient for visible incandescence. */
        
        subject system : EmberSystem;
        
        require constraint operatingTemperatureRange {
            doc /* Ember core temperature shall remain within glowing range */
            system.operatingTemperature >= 650.0[K] and 
            system.operatingTemperature <= 1100.0[K]
        }
        
        require constraint minimumThermalOutput {
            doc /* Ember shall produce minimum sustained heat output */
            system.thermalPowerOutput >= 250.0[W]
        }
        
        require constraint combustionEfficiency {
            doc /* Fuel consumption rate shall be controlled and efficient */
            system.combustionCore.reactionRate >= 0.08 and
            system.combustionCore.reactionRate <= 0.18
        }
        
        require constraint oxygenAvailability {
            doc /* Sufficient oxygen must be available for sustained combustion */
            system.availableOxygen >= 0.16
        }
        
        require constraint fuelReserve {
            doc /* Adequate fuel mass must be maintained for continuous operation */
            system.totalFuelMass >= 0.5[kg]
        }
    }
    
    requirement primaryMission : EmberPrimaryFunctionRequirement {
        subject emberSystem;
        doc /* Primary Function: The ember system converts chemical potential energy 
               stored in carbonaceous solid fuel into radiant and convective thermal 
               energy through continuous heterogeneous oxidation reactions. This process 
               maintains a self-sustaining glowing combustion state that provides 
               persistent heat output over extended duration without requiring active 
               flame propagation, serving applications in heating, cooking, and 
               controlled energy release. */
    }
}

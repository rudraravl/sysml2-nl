package 'Metal Foam Energy Absorption System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Porosity :> ScalarValues::Real;
    
    attribute def PoreDensity {
        attribute value :> ScalarValues::Real;
        attribute unit :> ScalarValues::String default "pores per inch";
    }
    
    attribute def SpecificEnergyAbsorption {
        attribute value :> ScalarValues::Real;
        attribute unit :> ScalarValues::String default "J/kg";
    }
    
    enum def LoadingPhase {
        elastic;
        plateau;
        densification;
    }
    
    item def ImpactLoad {
        attribute force : ForceValue;
        attribute velocity : SpeedValue;
        attribute mass : MassValue;
    }
    
    item def ThermalLoad {
        attribute heatFlux : PowerValue;
        attribute ambientTemperature : ThermodynamicTemperatureValue;
    }
    
    part def MetalFoamCore {
        attribute baseAlloy : ScalarValues::String;
        attribute porosity : Porosity;
        attribute poreDensity : PoreDensity;
        attribute cellSize : LengthValue;
        attribute density : DensityValue;
        attribute yieldStrength : PressureValue;
        attribute plateauStress : PressureValue;
        attribute thermalConductivity : ScalarValues::Real;
        
        port mechanicalInterface {
            in appliedForce : ForceValue;
            out reactionForce : ForceValue;
            out displacement : LengthValue;
        }
        
        port thermalInterface {
            in heatInput : PowerValue;
            out surfaceTemperature : ThermodynamicTemperatureValue;
        }
    }
    
    part def ProtectiveEnclosure {
        attribute thickness : LengthValue;
        attribute material : ScalarValues::String;
        
        port outerSurface {
            in externalLoad : ForceValue;
            out transmittedLoad : ForceValue;
        }
        
        port innerSurface {
            out distributedLoad : ForceValue;
        }
    }
    
    part def MountingBracket {
        attribute attachmentPoints : ScalarValues::Integer;
        attribute loadCapacity : ForceValue;
        
        port attachment {
            in structuralLoad : ForceValue;
            out anchorReaction : ForceValue;
        }
    }
    
    part def SensorArray {
        attribute numberOfSensors : ScalarValues::Integer;
        
        port dataOutput {
            out deformationData : LengthValue;
            out forceData : ForceValue;
            out temperatureData : ThermodynamicTemperatureValue;
        }
    }
    
    action def AbsorbImpactEnergy {
        in impactForce : ForceValue;
        in impactVelocity : SpeedValue;
        in foamDensity : DensityValue;
        in plateauStress : PressureValue;
        out energyAbsorbed : EnergyValue;
        out peakDeceleration : AccelerationValue;
        out permanentDeformation : LengthValue;
    }
    
    action def DissipateHeat {
        in heatFlux : PowerValue;
        in foamConductivity : ScalarValues::Real;
        in surfaceArea : AreaValue;
        in ambientTemp : ThermodynamicTemperatureValue;
        out steadyStateTemp : ThermodynamicTemperatureValue;
        out heatDissipated : PowerValue;
    }
    
    action def MonitorStructuralIntegrity {
        in currentDeformation : LengthValue;
        in maxAllowableDeformation : LengthValue;
        in currentTemperature : ThermodynamicTemperatureValue;
        in maxOperatingTemp : ThermodynamicTemperatureValue;
        out integrityStatus : ScalarValues::Boolean;
        out warningLevel : ScalarValues::Integer;
    }
    
    state def FoamOperationalStates {
        attribute currentPhase : LoadingPhase;
        attribute elasticLimit : LengthValue;
        attribute plateauLimit : LengthValue;
        
        entry; then unloaded;
        
        state unloaded;
        
        transition unloaded_to_loading
            first unloaded
            accept impactEvent : ImpactLoad
            if impactEvent.force > 0.0[N]
            then elasticDeformation;
        
        state elasticDeformation {
            do action absorb : AbsorbImpactEnergy;
        }
        
        transition elastic_to_plateau
            first elasticDeformation
            then plateauDeformation;
        
        state plateauDeformation {
            do action continuousAbsorption : AbsorbImpactEnergy;
        }
        
        transition plateau_to_densification
            first plateauDeformation
            then densificationState;
        
        state densificationState;
        
        transition densification_to_recovery
            first densificationState
            accept unloadEvent
            then partialRecovery;
        
        state partialRecovery;
        
        transition recovery_to_unloaded
            first partialRecovery
            then unloaded;
        
        transition thermal_event
            first unloaded
            accept thermalEvent : ThermalLoad
            if thermalEvent.heatFlux > 0.0[W]
            then thermalManagement;
        
        state thermalManagement {
            do action dissipate : DissipateHeat;
        }
        
        transition thermal_complete
            first thermalManagement
            accept cooldownComplete
            then unloaded;
    }
    
    part def MetalFoamEnergyAbsorptionSystem {
        part foamCore : MetalFoamCore;
        part enclosure : ProtectiveEnclosure;
        part mounting : MountingBracket;
        part sensors : SensorArray;
    }
    
    part metalFoamSystem : MetalFoamEnergyAbsorptionSystem {
        doc /*
            A metal foam-based energy absorption system designed to protect critical
            components and structures from impact loads and thermal transients.
            
            The system exploits the unique cellular architecture of metal foam to
            progressively collapse under load, converting kinetic energy into plastic
            deformation work while maintaining controlled deceleration. The high
            surface area and thermal mass enable effective heat dissipation.
            
            Primary function: Absorb and dissipate impact energy through controlled
            progressive deformation of the foam structure, while providing thermal
            management and maintaining structural integrity throughout the loading cycle.
        */
        
        part redefines foamCore : MetalFoamCore {
            attribute :>> baseAlloy = "Aluminum 6101-T6";
            attribute :>> porosity = 0.90;
            attribute :>> poreDensity = PoreDensity(value = 25.0);
            attribute :>> cellSize = 3.0[mm];
            attribute :>> density = 270.0[kg/m^3];
            attribute :>> yieldStrength = 2.5[MPa];
            attribute :>> plateauStress = 3.8[MPa];
            attribute :>> thermalConductivity = 18.5;
            
            perform action absorbEnergy : AbsorbImpactEnergy {
                in impactForce = foamCore.mechanicalInterface.appliedForce;
                in impactVelocity = 10.0[m/s];
                in foamDensity = foamCore.density;
                in plateauStress = foamCore.plateauStress;
                out energyAbsorbed;
                out peakDeceleration;
                out permanentDeformation;
            }
            
            perform action manageHeat : DissipateHeat {
                in heatFlux = foamCore.thermalInterface.heatInput;
                in foamConductivity = foamCore.thermalConductivity;
                in surfaceArea = 0.25[m^2];
                in ambientTemp = 293.15[K];
                out steadyStateTemp;
                out heatDissipated;
            }
        }
        
        part redefines enclosure : ProtectiveEnclosure {
            attribute :>> thickness = 2.0[mm];
            attribute :>> material = "Steel AISI 1020";
        }
        
        part redefines mounting : MountingBracket {
            attribute :>> attachmentPoints = 4;
            attribute :>> loadCapacity = 50000.0[N];
        }
        
        part redefines sensors : SensorArray {
            attribute :>> numberOfSensors = 8;
            
            perform action monitor : MonitorStructuralIntegrity {
                in currentDeformation = sensors.dataOutput.deformationData;
                in maxAllowableDeformation = 40.0[mm];
                in currentTemperature = sensors.dataOutput.temperatureData;
                in maxOperatingTemp = 473.15[K];
                out integrityStatus;
                out warningLevel;
            }
        }
        
        connect enclosure.outerSurface to enclosure.innerSurface;
        connect enclosure.innerSurface.distributedLoad to foamCore.mechanicalInterface.appliedForce;
        connect foamCore.mechanicalInterface.reactionForce to mounting.attachment.structuralLoad;
        
        perform action systemOperation {
            first start;
            then merge operationalLoop;
            
            action monitorSystem : MonitorStructuralIntegrity {
                in currentDeformation = sensors.dataOutput.deformationData;
                in maxAllowableDeformation = 40.0[mm];
                in currentTemperature = sensors.dataOutput.temperatureData;
                in maxOperatingTemp = 473.15[K];
                out integrityStatus;
                out warningLevel;
            }
            
            then decide;
                if monitorSystem.integrityStatus == true then normalOperation;
                if monitorSystem.integrityStatus == false then faultCondition;
            
            action normalOperation {
                action executeAbsorption references foamCore.absorbEnergy;
                flow executeAbsorption.energyAbsorbed to executeAbsorption.permanentDeformation;
                
                action executeThermal references foamCore.manageHeat;
                flow executeThermal.heatInput to executeThermal.steadyStateTemp;
            }
            then operationalLoop;
            
            action faultCondition;
            then done;
        }
        
        exhibit state foamBehavior : FoamOperationalStates {
            :>> elasticLimit = 5.0[mm];
            :>> plateauLimit = 35.0[mm];
        }
    }
    
    requirement def EnergyAbsorptionCapability {
        doc /* The system shall absorb impact energy with controlled deceleration. */
        
        subject system : MetalFoamEnergyAbsorptionSystem;
        
        require constraint {
            system.foamCore.absorbEnergy.energyAbsorbed >= 3000.0[J]
        }
        
        require constraint {
            system.foamCore.absorbEnergy.peakDeceleration <= 150.0[m/s^2]
        }
    }
    
    requirement def ThermalManagementCapability {
        doc /* The system shall dissipate thermal loads effectively. */
        
        subject system : MetalFoamEnergyAbsorptionSystem;
        
        require constraint {
            system.foamCore.manageHeat.steadyStateTemp <= 423.15[K]
        }
        
        require constraint {
            system.foamCore.manageHeat.heatDissipated >= 500.0[W]
        }
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* The system shall maintain structural integrity under operational loads. */
        
        subject system : MetalFoamEnergyAbsorptionSystem;
        
        require constraint {
            system.sensors.monitor.integrityStatus == true
        }
        
        require constraint {
            system.foamCore.absorbEnergy.permanentDeformation <= 40.0[mm]
        }
    }
    
    requirement def LightweightDesignRequirement {
        doc /* The system shall maintain low mass while providing protection. */
        
        subject system : MetalFoamEnergyAbsorptionSystem;
        
        require constraint {
            system.foamCore.density <= 300.0[kg/m^3]
        }
    }
    
    requirement <'MFEAS-001'> primarySystemRequirement {
        doc /*
            The metal foam energy absorption system shall protect critical components
            by absorbing impact energy through controlled progressive deformation,
            dissipating thermal loads, and maintaining structural integrity throughout
            the operational envelope while minimizing system mass.
        */
        
        subject protectionSystem = metalFoamSystem;
        
        assume constraint materialProperties {
            protectionSystem.foamCore.porosity >= 0.85 and
            protectionSystem.foamCore.porosity <= 0.95
        }
        
        assume constraint operatingConditions {
            protectionSystem.foamCore.thermalInterface.heatInput <= 2000.0[W]
        }
        
        require energyAbsorption : EnergyAbsorptionCapability;
        require thermalManagement : ThermalManagementCapability;
        require structuralIntegrity : StructuralIntegrityRequirement;
        require lightweightDesign : LightweightDesignRequirement;
    }
}

package FrackingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def DepthValue :> Real;
    attribute def ConcentrationValue :> Real;
    attribute def TemperatureValue :> Real;

    enum def OperationalPhase {
        idle;
        mixing;
        pressurizing;
        injecting;
        soaking;
        flowback;
        production;
        shutdown;
    }

    item def Water {
        attribute purity : Real;
        attribute volume : VolumeValue;
    }

    item def Proppant {
        attribute mass : MassValue;
        attribute particleSize : LengthValue;
        attribute meshSize : Real;
    }

    item def ChemicalAdditive {
        attribute viscosityModifier : Real;
        attribute frictionReducer : Real;
        attribute volume : VolumeValue;
    }

    item def FracturingFluid {
        attribute totalVolume : VolumeValue;
        attribute proppantConcentration : ConcentrationValue;
        attribute viscosity : Real;
        attribute density : Real;
        attribute pressure : PressureValue;
    }

    item def NaturalGas {
        attribute volume : VolumeValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    item def ProducedWater {
        attribute volume : VolumeValue;
        attribute contaminantLevel : Real;
    }

    port def FluidInputPort {
        in item fluid : FracturingFluid;
        attribute inletPressure : PressureValue;
        attribute inletFlowRate : FlowRateValue;
    }

    port def FluidOutputPort {
        out item fluid : FracturingFluid;
        attribute outletPressure : PressureValue;
        attribute outletFlowRate : FlowRateValue;
    }

    port def GasOutputPort {
        out item gas : NaturalGas;
        attribute outletPressure : PressureValue;
        attribute outletFlowRate : FlowRateValue;
    }

    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute statusSignal : Real;
        out attribute pressureReading : PressureValue;
        out attribute flowReading : FlowRateValue;
    }

    part def WaterSource {
        attribute storageCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute supplyRate : FlowRateValue;
        port waterOutput {
            out item water : Water;
        }
    }

    part def ProppantStorage {
        attribute storageCapacity : MassValue;
        attribute currentInventory : MassValue;
        attribute feedRate : MassValue;
        port proppantOutput {
            out item proppant : Proppant;
        }
    }

    part def ChemicalStorage {
        attribute storageCapacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute injectionRate : FlowRateValue;
        port chemicalOutput {
            out item chemical : ChemicalAdditive;
        }
    }

    part def BlendingUnit {
        attribute mixingCapacity : VolumeValue;
        attribute targetConcentration : ConcentrationValue;
        attribute outputRate : FlowRateValue;
        port waterInput {
            in item water : Water;
        }
        port proppantInput {
            in item proppant : Proppant;
        }
        port chemicalInput {
            in item chemical : ChemicalAdditive;
        }
        port fluidOutput : FluidOutputPort;
        port control : ControlPort;
    }

    part def HighPressurePump {
        attribute ratedPressure : PressureValue;
        attribute maxFlowRate : FlowRateValue;
        attribute currentPressure : PressureValue;
        attribute currentFlowRate : FlowRateValue;
        attribute efficiency : Real;
        port fluidInput : FluidInputPort;
        port fluidOutput : FluidOutputPort;
        port control : ControlPort;
    }

    part def WellheadAssembly {
        attribute ratedPressure : PressureValue;
        attribute casingDiameter : LengthValue;
        attribute currentPressure : PressureValue;
        port fluidInput : FluidInputPort;
        port wellboreConnection {
            out item fluid : FracturingFluid;
        }
        port gasReturn : GasOutputPort;
        port control : ControlPort;
    }

    part def WellboreAssembly {
        attribute totalDepth : DepthValue;
        attribute casingDepth : DepthValue;
        attribute perforationDepth : DepthValue;
        attribute formationPressure : PressureValue;
        part casing {
            attribute diameter : LengthValue;
            attribute thickness : LengthValue;
            attribute material : String;
        }
        part perforations[50..200] {
            attribute depth : DepthValue;
            attribute diameter : LengthValue;
            attribute spacing : LengthValue;
        }
        port fluidInlet {
            in item fluid : FracturingFluid;
        }
        port gasOutlet : GasOutputPort;
        port wasteWaterOutlet {
            out item water : ProducedWater;
        }
    }

    part def MonitoringSystem {
        attribute pressureThreshold : PressureValue;
        attribute flowThreshold : FlowRateValue;
        attribute seismicThreshold : Real;
        part pressureSensors[10..25] {
            attribute sensorDepth : DepthValue;
            attribute currentReading : PressureValue;
            attribute accuracy : Real;
        }
        part flowMeters[5..12] {
            attribute currentFlowRate : FlowRateValue;
            attribute accuracy : Real;
        }
        part seismicMonitors[8..16] {
            attribute seismicActivity : Real;
            attribute sensitivity : Real;
        }
        port dataOutput : ControlPort;
    }

    part def SeparationFacility {
        attribute separationEfficiency : Real;
        attribute gasCapacity : VolumeValue;
        attribute waterCapacity : VolumeValue;
        part gasSeparator {
            attribute separatedGasVolume : VolumeValue;
            attribute operatingPressure : PressureValue;
        }
        part waterTreatment {
            attribute recoveredWaterVolume : VolumeValue;
            attribute treatmentEfficiency : Real;
        }
        port mixedInput {
            in item gas : NaturalGas;
            in item water : ProducedWater;
        }
        port gasOutput : GasOutputPort;
        port waterOutput {
            out item water : ProducedWater;
        }
        port control : ControlPort;
    }

    action def MixFracturingFluid {
        in waterVolume : VolumeValue;
        in proppantMass : MassValue;
        in chemicalVolume : VolumeValue;
        in targetConcentration : ConcentrationValue;
        out mixedFluid : FracturingFluid;
    }

    action def PressurizeFluid {
        in inputPressure : PressureValue;
        in targetPressure : PressureValue;
        in flowRate : FlowRateValue;
        out outputPressure : PressureValue;
        out pumpingComplete : Boolean;
    }

    action def InjectFluid {
        in injectionPressure : PressureValue;
        in injectionRate : FlowRateValue;
        in totalVolume : VolumeValue;
        out injectedVolume : VolumeValue;
        out fracturesCreated : Boolean;
    }

    action def MonitorFormation {
        in wellDepth : DepthValue;
        out formationPressure : PressureValue;
        out seismicActivity : Real;
        out pressureStable : Boolean;
    }

    action def ExtractHydrocarbons {
        in wellPressure : PressureValue;
        out gasFlowRate : FlowRateValue;
        out gasVolume : VolumeValue;
        out waterVolume : VolumeValue;
    }

    action def HydraulicFracturingOperation {
        in targetPressure : PressureValue;
        in targetFlowRate : FlowRateValue;
        in targetVolume : VolumeValue;
        in formationDepth : DepthValue;

        first start;
        then merge continueOperation;

        then action monitorFormation : MonitorFormation {
            in wellDepth = formationDepth;
            out formationPressure : PressureValue;
            out seismicActivity : Real;
            out pressureStable : Boolean;
        }

        then decide;
            if monitorFormation.pressureStable then mixFluid;
            if !monitorFormation.pressureStable then adjustParameters;

        action mixFluid : MixFracturingFluid {
            in waterVolume = 15000.0;
            in proppantMass = 500000.0;
            in chemicalVolume = 750.0;
            in targetConcentration = 200.0;
            out mixedFluid : FracturingFluid;
        }
        then pressurizeFluid;

        action pressurizeFluid : PressurizeFluid {
            in inputPressure = 5000000.0;
            in targetPressure = targetPressure;
            in flowRate = targetFlowRate;
            out outputPressure : PressureValue;
            out pumpingComplete : Boolean;
        }
        then injectFluid;

        action injectFluid : InjectFluid {
            in injectionPressure = pressurizeFluid.outputPressure;
            in injectionRate = targetFlowRate;
            in totalVolume = targetVolume;
            out injectedVolume : VolumeValue;
            out fracturesCreated : Boolean;
        }

        then decide;
            if injectFluid.fracturesCreated and injectFluid.injectedVolume >= targetVolume then soakPeriod;
            if !injectFluid.fracturesCreated then adjustParameters;
            if injectFluid.injectedVolume < targetVolume then continueOperation;

        action soakPeriod {
            in soakDuration = 7200.0;
        }
        then extractHydrocarbons;

        action extractHydrocarbons : ExtractHydrocarbons {
            in wellPressure = monitorFormation.formationPressure;
            out gasFlowRate : FlowRateValue;
            out gasVolume : VolumeValue;
            out waterVolume : VolumeValue;
        }
        then continueOperation;

        action adjustParameters {
            in currentPressure = monitorFormation.formationPressure;
            in currentSeismic = monitorFormation.seismicActivity;
            out adjustedPressure : PressureValue;
            out adjustedFlowRate : FlowRateValue;
        }
        then continueOperation;
    }

    state def HydraulicFracturingStates {
        entry; then idle;

        state idle;
        
        transition idle_to_mixing
            first idle
            accept at startOperation
            then mixing;

        state mixing;
        
        transition mixing_to_pressurizing
            first mixing
            accept at mixingComplete
            then pressurizing;

        state pressurizing;
        
        transition pressurizing_to_injecting
            first pressurizing
            accept at targetPressureReached
            then injecting;

        state injecting;
        
        transition injecting_to_soaking
            first injecting
            accept at injectionComplete
            then soaking;

        state soaking;
        
        transition soaking_to_flowback
            first soaking
            accept after 7200.0
            then flowback;

        state flowback;
        
        transition flowback_to_production
            first flowback
            accept at flowbackComplete
            then production;

        state production;
        
        transition production_to_shutdown
            first production
            accept at shutdownRequested
            then shutdown;

        state shutdown;
    }

    part def HydraulicFracturingSystem {
        doc /* A hydraulic fracturing system designed to extract natural gas 
             * from subsurface shale formations by injecting high-pressure 
             * fracturing fluid to create and maintain fracture networks.
             */

        attribute operatingDepth : DepthValue;
        attribute totalFluidVolume : VolumeValue;
        attribute targetInjectionPressure : PressureValue;
        attribute targetInjectionRate : FlowRateValue;
        attribute gasProductionRate : FlowRateValue;
        attribute operationalEfficiency : Real;

        part waterSource : WaterSource {
            attribute :>> storageCapacity = 25000.0;
            attribute :>> currentLevel = 20000.0;
            attribute :>> supplyRate = 0.5;
        }

        part proppantStorage : ProppantStorage {
            attribute :>> storageCapacity = 1000000.0;
            attribute :>> currentInventory = 800000.0;
            attribute :>> feedRate = 15000.0;
        }

        part chemicalStorage : ChemicalStorage {
            attribute :>> storageCapacity = 2000.0;
            attribute :>> currentLevel = 1500.0;
            attribute :>> injectionRate = 0.05;
        }

        part blender : BlendingUnit {
            attribute :>> mixingCapacity = 100.0;
            attribute :>> targetConcentration = 200.0;
            attribute :>> outputRate = 0.3;
        }

        part pumps : HighPressurePump[3..6] {
            attribute :>> ratedPressure = 100000000.0;
            attribute :>> maxFlowRate = 0.25;
            attribute :>> efficiency = 0.85;
        }

        part wellhead : WellheadAssembly {
            attribute :>> ratedPressure = 105000000.0;
            attribute :>> casingDiameter = 0.34;
        }

        part wellbore : WellboreAssembly {
            attribute :>> totalDepth = 2800.0;
            attribute :>> casingDepth = 2500.0;
            attribute :>> perforationDepth = 2600.0;
            attribute :>> formationPressure = 45000000.0;
        }

        part monitoring : MonitoringSystem {
            attribute :>> pressureThreshold = 90000000.0;
            attribute :>> flowThreshold = 0.35;
            attribute :>> seismicThreshold = 2.5;
        }

        part separator : SeparationFacility {
            attribute :>> separationEfficiency = 0.92;
            attribute :>> gasCapacity = 5000.0;
            attribute :>> waterCapacity = 3000.0;
        }

        connection waterSupply connect waterSource.waterOutput to blender.waterInput;
        connection proppantSupply connect proppantStorage.proppantOutput to blender.proppantInput;
        connection chemicalSupply connect chemicalStorage.chemicalOutput to blender.chemicalInput;
        connection blenderToPump connect blender.fluidOutput to pumps[1].fluidInput;
        connection pumpToWellhead connect pumps[1].fluidOutput to wellhead.fluidInput;
        connection wellheadToWellbore connect wellhead.wellboreConnection to wellbore.fluidInlet;
        connection wellboreToSeparator connect wellbore.gasOutlet to separator.mixedInput;
        connection monitoringControl connect monitoring.dataOutput to pumps[1].control;

        perform action fracOperation : HydraulicFracturingOperation {
            in targetPressure = 75000000.0;
            in targetFlowRate = 0.3;
            in targetVolume = 18000.0;
            in formationDepth = 2800.0;
        }

        exhibit state operationalState : HydraulicFracturingStates;
    }

    requirement <'REQ-FRAC-001'> primaryMission {
        doc /* The hydraulic fracturing system shall create and maintain 
             * fracture networks in subsurface shale formations to enable 
             * economically viable extraction of natural gas by injecting 
             * high-pressure fluid mixtures containing water, proppant, 
             * and chemical additives.
             */
        subject system : HydraulicFracturingSystem;

        require <'REQ-FRAC-002'> injectionPressureRequirement {
            doc /* The system shall achieve and maintain injection pressures 
                 * between 60 MPa and 100 MPa to effectively fracture 
                 * target formations.
                 */
            assert constraint {
                system.targetInjectionPressure >= 60000000.0 and
                system.targetInjectionPressure <= 100000000.0
            }
        }

        require <'REQ-FRAC-003'> operatingDepthRequirement {
            doc /* The system shall operate at depths between 2000m and 3500m 
                 * to access economically viable shale formations.
                 */
            assert constraint {
                system.operatingDepth >= 2000.0 and
                system.operatingDepth <= 3500.0
            }
        }

        require <'REQ-FRAC-004'> fluidVolumeRequirement {
            doc /* The system shall inject a minimum of 15000 cubic meters 
                 * of fracturing fluid per well to create adequate fracture 
                 * network density.
                 */
            assert constraint {
                system.totalFluidVolume >= 15000.0
            }
        }

        require <'REQ-FRAC-005'> flowRateRequirement {
            doc /* The system shall maintain injection flow rates between 
                 * 0.2 and 0.4 cubic meters per second to achieve optimal 
                 * fracture propagation.
                 */
            assert constraint {
                system.targetInjectionRate >= 0.2 and
                system.targetInjectionRate <= 0.4
            }
        }

        require <'REQ-FRAC-006'> proppantConcentrationRequirement {
            doc /* The system shall maintain proppant concentration between 
                 * 120 and 360 kg/m³ to ensure adequate fracture conductivity.
                 */
            subject blender :>> system.blender;
            assert constraint {
                blender.targetConcentration >= 120.0 and
                blender.targetConcentration <= 360.0
            }
        }

        require <'REQ-FRAC-007'> safetyPressureLimit {
            doc /* The system operating pressure shall not exceed 95% of 
                 * wellhead rated pressure to maintain safety margins.
                 */
            subject wellhead :>> system.wellhead;
            assert constraint {
                system.targetInjectionPressure <= 0.95 * wellhead.ratedPressure
            }
        }

        require <'REQ-FRAC-008'> continuousMonitoring {
            doc /* The system shall continuously monitor pressure, flow rate, 
                 * and seismic activity during all operational phases to 
                 * ensure safe operation and regulatory compliance.
                 */
            subject monitoring :>> system.monitoring;
        }
    }

    part fracturingSystemInstance : HydraulicFracturingSystem {
        attribute :>> operatingDepth = 2800.0;
        attribute :>> totalFluidVolume = 18000.0;
        attribute :>> targetInjectionPressure = 75000000.0;
        attribute :>> targetInjectionRate = 0.3;
        attribute :>> gasProductionRate = 0.15;
        attribute :>> operationalEfficiency = 0.88;
    }

    satisfy primaryMission by fracturingSystemInstance;
}

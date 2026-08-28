package 'Hydraulic Fracturing System' {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        item def RawMaterial;
        item def Water :> RawMaterial;
        item def Proppant :> RawMaterial {
            attribute meshSize : Real;
        }
        item def Chemical :> RawMaterial;
        item def FracturingFluid {
            attribute proppantConcentration : Real;
            attribute chemicalConcentration : Real;
        }
        item def NaturalGas;
        item def ProducedWater;
        item def GasWaterMixture {
            attribute gasFraction : Real;
            attribute waterFraction : Real;
        }

        attribute def PressureValue :> ISQ::PressureValue;
        attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
        attribute def VolumeValue :> ISQ::VolumeValue;
        attribute def MassValue :> ISQ::MassValue;
        attribute def LengthValue :> ISQ::LengthValue;
        attribute def TimeValue :> ISQ::TimeValue;
        attribute def SeismicIntensityValue :> Real;

        port def RawMaterialOutPort {
            out item material : RawMaterial;
        }
        port def RawMaterialInPort {
            in item material : RawMaterial;
        }
        port def FluidOutPort {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            out item fluid : FracturingFluid;
        }
        port def FluidInPort {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            in item fluid : FracturingFluid;
        }
        port def MixtureOutPort {
            out item mixture : GasWaterMixture;
        }
        port def MixtureInPort {
            in item mixture : GasWaterMixture;
        }
        port def GasOutPort {
            out item gas : NaturalGas;
        }
        port def GasInPort {
            in item gas : NaturalGas;
        }
        port def WaterOutPort {
            out item water : ProducedWater;
        }
        port def WaterInPort {
            in item water : ProducedWater;
        }
        port def MonitoringOutPort {
            out attribute pressureReading : PressureValue;
            out attribute flowReading : FlowRateValue;
            out attribute seismicReading : SeismicIntensityValue;
        }
        port def MonitoringInPort {
            in attribute pressureReading : PressureValue;
            in attribute flowReading : FlowRateValue;
            in attribute seismicReading : SeismicIntensityValue;
        }

        interface def FluidInterface {
            end supplierPort : FluidOutPort;
            end consumerPort : FluidInPort;
        }
        interface def RawMaterialInterface {
            end supplierPort : RawMaterialOutPort;
            end consumerPort : RawMaterialInPort;
        }
        interface def MixtureInterface {
            end supplierPort : MixtureOutPort;
            end consumerPort : MixtureInPort;
        }
        interface def MonitoringInterface {
            end sourcePort : MonitoringOutPort;
            end targetPort : MonitoringInPort;
        }

        action def BlendFluid {
            in water : Water;
            in proppant : Proppant;
            in chemical : Chemical;
            out fluid : FracturingFluid;
        }
        action def PressurizeFluid {
            in inputFluid : FracturingFluid;
            out outputFluid : FracturingFluid;
            attribute targetPressure : PressureValue;
        }
        action def InjectFluid {
            in inputFluid : FracturingFluid;
            out outputFluid : FracturingFluid;
        }
        action def FractureRock {
            in fluid : FracturingFluid;
            out mixture : GasWaterMixture;
        }
        action def SeparateMixture {
            in mixture : GasWaterMixture;
            out gas : NaturalGas;
            out water : ProducedWater;
        }
        action def MonitorConditions {
            in pressure : PressureValue;
            in flowRate : FlowRateValue;
            in seismic : SeismicIntensityValue;
        }

        part def WaterSource {
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
            port waterOut : RawMaterialOutPort;
        }
        part def ProppantStorage {
            attribute massCapacity : MassValue;
            attribute currentMass : MassValue;
            port proppantOut : RawMaterialOutPort;
        }
        part def ChemicalStorage {
            attribute volumeCapacity : VolumeValue;
            attribute currentVolume : VolumeValue;
            port chemicalOut : RawMaterialOutPort;
        }
        part def BlendingUnit {
            port waterIn : RawMaterialInPort;
            port proppantIn : RawMaterialInPort;
            port chemicalIn : RawMaterialInPort;
            port fluidOut : FluidOutPort;
            perform action blend : BlendFluid {
                in water = waterIn.material;
                in proppant = proppantIn.material;
                in chemical = chemicalIn.material;
                out fluid = fluidOut.fluid;
            }
        }
        part def HighPressurePump {
            attribute maxOperatingPressure : PressureValue;
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            perform action pressurize : PressurizeFluid {
                in inputFluid = fluidIn.fluid;
                out outputFluid = fluidOut.fluid;
            }
        }
        part def WellheadAssembly {
            attribute maxRatedPressure : PressureValue;
            port fluidIn : FluidInPort;
            port fluidOutDownhole : FluidOutPort;
            port mixtureInDownhole : MixtureInPort;
            port mixtureOut : MixtureOutPort;
            port monitorOut : MonitoringOutPort;
            perform action inject : InjectFluid {
                in inputFluid = fluidIn.fluid;
                out outputFluid = fluidOutDownhole.fluid;
            }
        }
        part def WellboreAssembly {
            attribute totalDepth : LengthValue;
            port fluidInTop : FluidInPort;
            port fluidOutPerforations : FluidOutPort;
            port mixtureInPerforations : MixtureInPort;
            port mixtureOutTop : MixtureOutPort;
            perform action transferDown : InjectFluid {
                in inputFluid = fluidInTop.fluid;
                out outputFluid = fluidOutPerforations.fluid;
            }
        }
        part def ShaleFormation {
            attribute formationDepth : LengthValue;
            attribute permeability : Real;
            port fluidIn : FluidInPort;
            port mixtureOut : MixtureOutPort;
            perform action fracture : FractureRock {
                in fluid = fluidIn.fluid;
                out mixture = mixtureOut.mixture;
            }
        }
        part def SeparationFacility {
            port mixtureIn : MixtureInPort;
            port gasOut : GasOutPort;
            port waterOut : WaterOutPort;
            perform action separate : SeparateMixture {
                in mixture = mixtureIn.mixture;
                out gas = gasOut.gas;
                out water = waterOut.water;
            }
        }
        part def GasCollectionPoint {
            port gasIn : GasInPort;
            attribute volumeCollected : VolumeValue;
        }
        part def WaterDisposalPoint {
            port waterIn : WaterInPort;
            attribute volumeDisposed : VolumeValue;
        }
        part def PressureSensor {
            attribute reading : PressureValue;
            port monitorOut : MonitoringOutPort;
        }
        part def FlowMeter {
            attribute reading : FlowRateValue;
            port monitorOut : MonitoringOutPort;
        }
        part def SeismicMonitor {
            attribute reading : SeismicIntensityValue;
            port monitorOut : MonitoringOutPort;
        }
        part def MonitoringSystem {
            port monitorIn : MonitoringInPort;
            attribute alarmThreshold : PressureValue;
            attribute alarmActive : Boolean;
            part pressureSensors : PressureSensor[*];
            part flowMeters : FlowMeter[*];
            part seismicMonitors : SeismicMonitor[*];
            perform action monitor : MonitorConditions {
                in pressure = monitorIn.pressureReading;
                in flowRate = monitorIn.flowReading;
                in seismic = monitorIn.seismicReading;
            }
        }

        state def OperationalState {
            state idle;
            state mixing;
            state pressurizing;
            state injecting;
            state soaking;
            state flowback;
            state gasProduction;
            transition from idle to mixing;
            transition from mixing to pressurizing;
            transition from pressurizing to injecting;
            transition from injecting to soaking;
            transition from soaking to flowback;
            transition from flowback to gasProduction;
            transition from gasProduction to idle;
        }

        requirement def MaxInjectionPressure {
            doc /* The injection pressure must not exceed the maximum safe operating pressure. */
            attribute maxPressure : PressureValue = 100000000;
        }
        requirement def RealTimeMonitoring {
            doc /* The system must continuously monitor pressure, flow rate, and seismic activity. */
            attribute monitoringInterval : TimeValue = 0.1;
        }
        requirement def FractureDepthTarget {
            doc /* The system must fracture the shale formation at the target depth. */
            attribute targetDepth : LengthValue = 2500;
        }
        requirement def EnvironmentalSafety {
            doc /* The system must prevent fracturing fluid migration beyond the target shale formation. */
            attribute maxFractureHeight : LengthValue = 100;
        }
    }

    package Usages {
        private import Definitions::*;

        part frackingSystem {
            attribute systemName : String;

            part waterSource : WaterSource;
            part proppantStorage : ProppantStorage;
            part chemicalStorage : ChemicalStorage;
            part blendingUnit : BlendingUnit;
            part highPressurePump : HighPressurePump;
            part wellhead : WellheadAssembly;
            part wellbore : WellboreAssembly;
            part shaleFormation : ShaleFormation;
            part separationFacility : SeparationFacility;
            part gasCollection : GasCollectionPoint;
            part waterDisposal : WaterDisposalPoint;
            part monitoringSystem : MonitoringSystem;

            interface : RawMaterialInterface connect
                supplierPort ::> waterSource.waterOut to
                consumerPort ::> blendingUnit.waterIn;
            interface : RawMaterialInterface connect
                supplierPort ::> proppantStorage.proppantOut to
                consumerPort ::> blendingUnit.proppantIn;
            interface : RawMaterialInterface connect
                supplierPort ::> chemicalStorage.chemicalOut to
                consumerPort ::> blendingUnit.chemicalIn;
            interface : FluidInterface connect
                supplierPort ::> blendingUnit.fluidOut to
                consumerPort ::> highPressurePump.fluidIn;
            interface : FluidInterface connect
                supplierPort ::> highPressurePump.fluidOut to
                consumerPort ::> wellhead.fluidIn;
            interface : FluidInterface connect
                supplierPort ::> wellhead.fluidOutDownhole to
                consumerPort ::> wellbore.fluidInTop;
            interface : FluidInterface connect
                supplierPort ::> wellbore.fluidOutPerforations to
                consumerPort ::> shaleFormation.fluidIn;
            interface : MixtureInterface connect
                supplierPort ::> shaleFormation.mixtureOut to
                consumerPort ::> wellbore.mixtureInPerforations;
            interface : MixtureInterface connect
                supplierPort ::> wellbore.mixtureOutTop to
                consumerPort ::> wellhead.mixtureInDownhole;
            interface : MixtureInterface connect
                supplierPort ::> wellhead.mixtureOut to
                consumerPort ::> separationFacility.mixtureIn;
            interface : MonitoringInterface connect
                sourcePort ::> wellhead.monitorOut to
                targetPort ::> monitoringSystem.monitorIn;

            flow of water : Water
                from waterSource.waterOut.material to blendingUnit.waterIn.material;
            flow of proppant : Proppant
                from proppantStorage.proppantOut.material to blendingUnit.proppantIn.material;
            flow of chemical : Chemical
                from chemicalStorage.chemicalOut.material to blendingUnit.chemicalIn.material;
            flow of fracturingFluid : FracturingFluid
                from blendingUnit.fluidOut.fluid to highPressurePump.fluidIn.fluid;
            flow of fracturingFluid : FracturingFluid
                from highPressurePump.fluidOut.fluid to wellhead.fluidIn.fluid;
            flow of fracturingFluid : FracturingFluid
                from wellhead.fluidOutDownhole.fluid to wellbore.fluidInTop.fluid;
            flow of fracturingFluid : FracturingFluid
                from wellbore.fluidOutPerforations.fluid to shaleFormation.fluidIn.fluid;
            flow of mixture : GasWaterMixture
                from shaleFormation.mixtureOut.mixture to wellbore.mixtureInPerforations.mixture;
            flow of mixture : GasWaterMixture
                from wellbore.mixtureOutTop.mixture to wellhead.mixtureInDownhole.mixture;
            flow of mixture : GasWaterMixture
                from wellhead.mixtureOut.mixture to separationFacility.mixtureIn.mixture;
            flow of naturalGas : NaturalGas
                from separationFacility.gasOut.gas to gasCollection.gasIn.gas;
            flow of producedWater : ProducedWater
                from separationFacility.waterOut.water to waterDisposal.waterIn.water;

            state operationalState : OperationalState;

            satisfy MaxInjectionPressure by highPressurePump;
            satisfy RealTimeMonitoring by monitoringSystem;
            satisfy FractureDepthTarget by shaleFormation;
            satisfy EnvironmentalSafety by wellbore;
        }
    }
}

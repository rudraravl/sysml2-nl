package EductorJetPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package ValueTypes {
        attribute def PressureValue :> Real;
        attribute def VolumeFlowRateValue :> Real;
        attribute def VelocityValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def DensityValue :> Real;
        attribute def EfficiencyValue :> Real;
        attribute def LengthValue :> Real;
        attribute def AngleValue :> Real;
    }
    
    package Definitions {
        private import ValueTypes::*;
        
        item def Fluid {
            attribute density : DensityValue;
            attribute temperature : TemperatureValue;
            attribute viscosity : Real;
        }
        
        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute velocity : VelocityValue;
            out item fluid : Fluid;
        }
        
        port def MotivePort :> FluidPort {
            doc /* High-pressure motive fluid inlet */
        }
        
        port def SuctionPort :> FluidPort {
            doc /* Low-pressure suction fluid inlet */
        }
        
        port def DischargePort :> FluidPort {
            doc /* Mixed discharge fluid outlet */
        }
        
        part def ConvergingNozzle {
            doc /* Accelerates motive fluid by converting pressure to velocity */
            
            port inlet : ~MotivePort;
            port outlet : FluidPort;
            
            attribute throatDiameter : LengthValue;
            attribute convergenceAngle : AngleValue;
            attribute nozzleEfficiency : EfficiencyValue;
            
            perform action accelerateMotiveFluid {
                in motiveFluid : Fluid = inlet.fluid;
                out jetFluid : Fluid = outlet.fluid;
                
                assert constraint velocityIncrease {
                    outlet.velocity > inlet.velocity
                }
                assert constraint pressureDecrease {
                    outlet.pressure < inlet.pressure
                }
            }
        }
        
        part def SuctionChamber {
            doc /* Low-pressure zone where suction fluid is entrained by high-velocity jet */
            
            port suctionInlet : ~SuctionPort;
            port jetInlet : ~FluidPort;
            port mixedOutlet : FluidPort;
            
            attribute chamberDiameter : LengthValue;
            attribute chamberLength : LengthValue;
            
            perform action entrainSuctionFluid {
                in suctionFluid : Fluid = suctionInlet.fluid;
                in jetFluid : Fluid = jetInlet.fluid;
                out entrainedFluid : Fluid = mixedOutlet.fluid;
                
                assert constraint lowPressureZone {
                    doc /* Jet creates low pressure zone that draws in suction fluid */
                    mixedOutlet.pressure < suctionInlet.pressure
                }
            }
        }
        
        part def MixingThroat {
            doc /* Mixes motive and suction fluids through momentum transfer */
            
            port inlet : ~FluidPort;
            port outlet : FluidPort;
            
            attribute throatDiameter : LengthValue;
            attribute throatLength : LengthValue;
            attribute mixingEfficiency : EfficiencyValue;
            
            perform action mixFluids {
                in combinedFluid : Fluid = inlet.fluid;
                out homogenizedFluid : Fluid = outlet.fluid;
                
                assert constraint momentumTransfer {
                    doc /* Momentum from motive fluid transfers to suction fluid */
                    outlet.velocity > 0.0
                }
            }
        }
        
        part def DivergingDiffuser {
            doc /* Converts kinetic energy back to pressure energy */
            
            port inlet : ~FluidPort;
            port outlet : DischargePort;
            
            attribute divergenceAngle : AngleValue;
            attribute diffuserLength : LengthValue;
            attribute diffuserEfficiency : EfficiencyValue;
            
            perform action recoverPressure {
                in mixedFluid : Fluid = inlet.fluid;
                out dischargeFluid : Fluid = outlet.fluid;
                
                assert constraint pressureRecovery {
                    outlet.pressure > inlet.pressure
                }
                assert constraint velocityDecrease {
                    outlet.velocity < inlet.velocity
                }
            }
        }
        
        part def EductorJetPump {
            doc /* 
             * Eductor-jet pump uses high-pressure motive fluid to entrain 
             * and pump low-pressure suction fluid via momentum transfer.
             * No moving parts - operates on Venturi principle.
             */
            
            port motiveInlet : ~MotivePort;
            port suctionInlet : ~SuctionPort;
            port dischargeOutlet : DischargePort;
            
            part nozzle : ConvergingNozzle;
            part suctionChamber : SuctionChamber;
            part mixingThroat : MixingThroat;
            part diffuser : DivergingDiffuser;
            
            attribute overallEfficiency : EfficiencyValue;
            attribute compressionRatio : Real;
            attribute flowRatio : Real;
            
            flow of motiveFluid : Fluid
                from motiveInlet.fluid to nozzle.inlet.fluid;
            
            flow of acceleratedFluid : Fluid
                from nozzle.outlet.fluid to suctionChamber.jetInlet.fluid;
            
            flow of suctionFluid : Fluid
                from suctionInlet.fluid to suctionChamber.suctionInlet.fluid;
            
            flow of entrainedFluid : Fluid
                from suctionChamber.mixedOutlet.fluid to mixingThroat.inlet.fluid;
            
            flow of mixedFluid : Fluid
                from mixingThroat.outlet.fluid to diffuser.inlet.fluid;
            
            flow of dischargeFluid : Fluid
                from diffuser.outlet.fluid to dischargeOutlet.fluid;
            
            assert constraint massConservation {
                doc /* Total mass flow in equals total mass flow out */
                motiveInlet.flowRate + suctionInlet.flowRate == dischargeOutlet.flowRate
            }
            
            assert constraint energyBalance {
                doc /* Energy input from motive fluid must exceed discharge energy */
                motiveInlet.pressure * motiveInlet.flowRate >= 
                dischargeOutlet.pressure * dischargeOutlet.flowRate
            }
            
            assert constraint compressionCapability {
                doc /* Discharge pressure must exceed suction pressure */
                dischargeOutlet.pressure > suctionInlet.pressure
            }
        }
        
        part def MotiveFluidSource {
            doc /* High-pressure fluid source (pump or pressurized vessel) */
            
            port outlet : MotivePort;
            
            attribute sourcePressure : PressureValue;
            attribute maxFlowRate : VolumeFlowRateValue;
            
            item motiveFluid : Fluid;
        }
        
        part def SuctionFluidReservoir {
            doc /* Low-pressure fluid reservoir to be pumped */
            
            port outlet : SuctionPort;
            
            attribute reservoirPressure : PressureValue;
            attribute fluidLevel : LengthValue;
            
            item suctionFluid : Fluid;
        }
        
        part def DischargeDestination {
            doc /* Destination for pumped fluid */
            
            port inlet : ~DischargePort;
            
            attribute destinationPressure : PressureValue;
            attribute receivedVolume : Real;
            
            item receivedFluid : Fluid;
        }
        
        action def StartPumping {
            doc /* Initiate pumping operation */
            in motiveSupplyPressure : PressureValue;
            out pumpingStarted : Boolean;
        }
        
        action def MonitorOperation {
            doc /* Monitor pumping performance */
            in dischargeFlowRate : VolumeFlowRateValue;
            in dischargePressure : PressureValue;
            out operatingNormally : Boolean;
        }
        
        action def StopPumping {
            doc /* Terminate pumping operation */
            out pumpingStopped : Boolean;
        }
        
        action def PumpingCycle {
            doc /* Complete pumping operation cycle */
            
            first start;
            then action startPump : StartPumping {
                in motiveSupplyPressure;
                out pumpingStarted;
            }
            then merge continuePumping;
            then action monitor : MonitorOperation {
                in dischargeFlowRate;
                in dischargePressure;
                out operatingNormally;
            }
            then decide;
                if monitor.operatingNormally then continuePumping;
                if !monitor.operatingNormally then stopPump;
            action stopPump : StopPumping {
                out pumpingStopped;
            }
            then done;
            
            attribute motiveSupplyPressure : PressureValue;
            attribute dischargeFlowRate : VolumeFlowRateValue;
            attribute dischargePressure : PressureValue;
        }
        
        attribute def StartCommand;
        attribute def StopCommand;
        
        state def EductorOperatingStates {
            doc /* Operating states of eductor-jet pump */
            
            entry; then idle;
            
            state idle {
                doc /* No flow, system at rest */
            }
            
            transition idle_to_starting
                first idle
                accept at startTime : StartCommand
                then starting;
            
            state starting {
                doc /* Establishing motive flow */
                entry action establishMotiveFlow;
            }
            
            transition starting_to_operating
                first starting
                if motiveFlowEstablished
                then operating;
            
            state operating {
                doc /* Normal pumping operation */
                
                state steadyFlow {
                    doc /* Stable flow conditions */
                }
                
                state fluctuating {
                    doc /* Flow rate or pressure fluctuating */
                }
                
                transition steadyFlow_to_fluctuating
                    first steadyFlow
                    if flowInstability
                    then fluctuating;
                
                transition fluctuating_to_steadyFlow
                    first fluctuating
                    if flowStabilized
                    then steadyFlow;
            }
            
            transition operating_to_stopping
                first operating
                accept at stopTime : StopCommand
                then stopping;
            
            state stopping {
                doc /* Controlled shutdown */
                entry action closeMotiveSupply;
            }
            
            transition stopping_to_idle
                first stopping
                if flowStopped
                then idle;
            
            attribute motiveFlowEstablished : Boolean;
            attribute flowInstability : Boolean;
            attribute flowStabilized : Boolean;
            attribute flowStopped : Boolean;
        }
        
        requirement def EductorPerformanceRequirement {
            doc /* Performance requirements for eductor-jet pump subsystem */
            
            subject pump : EductorJetPump;
            
            require minimumSuctionFlowRate {
                doc /* Minimum suction flow rate requirement */
                assume motiveFlowRate : VolumeFlowRateValue;
                assume suctionFlowRate : VolumeFlowRateValue;
                
                assert constraint { suctionFlowRate >= 0.02 }
            }
            
            require minimumDischargePressure {
                doc /* Discharge pressure must exceed suction pressure */
                assume suctionPressure : PressureValue;
                assume dischargePressure : PressureValue;
                
                assert constraint { dischargePressure >= suctionPressure * 1.2 }
            }
            
            require minimumEfficiency {
                doc /* Minimum overall pumping efficiency */
                assert constraint { pump.overallEfficiency >= 0.25 }
            }
            
            require continuousOperation {
                doc /* System must operate continuously without cavitation */
                assume motiveSupplyPressure : PressureValue;
                
                assert constraint { motiveSupplyPressure >= 300000.0 }
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part eductorPumpingSystem {
            doc /* Complete eductor-jet pumping subsystem */
            
            part motiveSource : MotiveFluidSource {
                attribute :>> sourcePressure = 500000.0;
                attribute :>> maxFlowRate = 0.015;
                
                item :>> motiveFluid : Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> temperature = 293.15;
                    attribute :>> viscosity = 0.001;
                }
            }
            
            flow of motiveFluid : Fluid
                from motiveSource.outlet.fluid to eductorPump.motiveInlet.fluid;
            
            part suctionReservoir : SuctionFluidReservoir {
                attribute :>> reservoirPressure = 101325.0;
                attribute :>> fluidLevel = 2.5;
                
                item :>> suctionFluid : Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> temperature = 293.15;
                    attribute :>> viscosity = 0.001;
                }
            }
            
            flow of suctionFluid : Fluid
                from suctionReservoir.outlet.fluid to eductorPump.suctionInlet.fluid;
            
            part eductorPump : EductorJetPump {
                attribute :>> overallEfficiency = 0.30;
                attribute :>> compressionRatio = 1.5;
                attribute :>> flowRatio = 3.0;
                
                part :>> nozzle {
                    attribute :>> throatDiameter = 0.012;
                    attribute :>> convergenceAngle = 20.0;
                    attribute :>> nozzleEfficiency = 0.95;
                }
                
                part :>> suctionChamber {
                    attribute :>> chamberDiameter = 0.040;
                    attribute :>> chamberLength = 0.080;
                }
                
                part :>> mixingThroat {
                    attribute :>> throatDiameter = 0.025;
                    attribute :>> throatLength = 0.150;
                    attribute :>> mixingEfficiency = 0.85;
                }
                
                part :>> diffuser {
                    attribute :>> divergenceAngle = 8.0;
                    attribute :>> diffuserLength = 0.300;
                    attribute :>> diffuserEfficiency = 0.80;
                }
                
                perform action pumpingCycle : PumpingCycle {
                    attribute :>> motiveSupplyPressure = motiveInlet.pressure;
                    attribute :>> dischargeFlowRate = dischargeOutlet.flowRate;
                    attribute :>> dischargePressure = dischargeOutlet.pressure;
                }
                
                exhibit state operatingState : EductorOperatingStates;
            }
            
            flow of dischargeFluid : Fluid
                from eductorPump.dischargeOutlet.fluid to destination.inlet.fluid;
            
            part destination : DischargeDestination {
                attribute :>> destinationPressure = 150000.0;
                attribute :>> receivedVolume = 0.0;
                
                item :>> receivedFluid : Fluid {
                    attribute :>> density = 1000.0;
                    attribute :>> temperature = 293.15;
                    attribute :>> viscosity = 0.001;
                }
            }
            
            satisfy performanceRequirement : EductorPerformanceRequirement {
                subject pump = eductorPump;
            }
        }
    }
}

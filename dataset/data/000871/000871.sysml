package ElectroosmoticPumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        
        attribute def VoltageValue :> Real;
        attribute def FlowRateValue :> Real;
        attribute def PressureValue :> Real;
        attribute def LengthValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def ConductivityValue :> Real;
        
        item def Fluid {
            attribute ionicStrength : Real;
            attribute pH : Real;
            attribute conductivity : ConductivityValue;
            attribute volume : VolumeValue;
        }
        
        port def FluidPort {
            out item fluid : Fluid;
            attribute pressure : PressureValue;
        }
        
        port def ElectricalPort {
            attribute voltage : VoltageValue;
            attribute current : Real;
        }
        
        part def Reservoir {
            port outlet : FluidPort;
            attribute capacity : VolumeValue;
            attribute currentVolume : VolumeValue;
            item storedFluid : Fluid;
        }
        
        part def Microchannel {
            port inlet : ~FluidPort;
            port outlet : FluidPort;
            attribute length : LengthValue;
            attribute width : LengthValue;
            attribute height : LengthValue;
            attribute zetaPotential : VoltageValue;
        }
        
        part def Electrode {
            port electricalConnection : ~ElectricalPort;
            attribute material : String;
            attribute position : String;
        }
        
        part def ElectroosmoticPump {
            port fluidIn : ~FluidPort;
            port fluidOut : FluidPort;
            port powerIn : ~ElectricalPort;
            
            part channel : Microchannel;
            part anode : Electrode {
                attribute :>> material = "Platinum";
                attribute :>> position = "inlet";
            }
            part cathode : Electrode {
                attribute :>> material = "Platinum";
                attribute :>> position = "outlet";
            }
            
            attribute appliedVoltage : VoltageValue;
            attribute electricField : Real;
            attribute electroosmoticMobility : Real;
            attribute flowRate : FlowRateValue;
            attribute backPressure : PressureValue;
            
            bind powerIn.voltage = appliedVoltage;
            
            flow from fluidIn.fluid to channel.inlet.fluid;
            flow from channel.outlet.fluid to fluidOut.fluid;
            
            perform action pumpOperation : PumpFluidAction {
                in inputFluid = fluidIn.fluid;
                in voltage = powerIn.voltage;
                out outputFluid = fluidOut.fluid;
            }
            
            exhibit state operatingState : PumpStateMachine;
        }
        
        part def PowerSupply {
            port output : ElectricalPort;
            attribute outputVoltage : VoltageValue;
            attribute maxCurrent : Real;
            attribute isEnabled : Boolean;
        }
        
        part def CollectionChamber {
            port inlet : ~FluidPort;
            attribute capacity : VolumeValue;
            attribute collectedVolume : VolumeValue;
            item collectedFluid : Fluid;
        }
        
        part def FlowSensor {
            attribute measuredFlowRate : FlowRateValue;
        }
        
        part def PressureSensor {
            attribute measuredPressure : PressureValue;
        }
        
        action def PumpFluidAction {
            in inputFluid : Fluid;
            in voltage : VoltageValue;
            out outputFluid : Fluid;
            
            first start;
            then action applyElectricField {
                in appliedVoltage = voltage;
            }
            then action induceElectroosmoticFlow {
                in fluid = inputFluid;
                in field = applyElectricField.appliedVoltage;
            }
            then action transportFluid {
                in flowingFluid = induceElectroosmoticFlow.fluid;
                out pumpedFluid = outputFluid;
            }
            then done;
        }
        
        state def PumpStateMachine {
            entry; then idle;
            
            state idle {
                entry action initializeSystem;
            }
            
            transition idle_to_priming
                first idle
                accept at startTime
                then priming;
            
            state priming {
                entry action fillChannel;
                do action checkChannelFilled;
            }
            
            transition priming_to_operating
                first priming
                accept at channelFilledTime
                then operating;
            
            state operating {
                entry action enablePower;
                do action maintainFlow;
                
                state normalOperation {
                    entry action setNominalVoltage;
                }
                
                state highFlowMode {
                    entry action increaseVoltage;
                }
                
                state lowFlowMode {
                    entry action decreaseVoltage;
                }
                
                transition normalToHigh
                    first normalOperation
                    accept at increaseFlowTime
                    then highFlowMode;
                
                transition normalToLow
                    first normalOperation
                    accept at decreaseFlowTime
                    then lowFlowMode;
                
                transition highToNormal
                    first highFlowMode
                    accept at normalizeTime
                    then normalOperation;
            }
            
            transition operating_to_idle
                first operating
                accept at stopTime
                then idle;
            
            transition operating_to_fault
                first operating
                accept at faultTime
                then fault;
            
            state fault {
                entry action disablePower;
                entry action logFault;
            }
            
            transition fault_to_idle
                first fault
                accept at resetTime
                then idle;
        }
        
        requirement def FlowRateRequirement {
            subject pump : ElectroosmoticPump;
            doc /* The electroosmotic pump shall deliver a minimum flow rate 
                 * of 1.0 mL/min at nominal operating voltage. */
            
            require constraint {
                pump.flowRate >= 1.0
            }
        }
        
        requirement def VoltageRangeRequirement {
            subject pump : ElectroosmoticPump;
            doc /* The electroosmotic pump shall operate within a voltage range 
                 * of 10V to 100V. */
            
            require constraint {
                pump.appliedVoltage >= 10.0 and
                pump.appliedVoltage <= 100.0
            }
        }
        
        requirement def PressureCapabilityRequirement {
            subject pump : ElectroosmoticPump;
            doc /* The electroosmotic pump shall generate sufficient pressure 
                 * to overcome back pressure up to 50 kPa. */
            
            require constraint {
                pump.backPressure <= 50.0
            }
        }
        
        requirement def SystemReliabilityRequirement {
            subject subsystem : PumpingSubsystem;
            doc /* The pumping subsystem shall operate continuously for at least 
                 * 500 hours without failure. */
            
            attribute minimumOperatingHours : Real = 500.0;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part pumpingSubsystem : PumpingSubsystem {
            
            part sourceReservoir : Reservoir {
                attribute :>> capacity = 500.0;
                attribute :>> currentVolume = 500.0;
                item :>> storedFluid : Fluid {
                    attribute :>> ionicStrength = 0.01;
                    attribute :>> pH = 7.4;
                    attribute :>> conductivity = 1.2;
                    attribute :>> volume = 500.0;
                }
            }
            
            flow of fluid : Fluid
                from sourceReservoir.outlet.fluid
                to eoPump.fluidIn.fluid;
            
            part eoPump : ElectroosmoticPump {
                attribute :>> appliedVoltage = 50.0;
                attribute :>> electricField = 1000.0;
                attribute :>> electroosmoticMobility = 4.5e-8;
                attribute :>> flowRate = 2.0;
                attribute :>> backPressure = 30.0;
                
                part :>> channel {
                    attribute :>> length = 50.0;
                    attribute :>> width = 0.5;
                    attribute :>> height = 0.1;
                    attribute :>> zetaPotential = -45.0;
                }
            }
            
            flow of fluid : Fluid
                from eoPump.fluidOut.fluid
                to collectionChamber.inlet.fluid;
            
            part powerSupply : PowerSupply {
                attribute :>> outputVoltage = 50.0;
                attribute :>> maxCurrent = 0.1;
                attribute :>> isEnabled = true;
            }
            
            bind powerSupply.output.voltage = eoPump.powerIn.voltage;
            
            part collectionChamber : CollectionChamber {
                attribute :>> capacity = 500.0;
                attribute :>> collectedVolume = 0.0;
            }
            
            part flowSensor : FlowSensor {
                attribute :>> measuredFlowRate = 2.0;
            }
            
            part pressureSensor : PressureSensor {
                attribute :>> measuredPressure = 30.0;
            }
            
            satisfy flowReq : FlowRateRequirement by eoPump;
            satisfy voltageReq : VoltageRangeRequirement by eoPump;
            satisfy pressureReq : PressureCapabilityRequirement by eoPump;
            satisfy reliabilityReq : SystemReliabilityRequirement by pumpingSubsystem;
            
            assert constraint FlowRateMeetsTarget {
                eoPump.flowRate >= 1.0
            }
            
            assert constraint VoltageWithinLimits {
                eoPump.appliedVoltage >= 10.0 and
                eoPump.appliedVoltage <= 100.0
            }
        }
        
        part def PumpingSubsystem;
    }
}

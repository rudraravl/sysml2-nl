package 'HighDensitySolidsPumpingSubsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def Slurry {
            attribute density : MassDensityValue;
            attribute viscosity : DynamicViscosityValue;
            attribute solidsFraction : Real;
            attribute particleSize : LengthValue;
            attribute temperature : TemperatureValue;
            
            assert constraint { solidsFraction >= 0.0 and solidsFraction <= 1.0 }
        }
        
        item def HighDensitySlurry :> Slurry {
            assert constraint { solidsFraction >= 0.30 }
            assert constraint { density.num >= 1400.0 }
        }
        
        port def FluidPort {
            out item slurryOut : Slurry;
            attribute flowRate : VolumeFlowRateValue;
            attribute pressure : PressureValue;
        }
        
        port def FluidInPort {
            in item slurryIn : Slurry;
            attribute flowRate : VolumeFlowRateValue;
            attribute pressure : PressureValue;
        }
        
        part def SupplyTank {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            port outletPort : FluidPort;
            
            item storedSlurry : HighDensitySlurry {
                attribute volume : VolumeValue;
            }
            
            assert constraint { currentLevel.num <= capacity.num }
            assert constraint { currentLevel.num >= 0.0 }
        }
        
        part def HighDensitySolidsPump {
            comment
                /*
                Positive displacement pump designed for handling high-density slurries
                with significant solid content. Features wear-resistant components.
                */
            
            attribute ratedFlowRate : VolumeFlowRateValue;
            attribute maxDischargePressure : PressureValue;
            attribute motorPower : PowerValue;
            attribute efficiency : Real;
            attribute impellerSpeed : Real;
            
            port suctionPort : FluidInPort;
            port dischargePort : FluidPort;
            port powerInput;
            
            perform action pumpingOperation : PumpSlurry;
        }
        
        part def DischargeTank {
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            port inletPort : FluidInPort;
            
            item receivedSlurry : HighDensitySlurry {
                attribute volume : VolumeValue;
            }
            
            assert constraint { currentLevel.num <= capacity.num }
        }
        
        part def PressureSensor {
            attribute reading : PressureValue;
            attribute accuracy : Real;
            port measurementPort;
        }
        
        part def FlowSensor {
            attribute reading : VolumeFlowRateValue;
            attribute totalVolume : VolumeValue;
            port measurementPort;
        }
        
        part def Valve {
            attribute position : Real;
            attribute maxFlowCoefficient : Real;
            port inletPort : FluidInPort;
            port outletPort : FluidPort;
            
            assert constraint { position >= 0.0 and position <= 1.0 }
        }
        
        part def Piping {
            attribute length : LengthValue;
            attribute diameter : LengthValue;
            attribute roughness : Real;
            port inletPort : FluidInPort;
            port outletPort : FluidPort;
        }
        
        action def PumpSlurry {
            in slurryIn : HighDensitySlurry;
            in powerIn : PowerValue;
            out slurryOut : HighDensitySlurry;
            out pressureIncrease : PressureValue;
        }
        
        action def MonitorPumpCondition {
            in vibration : Real;
            in temperature : TemperatureValue;
            in suctionPressure : PressureValue;
            in dischargePressure : PressureValue;
            out status : PumpStatus;
        }
        
        enum def PumpStatus {
            enum operational;
            enum degraded;
            enum fault;
            enum emergency;
        }
        
        requirement def PumpingSubsystemRequirements {
            doc
                /*
                Requirements for high-density solids pumping subsystem operation
                */
            
            requirement flowCapabilityRequirement {
                doc /* Subsystem shall maintain minimum flow rate */
                subject subsystem : PumpingSubsystem;
                require constraint {
                    subsystem.pump.dischargePort.flowRate.num >= 60.0
                }
            }
            
            requirement pressureCapabilityRequirement {
                doc /* Subsystem shall achieve required discharge pressure */
                subject subsystem : PumpingSubsystem;
                require constraint {
                    subsystem.pump.dischargePort.pressure.num >= 600000.0
                }
            }
            
            requirement solidsHandlingRequirement {
                doc /* Subsystem shall handle high-density slurries */
                subject slurry : HighDensitySlurry;
                require constraint {
                    slurry.solidsFraction >= 0.35 and slurry.solidsFraction <= 0.70
                }
            }
            
            requirement efficiencyRequirement {
                doc /* Pump shall operate at minimum efficiency */
                subject pump : HighDensitySolidsPump;
                require constraint {
                    pump.efficiency >= 0.68
                }
            }
            
            requirement safetyRequirement {
                doc /* Subsystem shall not exceed maximum pressure */
                subject subsystem : PumpingSubsystem;
                require constraint {
                    subsystem.dischargePressureSensor.reading.num <= 
                    subsystem.pump.maxDischargePressure.num
                }
            }
        }
        
        interface def FluidTransferInterface {
            end port source : FluidPort;
            end port destination : FluidInPort;
        }
    }
    
    package Usages {
        part def PumpingSubsystem {
            
            part supplyTank : SupplyTank;
            part suctionPipe : Piping;
            part suctionValve : Valve;
            part pump : HighDensitySolidsPump;
            part suctionPressureSensor : PressureSensor;
            part dischargePipe : Piping;
            part dischargePressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part dischargeValve : Valve;
            part deliveryPipe : Piping;
            part dischargeTank : DischargeTank;
            
            flow suctionFlow : FluidTransferInterface
                from supplyTank.outletPort.slurryOut
                to suctionPipe.inletPort.slurryIn;
            
            flow suctionValveFlow : FluidTransferInterface
                from suctionPipe.outletPort.slurryOut
                to suctionValve.inletPort.slurryIn;
            
            flow pumpSuctionFlow : FluidTransferInterface
                from suctionValve.outletPort.slurryOut
                to pump.suctionPort.slurryIn;
            
            flow dischargeFlow : FluidTransferInterface
                from pump.dischargePort.slurryOut
                to dischargePipe.inletPort.slurryIn;
            
            flow dischargeValveFlow : FluidTransferInterface
                from dischargePipe.outletPort.slurryOut
                to dischargeValve.inletPort.slurryIn;
            
            flow deliveryFlow : FluidTransferInterface
                from dischargeValve.outletPort.slurryOut
                to deliveryPipe.inletPort.slurryIn;
            
            flow destinationFlow : FluidTransferInterface
                from deliveryPipe.outletPort.slurryOut
                to dischargeTank.inletPort.slurryIn;
            
            bind suctionPressureSensor.reading = pump.suctionPort.pressure;
            bind dischargePressureSensor.reading = pump.dischargePort.pressure;
            bind flowSensor.reading = pump.dischargePort.flowRate;
            
            action monitorCondition : MonitorPumpCondition;
            
            state pumpOperatingStates {
                entry; then stopped;
                
                state stopped;
                
                transition stopped_to_starting
                    first stopped
                    accept StartSignal
                    then starting;
                
                state starting;
                
                transition starting_to_operating
                    first starting
                    accept OperatingSpeed
                    then operating;
                
                state operating {
                    do action transferSlurry : PumpSlurry;
                }
                
                transition operating_to_stopping
                    first operating
                    accept StopSignal
                    then stopping;
                
                transition operating_to_fault
                    first operating
                    accept FaultDetected
                    then faulted;
                
                state stopping;
                
                transition stopping_to_stopped
                    first stopping
                    accept FullyStopped
                    then stopped;
                
                state faulted;
                
                transition fault_to_stopped
                    first faulted
                    accept ResetSignal
                    then stopped;
            }
            
            satisfy requirements : PumpingSubsystemRequirements;
        }
        
        part pumpingSubsystem : PumpingSubsystem {
            
            part :>> supplyTank {
                attribute :>> capacity = 12.0;
                attribute :>> currentLevel = 9.5;
                
                item :>> storedSlurry {
                    attribute :>> volume = 9.5;
                    attribute :>> density = 1720.0;
                    attribute :>> solidsFraction = 0.52;
                    attribute :>> particleSize = 0.008;
                    attribute :>> viscosity = 180.0;
                    attribute :>> temperature = 293.15;
                }
            }
            
            part :>> suctionPipe {
                attribute :>> length = 6.0;
                attribute :>> diameter = 0.20;
                attribute :>> roughness = 0.00020;
            }
            
            part :>> suctionValve {
                attribute :>> position = 1.0;
                attribute :>> maxFlowCoefficient = 150.0;
            }
            
            part :>> pump {
                attribute :>> ratedFlowRate = 80.0;
                attribute :>> maxDischargePressure = 850000.0;
                attribute :>> motorPower = 65000.0;
                attribute :>> efficiency = 0.74;
                attribute :>> impellerSpeed = 1200.0;
                
                perform action :>> pumpingOperation {
                    in :>> slurryIn = suctionPort.slurryIn;
                    in :>> powerIn = motorPower;
                    out :>> slurryOut = dischargePort.slurryOut;
                }
            }
            
            part :>> suctionPressureSensor {
                attribute :>> accuracy = 0.015;
            }
            
            part :>> dischargePipe {
                attribute :>> length = 18.0;
                attribute :>> diameter = 0.15;
                attribute :>> roughness = 0.00020;
            }
            
            part :>> dischargePressureSensor {
                attribute :>> accuracy = 0.015;
            }
            
            part :>> flowSensor {
                attribute :>> totalVolume = 0.0;
            }
            
            part :>> dischargeValve {
                attribute :>> position = 0.90;
                attribute :>> maxFlowCoefficient = 120.0;
            }
            
            part :>> deliveryPipe {
                attribute :>> length = 30.0;
                attribute :>> diameter = 0.15;
                attribute :>> roughness = 0.00020;
            }
            
            part :>> dischargeTank {
                attribute :>> capacity = 18.0;
                attribute :>> currentLevel = 4.5;
                
                item :>> receivedSlurry {
                    attribute :>> volume = 4.5;
                    attribute :>> density = 1720.0;
                    attribute :>> solidsFraction = 0.52;
                    attribute :>> particleSize = 0.008;
                    attribute :>> viscosity = 180.0;
                    attribute :>> temperature = 293.15;
                }
            }
            
            action :>> monitorCondition {
                in vibration = 3.2;
                in temperature = 318.15;
                in suctionPressure = suctionPressureSensor.reading;
                in dischargePressure = dischargePressureSensor.reading;
            }
        }
    }
}

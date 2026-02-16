package AldgatePumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        attribute def MassPerVolumeValue :> Real;
        attribute def VolumePerTimeValue :> Real;
        
        item def Fluid {
            attribute density : MassPerVolumeValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volume : VolumeValue;
        }
        
        port def FluidPort {
            out item fluid : Fluid;
        }
        
        part def AldgatePump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            
            attribute ratedFlowRate : VolumePerTimeValue;
            attribute operatingPressure : PressureValue;
            attribute powerConsumption : PowerValue;
            attribute efficiency : Real;
            attribute isRunning : Boolean;
            
            part motor {
                attribute speed : AngularVelocityValue;
                attribute power : PowerValue;
            }
            
            part impeller {
                attribute diameter : LengthValue;
            }
        }
        
        part def SourceTank {
            port fluidOutPort : FluidPort;
            
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute minOperatingLevel : VolumeValue;
            
            item storedFluid : Fluid {
                attribute :>> volume;
            }
        }
        
        part def DestinationTank {
            port fluidInPort : ~FluidPort;
            
            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute maxOperatingLevel : VolumeValue;
            
            item receivedFluid : Fluid {
                attribute :>> volume;
            }
        }
        
        part def FlowSensor {
            attribute flowRate : VolumePerTimeValue;
            attribute totalVolumeTransferred : VolumeValue;
        }
        
        part def PressureSensor {
            attribute pressureReading : PressureValue;
        }
        
        action def TransferFluid {
            in fluidIn : Fluid;
            out fluidOut : Fluid;
        }
        
        action def StartPump {
            in pump : AldgatePump;
        }
        
        action def StopPump {
            in pump : AldgatePump;
        }
        
        action def MonitorFlow {
            in sensor : FlowSensor;
            out currentFlow : VolumePerTimeValue;
        }
        
        requirement def PumpingSubsystemRequirements {
            doc /* The pumping subsystem shall reliably transfer fluid from source to destination */
            
            subject subsystem : PumpingSubsystem;
            
            require flowCapabilityRequirement {
                doc /* The subsystem shall maintain specified flow rate */
                assume minFlowRate : VolumePerTimeValue;
                require constraint {
                    subsystem.aldgatePump.ratedFlowRate >= minFlowRate
                }
            }
            
            require pressureLimitRequirement {
                doc /* The subsystem shall operate within safe pressure limits */
                assume maxPressure : PressureValue;
                require constraint {
                    subsystem.dischargePressure.pressureReading <= maxPressure
                }
            }
            
            require sourceLevelRequirement {
                doc /* The source tank shall maintain minimum level during operation */
                require constraint {
                    subsystem.sourceTank.currentLevel >= subsystem.sourceTank.minOperatingLevel
                }
            }
            
            require destinationCapacityRequirement {
                doc /* The destination tank shall not exceed maximum level */
                require constraint {
                    subsystem.destinationTank.currentLevel <= subsystem.destinationTank.maxOperatingLevel
                }
            }
        }
        
        part def PumpingSubsystem {
            port systemInPort : ~FluidPort;
            port systemOutPort : FluidPort;
            
            attribute systemFlowRate : VolumePerTimeValue;
            attribute operationalMode : String;
        }
    }
    
    package Usages {
        part pumpingSubsystem : PumpingSubsystem {
            
            part sourceTank : SourceTank {
                attribute :>> capacity = 10000.0[L];
                attribute :>> currentLevel = 8000.0[L];
                attribute :>> minOperatingLevel = 1000.0[L];
                
                item :>> storedFluid {
                    attribute :>> volume = 8000.0[L];
                    attribute :>> density = 998.0[kg/(m^3)];
                    attribute :>> temperature = 293.15[K];
                    attribute :>> pressure = 101325.0[Pa];
                }
            }
            
            flow of transferFluid : Fluid
                from sourceTank.fluidOutPort.fluid to aldgatePump.fluidInPort.fluid;
            
            part aldgatePump : AldgatePump {
                attribute :>> ratedFlowRate = 120.0[L/s];
                attribute :>> operatingPressure = 400000.0[Pa];
                attribute :>> powerConsumption = 8500.0[W];
                attribute :>> efficiency = 0.82;
                attribute :>> isRunning = true;
                
                part :>> motor {
                    attribute :>> speed = 1450.0[rad/s];
                    attribute :>> power = 8500.0[W];
                }
                
                part :>> impeller {
                    attribute :>> diameter = 0.28[m];
                }
                
                perform action transferFluid : TransferFluid {
                    in fluidIn = fluidInPort.fluid;
                    out fluidOut = fluidOutPort.fluid;
                }
            }
            
            part suctionPressure : PressureSensor {
                attribute :>> pressureReading = 98000.0[Pa];
            }
            
            part dischargePressure : PressureSensor {
                attribute :>> pressureReading = 380000.0[Pa];
            }
            
            part flowMeter : FlowSensor {
                attribute :>> flowRate = 115.0[L/s];
                attribute :>> totalVolumeTransferred = 0.0[L];
            }
            
            flow of pumpedFluid : Fluid
                from aldgatePump.fluidOutPort.fluid to destinationTank.fluidInPort.fluid;
            
            part destinationTank : DestinationTank {
                attribute :>> capacity = 15000.0[L];
                attribute :>> currentLevel = 3000.0[L];
                attribute :>> maxOperatingLevel = 14000.0[L];
                
                flow fluidInPort.fluid to receivedFluid;
                
                item :>> receivedFluid {
                    attribute :>> volume = 3000.0[L];
                    attribute :>> density = 998.0[kg/(m^3)];
                    attribute :>> temperature = 293.15[K];
                    attribute :>> pressure = 101325.0[Pa];
                }
            }
            
            bind systemInPort = sourceTank.fluidOutPort;
            bind systemOutPort = destinationTank.fluidInPort;
            
            attribute :>> systemFlowRate = flowMeter.flowRate;
            attribute :>> operationalMode = aldgatePump.isRunning ? "Active" : "Idle";
            
            perform action monitorFlowRate : MonitorFlow {
                in sensor = flowMeter;
                out currentFlow;
            }
            
            perform action controlPumpOperation {
                first start;
                then merge evaluateConditions;
                
                then action checkTankLevels {
                    out sourceOK : Boolean = 
                        sourceTank.currentLevel > sourceTank.minOperatingLevel;
                    out destinationOK : Boolean = 
                        destinationTank.currentLevel < destinationTank.maxOperatingLevel;
                }
                
                then decide;
                    if checkTankLevels.sourceOK and checkTankLevels.destinationOK 
                        then startPumpAction;
                    if not checkTankLevels.sourceOK or not checkTankLevels.destinationOK 
                        then stopPumpAction;
                
                action startPumpAction : StartPump {
                    in pump = aldgatePump;
                }
                then evaluateConditions;
                
                action stopPumpAction : StopPump {
                    in pump = aldgatePump;
                }
                then evaluateConditions;
            }
        }
        
        requirement subsystemRequirements : PumpingSubsystemRequirements {
            subject subsystem = pumpingSubsystem;
            
            require :>> flowCapabilityRequirement {
                assume minFlowRate = 100.0[L/s];
            }
            
            require :>> pressureLimitRequirement {
                assume maxPressure = 450000.0[Pa];
            }
            
            require :>> sourceLevelRequirement;
            
            require :>> destinationCapacityRequirement;
        }
        
        satisfy subsystemRequirements by pumpingSubsystem;
    }
}

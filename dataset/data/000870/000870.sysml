package 'Electromagnetic Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        item def ConductiveFluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
            attribute pressure : Real;
            attribute electricalConductivity : Real;
        }
        
        port def FluidPort {
            attribute pressure : Real;
            attribute temperature : Real;
            out item fluidOut : ConductiveFluid;
            in item fluidIn : ConductiveFluid;
        }
        
        port def PowerPort {
            attribute voltage : Real;
            attribute current : Real;
        }
        
        part def SourceTank {
            port fluidOutPort : FluidPort;
            
            attribute capacity : Real;
            attribute currentLevel : Real;
            attribute minOperatingLevel : Real;
            
            item storedFluid : ConductiveFluid {
                attribute volume : Real;
            }
        }
        
        part def DestinationTank {
            port fluidInPort : ~FluidPort;
            
            attribute capacity : Real;
            attribute currentLevel : Real;
            attribute maxOperatingLevel : Real;
            
            item receivedFluid : ConductiveFluid {
                attribute volume : Real;
            }
        }
        
        part def ElectromagneticPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port powerInPort : ~PowerPort;
            
            attribute ratedPower : Real;
            attribute ratedFlowRate : Real;
            attribute ratedPressureHead : Real;
            attribute efficiency : Real;
            attribute operatingTemperatureMin : Real;
            attribute operatingTemperatureMax : Real;
            
            part magneticSystem {
                attribute magneticFluxDensity : Real;
                attribute coilTurns : Integer;
                attribute coilResistance : Real;
                attribute coilInductance : Real;
            }
            
            part pumpingChannel {
                attribute channelWidth : Real;
                attribute channelHeight : Real;
                attribute channelLength : Real;
                attribute wallThickness : Real;
            }
            
            part powerElectronics {
                attribute inputVoltage : Real;
                attribute outputCurrent : Real;
                attribute switchingFrequency : Real;
            }
            
            action def PumpFluid {
                in fluidIn : ConductiveFluid;
                in appliedPower : Real;
                in magneticField : Real;
                out fluidOut : ConductiveFluid;
                out achievedFlowRate : Real;
                out generatedPressure : Real;
            }
            
            perform action pumpingAction : PumpFluid {
                in fluidIn = fluidInPort.fluidIn;
                in appliedPower = powerInPort.voltage * powerInPort.current;
                in magneticField = magneticSystem.magneticFluxDensity;
                out fluidOut = fluidOutPort.fluidOut;
                out achievedFlowRate;
                out generatedPressure;
            }
            
            state def PumpOperatingStates {
                entry; then off;
                
                state off;
                state priming;
                state running;
                state stopping;
                state fault;
                
                transition off_to_priming
                    first off
                    accept StartCommand
                    then priming;
                
                transition priming_to_running
                    first priming
                    if inletPressure >= minInletPressure
                    then running;
                
                transition running_to_stopping
                    first running
                    accept StopCommand
                    then stopping;
                
                transition stopping_to_off
                    first stopping
                    if currentFlowRate <= 0.1
                    then off;
                
                transition any_to_fault
                    first running
                    accept FaultDetected
                    then fault;
                
                transition fault_to_off
                    first fault
                    accept FaultCleared
                    then off;
                
                attribute currentPower : Real;
                attribute inletPressure : Real;
                attribute minInletPressure : Real;
                attribute currentFlowRate : Real;
            }
            
            exhibit state operatingState : PumpOperatingStates;
        }
        
        part def PressureSensor {
            port sensePort : ~FluidPort;
            
            attribute measuredPressure : Real;
            attribute accuracy : Real;
            attribute range : Real;
            
            action def MeasurePressure {
                in fluidPressure : Real;
                out pressureReading : Real;
            }
            
            perform action sensing : MeasurePressure {
                in fluidPressure = sensePort.fluidIn.pressure;
                out pressureReading = measuredPressure;
            }
        }
        
        part def FlowMeter {
            port flowInPort : ~FluidPort;
            port flowOutPort : FluidPort;
            
            attribute measuredFlowRate : Real;
            attribute totalVolume : Real;
            attribute accuracy : Real;
            
            action def MeasureFlow {
                in flowRate : Real;
                out flowReading : Real;
                out cumulativeVolume : Real;
            }
            
            perform action metering : MeasureFlow {
                out flowReading = measuredFlowRate;
                out cumulativeVolume = totalVolume;
            }
        }
        
        part def ControlValve {
            port valveInPort : ~FluidPort;
            port valveOutPort : FluidPort;
            
            attribute openingPercentage : Real;
            attribute maxFlowRate : Real;
            attribute responseTime : Real;
            
            state def ValveStates {
                entry; then closed;
                
                state closed;
                state opening;
                state open;
                state closing;
                
                transition closed_to_opening
                    first closed
                    accept OpenCommand
                    then opening;
                
                transition opening_to_open
                    first opening
                    if openingPercentage >= 100.0
                    then open;
                
                transition open_to_closing
                    first open
                    accept CloseCommand
                    then closing;
                
                transition closing_to_closed
                    first closing
                    if openingPercentage <= 0.0
                    then closed;
                
                attribute targetOpening : Real;
            }
            
            exhibit state valveState : ValveStates;
        }
        
        part def PowerSupply {
            port powerOutPort : PowerPort;
            
            attribute inputVoltage : Real;
            attribute outputVoltage : Real;
            attribute maxCurrent : Real;
            attribute maxPower : Real;
            attribute efficiency : Real;
            
            assert constraint PowerLimit {
                powerOutPort.current <= maxCurrent
            }
        }
        
        action def ControlPumping {
            in targetFlowRate : Real;
            in actualFlowRate : Real;
            in inletPressure : Real;
            in outletPressure : Real;
            out pumpPowerCommand : Real;
            out valvePositionCommand : Real;
        }
        
        requirement def PumpPerformanceRequirement {
            subject pump : ElectromagneticPump;
            
            doc /* The electromagnetic pump shall deliver the rated flow rate at rated pressure head */
            
            require constraint FlowRateCapability {
                pump.ratedFlowRate >= 100.0
            }
            
            require constraint PressureCapability {
                pump.ratedPressureHead >= 5.0
            }
            
            require constraint EfficiencyRequirement {
                pump.efficiency >= 0.75
            }
        }
        
        requirement def FluidCompatibilityRequirement {
            subject pump : ElectromagneticPump;
            subject fluid : ConductiveFluid;
            
            doc /* The pump shall operate with conductive fluids within specified temperature range */
            
            require constraint TemperatureRange {
                fluid.temperature >= pump.operatingTemperatureMin and
                fluid.temperature <= pump.operatingTemperatureMax
            }
            
            require constraint ConductivityRequirement {
                fluid.electricalConductivity >= 1.0e6
            }
        }
        
        requirement def SystemReliabilityRequirement {
            doc /* The pumping subsystem shall operate continuously for minimum 10000 hours */
            
            require constraint OperatingLife {
                operatingHours >= 10000.0
            }
            
            attribute operatingHours : Real;
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part pumpingSubsystem {
            part sourceTank : SourceTank {
                attribute :>> capacity = 5000.0;
                attribute :>> currentLevel = 4000.0;
                attribute :>> minOperatingLevel = 500.0;
                
                item :>> storedFluid {
                    attribute :>> volume = 4000.0;
                    attribute :>> density = 850.0;
                    attribute :>> viscosity = 0.002;
                    attribute :>> temperature = 320.0;
                    attribute :>> pressure = 101325.0;
                    attribute :>> electricalConductivity = 5.0e6;
                }
            }
            
            flow of fluid : ConductiveFluid
                from sourceTank.fluidOutPort.fluidOut
                to inletValve.valveInPort.fluidIn;
            
            part inletValve : ControlValve {
                attribute :>> openingPercentage = 100.0;
                attribute :>> maxFlowRate = 150.0;
                attribute :>> responseTime = 2.0;
            }
            
            flow of fluid : ConductiveFluid
                from inletValve.valveOutPort.fluidOut
                to inletPressureSensor.sensePort.fluidIn;
            
            part inletPressureSensor : PressureSensor {
                attribute :>> accuracy = 0.01;
                attribute :>> range = 1000000.0;
            }
            
            flow of fluid : ConductiveFluid
                from inletPressureSensor.sensePort.fluidOut
                to emPump.fluidInPort.fluidIn;
            
            part emPump : ElectromagneticPump {
                attribute :>> ratedPower = 7500.0;
                attribute :>> ratedFlowRate = 120.0;
                attribute :>> ratedPressureHead = 8.0;
                attribute :>> efficiency = 0.82;
                attribute :>> operatingTemperatureMin = 273.15;
                attribute :>> operatingTemperatureMax = 423.15;
                
                part :>> magneticSystem {
                    attribute :>> magneticFluxDensity = 1.8;
                    attribute :>> coilTurns = 600;
                    attribute :>> coilResistance = 0.4;
                    attribute :>> coilInductance = 0.15;
                }
                
                part :>> pumpingChannel {
                    attribute :>> channelWidth = 0.08;
                    attribute :>> channelHeight = 0.06;
                    attribute :>> channelLength = 0.4;
                    attribute :>> wallThickness = 0.005;
                }
                
                part :>> powerElectronics {
                    attribute :>> inputVoltage = 480.0;
                    attribute :>> outputCurrent = 18.0;
                    attribute :>> switchingFrequency = 5000.0;
                }
            }
            
            part powerSupplyUnit : PowerSupply {
                attribute :>> inputVoltage = 480.0;
                attribute :>> outputVoltage = 400.0;
                attribute :>> maxCurrent = 20.0;
                attribute :>> maxPower = 8000.0;
                attribute :>> efficiency = 0.95;
            }
            
            connect powerSupplyUnit.powerOutPort to emPump.powerInPort;
            
            flow of fluid : ConductiveFluid
                from emPump.fluidOutPort.fluidOut
                to flowMeter.flowInPort.fluidIn;
            
            part flowMeter : FlowMeter {
                attribute :>> accuracy = 0.02;
                attribute :>> totalVolume = 0.0;
            }
            
            flow of fluid : ConductiveFluid
                from flowMeter.flowOutPort.fluidOut
                to outletPressureSensor.sensePort.fluidIn;
            
            part outletPressureSensor : PressureSensor {
                attribute :>> accuracy = 0.01;
                attribute :>> range = 2000000.0;
            }
            
            flow of fluid : ConductiveFluid
                from outletPressureSensor.sensePort.fluidOut
                to destinationTank.fluidInPort.fluidIn;
            
            part destinationTank : DestinationTank {
                attribute :>> capacity = 6000.0;
                attribute :>> currentLevel = 1000.0;
                attribute :>> maxOperatingLevel = 5500.0;
                
                flow fluidInPort.fluidIn to receivedFluid;
                
                item :>> receivedFluid {
                    attribute :>> volume = 1000.0;
                }
            }
            
            part controller {
                perform action controlLoop : ControlPumping {
                    first start;
                    then merge continueControl;
                    
                    then action monitorFlow {
                        in flowRate = flowMeter.measuredFlowRate;
                        out flowReading;
                    }
                    
                    then action monitorInletPressure {
                        in pressure = inletPressureSensor.measuredPressure;
                        out pressureReading;
                    }
                    
                    then action monitorOutletPressure {
                        in pressure = outletPressureSensor.measuredPressure;
                        out pressureReading;
                    }
                    
                    then decide;
                        if monitorFlow.flowReading < targetFlowRate - 5.0 then increasePower;
                        if monitorFlow.flowReading > targetFlowRate + 5.0 then decreasePower;
                        if monitorOutletPressure.pressureReading > maxPressure then emergencyShutdown;
                        if monitorInletPressure.pressureReading < minInletPressure then lowPressureAlarm;
                    
                    action increasePower {
                        out pumpPowerCommand;
                    }
                    then continueControl;
                    
                    action decreasePower {
                        out pumpPowerCommand;
                    }
                    then continueControl;
                    
                    action lowPressureAlarm {
                        out pumpPowerCommand;
                        out valvePositionCommand;
                    }
                    then continueControl;
                    
                    action emergencyShutdown {
                        out pumpPowerCommand;
                        out valvePositionCommand;
                    }
                    then done;
                    
                    in targetFlowRate : Real;
                    attribute maxPressure : Real;
                    attribute minInletPressure : Real;
                }
            }
            
            satisfy pumpPerformance : PumpPerformanceRequirement {
                subject pump = emPump;
            }
            
            satisfy fluidCompatibility : FluidCompatibilityRequirement {
                subject pump = emPump;
                subject fluid = sourceTank.storedFluid;
            }
            
            satisfy systemReliability : SystemReliabilityRequirement;
        }
    }
}

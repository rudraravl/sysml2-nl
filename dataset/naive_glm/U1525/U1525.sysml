package WaterHammerMitigationSystem {
    import ScalarValues::*;
    
    package Types {
        value def Pressure :> Real {
            doc /* Measured in Pascals (Pa) */;
        }
        value def FlowRate :> Real {
            doc /* Measured in cubic meters per second (m3/s) */;
        }
        value def Volume :> Real {
            doc /* Measured in cubic meters (m3) */;
        }
        value def Length :> Real {
            doc /* Measured in meters (m) */;
        }
        value def Position :> Real {
            doc /* Measured in percent (0-100) */;
        }
        value def PositionRate :> Real {
            doc /* Measured in percent per second (0-100) */;
        }
        
        item def Water;
    }
    
    package Ports {
        import Types::*;
        
        port def FluidPort {
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
            flow item water : Water;
        }
        
        port def PressureSignalPort {
            out attribute pressureValue : Pressure;
        }
        
        port def FlowSignalPort {
            out attribute flowValue : FlowRate;
        }
        
        port def ValveCommandPort {
            in attribute targetPosition : Position;
            in attribute maxRate : PositionRate;
        }
        
        port def ReliefCommandPort {
            in attribute open : Boolean;
        }
        
        port def CloseCommandPort {
            in attribute closeRequested : Boolean;
        }
    }
    
    package Components {
        import Types::*;
        import Ports::*;
        
        part def Reservoir {
            out port fluidOut : FluidPort;
            attribute waterLevel : Volume = 10000.0;
        }
        
        part def Pipeline {
            inout port inlet : FluidPort;
            inout port outlet : FluidPort;
            inout port upstreamTap : FluidPort;
            inout port mitigationTap : FluidPort;
            
            attribute length : Length = 5000.0;
            attribute diameter : Length = 1.0;
        }
        
        part def MainControlValve {
            inout port inlet : FluidPort;
            inout port outlet : FluidPort;
            inout port downstreamTap : FluidPort;
            in port command : ValveCommandPort;
            
            attribute currentPosition : Position = 100.0;
            attribute currentRate : PositionRate = 0.0;
            attribute isClosed : Boolean = false;
            
            state machine ValveStates {
                state Open {
                    entry { isClosed = false; currentPosition = 100.0; }
                }
                state Closing {
                    entry { isClosed = false; currentRate = command.maxRate; }
                    do { currentPosition = currentPosition - currentRate; }
                }
                state Closed {
                    entry { isClosed = true; currentPosition = 0.0; }
                }
                
                transition Open to Closing when [command.targetPosition < 100.0];
                transition Closing to Closed when [currentPosition <= 0.0];
                transition Closing to Open when [command.targetPosition >= 100.0];
            }
        }
        
        part def PressureSensor {
            inout port measure : FluidPort;
            out port signal : PressureSignalPort;
            
            private attribute measuredValue : Pressure;
            
            action update {
                measuredValue = measure.pressure;
                signal.pressureValue = measuredValue;
            }
        }
        
        part def FlowMeter {
            inout port measure : FluidPort;
            out port signal : FlowSignalPort;
            
            private attribute measuredValue : FlowRate;
            
            action update {
                measuredValue = measure.flowRate;
                signal.flowValue = measuredValue;
            }
        }
        
        part def SurgeTank {
            inout port connect : FluidPort;
            attribute volume : Volume = 20.0;
            attribute maxVolume : Volume = 100.0;
        }
        
        part def AirVessel {
            inout port connect : FluidPort;
            attribute airPressure : Pressure = 800000.0;
            attribute waterVolume : Volume = 5.0;
            attribute maxWaterVolume : Volume = 50.0;
        }
        
        part def ReliefValve {
            inout port inlet : FluidPort;
            out port discharge : FluidPort;
            in port command : ReliefCommandPort;
            
            attribute isOpen : Boolean = false;
            
            state machine ReliefStates {
                state Closed {
                    entry { isOpen = false; }
                }
                state Open {
                    entry { isOpen = true; }
                }
                
                transition Closed to Open when [command.open == true];
                transition Open to Closed when [command.open == false];
            }
        }
        
        part def SurgeController {
            in port upstreamPressure : PressureSignalPort;
            in port downstreamPressure : PressureSignalPort;
            in port flowRate : FlowSignalPort;
            in port closeCommand : CloseCommandPort;
            out port valveCommand : ValveCommandPort;
            out port reliefCommand : ReliefCommandPort;
            
            attribute surgeThreshold : Pressure = 1500000.0;
            attribute safePressure : Pressure = 800000.0;
            
            state machine ControlLogic {
                state NormalMonitoring {
                    entry {
                        valveCommand.targetPosition = 100.0;
                        valveCommand.maxRate = 0.0;
                        reliefCommand.open = false;
                    }
                }
                state ControlledClosure {
                    entry {
                        valveCommand.targetPosition = 0.0;
                        valveCommand.maxRate = 2.0;
                        reliefCommand.open = false;
                    }
                }
                state ActiveMitigation {
                    entry {
                        valveCommand.maxRate = 0.0;
                        reliefCommand.open = true;
                    }
                }
                state Stabilization {
                    entry {
                        reliefCommand.open = false;
                    }
                }
                
                transition NormalMonitoring to ControlledClosure when [closeCommand.closeRequested == true];
                transition ControlledClosure to ActiveMitigation when [upstreamPressure.pressureValue > surgeThreshold];
                transition ControlledClosure to Stabilization when [valveCommand.targetPosition == 0.0 && upstreamPressure.pressureValue < surgeThreshold];
                transition ActiveMitigation to Stabilization when [upstreamPressure.pressureValue < safePressure];
                transition Stabilization to NormalMonitoring when [closeCommand.closeRequested == false];
            }
        }
    }
    
    package System {
        import Components::*;
        
        part def WaterHammerSystem {
            part reservoir : Reservoir;
            part pipeline : Pipeline;
            part mainValve : MainControlValve;
            part upstreamSensor : PressureSensor;
            part downstreamSensor : PressureSensor;
            part flowMeter : FlowMeter;
            part surgeTank : SurgeTank;
            part airVessel : AirVessel;
            part reliefValve : ReliefValve;
            part controller : SurgeController;
            
            connection reservoir.fluidOut to pipeline.inlet;
            connection pipeline.outlet to mainValve.inlet;
            
            connection pipeline.upstreamTap to upstreamSensor.measure;
            connection mainValve.downstreamTap to downstreamSensor.measure;
            connection pipeline.upstreamTap to flowMeter.measure;
            
            connection pipeline.mitigationTap to surgeTank.connect;
            connection pipeline.mitigationTap to airVessel.connect;
            connection pipeline.mitigationTap to reliefValve.inlet;
            
            connection upstreamSensor.signal to controller.upstreamPressure;
            connection downstreamSensor.signal to controller.downstreamPressure;
            connection flowMeter.signal to controller.flowRate;
            
            connection controller.valveCommand to mainValve.command;
            connection controller.reliefCommand to reliefValve.command;
        }
    }
    
    package Requirements {
        import System::*;
        import Components::*;
        
        requirement def ProtectPipelineFromSurges {
            doc /* The system shall protect the pipeline from pressure surges caused by rapid valve closure. */;
            subject system : WaterHammerSystem;
            objective {
                check {
                    system.controller.surgeThreshold > 0;
                }
            }
        }
        
        requirement def MonitorPipeline {
            doc /* The system shall monitor upstream pressure, downstream pressure, and flow rate. */;
            subject system : WaterHammerSystem;
            objective {
                check {
                    system.upstreamSensor.signal.pressureValue > 0;
                    system.downstreamSensor.signal.pressureValue > 0;
                    system.flowMeter.signal.flowValue > 0;
                }
            }
        }
        
        requirement def ActivelyMitigate {
            doc /* The system shall actively mitigate surges using a surge tank and air vessel. */;
            subject system : WaterHammerSystem;
            objective {
                check {
                    system.surgeTank.maxVolume > 0;
                    system.airVessel.airPressure > 0;
                }
            }
        }
        
        requirement def ProvideFailsafe {
            doc /* The system shall provide a failsafe relief valve to open at critical pressure. */;
            subject system : WaterHammerSystem;
            objective {
                check {
                    (system.controller.upstreamPressure.pressureValue > system.controller.surgeThreshold) implies (system.reliefValve.command.open == true);
                }
            }
        }
        
        requirement def ControlledClosurePhase {
            doc /* The controller shall manage the main control valve's closing speed to prevent surges. */;
            subject controller : SurgeController;
            objective {
                check {
                    controller.valveCommand.maxRate <= 5.0;
                }
            }
        }
    }
}

package 'Hydrocarbon Dew Point Control System' {
    private import ScalarValues::*;
    
    package Definitions {
        item def NaturalGas;
        item def SalesGas :> NaturalGas;
        item def LiquidCondensate;
        
        attribute def TemperatureValue :> Real;
        attribute def PressureValue :> Real;
        attribute def DewPointValue :> Real;
        attribute def PowerValue :> Real;
        
        item def GasFlow {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute dewPoint : DewPointValue;
        }
        
        item def ChilledMixture {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute dewPoint : DewPointValue;
            attribute liquidFraction : Real;
        }
        
        item def SensorData {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute dewPoint : DewPointValue;
        }
        
        item def ControlSignal {
            attribute coolingPower : PowerValue;
        }
        
        part def SensorSuite;
        part def DewPointAnalyzer;
        part def TemperatureSensor;
        part def PressureSensor;
        part def ChillerUnit;
        part def RefrigerationSystem;
        part def SeparationVessel;
        part def ProcessController;
        part def HydrocarbonDewPointControlSystem;
    }
    
    package Usages {
        private import Definitions::*;
        
        state machine def ControlBehavior {
            in sensorData : SensorData;
            attribute setpoint : DewPointValue = -5.0;
            initial state Monitoring;
            state Adjusting;
            transition from Monitoring to Adjusting 
                when sensorData.dewPoint > setpoint;
            transition from Adjusting to Monitoring 
                when sensorData.dewPoint <= setpoint;
        }
        
        part hydrocarbonDewPointControlSystem : HydrocarbonDewPointControlSystem {
            port gasInPort {
                in rawGas : GasFlow;
            }
            port salesGasOutPort {
                out salesGas : GasFlow;
            }
            port condensateOutPort {
                out condensate : LiquidCondensate;
            }
            
            part sensorSuite : SensorSuite {
                port gasSensorPort {
                    in gas : GasFlow;
                }
                port dataOutPort {
                    out sensorData : SensorData;
                }
                
                part dewPointAnalyzer : DewPointAnalyzer {
                    perform action measureDewPoint {
                        in gas : GasFlow;
                        out dewPoint : DewPointValue;
                    }
                }
                part temperatureSensor : TemperatureSensor {
                    perform action measureTemperature {
                        in gas : GasFlow;
                        out temperature : TemperatureValue;
                    }
                }
                part pressureSensor : PressureSensor {
                    perform action measurePressure {
                        in gas : GasFlow;
                        out pressure : PressureValue;
                    }
                }
            }
            
            part chillerUnit : ChillerUnit {
                port gasInPort {
                    in gas : GasFlow;
                }
                port mixtureOutPort {
                    out chilledMixture : ChilledMixture;
                }
                port controlPort {
                    in controlSignal : ControlSignal;
                }
                port coolingPort {
                    in coolingPower : PowerValue;
                }
                
                perform action chillGas {
                    in gas : GasFlow;
                    in controlSignal : ControlSignal;
                    in coolingPower : PowerValue;
                    out chilledMixture : ChilledMixture;
                }
            }
            
            part refrigerationSystem : RefrigerationSystem {
                port coolingOutPort {
                    out coolingPower : PowerValue;
                }
                perform action generateCooling {
                    out coolingPower : PowerValue;
                }
            }
            
            part separationVessel : SeparationVessel {
                port mixtureInPort {
                    in chilledMixture : ChilledMixture;
                }
                port gasOutPort {
                    out salesGas : GasFlow;
                }
                port liquidOutPort {
                    out condensate : LiquidCondensate;
                }
                
                perform action separateMixture {
                    in chilledMixture : ChilledMixture;
                    out salesGas : GasFlow;
                    out condensate : LiquidCondensate;
                }
            }
            
            part processController : ProcessController {
                port sensorDataPort {
                    in sensorData : SensorData;
                }
                port controlSignalPort {
                    out controlSignal : ControlSignal;
                }
                
                attribute setpoint : DewPointValue = -5.0;
                
                perform ControlBehavior {
                    in sensorData = sensorDataPort.sensorData;
                }
            }
            
            flow rawGasFlowToSensors of GasFlow 
                from gasInPort.rawGas to sensorSuite.gasSensorPort.gas;
            flow rawGasFlowToChiller of GasFlow 
                from gasInPort.rawGas to chillerUnit.gasInPort.gas;
                
            flow sensorDataFlow of SensorData 
                from sensorSuite.dataOutPort.sensorData to processController.sensorDataPort.sensorData;
                
            flow controlSignalFlow of ControlSignal 
                from processController.controlSignalPort.controlSignal to chillerUnit.controlPort.controlSignal;
                
            flow coolingPowerFlow of PowerValue 
                from refrigerationSystem.coolingOutPort.coolingPower to chillerUnit.coolingPort.coolingPower;
                
            flow chilledMixtureFlow of ChilledMixture 
                from chillerUnit.mixtureOutPort.chilledMixture to separationVessel.mixtureInPort.chilledMixture;
                
            flow salesGasFlow of GasFlow 
                from separationVessel.gasOutPort.salesGas to salesGasOutPort.salesGas;
                
            flow condensateFlow of LiquidCondensate 
                from separationVessel.liquidOutPort.condensate to condensateOutPort.condensate;
        }
        
        requirement def DewPointRequirement {
            subject processedGas : GasFlow;
            require processedGas.dewPoint <= -5.0;
        }
        
        requirement dewPointReq : DewPointRequirement {
            subject processedGas = hydrocarbonDewPointControlSystem.salesGasOutPort.salesGas;
        }
        
        satisfy dewPointReq by hydrocarbonDewPointControlSystem.processController;
    }
}

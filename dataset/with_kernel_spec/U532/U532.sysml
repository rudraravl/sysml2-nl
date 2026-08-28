package LiquidRingPumpingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;
    public import Usages::*;
    
    package Definitions {
        item def ProcessGas;
        item def SealingLiquid;
        item def GasLiquidMixture;
        item def CoolingWater;
        item def ElectricPower;
        
        signal def CommandSignal;
        signal def StartSignal :> CommandSignal;
        signal def StopSignal :> CommandSignal;
        signal def EmergencyStopSignal :> CommandSignal;
        signal def ResetSignal :> CommandSignal;
        signal def PrimeCompleteSignal;
        signal def RunSignal;
        signal def HighTempSignal;
        signal def CavitationSignal;
        signal def NormalTempSignal;
        signal def NormalPressureSignal;
        signal def SensorSignal {
            attribute value : Real;
        }
        signal def PressureSignal :> SensorSignal;
        signal def TemperatureSignal :> SensorSignal;
        signal def FlowSignal :> SensorSignal;
        signal def LevelSignal :> SensorSignal;
        
        port def GasPort {
            out item gas : ProcessGas;
        }
        port def LiquidPort {
            out item liquid : SealingLiquid;
        }
        port def MixturePort {
            out item mixture : GasLiquidMixture;
        }
        port def CoolingWaterPort {
            out item water : CoolingWater;
        }
        port def PowerPort {
            out item power : ElectricPower;
        }
        port def SignalPort {
            out item signal : SensorSignal;
        }
        port def CmdPort {
            out item signal : CommandSignal;
        }
        
        action def PumpGas {
            in gas : ProcessGas;
            in liquid : SealingLiquid;
            out mixture : GasLiquidMixture;
        }
        action def SeparateMixture {
            in mixture : GasLiquidMixture;
            out gas : ProcessGas;
            out liquid : SealingLiquid;
        }
        action def CoolLiquid {
            in hotLiquid : SealingLiquid;
            in coolingWater : CoolingWater;
            out coldLiquid : SealingLiquid;
            out warmWater : CoolingWater;
        }
        action def StartMotor;
        action def FillSealingLiquid;
        action def StopPump;
        action def TriggerCooling;
        action def ReduceLoad;
        action def AlertOperator;
        action def AdjustLiquidFlow;
        action def CutPower;
        action def VentGas;
        
        part def SourceVessel {
            port gasOutPort : GasPort;
            attribute pressure :> ISQ::pressure;
        }
        part def DischargeReceiver {
            port gasInPort : ~GasPort;
            attribute pressure :> ISQ::pressure;
        }
        part def LiquidRingPump {
            port gasInPort : ~GasPort;
            port liquidInPort : ~LiquidPort;
            port mixtureOutPort : MixturePort;
            port powerInPort : ~PowerPort;
            port cmdInPort : ~CmdPort;
            attribute speed :> ISQ::angularVelocity;
            attribute suctionPressure :> ISQ::pressure;
            attribute dischargePressure :> ISQ::pressure;
            attribute temperature :> ISQ::temperature;
            perform action pumpGas : PumpGas;
            perform action startMotor : StartMotor;
            perform action fillSealingLiquid : FillSealingLiquid;
            perform action stopPump : StopPump;
            perform action triggerCooling : TriggerCooling;
            perform action reduceLoad : ReduceLoad;
            perform action alertOperator : AlertOperator;
            perform action adjustLiquidFlow : AdjustLiquidFlow;
            perform action cutPower : CutPower;
            perform action ventGas : VentGas;
            
            exhibit state pumpStates {
                entry; then stopped;
                state stopped {
                    entry action stopPumpAction : StopPump;
                }
                state starting {
                    do action startMotorAction : StartMotor;
                }
                state priming {
                    do action fillSealingLiquidAction : FillSealingLiquid;
                }
                state running {
                    do action pumpGasAction : PumpGas;
                }
                state highTemp {
                    entry action triggerCoolingAction : TriggerCooling;
                    do action reduceLoadAction : ReduceLoad;
                }
                state cavitation {
                    entry action alertOperatorAction : AlertOperator;
                    do action adjustLiquidFlowAction : AdjustLiquidFlow;
                }
                state emergencyShutdown {
                    entry action cutPowerAction : CutPower;
                    do action ventGasAction : VentGas;
                }
                
                transition stopped_to_starting
                    first stopped
                    accept startCmd : StartSignal via cmdInPort
                    then starting;
                transition starting_to_priming
                    first starting
                    accept primeComplete : PrimeCompleteSignal
                    then priming;
                transition priming_to_running
                    first priming
                    accept runCmd : RunSignal
                    then running;
                transition running_to_highTemp
                    first running
                    accept HighTempSignal
                    then highTemp;
                transition running_to_cavitation
                    first running
                    accept CavitationSignal
                    then cavitation;
                transition highTemp_to_running
                    first highTemp
                    accept NormalTempSignal
                    then running;
                transition cavitation_to_running
                    first cavitation
                    accept NormalPressureSignal
                    then running;
                transition running_to_stopped
                    first running
                    accept stopCmd : StopSignal via cmdInPort
                    then stopped;
                transition highTemp_to_stopped
                    first highTemp
                    accept stopCmd : StopSignal via cmdInPort
                    then stopped;
                transition cavitation_to_stopped
                    first cavitation
                    accept stopCmd : StopSignal via cmdInPort
                    then stopped;
                    
                transition stopped_to_emergency
                    first stopped
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                transition starting_to_emergency
                    first starting
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                transition priming_to_emergency
                    first priming
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                transition running_to_emergency
                    first running
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                transition highTemp_to_emergency
                    first highTemp
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                transition cavitation_to_emergency
                    first cavitation
                    accept emergencyCmd : EmergencyStopSignal via cmdInPort
                    then emergencyShutdown;
                    
                transition emergencyShutdown_to_stopped
                    first emergencyShutdown
                    accept resetCmd : ResetSignal via cmdInPort
                    then stopped;
            }
        }
        part def Separator {
            port mixtureInPort : ~MixturePort;
            port gasOutPort : GasPort;
            port liquidOutPort : LiquidPort;
            perform action separateMixture : SeparateMixture;
        }
        part def HeatExchanger {
            port liquidInPort : ~LiquidPort;
            port liquidOutPort : LiquidPort;
            port coolingWaterInPort : ~CoolingWaterPort;
            port coolingWaterOutPort : CoolingWaterPort;
            attribute coolingCapacity :> ISQ::power;
            perform action coolLiquid : CoolLiquid;
        }
        part def SealingLiquidTank {
            port liquidInPort : ~LiquidPort;
            port liquidOutPort : LiquidPort;
            attribute level :> ISQ::volume;
            attribute volumeMax :> ISQ::volume;
            item liquid : SealingLiquid;
        }
        part def ElectricMotor {
            port powerOutPort : PowerPort;
            attribute ratedPower :> ISQ::power;
        }
        part def PumpController {
            port cmdOutPort : CmdPort;
            port sensorInPort : ~SignalPort;
        }
        part def PressureTransmitter {
            port signalOutPort : SignalPort;
            attribute reading :> ISQ::pressure;
        }
        part def TemperatureTransmitter {
            port signalOutPort : SignalPort;
            attribute reading :> ISQ::temperature;
        }
        part def FlowTransmitter {
            port signalOutPort : SignalPort;
            attribute reading :> ISQ::volumeFlowRate;
        }
        part def LevelTransmitter {
            port signalOutPort : SignalPort;
            attribute reading :> ISQ::volume;
        }
        part def CoolingWaterSupply {
            port waterOutPort : CoolingWaterPort;
        }
        part def CoolingWaterReturn {
            port waterInPort : ~CoolingWaterPort;
        }
        
        requirement def OperationalSafety {
            subject pump : LiquidRingPump;
            doc /* The pump shall not operate above 80 degrees Celsius to ensure safe operation. */
        }
        requirement def CoolingRequirement {
            subject heatExchanger : HeatExchanger;
            doc /* The heat exchanger shall cool the sealing liquid to below 40 degrees Celsius before returning it to the storage tank. */
        }
        requirement def ContinuousSealing {
            subject tank : SealingLiquidTank;
            doc /* The sealing liquid tank level shall remain above zero to ensure continuous pump operation. */
        }
        requirement def EmergencyShutdownCapability {
            subject pump : LiquidRingPump;
            doc /* The pump shall enter emergency shutdown state upon receiving an emergency stop signal from any operating state. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        part context {
            part sourceVessel : SourceVessel;
            part dischargeReceiver : DischargeReceiver;
            part pump : LiquidRingPump;
            part separator : Separator;
            part heatExchanger : HeatExchanger;
            part storageTank : SealingLiquidTank;
            part motor : ElectricMotor;
            part controller : PumpController;
            part coolingWaterSupply : CoolingWaterSupply;
            part coolingWaterReturn : CoolingWaterReturn;
            part pressureTransmitter : PressureTransmitter;
            part temperatureTransmitter : TemperatureTransmitter;
            part flowTransmitter : FlowTransmitter;
            part levelTransmitter : LevelTransmitter;
            
            flow of gas : ProcessGas
                from sourceVessel.gasOutPort.gas to pump.gasInPort.gas;
            flow of liquid : SealingLiquid
                from storageTank.liquidOutPort.liquid to pump.liquidInPort.liquid;
            flow of mixture : GasLiquidMixture
                from pump.mixtureOutPort.mixture to separator.mixtureInPort.mixture;
            flow of gas : ProcessGas
                from separator.gasOutPort.gas to dischargeReceiver.gasInPort.gas;
            flow of liquid : SealingLiquid
                from separator.liquidOutPort.liquid to heatExchanger.liquidInPort.liquid;
            flow of liquid : SealingLiquid
                from heatExchanger.liquidOutPort.liquid to storageTank.liquidInPort.liquid;
            flow of water : CoolingWater
                from coolingWaterSupply.waterOutPort.water to heatExchanger.coolingWaterInPort.water;
            flow of water : CoolingWater
                from heatExchanger.coolingWaterOutPort.water to coolingWaterReturn.waterInPort.water;
            flow of power : ElectricPower
                from motor.powerOutPort.power to pump.powerInPort.power;
            
            connect pressureTransmitter.signalOutPort to controller.sensorInPort;
            connect temperatureTransmitter.signalOutPort to controller.sensorInPort;
            connect flowTransmitter.signalOutPort to controller.sensorInPort;
            connect levelTransmitter.signalOutPort to controller.sensorInPort;
            connect controller.cmdOutPort to pump.cmdInPort;
            
            requirement operationalSafety : OperationalSafety {
                subject pump = pump;
            }
            requirement coolingRequirement : CoolingRequirement {
                subject heatExchanger = heatExchanger;
            }
            requirement continuousSealing : ContinuousSealing {
                subject tank = storageTank;
            }
            requirement emergencyShutdownCapability : EmergencyShutdownCapability {
                subject pump = pump;
            }
        }
    }
}

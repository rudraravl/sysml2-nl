package MarinePumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def VolumeValue :> Real;
        attribute def PressureValue :> Real;
        attribute def DurationValue :> Real;
        attribute def SpeedValue :> Real;
        attribute def FlowRateValue :> Real;
        
        item def Seawater;
        item def ElectricalEnergy;
        
        port def FluidPort {
            out item water: Seawater;
        }
        port def PowerPort {
            out item power: ElectricalEnergy;
        }
        port def ControlPort {
            out attribute command: SpeedCommand;
        }
        
        attribute def SpeedCommand {
            attribute value: Real;
        }
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def PrimingComplete;
        attribute def OverPressure;
        attribute def LowSuctionPressure;
        attribute def EnableAuto;
        attribute def DisableAuto;
        
        enum def Mode {
            manual;
            auto;
        }
        
        action def PrimePump;
        action def PumpWater {
            in speed: Real;
        }
        action def GenerateSpeedCommand {
            in targetFlow: FlowRateValue;
            out cmd: SpeedCommand;
        }
        
        part def SuctionTank {
            attribute volumeMax : VolumeValue;
            port fluidOutPort : FluidPort;
            item water: Seawater {
                attribute volume : VolumeValue;
            }
            assert constraint { water.volume <= volumeMax }
        }
        
        part def SuctionStrainer {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
        }
        
        part def MarinePump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port powerInPort : ~PowerPort;
            port controlInPort : ~ControlPort;
            
            attribute speed : SpeedValue;
            attribute dischargePressure : PressureValue;
            attribute suctionPressure : PressureValue;
            attribute maxDischargePressure : PressureValue = 8.0e5;
            attribute minSuctionPressure : PressureValue = 0.5e5;
            
            perform action primePump : PrimePump;
            perform action pumpWater : PumpWater;
            exhibit state pumpStates : PumpStates;
        }
        
        part def DischargeCheckValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
        }
        
        part def DischargeManifold {
            port fluidInPort : ~FluidPort;
            attribute flowRate : FlowRateValue;
            attribute pressure : PressureValue;
        }
        
        part def ElectricalPowerSupply {
            port powerOutPort : PowerPort;
        }
        
        part def PumpController {
            attribute mode : Mode = Mode::manual;
            attribute targetFlow : FlowRateValue = 500;
            port commandOutPort : ControlPort;
            exhibit state controllerStates : ControllerStates;
        }
        
        part def MarinePumpingSystem {
            attribute operationalTime : DurationValue;
        }
        
        state def PumpStates {
            entry; then Stopped;
            state Stopped;
            transition Stopped_to_Priming
                first Stopped
                accept StartSignal
                then Priming;
            state Priming {
                entry action primePump : PrimePump;
            }
            transition Priming_to_Running
                first Priming
                accept PrimingComplete
                then Running;
            state Running {
                do action pumpWater : PumpWater;
            }
            transition Running_to_Faulted_OverPressure
                first Running
                accept OverPressure
                then Faulted;
            transition Running_to_Faulted_LowSuction
                first Running
                accept LowSuctionPressure
                then Faulted;
            state Faulted;
            transition Faulted_to_Stopped
                first Faulted
                accept StopSignal
                then Stopped;
        }
        
        state def ControllerStates {
            entry; then Manual;
            state Manual;
            transition Manual_to_Auto
                first Manual
                accept EnableAuto
                then Auto;
            state Auto {
                do action generateSpeedCommand : GenerateSpeedCommand;
            }
            transition Auto_to_Manual
                first Auto
                accept DisableAuto
                then Manual;
        }
        
        requirement def PumpPerformanceRequirements {
            doc /* Performance requirements for the marine pumping subsystem. */
            attribute requiredFlowRate : FlowRateValue = 500;
            attribute requiredDischargePressure : PressureValue = 8.0e5;
            attribute requiredUptime : DurationValue = 7200000;
        }
    }
    
    public import Definitions::*;
    
    package Usages {
        private import Definitions::*;
        
        part marinePumpingSubsystem : MarinePumpingSystem {
            part suctionTank : SuctionTank;
            part suctionStrainer : SuctionStrainer;
            part marinePump : MarinePump;
            part dischargeCheckValve : DischargeCheckValve;
            part dischargeManifold : DischargeManifold;
            part electricalPowerSupply : ElectricalPowerSupply;
            part pumpController : PumpController;
            
            flow of water : Seawater
                from suctionTank.fluidOutPort.water to suctionStrainer.fluidInPort.water;
            flow of water : Seawater
                from suctionStrainer.fluidOutPort.water to marinePump.fluidInPort.water;
            flow of water : Seawater
                from marinePump.fluidOutPort.water to dischargeCheckValve.fluidInPort.water;
            flow of water : Seawater
                from dischargeCheckValve.fluidOutPort.water to dischargeManifold.fluidInPort.water;
                
            flow of power : ElectricalEnergy
                from electricalPowerSupply.powerOutPort.power to marinePump.powerInPort.power;
                
            connect pumpController.commandOutPort to marinePump.controlInPort;
            
            requirement perfReq : PumpPerformanceRequirements;
            satisfy perfReq;
        }
    }
}

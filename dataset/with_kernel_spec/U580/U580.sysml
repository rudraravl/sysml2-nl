package AutomatedWaterWellPumpingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    public import Definitions::*;

    package Definitions {
        item def Water;

        attribute def PumpStartSignal;
        attribute def PumpStopSignal;
        attribute def OverCurrentSignal;
        attribute def PrimingCompleteSignal;
        attribute def ManualStartSignal;
        attribute def ManualStopSignal;
        attribute def ManualResetSignal;
        attribute def ManualOverrideSignal;

        port def WaterPort {
            out item water : Water;
        }

        action def PumpWater {
            in waterIn : Water;
            out waterOut : Water;
        }

        action def PrimePump;
        action def ManualResetAction;
        action def MeasureFlow;

        state def PumpStates;
        state def ControlPanelStates;
        state def PressureSwitchStates;

        part def WellCasing {
            port waterOutPort : WaterPort;
            item groundwater : Water;
        }

        part def CheckValve {
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
        }

        part def WellPump {
            attribute electricalCurrent :> ISQ::electricCurrent;
            attribute maxCurrent :> ISQ::electricCurrent;
            attribute isPrimed : Boolean;
            port suctionPort : ~WaterPort;
            port dischargePort : WaterPort;
            perform action pumpWater : PumpWater;
            perform action primePump : PrimePump;
            perform action manualResetAction : ManualResetAction;
            exhibit state pumpStates : PumpStates;
        }

        part def PressureTank {
            attribute pressure :> ISQ::pressure;
            attribute volumeMax :> ISQ::volume;
            attribute airPrechargePressure :> ISQ::pressure;
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            item storedWater : Water;
        }

        part def PressureSwitch {
            attribute cutInPressure :> ISQ::pressure;
            attribute cutOutPressure :> ISQ::pressure;
            attribute measuredPressure :> ISQ::pressure;
            exhibit state pressureSwitchStates : PressureSwitchStates;
        }

        part def ControlPanel {
            attribute manualOverrideActive : Boolean;
            exhibit state controlPanelStates : ControlPanelStates;
        }

        part def FlowMeter {
            attribute flowRate : Real;
            attribute totalVolume :> ISQ::volume;
            port waterInPort : ~WaterPort;
            port waterOutPort : WaterPort;
            perform action measureFlow : MeasureFlow;
        }

        part def User {
            port waterInPort : ~WaterPort;
        }

        requirement def CutInPressureRequirement {
            doc /* The pressure switch shall signal pump start when tank pressure drops to cut-in pressure. */
            attribute cutInPressure :> ISQ::pressure;
        }

        requirement def CutOutPressureRequirement {
            doc /* The pressure switch shall signal pump stop when tank pressure reaches cut-out pressure. */
            attribute cutOutPressure :> ISQ::pressure;
        }

        requirement def OverCurrentProtectionRequirement {
            doc /* The pump shall enter a fault state if electrical current exceeds its maximum rating. */
            attribute maxCurrent :> ISQ::electricCurrent;
        }

        requirement def PressureTankStorageRequirement {
            doc /* The pressure tank shall store water under pressure to reduce pump cycling. */
            attribute volumeMax :> ISQ::volume;
        }

        requirement def BackflowPreventionRequirement {
            doc /* Check valves shall prevent reverse water flow when pump is off. */
        }
    }

    package Usages {
        private import Definitions::*;

        part systemContext {
            part wellCasing : WellCasing;
            part checkValveSuction : CheckValve;
            part pump : WellPump;
            part checkValveDischarge : CheckValve;
            part pressureTank : PressureTank;
            part pressureSwitch : PressureSwitch;
            part controlPanel : ControlPanel;
            part flowMeter : FlowMeter;
            part user : User;

            flow of water : Water
                from wellCasing.waterOutPort.water to checkValveSuction.waterInPort.water;
            flow of water : Water
                from checkValveSuction.waterOutPort.water to pump.suctionPort.water;
            flow of water : Water
                from pump.dischargePort.water to checkValveDischarge.waterInPort.water;
            flow of water : Water
                from checkValveDischarge.waterOutPort.water to pressureTank.waterInPort.water;
            flow of water : Water
                from pressureTank.waterOutPort.water to flowMeter.waterInPort.water;
            flow of water : Water
                from flowMeter.waterOutPort.water to user.waterInPort.water;

            action pumpWaterAction : PumpWater;
            action primePumpAction : PrimePump;
            action manualResetActionUsage : ManualResetAction;
            action measureFlowAction : MeasureFlow;

            requirement cutInReq : CutInPressureRequirement;
            requirement cutOutReq : CutOutPressureRequirement;
            requirement overCurrentReq : OverCurrentProtectionRequirement;
            requirement pressureTankReq : PressureTankStorageRequirement;
            requirement backflowReq1 : BackflowPreventionRequirement;
            requirement backflowReq2 : BackflowPreventionRequirement;

            state pumpStates : PumpStates {
                entry; then idle;
                state idle;
                accept PumpStartSignal then priming;
                state priming {
                    do primePumpAction;
                }
                accept PrimingCompleteSignal then running;
                state running {
                    do pumpWaterAction;
                }
                accept PumpStopSignal then idle;
                accept when pump.electricalCurrent > pump.maxCurrent
                    do send new OverCurrentSignal() to controlPanel
                    then fault;
                state fault;
                accept ManualResetSignal
                    do manualResetActionUsage
                    then idle;
            }

            state controlPanelStates : ControlPanelStates {
                entry; then auto;
                state auto;
                accept PumpStartSignal
                    do send new PumpStartSignal() to pump
                    then auto;
                accept PumpStopSignal
                    do send new PumpStopSignal() to pump
                    then auto;
                accept ManualOverrideSignal then manual;
                state manual;
                accept ManualStartSignal
                    do send new PumpStartSignal() to pump
                    then manual;
                accept ManualStopSignal
                    do send new PumpStopSignal() to pump
                    then manual;
                accept ManualOverrideSignal then auto;
                accept OverCurrentSignal
                    do send new PumpStopSignal() to pump
                    then fault;
                state fault;
                accept ManualResetSignal then auto;
            }

            state pressureSwitchStates : PressureSwitchStates {
                entry; then pumpOff;
                state pumpOff;
                accept when pressureTank.pressure <= pressureSwitch.cutInPressure
                    do send new PumpStartSignal() to controlPanel
                    then pumpOn;
                state pumpOn;
                accept when pressureTank.pressure >= pressureSwitch.cutOutPressure
                    do send new PumpStopSignal() to controlPanel
                    then pumpOff;
            }

            assert constraint { pressureSwitch.cutInPressure < pressureSwitch.cutOutPressure }

            satisfy cutInReq by pressureSwitch;
            satisfy cutOutReq by pressureSwitch;
            satisfy overCurrentReq by pump;
            satisfy pressureTankReq by pressureTank;
            satisfy backflowReq1 by checkValveSuction;
            satisfy backflowReq2 by checkValveDischarge;
        }
    }
}

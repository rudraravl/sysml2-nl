package 'Generalized Heat Engine' {
    private import ScalarValues::Real;
    private import ISQ::EnergyValue;
    private import ISQ::TemperatureValue;
    private import ISQ::PressureValue;
    private import SI::J;
    private import SI::K;
    private import SI::Pa;

    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def Heat {
            attribute energy : EnergyValue;
        }
        item def Work {
            attribute energy : EnergyValue;
        }
        item def WorkingSubstance {
            attribute internalEnergy : EnergyValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute volume : Real;
        }

        port def HeatOutPort {
            out item heat : Heat;
        }
        port def HeatInPort {
            in item heat : Heat;
        }
        port def WorkOutPort {
            out item work : Work;
        }
        port def WorkInPort {
            in item work : Work;
        }

        part def HotReservoir {
            port heatOutPort : HeatOutPort;
            attribute temperature : TemperatureValue;
        }
        part def ColdReservoir {
            port heatInPort : HeatInPort;
            attribute temperature : TemperatureValue;
        }
        part def MechanicalLoad {
            port workInPort : WorkInPort;
            attribute absorbedWork : EnergyValue;
        }

        part def EngineCore {
            port heatInPort : HeatInPort;
            port heatOutPort : HeatOutPort;
            port workOutPort : WorkOutPort;

            attribute internalEnergy : EnergyValue;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;

            item workingSubstance : WorkingSubstance;
        }

        action def AbsorbHeat {
            in heatIn : Heat;
            in substanceIn : WorkingSubstance;
            out substanceOut : WorkingSubstance;
        }
        action def ExpandAndDoWork {
            in substanceIn : WorkingSubstance;
            out workOut : Work;
            out substanceOut : WorkingSubstance;
        }
        action def RejectHeat {
            in substanceIn : WorkingSubstance;
            out heatOut : Heat;
            out substanceOut : WorkingSubstance;
        }
        action def Compress {
            in substanceIn : WorkingSubstance;
            out substanceOut : WorkingSubstance;
        }

        action def EngineCycle {
            in heatIn : Heat;
            out workOut : Work;
            out heatOut : Heat;
            loop {
                action absorbHeat : AbsorbHeat {
                    in heatIn = EngineCycle::heatIn;
                    in substanceIn : WorkingSubstance;
                    out substanceOut : WorkingSubstance;
                }
                flow absorbHeat.substanceOut to expandAndDoWork.substanceIn;
                action expandAndDoWork : ExpandAndDoWork {
                    in substanceIn : WorkingSubstance;
                    out workOut = EngineCycle::workOut;
                    out substanceOut : WorkingSubstance;
                }
                flow expandAndDoWork.substanceOut to rejectHeat.substanceIn;
                action rejectHeat : RejectHeat {
                    in substanceIn : WorkingSubstance;
                    out heatOut = EngineCycle::heatOut;
                    out substanceOut : WorkingSubstance;
                }
                flow rejectHeat.substanceOut to compress.substanceIn;
                action compress : Compress {
                    in substanceIn : WorkingSubstance;
                    out substanceOut : WorkingSubstance;
                }
                flow compress.substanceOut to absorbHeat.substanceIn;
            }
        }

        attribute def CycleStart;
        attribute def HeatAbsorbed;
        attribute def ExpansionComplete;
        attribute def HeatRejected;
        attribute def CompressionComplete;

        state def EngineStates {
            entry; then idle;
            state idle;
            transition idle_to_absorbing
                first idle
                accept CycleStart
                then absorbing;
            state absorbing;
            transition absorbing_to_expanding
                first absorbing
                accept HeatAbsorbed
                then expanding;
            state expanding;
            transition expanding_to_rejecting
                first expanding
                accept ExpansionComplete
                then rejecting;
            state rejecting;
            transition rejecting_to_compressing
                first rejecting
                accept HeatRejected
                then compressing;
            state compressing;
            transition compressing_to_idle
                first compressing
                accept CompressionComplete
                then idle;
        }

        requirement def FirstLawOfThermodynamics {
            attribute qHot : EnergyValue;
            attribute workDone : EnergyValue;
            attribute qCold : EnergyValue;
            constraint energyConservation { qHot == workDone + qCold }
        }

        requirement def CarnotEfficiencyBound {
            attribute efficiency : Real;
            attribute maxEfficiency : Real;
            constraint efficiencyBound { efficiency <= maxEfficiency }
        }
    }

    package Usages {
        part context {
            part hotReservoir : HotReservoir {
                attribute temperature = 500 [K];
            }
            part coldReservoir : ColdReservoir {
                attribute temperature = 300 [K];
            }
            part mechanicalLoad : MechanicalLoad {
                attribute absorbedWork = 0 [J];
            }

            part engineCore : EngineCore {
                perform action cycle : EngineCycle {
                    in heatIn = heatInPort.heat;
                    out workOut = workOutPort.work;
                    out heatOut = heatOutPort.heat;
                }

                state cycleStates : EngineStates;
            }

            requirement req1 : FirstLawOfThermodynamics {
                attribute qHot = 1000 [J];
                attribute workDone = 400 [J];
                attribute qCold = 600 [J];
            }

            requirement req2 : CarnotEfficiencyBound {
                attribute efficiency = 0.40;
                attribute maxEfficiency = 0.40;
            }

            satisfy req1 by engineCore;
            satisfy req2 by engineCore;

            flow of heat : Heat from hotReservoir.heatOutPort.heat to engineCore.heatInPort.heat;
            flow of work : Work from engineCore.workOutPort.work to mechanicalLoad.workInPort.work;
            flow of wasteHeat : Heat from engineCore.heatOutPort.heat to coldReservoir.heatInPort.heat;
        }
    }
}

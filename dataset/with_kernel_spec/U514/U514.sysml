package PortableWaterPumpSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        item def Water;
        item def Gasoline;

        attribute def StartSignal;
        attribute def StartupComplete;
        attribute def StopSignal;
        attribute def ShutdownComplete;
        attribute def OverPressure;
        attribute def ResetSignal;

        port def WaterInPort {
            in item water : Water;
        }
        port def WaterOutPort {
            out item water : Water;
        }
        port def FuelPort {
            out item fuel : Gasoline;
        }
        port def MechanicalPowerPort {
            out torque : Real;
            out speed : Real;
        }
        port def ControlPort {
            out throttleCmd : Real;
            in pressure : Real;
            in flowRate : Real;
        }

        action def CheckFuel;
        action def PrimePump;
        action def StartEngine;
        action def WarmUp;
        action def IdleCoolDown;
        action def SwitchOff;
        action def PumpWater;
        action def MonitorPerformance;
        action def AdjustThrottle;

        action def StartupSequence {
            action checkFuel : CheckFuel;
            action primePump : PrimePump;
            action startEngine : StartEngine;
            action warmUp : WarmUp;
            succession first checkFuel then primePump;
            succession first primePump then startEngine;
            succession first startEngine then warmUp;
        }

        action def ShutdownSequence {
            action idleCoolDown : IdleCoolDown;
            action switchOff : SwitchOff;
            succession first idleCoolDown then switchOff;
        }

        part def StructuralFrame {
            attribute material : String = "Steel";
            attribute mass :> ISQ::mass;
            part handle;
            part vibrationIsolator;
        }

        part def GasolineEngine {
            attribute displacement :> ISQ::volume = 163 [cm^3];
            attribute fuelConsumptionRate : Real;
            port fuelInPort : ~FuelPort;
            port powerOutPort : MechanicalPowerPort;
            port controlPort : ~ControlPort;

            part fuelTank {
                attribute capacity :> ISQ::volume = 3.1 [L];
                item fuel : Gasoline {
                    attribute volume :> ISQ::volume = 3.1 [L];
                }
            }
            part ignitionSystem;
            part coolingSystem;

            perform action startEngine : StartEngine;
            perform action warmUp : WarmUp;
            perform action idleCoolDown : IdleCoolDown;
            perform action switchOff : SwitchOff;
        }

        part def DriveShaft {
            port engineEnd : ~MechanicalPowerPort;
            port pumpEnd : MechanicalPowerPort;
        }

        part def CentrifugalPumpHead {
            port powerInPort : ~MechanicalPowerPort;
            port waterInPort : ~WaterInPort;
            port waterOutPort : WaterOutPort;
            port sensorPort : ControlPort;

            part impeller {
                attribute material : String = "Cast Iron";
                attribute bladeCount : Integer = 6;
            }
            part shaft {
                attribute material : String = "Stainless Steel";
            }
            part bearing {
                attribute type : String = "Ball Bearing";
                attribute lubricated : Boolean = true;
            }
            part seal {
                attribute type : String = "Carbon-Ceramic";
            }

            perform action pumpWater : PumpWater;
        }

        part def PrimingSystem {
            port waterInPort : ~WaterInPort;
            port waterOutPort : WaterOutPort;
            part primingChamber {
                item water : Water;
            }
            perform action primePump : PrimePump;
        }

        part def ControlSystem {
            port sensorPort : ~ControlPort;
            port engineControlPort : ControlPort;

            part throttleActuator;
            part pressureGauge {
                attribute reading : Real;
            }
            part flowGauge {
                attribute reading : Real;
            }

            attribute targetFlowRate : Real = 600;

            perform action monitorPerformance : MonitorPerformance;
            perform action adjustThrottle : AdjustThrottle;
        }

        part def WaterPumpSystem {
            attribute totalMass :> ISQ::mass;
            port waterInPort : ~WaterInPort;
            port waterOutPort : WaterOutPort;

            part frame : StructuralFrame;
            part engine : GasolineEngine;
            part driveShaft : DriveShaft;
            part pumpHead : CentrifugalPumpHead;
            part primingSystem : PrimingSystem;
            part controlSystem : ControlSystem;

            perform action startupSequence : StartupSequence;
            perform action pumpWater : PumpWater;
            perform action shutdownSequence : ShutdownSequence;

            exhibit state pumpLifecycle {
                entry action initial;
                state off;
                state starting {
                    do startupSequence;
                }
                state active {
                    do pumpWater;
                }
                state shuttingDown {
                    do shutdownSequence;
                }
                state fault;

                transition initial then off;
                transition off_to_starting
                    first off
                    accept StartSignal
                    then starting;
                transition starting_to_active
                    first starting
                    accept StartupComplete
                    then active;
                transition active_to_shuttingDown
                    first active
                    accept StopSignal
                    then shuttingDown;
                transition shuttingDown_to_off
                    first shuttingDown
                    accept ShutdownComplete
                    then off;
                transition active_to_fault
                    first active
                    accept OverPressure
                    then fault;
                transition fault_to_off
                    first fault
                    accept ResetSignal
                    then off;
            }
        }

        requirement def FlowRateRequirement {
            attribute requiredFlowRate : Real = 600;
            subject pump : WaterPumpSystem;
            require {
                pump.controlSystem.flowGauge.reading >= requiredFlowRate;
            }
        }

        requirement def PressureRequirement {
            attribute requiredHead : Real = 30;
            subject pump : WaterPumpSystem;
            require {
                pump.controlSystem.pressureGauge.reading >= requiredHead;
            }
        }

        requirement def WeightRequirement {
            attribute maxWeight :> ISQ::mass = 25 [kg];
            subject pump : WaterPumpSystem;
            require {
                pump.totalMass <= maxWeight;
            }
        }

        requirement def FuelCapacityRequirement {
            attribute requiredCapacity :> ISQ::volume = 3.1 [L];
            subject pump : WaterPumpSystem;
            require {
                pump.engine.fuelTank.capacity >= requiredCapacity;
            }
        }

        requirement def RuntimeRequirement {
            attribute requiredRuntime :> ISQ::time = 2 [h];
            subject pump : WaterPumpSystem;
            require {
                pump.engine.fuelTank.fuel.volume / pump.engine.fuelConsumptionRate >= requiredRuntime;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part waterPump : WaterPumpSystem {
            attribute redefines totalMass = 24 [kg];

            part frame : StructuralFrame {
                attribute redefines mass = 5 [kg];
            }

            part engine : GasolineEngine {
                attribute redefines fuelConsumptionRate = 1.5;
            }

            part driveShaft : DriveShaft;
            part pumpHead : CentrifugalPumpHead;
            part primingSystem : PrimingSystem;
            part controlSystem : ControlSystem;

            flow of water : Water
                from waterInPort.water to primingSystem.waterInPort.water;
            flow of water : Water
                from primingSystem.waterOutPort.water to pumpHead.waterInPort.water;
            flow of water : Water
                from pumpHead.waterOutPort.water to waterOutPort.water;
            flow of fuel : Gasoline
                from engine.fuelTank.fuel to engine.fuelInPort.fuel;

            connect engine.powerOutPort to driveShaft.engineEnd;
            connect driveShaft.pumpEnd to pumpHead.powerInPort;
            connect controlSystem.engineControlPort to engine.controlPort;
            connect pumpHead.sensorPort to controlSystem.sensorPort;
        }

        satisfy FlowRateRequirement by waterPump;
        satisfy PressureRequirement by waterPump;
        satisfy WeightRequirement by waterPump;
        satisfy FuelCapacityRequirement by waterPump;
        satisfy RuntimeRequirement by waterPump;
    }
}

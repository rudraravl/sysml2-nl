package SumpPumpingSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def PVC;

    item def Fluid {
        attribute density : MassDensityValue;
        attribute volume : VolumeValue;
    }

    port def FluidPort {
        out item fluid : Fluid;
    }

    port def SignalPort {
        out attribute signal : Boolean;
    }

    part def SumpBasin {
        attribute capacity : VolumeValue;
        attribute highThreshold : LengthValue;
        attribute lowThreshold : LengthValue;
        attribute currentLevel : LengthValue;

        port fluidOutPort : FluidPort;

        item accumulatedFluid : Fluid;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute running : Boolean;

        port powerSignalPort : SignalPort;
        port mechanicalOutputPort {
            out attribute torque : TorqueValue;
            out attribute speed : AngularVelocityValue;
        }
    }

    part def Impeller {
        attribute diameter : LengthValue;
        attribute efficiency : Real;

        port mechanicalInputPort {
            in attribute torque : TorqueValue;
            in attribute speed : AngularVelocityValue;
        }
        port fluidInPort : ~FluidPort;
        port fluidOutPort : FluidPort;
    }

    part def FloatSwitch {
        attribute activated : Boolean;
        port signalPort : SignalPort;

        action def SenseLevel {
            in level : LengthValue;
            in high : LengthValue;
            in low : LengthValue;
            out trigger : Boolean;
        }

        perform action senseLevel : SenseLevel;
    }

    part def CheckValve {
        attribute isOpen : Boolean;
        port fluidInPort : ~FluidPort;
        port fluidOutPort : FluidPort;
    }

    part def SumpPump {
        port fluidInPort : ~FluidPort;
        port fluidOutPort : FluidPort;

        part motor : ElectricMotor;
        part impeller : Impeller;
        part floatSwitch : FloatSwitch;
        part checkValve : CheckValve;

        flow of fluid : Fluid from fluidInPort.fluid to impeller.fluidInPort.fluid;
        flow of fluid : Fluid from impeller.fluidOutPort.fluid to checkValve.fluidInPort.fluid;
        flow of fluid : Fluid from checkValve.fluidOutPort.fluid to fluidOutPort.fluid;
        bind motor.mechanicalOutputPort.torque = impeller.mechanicalInputPort.torque;
        bind motor.mechanicalOutputPort.speed = impeller.mechanicalInputPort.speed;
    }

    part def DischargePipe {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute material : PVC;

        port fluidInPort : ~FluidPort;
        port fluidOutPort : FluidPort;
    }

    part def DischargePoint {
        attribute location : String;
        port fluidInPort : ~FluidPort;
        item expelledFluid : Fluid;
    }

    action def ActivatePump;
    action def DeactivatePump;

    part def SumpSystem {
        part basin : SumpBasin {
            attribute capacity = 200 [L];
            attribute highThreshold = 0.8 [m];
            attribute lowThreshold = 0.2 [m];
            attribute currentLevel = 0.0 [m];
        }

        part pump : SumpPump {
            part motor : ElectricMotor {
                attribute ratedPower = 500 [W];
                attribute voltage = 120 [V];
            }
            part impeller : Impeller {
                attribute diameter = 0.1 [m];
                attribute efficiency = 0.75;
            }
            part floatSwitch : FloatSwitch;
            part checkValve : CheckValve;
        }

        part dischargePipe : DischargePipe {
            attribute length = 10 [m];
            attribute diameter = 0.04 [m];
        }

        part dischargePoint : DischargePoint {
            attribute location = "Storm Drain";
        }

        flow of fluid : Fluid
            from basin.fluidOutPort.fluid to pump.fluidInPort.fluid;

        flow of fluid : Fluid
            from pump.fluidOutPort.fluid to dischargePipe.fluidInPort.fluid;

        flow of fluid : Fluid
            from dischargePipe.fluidOutPort.fluid to dischargePoint.fluidInPort.fluid;

        state pumpingCycle {
            entry; then idle;
            state idle;
            accept when basin.currentLevel >= basin.highThreshold
                do action activatePump : ActivatePump
                then pumping;
            state pumping;
            accept when basin.currentLevel <= basin.lowThreshold
                do action deactivatePump : DeactivatePump
                then idle;
        }
    }

    requirement def SumpSystemRequirement {
        subject sumpSystem : SumpSystem;
    }

    requirement def FloodPreventionRequirement :> SumpSystemRequirement {
        doc /* The system must prevent flooding by evacuating fluid before the basin overflows. */
        require constraint {
            sumpSystem.basin.accumulatedFluid.volume <= sumpSystem.basin.capacity
        }
    }

    requirement def PumpActivationRequirement :> SumpSystemRequirement {
        doc /* The pump must activate when the fluid level reaches the high threshold. */
        require constraint {
            sumpSystem.basin.currentLevel >= sumpSystem.basin.highThreshold
            implies sumpSystem.pump.floatSwitch.activated == true
        }
    }

    requirement def BackflowPreventionRequirement :> SumpSystemRequirement {
        doc /* The check valve must close when the pump is deactivated to prevent backflow. */
        require constraint {
            sumpSystem.pump.motor.running == false
            implies sumpSystem.pump.checkValve.isOpen == false
        }
    }

    requirement def DischargeFlowRequirement :> SumpSystemRequirement {
        doc /* Fluid must flow from basin through pump and pipe to the discharge point. */
        require constraint {
            sumpSystem.dischargePoint.expelledFluid.volume > 0
        }
    }
}

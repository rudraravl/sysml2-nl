package SolenoidActuatorSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def ActivateCommand;
    attribute def DeactivateCommand;

    port def ElectricalPort {
        in voltage :> ISQ::electricPotential;
        in current :> ISQ::electricCurrent;
    }

    port def MechanicalPort {
        out force :> ISQ::force;
        out displacement :> ISQ::length;
    }

    port def MagneticPort {
        out force :> ISQ::force;
    }

    port def ControlPort {
        in activate : ActivateCommand;
        in deactivate : DeactivateCommand;
    }

    part def Housing {
        attribute material : String = "Ferromagnetic Steel";
        attribute mass :> ISQ::mass;
    }

    part def Coil {
        attribute ratedVoltage :> ISQ::electricPotential = 24 [V];
        attribute resistance :> ISQ::resistance;
        attribute inductance :> ISQ::inductance;
        attribute powerConsumption :> ISQ::power;
        port electricalInput : ~ElectricalPort;
        port magneticOutput : MagneticPort;
    }

    part def Plunger {
        attribute stroke :> ISQ::length = 12 [mm];
        attribute mass :> ISQ::mass;
        attribute position :> ISQ::length;
        port magneticInput : ~MagneticPort;
        port mechanicalOutput : MechanicalPort;
    }

    part def ReturnSpring {
        attribute springConstant :> ISQ::forcePerLength;
        attribute freeLength :> ISQ::length;
        port mechanical : ~MechanicalPort;
    }

    action def GenerateMagneticField {
        in voltage :> ISQ::electricPotential;
        out magneticForce :> ISQ::force;
    }

    action def ExtendPlunger {
        in magneticForce :> ISQ::force;
        out displacement :> ISQ::length;
    }

    action def CollapseMagneticField {
        in voltageDrop : Boolean;
        out residualForce :> ISQ::force;
    }

    action def RetractPlunger {
        in springForce :> ISQ::force;
        out displacement :> ISQ::length;
    }

    part def SolenoidActuator {
        attribute responseTime :> ISQ::time;
        attribute cycleLife : Integer;
        attribute powerConsumption :> ISQ::power;
        attribute outputForce :> ISQ::force;

        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalPort;
        port controlInput : ControlPort;

        part housing : Housing;
        part coil : Coil;
        part plunger : Plunger;
        part returnSpring : ReturnSpring;

        connect electricalInput to coil.electricalInput;
        connect coil.magneticOutput to plunger.magneticInput;
        connect plunger.mechanicalOutput to mechanicalOutput;
        connect returnSpring.mechanical to plunger.mechanicalOutput;
        connect coil to housing;
        connect plunger to housing;
        connect returnSpring to housing;

        exhibit state actuationStates {
            entry; then deactivated;
            state deactivated;
            transition deactivated to activated
                accept activate : ActivateCommand;
            state activated;
            transition activated to deactivated
                accept deactivate : DeactivateCommand;
        }

        bind coil.ratedVoltage = 24 [V];
        bind plunger.stroke = 12 [mm];
        bind responseTime = 35 [ms];
        bind cycleLife = 2500000;
        bind powerConsumption = 10 [W];
    }

    requirement def SolenoidRequirement {
        subject solenoid : SolenoidActuator;
    }

    requirement def StrokeRequirement :> SolenoidRequirement {
        attribute actualStroke :> ISQ::length;
        attribute requiredStroke :> ISQ::length = 12 [mm];
        require constraint { actualStroke >= requiredStroke }
    }

    requirement def ResponseTimeRequirement :> SolenoidRequirement {
        attribute actualResponseTime :> ISQ::time;
        attribute maxResponseTime :> ISQ::time = 40 [ms];
        require constraint { actualResponseTime <= maxResponseTime }
    }

    requirement def CycleLifeRequirement :> SolenoidRequirement {
        attribute actualCycles : Integer;
        attribute minCycles : Integer = 2000000;
        require constraint { actualCycles >= minCycles }
    }

    requirement def VoltageRequirement :> SolenoidRequirement {
        attribute actualVoltage :> ISQ::electricPotential;
        attribute requiredVoltage :> ISQ::electricPotential = 24 [V];
        require constraint { actualVoltage == requiredVoltage }
    }

    requirement def PowerRequirement :> SolenoidRequirement {
        attribute actualPower :> ISQ::power;
        attribute maxPower :> ISQ::power = 15 [W];
        require constraint { actualPower <= maxPower }
    }

    part solenoidSystem : SolenoidActuator {
        attribute outputForce = 10 [N];

        part coil redefines coil {
            attribute resistance = 2.5 [Ohm];
            attribute inductance = 0.01 [H];
            attribute powerConsumption = 10 [W];
        }
        part plunger redefines plunger {
            attribute mass = 0.05 [kg];
            attribute stroke = 12 [mm];
        }
        part returnSpring redefines returnSpring {
            attribute springConstant = 500 [N/m];
        }
        part housing redefines housing {
            attribute mass = 0.3 [kg];
        }
    }

    requirement <'REQ-01'> strokeReq : StrokeRequirement {
        subject solenoid :>> solenoidSystem;
        attribute actualStroke = 12 [mm];
    }

    requirement <'REQ-02'> responseTimeReq : ResponseTimeRequirement {
        subject solenoid :>> solenoidSystem;
        attribute actualResponseTime = 35 [ms];
    }

    requirement <'REQ-03'> cycleLifeReq : CycleLifeRequirement {
        subject solenoid :>> solenoidSystem;
        attribute actualCycles = 2500000;
    }

    requirement <'REQ-04'> voltageReq : VoltageRequirement {
        subject solenoid :>> solenoidSystem;
        attribute actualVoltage = 24 [V];
    }

    requirement <'REQ-05'> powerReq : PowerRequirement {
        subject solenoid :>> solenoidSystem;
        attribute actualPower = 10 [W];
    }

    satisfy strokeReq by solenoidSystem;
    satisfy responseTimeReq by solenoidSystem;
    satisfy cycleLifeReq by solenoidSystem;
    satisfy voltageReq by solenoidSystem;
    satisfy powerReq by solenoidSystem;
}

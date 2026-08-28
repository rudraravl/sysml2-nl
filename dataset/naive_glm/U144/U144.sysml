package AlgerBrush {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Power :> Real { unit "W"; }
    value def Torque :> Real { unit "N·m"; }
    value def RotationalSpeed :> Real { unit "rpm"; }
    value def Force :> Real {> Real { unit "N"; }
    value def Length :> Real { unit "mm"; }
    value def Duration :> Real { unit "s"; }
    value def BatteryCapacity :> Real { unit "mAh"; }

    // ---- Item types ----
    item def ElectricalEnergy;
    item def RotationalMotion;
    item def CornealDebris;
    item def CornealTissue;

    // ---- Port definitions ----
    port def ElectricalPowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def MechanicalPowerPort {
        out torque : Torque;
        out speed : RotationalSpeed;
    }

    port def BurrInterfacePort {
        out torque : Torque;
        out speed : RotationalSpeed;
        in contactForce : Force;
    }

    // ---- Part definitions ----
    part def Housing {
        attribute gripType : String = "ergonomic";
        attribute material : String = "medical-grade polymer";
        attribute length : Length = 120;
        attribute diameter : Length = 18;
        port def distalEnd;
        port def proximalEnd;
    }

    part def BatteryCell {
        attribute nominalVoltage : Voltage = 1.5;
        attribute capacity : BatteryCapacity = 2200;
        attribute chemistry : String = "alkaline";
        out port powerOut : ElectricalPowerPort {
            redefines voltage = nominalVoltage;
        }
    }

    part def ActivationSwitch {
        attribute isPressed : Boolean = false;
        in port powerIn : ElectricalPowerPort;
        out port powerOut : ElectricalPowerPort;
        action def press {
            in pressed : Boolean;
            then assign isPressed = pressed;
        }
        action def release {
            then assign isPressed = false;
        }
    }

    part def LowTorqueMotor {
        attribute nominalVoltage : Voltage = 1.5;
        attribute maxTorque : Torque = 0.0025;
        attribute nominalSpeed : RotationalSpeed = 800;
        attribute stallTorque : Torque = 0.0030;
        attribute isStalled : Boolean = false;
        in port powerIn : ElectricalPowerPort;
        out port mechanicalOut : MechanicalPowerPort;
        action def rotate {
            when powerIn.voltage > 0.0 and isStalled == false;
            then assign mechanicalOut.speed = nominalSpeed;
        }
        action def stall {
            when mechanicalOut.torque > maxTorque;
            then assign isStalled = true;
            then assign mechanicalOut.speed = 0.0;
        }
        action def resume {
            when mechanicalOut.torque <= maxTorque and powerIn.voltage > 0.0;
            then assign isStalled = false;
        }
    }

    part def ChuckAdapter {
        attribute couplingType : String = "friction collet";
        attribute compatibleBurrDiameter : Length = 1.5;
        in port mechanicalIn : MechanicalPowerPort;
        out port mechanicalOut : BurrInterfacePort;
        action def transmitMotion {
            then assign mechanicalOut.torque = mechanicalIn.torque;
            then assign mechanicalOut.speed = mechanicalIn.speed;
        }
    }

    part def OphthalmicBurr {
        attribute diameter : Length = 1.5;
        attribute abrasiveGrade : String = "fine diamond";
        attribute sterile : Boolean = true;
        attribute contactWithEye : Boolean = false;
        in port mechanicalIn : BurrInterfacePort;
        out port abradingSurface;
        action def abrade {
            in tissue : CornealTissue;
            out debris : CornealDebris;
            when contactWithEye == true and mechanicalIn.speed > 0.0;
        }
    }

    // ---- The Alger Brush assembly ----
    part def AlgerBrush {
        attribute deviceName : String = "Alger Brush";
        attribute intendedUse : String = "ophthalmic foreign body removal";
        attribute singleUseBurr : Boolean = true;

        part housing : Housing;
        part battery : BatteryCell;
        part switch : ActivationSwitch;
        part motor : LowTorqueMotor;
        part chuck : ChuckAdapter;
        part burr : OphthalmicBurr;

        connection batteryPowerFlow : ElectricalEnergy
            from battery.powerOut to switch.powerIn;
        connection switchedPowerFlow : ElectricalEnergy
            from switch.powerOut to motor.powerIn;
        connection motorMotionFlow : RotationalMotion
            from motor.mechanicalOut to chuck.mechanicalIn;
        connection chuckMotionFlow : RotationalMotion
            from chuck.mechanicalOut to burr.mechanicalIn;

        // ---- Operational state machine ----
        state def OperationalStates {
            entry; then idle;

            state idle {
                entry assign motor.mechanicalOut.speed = 0.0;
            }

            state rotating {
                entry assign motor.isStalled = false;
                do motor.rotate();
            }

            state abrading {
                entry assign burr.contactWithEye = true;
                do burr.abrade();
            }

            state stalled {
                entry assign motor.isStalled = true;
                entry assign motor.mechanicalOut.speed = 0.0;
            }

            transition t1 first idle to rotating
                when switch.isPressed == true;

            transition t2 rotating to abrading
                when burr.contactWithEye == true;

            transition t3 abrading to stalled
                when motor.mechanicalOut.torque > motor.maxTorque;

            transition t4 abrading to rotating
                when burr.contactWithEye == false;

            transition t5 rotating to idle
                when switch.isPressed == false;

            transition t6 stalled to idle
                when switch.isPressed == false;

            transition t7 stalled to rotating
                when motor.mechanicalOut.torque <= motor.maxTorque
                and switch.isPressed == true;
        }

        part behavior : OperationalStates;

        // ---- Requirements satisfaction ----
        satisfy PowerRequirement by battery;
        satisfy LowTorqueSafetyRequirement by motor;
        satisfy BurrInterchangeabilityRequirement by chuck;
        satisfy ErgonomicGripRequirement by housing;
        satisfy SterilityRequirement by burr;
    }

    // ---- Requirements ----
    requirement def PowerRequirement {
        doc "The Alger Brush shall be powered by a single self-contained battery cell.";
        subject device : AlgerBrush;
        objective {
            device.battery.nominalVoltage >= 1.2 and
            device.battery.nominalVoltage <= 3.0
        }
    }

    requirement def LowTorqueSafetyRequirement {
        doc "The motor shall stall automatically when torque exceeds a safe threshold, preventing penetration of Bowman's layer.";
        subject device : AlgerBrush;
        attribute maxSafeTorque : Torque = 0.0025;
        objective {
            device.motor.maxTorque <= maxSafeTorque
        }
    }

    requirement def BurrInterchangeabilityRequirement {
        doc "The ophthalmic burr shall be interchangeable via the chuck adapter without tools.";
        subject device : AlgerBrush;
        objective {
            device.chuck.couplingType == "friction collet"
        }
    }

    requirement def ErgonomicGripRequirement {
        doc "The housing shall provide an ergonomic grip suitable for precision ophthalmic work.";
        subject device : AlgerBrush;
        objective {
            device.housing.gripType == "ergonomic"
        }
    }

    requirement def SterilityRequirement {
        doc "Each ophthalmic burr shall be sterile prior to use.";
        subject device : AlgerBrush;
        objective {
            device.burr.sterile == true
        }
    }

    requirement def OperationalStateRequirement {
        doc "The device shall exhibit idle, rotating, abrading, and stalled operational states.";
        subject device : AlgerBrush;
        objective {
            device.behavior.states == {"idle", "rotating", "abrading", "stalled"}
        }
    }
}

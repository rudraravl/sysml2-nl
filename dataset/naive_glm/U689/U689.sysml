package GalvanometerModel {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Current :> Real {
        unit ampere;
    }
    value def Voltage :> Real {
        unit volt;
    }
    value def Resistance :> Real {
        unit ohm;
    }
    value def MagneticFluxDensity :> Real {
        unit tesla;
    }
    value def Torque :> Real {
        unit 'N·m';
    }
    value def Angle :> Real {
        unit rad;
    }
    value def AngularVelocity :> Real {
        unit 'rad/s';
    }
    value def SpringConstant :> Real {
        unit 'N·m/rad';
    }
    value def DampingCoefficient :> Real {
        unit 'N·m·s/rad';
    }
    value def CoilTurns :> Integer;
    value def CoilArea :> Real {
        unit 'm²';
    }
    value def MomentOfInertia :> Real {
        unit 'kg·m²';
    }

    // ===== Item Types =====
    item def ElectricCurrent {
        attribute magnitude : Current;
    }
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
    }
    item def MechanicalRotation {
        attribute angle : Angle;
        attribute angularVelocity : AngularVelocity;
    }

    // ===== Port Definitions =====
    port def ElectricalInputPort {
        attribute voltage : Voltage;
        in item current : ElectricCurrent;
    }
    port def MechanicalOutputPort {
        out item rotation : MechanicalRotation;
        attribute angle : Angle;
    }

    // ===== Requirements =====
    requirement def DetectSmallCurrents {
        doc /* The galvanometer shall detect and measure small electric currents. */
        subject galvanometer : Galvanometer;
        requirement detectThreshold : Current = 1e-6 [ampere];
        requirement measureRange : Current = 0.01 [ampere];
    }
    requirement def ConvertCurrentToRotation {
        doc /* The galvanometer shall convert an electrical current into a proportional mechanical rotation. */
        subject galvanometer : Galvanometer;
        requirement proportionality : Real = 1.0;
    }
    requirement def StableReading {
        doc /* The galvanometer shall provide a stable reading without excessive oscillation. */
        subject galvanometer : Galvanometer;
        requirement settlingTime : Real = 2.0 [s];
        requirement overshootLimit : Real = 0.05;
    }
    requirement def ReturnToZero {
        doc /* When current is removed, the pointer shall return to the zero position. */
        subject galvanometer : Galvanometer;
        requirement zeroTolerance : Angle = 0.01 [rad];
    }

    // ===== Component Parts =====
    part def PermanentMagnet {
        attribute fluxDensity : MagneticFluxDensity = 0.5 [tesla];
        out item field : MagneticField;
        private attribute fieldGenerated : Boolean = true;
        compute field {
            field.fluxDensity = fluxDensity;
        }
    }

    part def CoilAssembly {
        attribute turns : CoilTurns = 1000;
        attribute area : CoilArea = 1e-4 ['m²'];
        attribute resistance : Resistance = 50 [ohm];
        attribute momentOfInertia : MomentOfInertia = 1e-6 ['kg·m²'];
        in item inputCurrent : ElectricCurrent;
        in item magneticField : MagneticField;
        out attribute electromagneticTorque : Torque;
        out item rotation : MechanicalRotation;
        attribute currentAngle : Angle = 0 [rad];
        attribute currentAngularVelocity : AngularVelocity = 0 ['rad/s'];

        compute electromagneticTorque {
            electromagneticTorque = turns * area * magneticField.fluxDensity * inputCurrent.magnitude;
        }
    }

    part def SpringMechanism {
        attribute springConstant : SpringConstant = 5e-5 ['N·m/rad'];
        in attribute coilAngle : Angle;
        out attribute restoringTorque : Torque;
        compute restoringTorque {
            restoringTorque = springConstant * coilAngle;
        }
    }

    part def PointerNeedle {
        attribute length : Real = 0.05 [m];
        in attribute coilAngle : Angle;
        out attribute pointerAngle : Angle;
        compute pointerAngle {
            pointerAngle = coilAngle;
        }
    }

    part def CalibratedScale {
        attribute maxAngle : Angle = 1.5708 [rad];
        attribute maxCurrent : Current = 0.01 [ampere];
        in attribute pointerAngle : Angle;
        out attribute displayedValue : Current;
        compute displayedValue {
            displayedValue = (pointerAngle / maxAngle) * maxCurrent;
        }
    }

    part def DampingMechanism {
        attribute dampingCoefficient : DampingCoefficient = 1e-5 ['N·m·s/rad'];
        in attribute angularVelocity : AngularVelocity;
        out attribute dampingTorque : Torque;
        compute dampingTorque {
            dampingTorque = dampingCoefficient * angularVelocity;
        }
    }

    // ===== Galvanometer Assembly =====
    part def Galvanometer {
        port electricalInput : ElectricalInputPort;
        port mechanicalOutput : MechanicalOutputPort;

        part magnet : PermanentMagnet;
        part coil : CoilAssembly;
        part spring : SpringMechanism;
        part pointer : PointerNeedle;
        part scale : CalibratedScale;
        part damper : DampingMechanism;

        // Internal connections
        connection magneticFieldFlow connect magnet.field to coil.magneticField;
        connection currentFlow connect electricalInput.current to coil.inputCurrent;
        flow torqueFlow from coil.electromagneticTorque to spring.restoringTorque;
        flow dampingFlow from damper.dampingTorque to coil.electromagneticTorque;

        attribute netTorque : Torque;
        attribute coilAngle : Angle = 0 [rad];
        attribute coilAngularVelocity : AngularVelocity = 0 ['rad/s'];

        compute netTorque {
            netTorque = coil.electromagneticTorque - spring.restoringTorque - damper.dampingTorque;
        }

        // State Machine Behavior
        state def GalvanometerStates {
            entry; then idle;

            state idle {
                doc /* Pointer at zero, ready for measurement. */
                entry {
                    coilAngle = 0 [rad];
                    coilAngularVelocity = 0 ['rad/s'];
                }
            }

            transition energize
                from idle
                to energized
                when electricalInput.current.magnitude > 0 [ampere];

            state energized {
                doc /* Current applied, pointer deflecting. */
                do {
                    coilAngularVelocity = coilAngularVelocity + netTorque / coil.momentOfInertia * 0.001 [s];
                    coilAngle = coilAngle + coilAngularVelocity * 0.001 [s];
                }
            }

            transition balance
                from energized
                to settled
                when abs(coil.electromagneticTorque - spring.restoringTorque) < 1e-9 ['N·m'];

            state settled {
                doc /* Magnetic and spring torques balanced, pointer at final position. */
                do {
                    coilAngularVelocity = 0 ['rad/s'];
                }
            }

            transition deenergize
                from settled
                to returning
                when electricalInput.current.magnitude == 0 [ampere];

            transition deenergizeFromEnergized
                from energized
                to returning
                when electricalInput.current.magnitude == 0 [ampere];

            state returning {
                doc /* Current removed, spring returns coil and pointer to zero. */
                do {
                    coilAngularVelocity = coilAngularVelocity + netTorque / coil.momentOfInertia * 0.001 [s];
                    coilAngle = coilAngle + coilAngularVelocity * 0.001 [s];
                }
            }

            transition zeroReached
                from returning
                to idle
                when abs(coilAngle) < 0.001 [rad] and abs(coilAngularVelocity) < 0.001 ['rad/s'];
        }

        state machine behavior : GalvanometerStates;

        // Bind internal attributes
        bind coil.currentAngle = coilAngle;
        bind coil.currentAngularVelocity = coilAngularVelocity;
        bind spring.coilAngle = coilAngle;
        bind pointer.coilAngle = coilAngle;
        bind scale.pointerAngle = pointer.pointerAngle;
        bind damper.angularVelocity = coilAngularVelocity;

        // Output binding
        bind mechanicalOutput.angle = pointer.pointerAngle;

        // Requirements satisfaction
        satisfy DetectSmallCurrents by galvanometer;
        satisfy ConvertCurrentToRotation by galvanometer;
        satisfy StableReading by galvanometer;
        satisfy ReturnToZero by galvanometer;
    }

    // ===== Test Configuration =====
    part def GalvanometerTestBench {
        part unitUnderTest : Galvanometer;
        part currentSource {
            attribute outputCurrent : Current = 0.005 [ampere];
            out item testCurrent : ElectricCurrent;
            compute testCurrent {
                testCurrent.magnitude = outputCurrent;
            }
        }
        connection testCurrentFlow connect currentSource.testCurrent to unitUnderTest.electricalInput.current;
    }
}

package GalvanometerModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        alias Current for ISQ::ElectricCurrentValue;
        alias Torque for ISQ::TorqueValue;
        alias Angle for ISQ::PlaneAngleValue;
        alias AngularVelocity for ISQ::AngularVelocityValue;
        alias MagneticFluxDensity for ISQ::MagneticFluxDensityValue;
        alias Length for ISQ::LengthValue;
        alias Area for ISQ::AreaValue;

        port def ElectricalInputPort {
            in current : Current;
        }

        port def MagneticFieldOutputPort {
            out field : MagneticFluxDensity;
        }

        port def MagneticFieldInputPort {
            in field : MagneticFluxDensity;
        }

        port def DisplayOutputPort {
            out pointerAngle : Angle;
        }

        part def PermanentMagnet {
            doc /* Creates a stable and uniform magnetic field. */
            attribute fluxDensity : MagneticFluxDensity = 0.5 [T];
            port fieldPort : MagneticFieldOutputPort;
            bind fieldPort.field = fluxDensity;
        }

        part def CoilAssembly {
            doc /* Movable coil of fine wire suspended within the magnetic field. */
            attribute turns : Integer = 1000;
            attribute coilArea : Area = 1.0e-4 [m^2];
            port elecPort : ElectricalInputPort;
            port fieldPort : MagneticFieldInputPort;
        }

        part def SpringMechanism {
            doc /* Provides restoring torque proportional to deflection angle. */
            attribute torsionConstant : Real = 1.0e-3;
        }

        part def DampingMechanism {
            doc /* Prevents oscillation and ensures smooth settling. */
            attribute dampingCoeff : Real = 1.0e-5;
        }

        part def PointerNeedle {
            doc /* Lightweight needle attached to the coil for visual indication. */
            attribute needleLength : Length = 0.1 [m];
            port displayPort : DisplayOutputPort;
        }

        part def CalibratedScale {
            doc /* Calibrated scale for reading current values. */
        }

        action def GenerateMagneticTorque {
            in current : Current;
            in field : MagneticFluxDensity;
            out torque : Torque;
        }

        action def GenerateRestoringTorque {
            in angle : Angle;
            out torque : Torque;
        }

        action def ApplyDamping {
            in angularVelocity : AngularVelocity;
            out torque : Torque;
        }

        action def DisplayReading {
            in angle : Angle;
            out pointerAngle : Angle;
        }

        state def GalvanometerState {
            in current : Current;
            in deflectionAngle : Angle;
            in angularVelocity : AngularVelocity;

            initial idle;
            state idle;
            state energized;
            state settled;
            state returning;

            transition idle to energized when current > 0 [uA];
            transition energized to settled when angularVelocity == 0 [rad/s];
            transition settled to returning when current == 0 [uA];
            transition returning to idle when deflectionAngle == 0 [deg];
        }

        requirement def ConvertCurrentToRotation {
            doc /* The galvanometer shall convert an electrical current into a proportional mechanical rotation. */
        }

        requirement def TorqueBalance {
            doc /* Rotation shall cease when magnetic torque equals spring restoring torque. */
        }

        requirement def DampOscillation {
            doc /* A damping mechanism shall prevent oscillation and ensure smooth settling. */
        }

        requirement def VisualDisplay {
            doc /* A pointer shall indicate the measured current on a calibrated scale. */
        }
    }

    package Usages {
        private import Definitions::*;

        part def Galvanometer {
            part magnet : PermanentMagnet;
            part coil : CoilAssembly;
            part spring : SpringMechanism;
            part damper : DampingMechanism;
            part pointer : PointerNeedle;
            part scale : CalibratedScale;

            port currentInputPort : ElectricalInputPort;
            port displayOutputPort : DisplayOutputPort;

            attribute deflectionAngle : Angle = 0 [deg];
            attribute angularVelocity : AngularVelocity = 0 [rad/s];

            bind currentInputPort.current = coil.elecPort.current;
            bind pointer.displayPort.pointerAngle = displayOutputPort.pointerAngle;

            connect magnet.fieldPort to coil.fieldPort;

            perform state operation : GalvanometerState {
                in current = currentInputPort.current;
                in deflectionAngle = deflectionAngle;
                in angularVelocity = angularVelocity;
            }

            satisfy ConvertCurrentToRotation by coil;
            satisfy TorqueBalance by spring;
            satisfy DampOscillation by damper;
            satisfy VisualDisplay by pointer;
        }

        part galvanometerSystem : Galvanometer;
    }
}

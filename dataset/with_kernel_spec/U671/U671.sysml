package FabryPerotInterferometerSystem {
    private import ScalarValues::*;
    private import Quantities::*;
    private import ISQ::*;
    private import SI::*;
    private import MeasurementReferences::*;

    package OpticalQuantities {
        attribute Nanometer : LengthUnit = 1e-9 * SI::m;
        attribute Milliwatt : PowerUnit = 1e-3 * SI::W;

        attribute def WavelengthValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef = Nanometer;
        }
        attribute def LengthValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef = Nanometer;
        }
        attribute def IntensityValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef = Milliwatt;
        }
        attribute def VoltageValue :> ScalarQuantityValue {
            :>> num : Real;
            :>> mRef = SI::V;
        }
    }

    package SignalItems {
        private import OpticalQuantities::*;

        item def OpticalBeam {
            attribute wavelength : WavelengthValue;
            attribute intensity : IntensityValue;
        }
        item def ControlSignal {
            attribute voltage : VoltageValue;
        }
        item def IntensityMeasurement {
            attribute measuredIntensity : IntensityValue;
        }
    }

    package Ports {
        private import SignalItems::*;
        private import OpticalQuantities::*;

        port def OpticalOutputPort {
            out beam : OpticalBeam;
        }
        port def OpticalInputPort {
            in beam : OpticalBeam;
        }
        port def ControlInputPort {
            in signal : ControlSignal;
        }
        port def ControlOutputPort {
            out signal : ControlSignal;
        }
        port def MeasurementOutputPort {
            out measurement : IntensityMeasurement;
        }
        port def MeasurementInputPort {
            in measurement : IntensityMeasurement;
        }
        port def DisplacementOutputPort {
            out displacement : LengthValue;
        }
    }

    package Components {
        private import SignalItems::*;
        private import Ports::*;
        private import OpticalQuantities::*;

        part def LaserSource {
            port beamOut : OpticalOutputPort;
            attribute targetWavelength : WavelengthValue;
        }

        part def Mirror {
            attribute reflectivity : Real;
        }

        part def PiezoActuator {
            port controlIn : ControlInputPort;
            port displacementOut : DisplacementOutputPort;
            attribute maxDisplacement : LengthValue;
        }

        part def OpticalCavity {
            port inputPort : OpticalInputPort;
            port outputPort : OpticalOutputPort;
            port controlPort : ControlInputPort;

            part inputMirror : Mirror;
            part outputMirror : Mirror;
            part actuator : PiezoActuator;

            attribute cavityLength : LengthValue;
            bind cavityLength = actuator.displacementOut.displacement;

            connect controlPort to actuator.controlIn;
        }

        part def Photodetector {
            port lightIn : OpticalInputPort;
            port measurementOut : MeasurementOutputPort;
            attribute sensitivity : Real;
        }

        part def StabilizationController {
            port measurementIn : MeasurementInputPort;
            port controlOut : ControlOutputPort;
            attribute setpoint : IntensityValue;
            attribute gain : Real;
        }
    }

    package System {
        private import Components::*;
        private import SignalItems::*;
        private import Ports::*;
        private import OpticalQuantities::*;

        part def FabryPerotInterferometer {
            part laser : LaserSource;
            part cavity : OpticalCavity;
            part detector : Photodetector;
            part controller : StabilizationController;

            flow laserToCavityFlow of OpticalBeam
                from laser.beamOut.beam to cavity.inputPort.beam;
            flow cavityToDetectorFlow of OpticalBeam
                from cavity.outputPort.beam to detector.lightIn.beam;
            flow detectorToControllerFlow of IntensityMeasurement
                from detector.measurementOut.measurement to controller.measurementIn.measurement;
            flow controllerToCavityFlow of ControlSignal
                from controller.controlOut.signal to cavity.controlPort.signal;
        }
    }

    package Behaviors {
        private import OpticalQuantities::*;
        private import SignalItems::*;

        action def ScanMirrorSpacing {
            in startSpacing : LengthValue;
            in endSpacing : LengthValue;
            in stepSize : LengthValue;
            out transmissionSpectrum : Real[*];
        }

        action def LockToResonance {
            in targetIntensity : IntensityValue;
            out controlVoltage : VoltageValue;
        }

        attribute def StartScan;
        attribute def StartLock;
        attribute def Stop;

        state def InterferometerOperation {
            entry; then Idle;
            state Idle;
            state Scanning {
                do action scan : ScanMirrorSpacing;
            }
            state Locked {
                do action lock : LockToResonance;
            }

            transition first Idle accept StartScan then Scanning;
            transition first Idle accept StartLock then Locked;
            transition first Scanning accept Stop then Idle;
            transition first Locked accept Stop then Idle;
        }
    }

    package Requirements {
        private import Components::*;
        private import OpticalQuantities::*;

        requirement def ResonanceCondition {
            subject cavity : OpticalCavity;
            attribute wavelength : LengthValue;
            require cavity.cavityLength == wavelength;
        }

        requirement def StabilizationRequirement {
            subject controller : StabilizationController;
            attribute measuredIntensity : IntensityValue;
            attribute setpoint : IntensityValue;
            require measuredIntensity == setpoint;
        }

        requirement def SpectralResolution {
            attribute resolution : WavelengthValue;
            require resolution <= 0.01 [Nanometer];
        }

        requirement def LockStability {
            attribute drift : LengthValue;
            require drift <= 1.0 [Nanometer];
        }

        requirement def WavelengthRange {
            attribute minWavelength : WavelengthValue = 400.0 [Nanometer];
            attribute maxWavelength : WavelengthValue = 700.0 [Nanometer];
        }
    }

    package IndividualInstance {
        private import System::*;
        private import Components::*;
        private import OpticalQuantities::*;

        individual part def Laser_1 :> LaserSource;
        individual part def Cavity_1 :> OpticalCavity;
        individual part def Detector_1 :> Photodetector;
        individual part def Controller_1 :> StabilizationController;

        individual part interferometer_1 :> FabryPerotInterferometer {
            part :>> laser :>> Laser_1 {
                attribute :>> targetWavelength = 633.0 [Nanometer];
            }
            part :>> cavity :>> Cavity_1 {
                attribute :>> cavityLength = 500.0 [Nanometer];
            }
            part :>> detector :>> Detector_1;
            part :>> controller :>> Controller_1 {
                attribute :>> setpoint = 5.0 [Milliwatt];
                attribute :>> gain = 0.8;
            }
        }
    }
}

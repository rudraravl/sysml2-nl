package 'Atomic Force Microscope System' {
    private import ISQ::*;
    private import ScalarValues::*;

    package DataTypes {
        attribute def SpringConstant :> ScalarValues::Real; // N/m
        enum def OperatingMode {
            contact;
            tapping;
        }
    }

    package Items {
        private import DataTypes::OperatingMode;

        item def LaserBeam {
            attribute wavelength : LengthValue;
            attribute power : PowerValue;
        }

        item def DeflectionSignal {
            attribute vertical : ElectricPotentialValue;
            attribute lateral : ElectricPotentialValue;
        }

        item def ControlSignal {
            attribute xVoltage : ElectricPotentialValue;
            attribute yVoltage : ElectricPotentialValue;
            attribute zVoltage : ElectricPotentialValue;
        }

        item def SetpointSignal {
            attribute targetForce : ForceValue;
            attribute mode : OperatingMode;
        }

        item def HeightData {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
            attribute normalForce : ForceValue;
        }

        item def TopographyMap;
        item def ForceMap;
    }

    package Parts {
        private import DataTypes::*;
        private import Items::*;

        part def Cantilever {
            attribute springConstant : SpringConstant;
            attribute tipRadius : LengthValue;
            attribute resonantFrequency : FrequencyValue;
            attribute qualityFactor : Real;
            port laserInteractionPort {
                in beam : LaserBeam;
                out reflectedBeam : LaserBeam;
            }
        }

        part def LaserSystem {
            attribute power : PowerValue;
            attribute wavelength : LengthValue;
            port beamPort {
                out beam : LaserBeam;
            }
        }

        part def Photodetector {
            attribute sensitivity : Real;
            port beamPort {
                in beam : LaserBeam;
            }
            port deflectionPort {
                out deflection : DeflectionSignal;
            }
            action def DetectDeflection {
                in beam : LaserBeam;
                out deflection : DeflectionSignal;
            }
        }

        part def PiezoScanner {
            attribute scanRange : LengthValue;
            attribute positioningAccuracy : LengthValue;
            attribute calibrationX : Real;
            attribute calibrationY : Real;
            attribute calibrationZ : Real;
            port scanPort {
                in raster : ControlSignal;
            }
            port feedbackPort {
                in zControl : ControlSignal;
            }
            port positionPort {
                out x : LengthValue;
                out y : LengthValue;
                out z : LengthValue;
            }
            action def MoveToPosition {
                in xVoltage : ElectricPotentialValue;
                in yVoltage : ElectricPotentialValue;
                in zVoltage : ElectricPotentialValue;
                out x : LengthValue;
                out y : LengthValue;
                out z : LengthValue;
            }
        }

        part def ScanController {
            attribute scanSize : LengthValue;
            attribute scanRate : FrequencyValue;
            attribute xPixels : Natural;
            attribute yPixels : Natural;
            port rasterPort {
                out raster : ControlSignal;
            }
            action def GenerateRaster {
                in scanSize : LengthValue;
                in xPixels : Natural;
                in yPixels : Natural;
                out raster : ControlSignal;
            }
        }

        part def FeedbackController {
            attribute proportionalGain : Real;
            attribute integralGain : Real;
            attribute derivativeGain : Real;
            attribute deflectionSensitivity : Real;
            attribute running : Boolean;
            port setpointPort {
                in setpoint : SetpointSignal;
            }
            port deflectionPort {
                in deflection : DeflectionSignal;
            }
            port controlPort {
                out control : ControlSignal;
            }
            port forcePort {
                out measuredForce : ForceValue;
            }
            action def ComputeControl {
                in setpoint : ForceValue;
                in deflection : DeflectionSignal;
                in sensitivity : Real;
                in gain : Real;
                out measuredForce : ForceValue;
                out control : ControlSignal;
            }
            exhibit state ControllerState {
                entry; then idle;
                state idle;
                transition from idle to active if running;
                state active;
                transition from active to idle if not running;
            }
        }

        part def DataAcquisition {
            attribute samplingRate : FrequencyValue;
            port dataPort {
                in x : LengthValue;
                in y : LengthValue;
                in z : LengthValue;
                in normalForce : ForceValue;
            }
            port mapPort {
                out topography : TopographyMap;
                out forceMap : ForceMap;
            }
            action def AcquireData {
                in samples : HeightData[*];
                out topography : TopographyMap;
                out forceMap : ForceMap;
            }
        }

        part def Sample {
            attribute surfaceRoughness : LengthValue;
            port positionPort {
                in x : LengthValue;
                in y : LengthValue;
                in z : LengthValue;
            }
        }

        part def AFM {
            attribute operatingMode : OperatingMode = OperatingMode::contact;
            part cantilever : Cantilever;
            part laserSystem : LaserSystem;
            part photodetector : Photodetector;
            part scanner : PiezoScanner;
            part scanController : ScanController;
            part feedbackController : FeedbackController;
            part dataAcquisition : DataAcquisition;
            part sample : Sample;

            port setpointPort {
                in setpoint : SetpointSignal;
            }
            port mapPort {
                out topography : TopographyMap;
                out forceMap : ForceMap;
            }

            interface laserToCantilever connect laserSystem.beamPort to cantilever.laserInteractionPort {
                flow beamFlow of LaserBeam from laserSystem.beamPort.beam to cantilever.laserInteractionPort.beam;
            }
            interface cantileverToPhotodetector connect cantilever.laserInteractionPort to photodetector.beamPort {
                flow reflectedBeamFlow of LaserBeam from cantilever.laserInteractionPort.reflectedBeam to photodetector.beamPort.beam;
            }
            flow deflectionFlow of DeflectionSignal from photodetector.deflectionPort.deflection to feedbackController.deflectionPort.deflection;
            bind setpointPort = feedbackController.setpointPort;
            flow feedbackControlFlow of ControlSignal from feedbackController.controlPort.control to scanner.feedbackPort.zControl;
            flow rasterFlow of ControlSignal from scanController.rasterPort.raster to scanner.scanPort.raster;
            flow positionFlowX of LengthValue from scanner.positionPort.x to sample.positionPort.x;
            flow positionFlowY of LengthValue from scanner.positionPort.y to sample.positionPort.y;
            flow positionFlowZ of LengthValue from scanner.positionPort.z to sample.positionPort.z;
            flow positionDataFlowX of LengthValue from scanner.positionPort.x to dataAcquisition.dataPort.x;
            flow positionDataFlowY of LengthValue from scanner.positionPort.y to dataAcquisition.dataPort.y;
            flow positionDataFlowZ of LengthValue from scanner.positionPort.z to dataAcquisition.dataPort.z;
            flow forceDataFlow of ForceValue from feedbackController.forcePort.measuredForce to dataAcquisition.dataPort.normalForce;
            bind mapPort = dataAcquisition.mapPort;

            exhibit state OperatingState {
                entry; then contactMode;
                state contactMode;
                transition from contactMode to tappingMode if operatingMode == OperatingMode::tapping;
                state tappingMode;
                transition from tappingMode to contactMode if operatingMode == OperatingMode::contact;
            }
        }
    }

    package Requirements {
        private import Parts::*;

        requirement def TopographyMappingRequirement {
            subject afm : AFM;
            /* The AFM shall generate a three-dimensional topographical map of the sample surface with near-atomic resolution. */
        }

        requirement def ForceMeasurementRequirement {
            subject afm : AFM;
            /* The AFM shall measure mechanical properties by analyzing forces between the cantilever tip and the sample. */
        }

        requirement def ScannerAccuracyRequirement {
            subject scanner : PiezoScanner;
            /* The piezo scanner shall move the sample in a raster pattern with sub-nanometer accuracy. */
        }

        requirement def FeedbackControlRequirement {
            subject controller : FeedbackController;
            /* The feedback controller shall maintain a constant force between the cantilever tip and the sample by comparing measured deflection to a setpoint. */
        }

        requirement def OperatingModesRequirement {
            subject afm : AFM;
            /* The system shall support configurable contact and tapping operating modes. */
        }

        requirement def DataAcquisitionRequirement {
            subject daq : DataAcquisition;
            /* The data acquisition system shall record height adjustments and force data at every coordinate to construct surface and force maps. */
        }
    }
}

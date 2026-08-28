package LAPS {

    package Measures {
        import ScalarValues::*;

        value def pH :> Real;
        value def Concentration :> Real;
        value def Voltage :> Real;
        value def ElectricCurrent :> Real;
        value def Photocurrent :> ElectricCurrent;
        value def Frequency :> Real;
        value def Length :> Real;
        value def Wavelength :> Length;
        value def Time :> Real;
        value def Temperature :> Real;
        value def OpticalPower :> Real;
        value def Area :> Real;
        value def PlaneAngle :> Real;
        value def Dimensionless :> Real;
        value def SpatialCoordinate :> Real;
        value def SurfacePotential :> Voltage;
        value def ModulationDepth :> Dimensionless;
        value def MembraneSensitivity :> Real;
        value def DriftRate :> Real;
        value def Velocity :> Real;
        value def Resistance :> Real;

        unit nm;
        unit um;
        unit mm;
        unit cm;
        unit m;
        unit s;
        unit ms;
        unit us;
        unit Hz;
        unit kHz;
        unit V;
        unit mV;
        unit uV;
        unit A;
        unit mA;
        unit uA;
        unit nA;
        unit pA;
        unit W;
        unit mW;
        unit uW;
        unit K;
        unit degC;
        unit mm2;
        unit deg;
        unit rad;
        unit mol_per_L;
        unit mL;
        unit mm_per_s;
        unit mV_per_pH;
        unit mV_per_h;
        unit V_per_A;
    }

    package Items {
        import ScalarValues::*;
        import Measures::*;

        item def ModulatedLight {
            attribute wavelength : Wavelength;
            attribute opticalPower : OpticalPower;
            attribute modulationFrequency : Frequency;
            attribute modulationDepth : Dimensionless;
            attribute positionX : SpatialCoordinate;
            attribute positionY : SpatialCoordinate;
        }

        item def LightBeam :> ModulatedLight;

        item def FocusedLightBeam :> LightBeam {
            attribute spotDiameter : Length;
        }

        item def Analyte {
            attribute pH : pH;
            attribute targetIonConcentration : Concentration;
            attribute temperature : Temperature;
            attribute sampleVolume : Real;
        }

        item def ScanPosition {
            attribute x : SpatialCoordinate;
            attribute y : SpatialCoordinate;
        }

        item def ScanCommand {
            attribute scanWidth : Length;
            attribute scanHeight : Length;
            attribute pointsX : Integer;
            attribute pointsY : Integer;
            attribute dwellTime : Time;
        }

        item def PhotocurrentSample {
            attribute current : Photocurrent;
            attribute position : ScanPosition;
            attribute timestamp : Time;
        }

        item def LockInOutput {
            attribute amplitude : Photocurrent;
            attribute phase : PlaneAngle;
            attribute position : ScanPosition;
            attribute timestamp : Time;
        }

        item def ModulationReference {
            attribute frequency : Frequency;
            attribute phase : PlaneAngle;
        }

        item def CalibrationPoint {
            attribute knownConcentration : Concentration;
            attribute measuredPotential : Voltage;
        }

        item def CalibrationData {
            attribute points : CalibrationPoint[0..*];
            attribute slope : Dimensionless;
            attribute offset : Voltage;
            attribute calibrationTime : Time;
            attribute valid : Boolean;
        }

        item def SurfacePotentialMap {
            attribute width : Integer;
            attribute height : Integer;
            attribute pixelSizeX : Length;
            attribute pixelSizeY : Length;
            attribute potentials : Voltage[0..*];
            attribute timestamp : Time;
        }

        item def ConcentrationResult {
            attribute averageConcentration : Concentration;
            attribute minConcentration : Concentration;
            attribute maxConcentration : Concentration;
            attribute standardDeviation : Concentration;
            attribute potentialMap : SurfacePotentialMap;
            attribute timestamp : Time;
            attribute valid : Boolean;
        }

        item def SystemCommand {
            attribute command : String;
        }

        item def SystemStatus {
            attribute state : String;
            attribute ready : Boolean;
            attribute errorCode : Integer;
            attribute timestamp : Time;
        }
    }

    package Components {
        import ScalarValues::*;
        import Measures::*;
        import Items::*;

        part def LightSource {
            attribute nominalWavelength : Wavelength = 650 [nm];
            attribute maxOpticalPower : OpticalPower = 5 [mW];
            attribute modulationFrequency : Frequency = 1000 [Hz];
            attribute enabled : Boolean = false;

            out port lightOut : LightBeam;

            action def emitLight {
                out emitted : LightBeam;
            }
        }

        part def OpticalSystem {
            attribute focalLength : Length = 10 [mm];
            attribute numericalAperture : Dimensionless = 0.5;
            attribute magnification : Dimensionless = 1.0;

            in port lightIn : LightBeam;
            in port scanControlIn : ScanPosition;
            out port lightOut : FocusedLightBeam;

            action def focusAndScan {
                in incoming : LightBeam;
                in position : ScanPosition;
                out focused : FocusedLightBeam;
            }
        }

        part def ScanningController {
            attribute scanWidth : Length = 10 [mm];
            attribute scanHeight : Length = 10 [mm];
            attribute pointsX : Integer = 100;
            attribute pointsY : Integer = 100;
            attribute dwellTime : Time = 50 [ms];
            attribute scanSpeed : Velocity = 1 [mm_per_s];
            attribute scanComplete : Boolean = false;

            in port commandIn : ScanCommand;
            out port positionOut : ScanPosition;
            out port referenceOut : ModulationReference;

            action def executeScan {
                in command : ScanCommand;
                out positions : ScanPosition[0..*];
                out references : ModulationReference[0..*];
            }
        }

        part def ReferenceElectrode {
            attribute electrodeType : String = "Ag/AgCl";
            attribute referencePotential : Voltage = 0 [V];
            attribute electrolyte : String = "3M KCl";
            attribute maxDrift : DriftRate = 1 [mV_per_h];

            in port analyteIn : Analyte;
            out port referenceOut : Voltage;

            action def provideReference {
                in analyte : Analyte;
                out potential : Voltage;
            }
        }

        part def SemiconductorSubstrate {
            attribute material : String = "n-type Si";
            attribute thickness : Length = 0.5 [mm];
            attribute doping : Concentration;
        }

        part def InsulatingLayer {
            attribute material : String = "SiO2";
            attribute thickness : Length = 30 [nm];
            attribute dielectricConstant : Dimensionless = 3.9;
        }

        part def IonSensitiveMembrane {
            attribute ionType : String = "H+";
            attribute sensitivity : MembraneSensitivity = 56 [mV_per_pH];
            attribute thickness : Length = 0.5 [um];
        }

        part def SensorChip {
            attribute chipWidth : Length = 10 [mm];
            attribute chipHeight : Length = 10 [mm];
            attribute surfacePotential : Voltage;

            part substrate : SemiconductorSubstrate;
            part insulator : InsulatingLayer;
            part membrane : IonSensitiveMembrane;

            in port analytePort : Analyte;
            in port opticalPort : FocusedLightBeam;
            in port referenceIn : Voltage;
            out port photocurrentOut : Photocurrent;

            action def generatePhotocurrent {
                in light : FocusedLightBeam;
                in potential : Voltage;
                out current : Photocurrent;
            }
        }

        part def PhotodetectionCircuit {
            attribute transimpedanceGain : Resistance = 1000000 [V_per_A];
            attribute bandwidth : Frequency = 100 [kHz];
            attribute noiseFloor : ElectricCurrent = 10 [pA];

            in port currentIn : Photocurrent;
            out port voltageOut : Voltage;

            action def convertCurrentToVoltage {
                in current : Photocurrent;
                out voltage : Voltage;
            }
        }

        part def LockInAmplifier {
            attribute timeConstant : Time = 100 [ms];
            attribute filterSlope : Integer = 24;
            attribute sensitivity : Voltage;
            attribute referenceFrequency : Frequency;

            in port signalIn : Voltage;
            in port referenceIn : ModulationReference;
            out port signalOut : LockInOutput;

            action def demodulate {
                in signal : Voltage;
                in reference : ModulationReference;
                out result : LockInOutput;
            }
        }

        part def DataProcessor {
            attribute averagingCount : Integer = 1;
            attribute calibrationData : CalibrationData;
            attribute measurementsReceived : Integer = 0;

            in port measurementIn : LockInOutput[0..*];
            in port positionIn : ScanPosition[0..*];
            in port commandIn : SystemCommand;
            out port mapOut : SurfacePotentialMap;
            out port resultOut : ConcentrationResult;
            out port statusOut : SystemStatus;

            action def assembleMap {
                in samples : LockInOutput[0..*];
                in positions : ScanPosition[0..*];
                out map : SurfacePotentialMap;
            }

            action def computeConcentration {
                in map : SurfacePotentialMap;
                in calibration : CalibrationData;
                out result : ConcentrationResult;
            }
        }
    }

    package System {
        import ScalarValues::*;
        import Components::*;
        import Items::*;
        import Measures::*;

        part def LAPSDevice {
            attribute deviceName : String = "LAPS-200";
            attribute manufacturer : String = "LabInc";
            attribute serialNumber : String;
            attribute firmwareVersion : String = "1.0";
            attribute powerOn : Boolean = false;
            attribute calibrationValid : Boolean = false;
            attribute measurementComplete : Boolean = false;
            attribute processingComplete : Boolean = false;
            attribute currentCommand : SystemCommand;
            attribute faultDetected : Boolean = false;

            part lightSource : LightSource;
            part opticalSystem : OpticalSystem;
            part scanningController : ScanningController;
            part referenceElectrode : ReferenceElectrode;
            part sensorChip : SensorChip;
            part photodetectionCircuit : PhotodetectionCircuit;
            part lockInAmplifier : LockInAmplifier;
            part dataProcessor : DataProcessor;

            in port analytePort : Analyte;
            in port commandPort : SystemCommand;
            out port statusPort : SystemStatus;
            out port resultPort : ConcentrationResult;
            out port mapPort : SurfacePotentialMap;

            connect lightSource.lightOut to opticalSystem.lightIn;
            connect scanningController.positionOut to opticalSystem.scanControlIn;
            connect opticalSystem.lightOut to sensorChip.opticalPort;
            connect scanningController.referenceOut to lockInAmplifier.referenceIn;
            connect scanningController.positionOut to dataProcessor.positionIn;
            connect referenceElectrode.referenceOut to sensorChip.referenceIn;
            connect analytePort to referenceElectrode.analyteIn;
            connect analytePort to sensorChip.analytePort;
            connect sensorChip.photocurrentOut to photodetectionCircuit.currentIn;
            connect photodetectionCircuit.voltageOut to lockInAmplifier.signalIn;
            connect lockInAmplifier.signalOut to dataProcessor.measurementIn;
            connect dataProcessor.resultOut to resultPort;
            connect dataProcessor.mapOut to mapPort;
            connect dataProcessor.statusOut to statusPort;
            connect commandPort to dataProcessor.commandIn;

            state machine LAPSStateMachine {
                state Off {
                    doc /* System powered off and idle. */;
                }
                state Initializing {
                    doc /* Performing self-test and configuration. */;
                }
                state Calibrating {
                    doc /* Acquiring calibration data with known reference solutions. */;
                }
                state Measuring {
                    doc /* Actively scanning the sensor surface and collecting photocurrent. */;
                }
                state Processing {
                    doc /* Building the 2D surface potential map and computing concentration. */;
                }
                state Ready {
                    doc /* Calibration valid and ready for next measurement. */;
                }
                state Error {
                    doc /* Fault condition; reset required. */;
                }

                transition powerOnInit from Off to Initializing {
                    guard currentCommand.command == "powerOn";
                }
                transition initDone from Initializing to Calibrating {
                    guard lightSource.enabled and not calibrationValid;
                }
                transition calDone from Calibrating to Ready {
                    guard dataProcessor.calibrationData.valid;
                }
                transition startMeasure from Ready to Measuring {
                    guard currentCommand.command == "measure";
                }
                transition measureDone from Measuring to Processing {
                    guard scanningController.scanComplete;
                }
                transition processingDone from Processing to Ready {
                    guard dataProcessor.resultOut.valid;
                }
                transition initError from Initializing to Error {
                    guard faultDetected;
                }
                transition measureError from Measuring to Error {
                    guard faultDetected;
                }
                transition processError from Processing to Error {
                    guard faultDetected;
                }
                transition resetFromError from Error to Off {
                    guard currentCommand.command == "reset";
                }
            }
        }
    }

    package Requirements {
        import ScalarValues::*;
        import System::*;
        import Components::*;
        import Items::*;
        import Measures::*;

        requirement def LAPS_Overall {
            subject lapsDevice : LAPSDevice;
            doc /* The LAPS shall measure ion concentration in a liquid sample and produce a 2D chemical map. */;
            attribute purpose : String = "High-resolution potentiometric chemical imaging";
        }

        requirement def SpatialResolutionReq {
            subject lapsDevice : LAPSDevice;
            doc /* The system shall achieve at least 100x100 spatial resolution across a 10x10 mm area. */;
            attribute minPointsX : Integer = 100;
            attribute minPointsY : Integer = 100;
            attribute minScanArea : Area = 100 [mm2];
        }

        requirement def MultiLayerChipReq {
            subject sensorChip : SensorChip;
            doc /* The sensor chip shall consist of a semiconductor substrate, insulating layer, and ion-sensitive membrane. */;
        }

        requirement def PhotocurrentReq {
            subject sensorChip : SensorChip;
            doc /* The photocurrent at each scan point shall be modulated by the local surface potential. */;
            attribute minPhotocurrent : Photocurrent = 100 [pA];
        }

        requirement def ScanningReq {
            subject scanningController : ScanningController;
            doc /* The scanning controller shall direct the modulated light beam across the sensor surface in a 2D pattern. */;
            attribute maxDwellTime : Time = 100 [ms];
            attribute minScanRate : Frequency = 10 [Hz];
        }

        requirement def LockInDetectionReq {
            subject lockInAmplifier : LockInAmplifier;
            doc /* The lock-in amplifier shall extract the weak photocurrent using the light modulation as reference. */;
            attribute minSNR : Dimensionless = 100;
            attribute maxTimeConstant : Time = 500 [ms];
        }

        requirement def ReferenceStabilityReq {
            subject referenceElectrode : ReferenceElectrode;
            doc /* The reference electrode shall provide a stable voltage baseline for potentiometric measurement. */;
            attribute maxDrift : DriftRate = 1 [mV_per_h];
            attribute referenceType : String = "Ag/AgCl";
        }

        requirement def CalibrationReq {
            subject dataProcessor : DataProcessor;
            doc /* The data processor shall apply calibration data to convert surface potential to concentration. */;
            attribute minCalPoints : Integer = 3;
        }

        requirement def StateControlReq {
            subject lapsDevice : LAPSDevice;
            doc /* The system shall implement distinct states: initialization, calibration, active measurement, data processing, ready, and error. */;
            attribute requiredStates : String = "Off, Initializing, Calibrating, Measuring, Processing, Ready, Error";
        }

        requirement def ConcentrationOutputReq {
            subject lapsDevice : LAPSDevice;
            doc /* The system shall output a 2D surface potential map and a calculated overall analyte concentration. */;
            attribute outputMapType : String = "SurfacePotentialMap";
            attribute outputResultType : String = "ConcentrationResult";
        }

        requirement def ModulationReq {
            subject lightSource : LightSource;
            doc /* The light beam shall be modulated at a known frequency referenced by the lock-in amplifier. */;
            attribute typicalModulation : Frequency = 1000 [Hz];
        }
    }
}

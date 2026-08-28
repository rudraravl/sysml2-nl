package DigitalRadiographySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value def Voltage :> Real { unit 'kV' }
    value def Current :> Real { unit 'mA' }
    value def Power :> Real { unit 'kW' }
    value def Temperature :> Real { unit 'degC' }
    value def FlowRate :> Real { unit 'L/min' }
    value def Dose :> Real { unit 'mGy' }
    value def DoseAreaProduct :> Real { unit 'mGy*cm2' }
    value def ExposureTime :> Real { unit 'ms' }
    value def Distance :> Real { unit 'cm' }
    value def Angle :> Real { unit 'deg' }
    value def PixelData :> Integer;
    value def ImageMatrix [n, m] :> Integer;
    value def DataRate :> Real { unit 'MB/s' }

    // ---------- Items ----------
    item def Coolant {
        attribute mixture : String = "water-glycol";
        attribute temperature : Temperature;
    }
    item def XRayBeam {
        attribute energy : Voltage;
        attribute intensity : Current;
        attribute duration : ExposureTime;
        attribute collimated : Boolean;
    }
    item def RawImage {
        attribute matrix : ImageMatrix;
        attribute resolution : Integer;
        attribute bitDepth : Integer;
    }
    item def ProcessedImage {
        attribute matrix : ImageMatrix;
        attribute windowLevel : Integer;
        attribute windowWidth : Integer;
        attribute appliedFilters : String[*];
    }
    item def DoseReport {
        attribute patientId : String;
        attribute studyId : String;
        attribute cumulativeDose : Dose;
        attribute doseAreaProduct : DoseAreaProduct;
        attribute timestamp : DateTime;
    }
    item def ExposureParameters {
        attribute kVp : Voltage;
        attribute mA : Current;
        attribute exposureTime : ExposureTime;
        attribute focusSpotSize : Distance;
        attribute protocolName : String;
    }
    item def PatientPosition {
        attribute tableHeight : Distance;
        attribute tableLateral : Distance;
        attribute tableLongitudinal : Distance;
        attribute tubeAngle : Angle;
    }

    // ---------- Port Definitions ----------
    port def ElectricalPowerPort {
        out attribute voltage : Voltage;
        out attribute current : Current;
        out attribute power : Power;
    }
    port def CoolantFlowPort {
        out item coolant : Coolant;
        in item returnCoolant : Coolant;
    }
    port def XRayPort {
        out item beam : XRayBeam;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
        out attribute feedback : Real;
    }
    port def DataPort {
        out item rawImage : RawImage;
        out item processedImage : ProcessedImage;
        out item doseReport : DoseReport;
    }
    port def NetworkPort {
        out item image : ProcessedImage;
        out item report : DoseReport;
    }

    // ---------- Component Parts ----------

    part def HighVoltageGenerator {
        port powerOut : ElectricalPowerPort;
        port controlIn : ControlPort;
        attribute maxPower : Power = 80.0;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute status : String = "idle";

        action def generatePower(in kVp : Voltage, in mA : Current, out v : Voltage, out c : Current) {
            v := kVp;
            c := mA;
        }
    }

    part def XRayTube {
        port powerIn : ElectricalPowerPort;
        port beamOut : XRayPort;
        port thermalOut : CoolantFlowPort;
        port controlIn : ControlPort;
        attribute anodeTemperature : Temperature;
        attribute maxTemperature : Temperature = 200.0;
        attribute focusSpotSize : Distance;
        attribute status : String = "idle";

        action def produceXRay(in power : Power, in duration : ExposureTime, out beam : XRayBeam) {
            beam.energy := powerIn.voltage;
            beam.intensity := powerIn.current;
            beam.duration := duration;
            beam.collimated := false;
        }
    }

    part def CoolingSystem {
        port coolantOut : CoolantFlowPort;
        port coolantReturn : CoolantFlowPort;
        port controlIn : ControlPort;
        attribute coolantFlowRate : FlowRate;
        attribute coolantTemperature : Temperature;
        attribute radiatorFanSpeed : Integer;
        attribute status : String = "idle";

        action def circulateCoolant(in heatLoad : Power, out flow : FlowRate) {
            flow := heatLoad * 0.05;
        }
    }

    part def BeamCollimator {
        port beamIn : XRayPort;
        port beamOut : XRayPort;
        port controlIn : ControlPort;
        attribute bladePositionX : Distance;
        attribute bladePositionY : Distance;
        attribute fieldSize : Distance;
        attribute status : String = "idle";

        action def collimateBeam(in beam : XRayBeam, in fieldX : Distance, in fieldY : Distance, out collimated : XRayBeam) {
            collimated := beam;
            collimated.collimated := true;
        }
    }

    part def PatientPositioningTable {
        port controlIn : ControlPort;
        attribute height : Distance;
        attribute lateralPosition : Distance;
        attribute longitudinalPosition : Distance;
        attribute maxWeight : Real = 250.0;
        attribute status : String = "idle";

        action def positionPatient(in heightCmd : Distance, in latCmd : Distance, in longCmd : Distance) {
            height := heightCmd;
            lateralPosition := latCmd;
            longitudinalPosition := longCmd;
        }
    }

    part def DigitalDetector {
        port beamIn : XRayPort;
        port dataOut : DataPort;
        port controlIn : ControlPort;
        attribute pixelPitch : Distance = 0.0139;
        attribute matrixSize : Integer = 2048;
        attribute bitDepth : Integer = 16;
        attribute conversionEfficiency : Real = 0.85;
        attribute status : String = "idle";

        action def captureImage(in beam : XRayBeam, out raw : RawImage) {
            raw.resolution := matrixSize;
            raw.bitDepth := bitDepth;
        }
    }

    part def ImageProcessingUnit {
        port dataIn : DataPort;
        port dataOut : DataPort;
        port controlIn : ControlPort;
        attribute calibrationData : ImageMatrix;
        attribute processingAlgorithms : String[*] = ["flat-field", "noise-reduction", "edge-enhancement", "contrast-normalization"];
        attribute status : String = "idle";

        action def processImage(in raw : RawImage, out processed : ProcessedImage) {
            processed.matrix := raw.matrix;
            processed.windowLevel := 2048;
            processed.windowWidth := 4096;
            processed.appliedFilters := processingAlgorithms;
        }
    }

    part def DoseManagementSystem {
        port controlIn : ControlPort;
        port dataOut : DataPort;
        attribute estimatedDose : Dose;
        attribute cumulativeDose : Dose;
        attribute doseAreaProduct : DoseAreaProduct;
        attribute alaraThreshold : Dose = 5.0;
        attribute status : String = "idle";

        action def estimateDose(in params : ExposureParameters, out dose : Dose) {
            dose := params.kVp * params.mA * params.exposureTime * 0.00001;
        }

        action def monitorDose(in delivered : Dose) {
            cumulativeDose := cumulativeDose + delivered;
        }

        action def generateReport(out report : DoseReport) {
            report.cumulativeDose := cumulativeDose;
            report.doseAreaProduct := doseAreaProduct;
        }
    }

    part def OperatorWorkstation {
        port controlOut : ControlPort;
        port dataIn : DataPort;
        port networkOut : NetworkPort;
        port displayOut : DataPort;
        attribute selectedProtocol : String;
        attribute exposureParams : ExposureParameters;
        attribute displayActive : Boolean;
        attribute status : String = "idle";

        action def selectProtocol(in name : String, out params : ExposureParameters) {
            selectedProtocol := name;
            params.protocolName := name;
        }

        action def initiateExposure() {}

        action def reviewImage(in image : ProcessedImage) {}

        action def archiveToNetwork(in image : ProcessedImage, in report : DoseReport) {}
    }

    // ---------- System ----------
    part def DigitalRadiographySystem {
        port operatorInterface : ControlPort;
        port hospitalNetwork : NetworkPort;
        port powerInput : ElectricalPowerPort;

        part highVoltageGenerator : HighVoltageGenerator {
            port powerOut : ElectricalPowerPort;
            port controlIn : ControlPort;
        }
        part xrayTube : XRayTube {
            port powerIn : ElectricalPowerPort;
            port beamOut : XRayPort;
            port thermalOut : CoolantFlowPort;
            port controlIn : ControlPort;
        }
        part coolingSystem : CoolingSystem {
            port coolantOut : CoolantFlowPort;
            port coolantReturn : CoolantFlowPort;
            port controlIn : ControlPort;
        }
        part beamCollimator : BeamCollimator {
            port beamIn : XRayPort;
            port beamOut : XRayPort;
            port controlIn : ControlPort;
        }
        part patientTable : PatientPositioningTable {
            port controlIn : ControlPort;
        }
        part digitalDetector : DigitalDetector {
            port beamIn : XRayPort;
            port dataOut : DataPort;
            port controlIn : ControlPort;
        }
        part imageProcessingUnit : ImageProcessingUnit {
            port dataIn : DataPort;
            port dataOut : DataPort;
            port controlIn : ControlPort;
        }
        part doseManagement : DoseManagementSystem {
            port controlIn : ControlPort;
            port dataOut : DataPort;
        }
        part operatorWorkstation : OperatorWorkstation {
            port controlOut : ControlPort;
            port dataIn : DataPort;
            port networkOut : NetworkPort;
            port displayOut : DataPort;
        }

        // Connections
        connection powerInputToGenerator connect powerInput to highVoltageGenerator.powerOut;
        connection generatorToTube connect highVoltageGenerator.powerOut to xrayTube.powerIn;
        connection tubeToCollimator connect xrayTube.beamOut to beamCollimator.beamIn;
        connection collimatorToDetector connect beamCollimator.beamOut to digitalDetector.beamIn;
        connection detectorToProcessor connect digitalDetector.dataOut to imageProcessingUnit.dataIn;
        connection processorToWorkstation connect imageProcessingUnit.dataOut to operatorWorkstation.dataIn;
        connection doseToWorkstation connect doseManagement.dataOut to operatorWorkstation.dataIn;
        connection workstationToNetwork connect operatorWorkstation.networkOut to hospitalNetwork;
        connection workstationControl connect operatorWorkstation.controlOut to operatorInterface;
        connection tubeCoolantOut connect xrayTube.thermalOut to coolingSystem.coolantReturn;
        connection coolingCoolantOut connect coolingSystem.coolantOut to xrayTube.thermalOut;

        // Control bus connections
        connection ctrlGenerator connect operatorWorkstation.controlOut to highVoltageGenerator.controlIn;
        connection ctrlTube connect operatorWorkstation.controlOut to xrayTube.controlIn;
        connection ctrlCollimator connect operatorWorkstation.controlOut to beamCollimator.controlIn;
        connection ctrlTable connect operatorWorkstation.controlOut to patientTable.controlIn;
        connection ctrlDetector connect operatorWorkstation.controlOut to digitalDetector.controlIn;
        connection ctrlProcessor connect operatorWorkstation.controlOut to imageProcessingUnit.controlIn;
        connection ctrlDose connect operatorWorkstation.controlOut to doseManagement.controlIn;
        connection ctrlCooling connect operatorWorkstation.controlOut to coolingSystem.controlIn;

        // ---------- State Machine ----------
        state machine SystemStateMachine {
            entry;
            then standby;

            state standby {
                entry {
                    highVoltageGenerator.status := "idle";
                    xrayTube.status := "idle";
                    coolingSystem.status := "idle";
                    digitalDetector.status := "idle";
                    imageProcessingUnit.status := "idle";
                    doseManagement.status := "idle";
                    operatorWorkstation.status := "standby";
                }
            }

            transition standby_to_preparation
                from standby
                to preparation
                when operatorWorkstation.selectedProtocol != null;

            state preparation {
                entry {
                    operatorWorkstation.status := "preparation";
                    patientTable.positionPatient(
                        operatorWorkstation.exposureParams.kVp,
                        0.0,
                        0.0
                    );
                    beamCollimator.fieldSize := 20.0;
                    doseManagement.estimateDose(
                        operatorWorkstation.exposureParams,
                        doseManagement.estimatedDose
                    );
                }
            }

            transition preparation_to_ready
                from preparation
                to ready
                when doseManagement.estimatedDose < doseManagement.alaraThreshold;

            transition preparation_to_emergency
                from preparation
                to emergency
                when doseManagement.estimatedDose >= doseManagement.alaraThreshold;

            state ready {
                entry {
                    highVoltageGenerator.status := "ready";
                    xrayTube.status := "ready";
                    digitalDetector.status := "ready";
                    operatorWorkstation.status := "ready";
                }
            }

            transition ready_to_exposing
                from ready
                to exposing
                when operatorWorkstation.initiateExposure().isInvoked;

            state exposing {
                entry {
                    highVoltageGenerator.generatePower(
                        operatorWorkstation.exposureParams.kVp,
                        operatorWorkstation.exposureParams.mA,
                        highVoltageGenerator.outputVoltage,
                        highVoltageGenerator.outputCurrent
                    );
                    xrayTube.produceXRay(
                        highVoltageGenerator.powerOut.power,
                        operatorWorkstation.exposureParams.exposureTime,
                        xrayTube.beamOut.beam
                    );
                    beamCollimator.collimateBeam(
                        xrayTube.beamOut.beam,
                        beamCollimator.bladePositionX,
                        beamCollimator.bladePositionY,
                        beamCollimator.beamOut.beam
                    );
                    coolingSystem.circulateCoolant(
                        highVoltageGenerator.powerOut.power,
                        coolingSystem.coolantFlowRate
                    );
                    doseManagement.monitorDose(doseManagement.estimatedDose);
                }
            }

            transition exposing_to_acquiring
                from exposing
                to acquiring
                after 200 [ms];

            state acquiring {
                entry {
                    digitalDetector.captureImage(
                        beamCollimator.beamOut.beam,
                        digitalDetector.dataOut.rawImage
                    );
                    digitalDetector.status := "acquiring";
                }
            }

            transition acquiring_to_processing
                from acquiring
                to processing
                when digitalDetector.dataOut.rawImage != null;

            state processing {
                entry {
                    imageProcessingUnit.processImage(
                        digitalDetector.dataOut.rawImage,
                        imageProcessingUnit.dataOut.processedImage
                    );
                    imageProcessingUnit.status := "processing";
                }
            }

            transition processing_to_review
                from processing
                to review
                when imageProcessingUnit.dataOut.processedImage != null;

            state review {
                entry {
                    operatorWorkstation.reviewImage(
                        imageProcessingUnit.dataOut.processedImage
                    );
                    operatorWorkstation.displayOut.processedImage := imageProcessingUnit.dataOut.processedImage;
                    doseManagement.generateReport(doseManagement.dataOut.doseReport);
                    operatorWorkstation.status := "review";
                }
            }

            transition review_to_archived
                from review
                to archived
                when operatorWorkstation.displayActive == true;

            state archived {
                entry {
                    operatorWorkstation.archiveToNetwork(
                        imageProcessingUnit.dataOut.processedImage,
                        doseManagement.dataOut.doseReport
                    );
                    operatorWorkstation.status := "archived";
                }
            }

            transition archived_to_standby
                from archived
                to standby;

            state emergency {
                entry {
                    highVoltageGenerator.status := "shutdown";
                    xrayTube.status := "shutdown";
                    coolingSystem.status := "max-cooling";
                    operatorWorkstation.status := "emergency";
                    doseManagement.status := "alert";
                }
            }

            transition emergency_to_standby
                from emergency
                to standby
                when operatorWorkstation.status == "reset";
        }

        // ---------- Requirements ----------
        requirement def SafetyRequirement {
            doc "The system must ensure patient radiation dose remains within ALARA limits."
            attribute maxSingleDose : Dose = 5.0;
            attribute maxCumulativeDose : Dose = 50.0;
            require doseManagement.cumulativeDose <= maxCumulativeDose;
        }

        requirement def ImageQualityRequirement {
            doc "The system must produce diagnostic-quality images with minimum resolution."
            attribute minResolution : Integer = 2048;
            attribute minBitDepth : Integer = 16;
            require digitalDetector.matrixSize >= minResolution;
            require digitalDetector.bitDepth >= minBitDepth;
        }

        requirement def ThermalManagementRequirement {
            doc "The cooling system must maintain tube temperature below maximum limit."
            require xrayTube.anodeTemperature <= xrayTube.maxTemperature;
        }

        requirement def BeamCollimationRequirement {
            doc "The collimator must restrict the beam to the selected field size."
            require beamCollimator.beamOut.beam.collimated == true;
        }

        requirement def NetworkArchiveRequirement {
            doc "The system must archive processed images and dose reports to the hospital network."
            require operatorWorkstation.networkOut.image != null;
            require operatorWorkstation.networkOut.report != null;
        }

        requirement def SystemResponseTimeRequirement {
            doc "The system must complete exposure and image acquisition within specified time."
            attribute maxExposureToAcquire : ExposureTime = 500;
            require true;
        }

        satisfy SafetyRequirement by SystemStateMachine;
        satisfy ImageQualityRequirement by digitalDetector;
        satisfy ThermalManagementRequirement by coolingSystem;
        satisfy BeamCollimationRequirement by beamCollimator;
        satisfy NetworkArchiveRequirement by operatorWorkstation;
    }
}

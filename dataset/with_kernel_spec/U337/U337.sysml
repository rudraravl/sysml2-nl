package OEP_System {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def StartCalibrationSignal;
    attribute def CalibrationCompleteSignal;
    attribute def AlertDetectedSignal;
    attribute def AlertResolvedSignal;
    attribute def StopMonitoringSignal;

    item def Coordinate3D {
        attribute x :> ISQ::length;
        attribute y :> ISQ::length;
        attribute z :> ISQ::length;
    }

    item def VideoFrame;

    item def MarkerData {
        attribute id : Integer;
        attribute position : Coordinate3D;
    }

    item def VolumeData {
        attribute ribCageVolume :> ISQ::volume;
        attribute abdominalVolume :> ISQ::volume;
    }

    item def RespiratoryMetrics {
        attribute tidalVolume :> ISQ::volume;
        attribute respiratoryRate :> ISQ::frequency;
        attribute minuteVentilation : Real;
    }

    item def AlertSignal {
        attribute isActive : Boolean;
        attribute message : String;
    }

    item def ControlCommand {
        attribute command : String;
    }

    item def ElectricalPower {
        attribute value :> ISQ::power;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }
    port def PowerInPort {
        in power : ElectricalPower;
    }
    port def VideoOutPort {
        out frame : VideoFrame;
    }
    port def VideoInPort {
        in frame : VideoFrame;
    }
    port def MarkerOutPort {
        out markers : MarkerData[89];
    }
    port def MarkerInPort {
        in markers : MarkerData[89];
    }
    port def VolumeOutPort {
        out data : VolumeData;
    }
    port def VolumeInPort {
        in data : VolumeData;
    }
    port def MetricsOutPort {
        out metrics : RespiratoryMetrics;
        out alert : AlertSignal;
    }
    port def MetricsInPort {
        in metrics : RespiratoryMetrics;
        in alert : AlertSignal;
    }
    port def ControlOutPort {
        out cmd : ControlCommand;
    }
    port def ControlInPort {
        in cmd : ControlCommand;
    }

    part def Marker {
        attribute id : Integer;
    }

    part def Patient {
        part markers : Marker[89];
    }

    part def InfraredLightSource {
        port powerIn : PowerInPort;
    }

    part def InfraredCamera {
        port powerIn : PowerInPort;
        port videoOut : VideoOutPort;
    }

    part def ImageProcessingUnit {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port videoIn : VideoInPort[8];
        port markerOut : MarkerOutPort;

        action def ProcessImages {
            in frames : VideoFrame[8];
            out markers : MarkerData[89];
        }
    }

    part def VolumeComputationUnit {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port markerIn : MarkerInPort;
        port volumeOut : VolumeOutPort;

        action def ComputeVolumes {
            in markers : MarkerData[89];
            out volume : VolumeData;
        }
    }

    part def RespiratoryAnalysisUnit {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port volumeIn : VolumeInPort;
        port metricsOut : MetricsOutPort;

        action def AnalyzeRespiration {
            in volume : VolumeData;
            out metrics : RespiratoryMetrics;
            out alert : AlertSignal;
        }
    }

    state def ControllerStates;

    part def CentralController {
        port powerIn : PowerInPort;
        port controlOut : ControlOutPort;
        port metricsIn : MetricsInPort;

        state controllerStates : ControllerStates {
            entry; then offline;
            state offline;
            accept StartCalibrationSignal then calibrating;
            state calibrating;
            accept CalibrationCompleteSignal then monitoring;
            state monitoring;
            accept AlertDetectedSignal then alerting;
            accept StopMonitoringSignal then offline;
            state alerting;
            accept AlertResolvedSignal then monitoring;
        }
    }

    part def DisplayMonitor {
        port powerIn : PowerInPort;
        port displayIn : MetricsInPort;
    }

    part def PowerSupply {
        port powerOut : PowerOutPort;
    }

    part def OEPSystem {
        part patient : Patient;
        part lightSources : InfraredLightSource[8];
        part cameras : InfraredCamera[8];
        part imageProcessor : ImageProcessingUnit;
        part volumeComputer : VolumeComputationUnit;
        part respiratoryAnalyzer : RespiratoryAnalysisUnit;
        part controller : CentralController;
        part display : DisplayMonitor;
        part powerSupply : PowerSupply;

        connect powerSupply.powerOut to lightSources.powerIn;
        connect powerSupply.powerOut to cameras.powerIn;
        connect powerSupply.powerOut to imageProcessor.powerIn;
        connect powerSupply.powerOut to volumeComputer.powerIn;
        connect powerSupply.powerOut to respiratoryAnalyzer.powerIn;
        connect powerSupply.powerOut to controller.powerIn;
        connect powerSupply.powerOut to display.powerIn;

        connect cameras.videoOut to imageProcessor.videoIn;
        connect imageProcessor.markerOut to volumeComputer.markerIn;
        connect volumeComputer.volumeOut to respiratoryAnalyzer.volumeIn;
        connect respiratoryAnalyzer.metricsOut to controller.metricsIn;
        connect respiratoryAnalyzer.metricsOut to display.displayIn;
        connect controller.controlOut to imageProcessor.controlIn;
        connect controller.controlOut to volumeComputer.controlIn;
        connect controller.controlOut to respiratoryAnalyzer.controlIn;
    }

    part oepSystem : OEPSystem;

    requirement TidalVolumeRequirement {
        doc /* The system shall compute tidal volume for each breath. */
    }
    requirement RespiratoryRateRequirement {
        doc /* The system shall compute respiratory rate in breaths per minute. */
    }
    requirement MinuteVentilationRequirement {
        doc /* The system shall compute minute ventilation. */
    }
    requirement AlertRequirement {
        doc /* The system shall trigger an alert if abnormal breathing patterns are detected. */
    }
    requirement MarkerCountRequirement {
        doc /* The system shall use 89 reflective markers on the patient torso. */
    }

    satisfy TidalVolumeRequirement by oepSystem.respiratoryAnalyzer;
    satisfy RespiratoryRateRequirement by oepSystem.respiratoryAnalyzer;
    satisfy MinuteVentilationRequirement by oepSystem.respiratoryAnalyzer;
    satisfy AlertRequirement by oepSystem.respiratoryAnalyzer;
    satisfy MarkerCountRequirement by oepSystem.patient;
}
